import "server-only";
import type { PoolClient } from "pg";
import type { Locale } from "@/lib/i18n/config";
import { mutationExecution, type ServerMutationExecution } from "@/lib/server/mutation-execution";
import {
  withAuthorizedUserTransaction,
  type AuthorizationFailureReason,
} from "@/modules/account/authorization";
import {
  createEmptyEvidencePayload,
  evidencePayloadsEqual,
  evaluateEvidenceArtifactPayload,
  getEvidenceArtifactContract,
  parseEvidenceArtifactPayload,
  parseEvidenceLifecycleInput,
  parseEvidenceSaveInput,
  parseEvidenceStartInput,
} from "@/modules/evidence/contract";
import { createEvidenceFeedback } from "@/modules/evidence/view";
import {
  EVIDENCE_ARTIFACT_TYPE,
  EVIDENCE_ARTIFACT_CONTRACT_ID,
  EVIDENCE_ARTIFACT_CONTRACT_VERSION,
  EVIDENCE_CLASSIFICATION,
  EVIDENCE_COMPETENCY_RELATIONSHIP,
  EVIDENCE_SOURCE_PACK_ID,
  EVIDENCE_SOURCE_PROOF_ID,
  EVIDENCE_SOURCE_PROOF_VERSION,
  EVIDENCE_VALIDATION_STATUS,
  type EvidenceArtifactPayload,
  type EvidenceArtifactStatus,
  type EvidenceLifecycleInput,
  type EvidenceSaveInput,
} from "@/modules/evidence/types";
import type { IdentityProvider } from "@/modules/identity/contract";
import { createClerkDevelopmentIdentityProvider } from "@/modules/identity/providers/clerk/server";
import { getPersistedLessonMetadata } from "@/modules/lesson/persistence/contract";
import { PRIVACY_NOTICE_VERSION, SERVICE_DATA_PURPOSE } from "@/modules/consent/notice";

type ArtifactRow = {
  id: unknown;
  status: unknown;
  start_mutation_id: unknown;
  start_mutation_locale: unknown;
  ready_mutation_id: unknown;
  ready_mutation_locale: unknown;
  ready_expected_revision: unknown;
  withdraw_mutation_id: unknown;
  withdraw_mutation_locale: unknown;
  withdraw_expected_revision: unknown;
};

type RevisionRow = {
  id: unknown;
  revision: unknown;
  payload: unknown;
  client_mutation_id: unknown;
  mutation_intent: unknown;
  mutation_locale: unknown;
  mutation_expected_revision: unknown;
};

type SourceContext = Readonly<{
  consentId: string;
  lessonAttemptId: string;
  practiceAttemptId: string;
  frameworkVersionId: string;
  competencyVersionId: string;
}>;

export type EvidenceArtifactClientState = Readonly<{
  status: EvidenceArtifactStatus;
  revision: number;
  payload: EvidenceArtifactPayload;
  feedback: ReturnType<typeof createEvidenceFeedback>;
}>;

export type EvidencePageState =
  | Readonly<{ state: "denied"; reason: AuthorizationFailureReason }>
  | Readonly<{ state: "consent-required" }>
  | Readonly<{ state: "unavailable" }>
  | Readonly<{ state: "not-started" }>
  | Readonly<{ state: "artifact"; artifact: EvidenceArtifactClientState }>;

export type EvidenceMutationResult =
  | Readonly<{ state: "saved" | "ready" | "withdrawn"; artifact: EvidenceArtifactClientState }>
  | Readonly<{ state: "conflict" | "not-ready" | "denied" }>;

function stringValue(value: unknown, label: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`Evidence ${label} is invalid.`);
  }
  return value;
}

function integerValue(value: unknown, label: string): number {
  if (!Number.isInteger(value) || (value as number) < 0) {
    throw new Error(`Evidence ${label} is invalid.`);
  }
  return value as number;
}

function nullableString(value: unknown, label: string): string | null {
  return value === null ? null : stringValue(value, label);
}

function nullableInteger(value: unknown, label: string): number | null {
  return value === null ? null : integerValue(value, label);
}

function parseArtifact(row: ArtifactRow | undefined) {
  if (!row) return null;
  if (row.status !== "draft" && row.status !== "ready" && row.status !== "withdrawn") {
    throw new Error("Evidence artifact status is invalid.");
  }
  return {
    id: stringValue(row.id, "artifact ID"),
    status: row.status,
    startMutationId: stringValue(row.start_mutation_id, "start mutation ID"),
    startMutationLocale: stringValue(row.start_mutation_locale, "start mutation locale"),
    readyMutationId: nullableString(row.ready_mutation_id, "ready mutation ID"),
    readyMutationLocale: nullableString(row.ready_mutation_locale, "ready mutation locale"),
    readyExpectedRevision: nullableInteger(row.ready_expected_revision, "ready revision"),
    withdrawMutationId: nullableString(row.withdraw_mutation_id, "withdraw mutation ID"),
    withdrawMutationLocale: nullableString(
      row.withdraw_mutation_locale,
      "withdraw mutation locale",
    ),
    withdrawExpectedRevision: nullableInteger(row.withdraw_expected_revision, "withdraw revision"),
  } as const;
}

function parseRevision(row: RevisionRow | undefined) {
  if (!row) return null;
  if (row.mutation_intent !== "save") throw new Error("Evidence mutation intent is invalid.");
  return {
    id: stringValue(row.id, "revision ID"),
    revision: integerValue(row.revision, "revision"),
    payload: parseEvidenceArtifactPayload(row.payload),
    clientMutationId: stringValue(row.client_mutation_id, "revision mutation ID"),
    mutationIntent: "save" as const,
    mutationLocale: stringValue(row.mutation_locale, "revision locale"),
    mutationExpectedRevision: integerValue(row.mutation_expected_revision, "expected revision"),
  };
}

async function currentConsent(client: PoolClient, userId: string): Promise<string | null> {
  const result = await client.query<{ id: unknown; decision: unknown }>(
    `SELECT id, decision FROM consent_records
     WHERE user_id = $1 AND purpose_code = $2 AND notice_version = $3
     ORDER BY occurred_at DESC, id DESC LIMIT 1`,
    [userId, SERVICE_DATA_PURPOSE, PRIVACY_NOTICE_VERSION],
  );
  return result.rows[0]?.decision === "granted"
    ? stringValue(result.rows[0].id, "consent ID")
    : null;
}

async function resolveSourceContext(
  client: PoolClient,
  userId: string,
): Promise<SourceContext | "consent-required" | "unavailable"> {
  const consentId = await currentConsent(client, userId);
  if (!consentId) return "consent-required";
  const metadata = getPersistedLessonMetadata();
  const source = await client.query<{
    lesson_id: unknown;
    practice_id: unknown;
    framework_id: unknown;
    competency_id: unknown;
  }>(
    `SELECT la.id AS lesson_id, pa.id AS practice_id,
            fv.id AS framework_id, cv.id AS competency_id
     FROM lesson_attempts AS la
     JOIN practice_attempts AS pa
       ON pa.lesson_attempt_id = la.id AND pa.user_id = la.user_id
     JOIN framework_versions AS fv
       ON fv.framework_key = 'rise-pals-8-plus-2'
      AND fv.version = '2.0' AND fv.status = 'published'
     JOIN competency_versions AS cv
       ON cv.framework_version_id = fv.id
      AND cv.competency_key = 'critical-thinking-fact-checking' AND cv.kind = 'core'
     WHERE la.user_id = $1 AND la.status = 'demonstrated'
       AND la.lesson_key = $2 AND la.lesson_version_id = $3 AND la.lesson_version = $4
       AND la.lesson_digest = $5 AND la.practice_id = $6 AND la.practice_version = $7
       AND la.rubric_version_id = $8 AND la.rubric_version = $9
       AND la.evaluation_contract_version_id = $10
       AND pa.status = 'evaluated' AND pa.demonstrated = true
       AND NOT EXISTS (
         SELECT 1 FROM practice_attempts AS newer
         WHERE newer.lesson_attempt_id = pa.lesson_attempt_id
           AND newer.user_id = pa.user_id AND newer.revision > pa.revision
       )
     LIMIT 1`,
    [
      userId,
      metadata.lessonKey,
      metadata.lessonVersionId,
      metadata.lessonVersion,
      metadata.lessonDigest,
      metadata.practiceId,
      metadata.practiceVersion,
      metadata.rubricVersionId,
      metadata.rubricVersion,
      metadata.evaluationContractVersionId,
    ],
  );
  const row = source.rows[0];
  if (!row) return "unavailable";
  return {
    consentId,
    lessonAttemptId: stringValue(row.lesson_id, "source lesson ID"),
    practiceAttemptId: stringValue(row.practice_id, "source practice ID"),
    frameworkVersionId: stringValue(row.framework_id, "framework ID"),
    competencyVersionId: stringValue(row.competency_id, "competency ID"),
  };
}

async function findArtifact(client: PoolClient, userId: string, lock = false) {
  const result = await client.query<ArtifactRow>(
    `SELECT id, status, start_mutation_id, start_mutation_locale,
            ready_mutation_id, ready_mutation_locale, ready_expected_revision,
            withdraw_mutation_id, withdraw_mutation_locale, withdraw_expected_revision
     FROM evidence_artifacts
     WHERE user_id = $1 AND artifact_contract_id = $2 AND artifact_contract_version = $3
     ${lock ? "FOR UPDATE" : ""}`,
    [userId, EVIDENCE_ARTIFACT_CONTRACT_ID, EVIDENCE_ARTIFACT_CONTRACT_VERSION],
  );
  if (result.rows.length > 1) throw new Error("Evidence artifact identity is ambiguous.");
  return parseArtifact(result.rows[0]);
}

async function latestRevision(client: PoolClient, artifactId: string) {
  const result = await client.query<RevisionRow>(
    `SELECT id, revision, payload, client_mutation_id, mutation_intent,
            mutation_locale, mutation_expected_revision
     FROM evidence_artifact_revisions
     WHERE artifact_id = $1 ORDER BY revision DESC LIMIT 1`,
    [artifactId],
  );
  return parseRevision(result.rows[0]);
}

function clientState(
  locale: Locale,
  status: EvidenceArtifactStatus,
  revision: ReturnType<typeof parseRevision>,
): EvidenceArtifactClientState {
  const payload = revision?.payload ?? createEmptyEvidencePayload();
  return {
    status,
    revision: revision?.revision ?? 0,
    payload,
    feedback: createEvidenceFeedback(locale, payload),
  };
}

export async function loadEvidencePageState(
  locale: Locale,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<EvidencePageState> {
  const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    const context = await resolveSourceContext(client, userId);
    if (context === "consent-required") return { state: "consent-required" } as const;
    const artifact = await findArtifact(client, userId);
    if (artifact) {
      return {
        state: "artifact",
        artifact: clientState(locale, artifact.status, await latestRevision(client, artifact.id)),
      } as const;
    }
    if (context === "unavailable") return { state: "unavailable" } as const;
    return { state: "not-started" } as const;
  });
  return result.state === "authorized" ? result.value : { state: "denied", reason: result.reason };
}

export async function startEvidenceArtifact(
  rawInput: unknown,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<EvidenceMutationResult> {
  const input = parseEvidenceStartInput(rawInput);
  const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    const context = await resolveSourceContext(client, userId);
    if (context === "consent-required" || context === "unavailable") {
      return { state: "not-ready" } as const;
    }
    await client.query(
      `SELECT pg_advisory_xact_lock(hashtextextended('evidence-artifact:' || $1 || ':' || $2, 0))`,
      [userId, EVIDENCE_ARTIFACT_CONTRACT_ID],
    );
    const existing = await findArtifact(client, userId, true);
    if (existing) {
      const exactReplay =
        existing.startMutationId === input.clientMutationId &&
        existing.startMutationLocale === input.locale;
      if (existing.startMutationId === input.clientMutationId && !exactReplay) {
        return { state: "conflict" } as const;
      }
      return {
        state:
          existing.status === "ready"
            ? "ready"
            : existing.status === "withdrawn"
              ? "withdrawn"
              : "saved",
        artifact: clientState(
          input.locale,
          existing.status,
          await latestRevision(client, existing.id),
        ),
      } as const;
    }
    const contract = getEvidenceArtifactContract();
    const metadata = getPersistedLessonMetadata();
    const inserted = await client.query<{ id: string }>(
      `INSERT INTO evidence_artifacts
        (user_id, consent_record_id, source_lesson_attempt_id, source_practice_attempt_id,
         artifact_contract_id, artifact_contract_version, artifact_type,
         source_proof_id, source_proof_version, source_lesson_key, source_lesson_version,
         source_lesson_digest, source_pack_id, classification, validation_status,
         start_mutation_id, start_mutation_locale)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
       RETURNING id`,
      [
        userId,
        context.consentId,
        context.lessonAttemptId,
        context.practiceAttemptId,
        contract.id,
        contract.version,
        EVIDENCE_ARTIFACT_TYPE,
        EVIDENCE_SOURCE_PROOF_ID,
        EVIDENCE_SOURCE_PROOF_VERSION,
        metadata.lessonKey,
        metadata.lessonVersion,
        metadata.lessonDigest,
        EVIDENCE_SOURCE_PACK_ID,
        EVIDENCE_CLASSIFICATION,
        EVIDENCE_VALIDATION_STATUS,
        input.clientMutationId,
        input.locale,
      ],
    );
    await client.query(
      `INSERT INTO evidence_competency_links
        (user_id, artifact_id, framework_version_id, competency_version_id, relationship_code)
       VALUES ($1,$2,$3,$4,$5)`,
      [
        userId,
        inserted.rows[0]!.id,
        context.frameworkVersionId,
        context.competencyVersionId,
        EVIDENCE_COMPETENCY_RELATIONSHIP,
      ],
    );
    return {
      state: "saved",
      artifact: clientState(input.locale, "draft", null),
    } as const;
  });
  return result.state === "authorized" ? result.value : { state: "denied" };
}

function exactSaveReplay(
  input: EvidenceSaveInput,
  revision: NonNullable<ReturnType<typeof parseRevision>>,
) {
  return (
    revision.mutationIntent === input.intent &&
    revision.mutationLocale === input.locale &&
    revision.mutationExpectedRevision === input.expectedRevision &&
    revision.revision === input.expectedRevision + 1 &&
    evidencePayloadsEqual(revision.payload, input.payload)
  );
}

export async function saveEvidenceArtifactWithExecution(
  rawInput: EvidenceSaveInput,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<ServerMutationExecution<EvidenceMutationResult>> {
  const input = parseEvidenceSaveInput(rawInput);
  const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    if (!(await currentConsent(client, userId))) {
      return mutationExecution({ state: "not-ready" } as const, "not-applied");
    }
    const artifact = await findArtifact(client, userId, true);
    if (!artifact) return mutationExecution({ state: "not-ready" } as const, "not-applied");
    const replayResult = await client.query<RevisionRow>(
      `SELECT id, revision, payload, client_mutation_id, mutation_intent,
              mutation_locale, mutation_expected_revision
       FROM evidence_artifact_revisions
       WHERE artifact_id = $1 AND client_mutation_id = $2`,
      [artifact.id, input.clientMutationId],
    );
    const replay = parseRevision(replayResult.rows[0]);
    if (replay) {
      if (!exactSaveReplay(input, replay)) {
        return mutationExecution({ state: "conflict" } as const, "not-applied");
      }
      const currentRevision = await latestRevision(client, artifact.id);
      return mutationExecution(
        {
          state:
            artifact.status === "ready"
              ? ("ready" as const)
              : artifact.status === "withdrawn"
                ? ("withdrawn" as const)
                : ("saved" as const),
          artifact: clientState(input.locale, artifact.status, currentRevision),
        },
        "replayed",
      );
    }
    if (
      artifact.startMutationId === input.clientMutationId ||
      artifact.readyMutationId === input.clientMutationId ||
      artifact.withdrawMutationId === input.clientMutationId
    ) {
      return mutationExecution({ state: "conflict" } as const, "not-applied");
    }
    if (artifact.status !== "draft") {
      return mutationExecution({ state: "not-ready" } as const, "not-applied");
    }
    const previous = await latestRevision(client, artifact.id);
    if ((previous?.revision ?? 0) !== input.expectedRevision) {
      return mutationExecution({ state: "conflict" } as const, "not-applied");
    }
    const contract = getEvidenceArtifactContract();
    const inserted = await client.query<RevisionRow>(
      `INSERT INTO evidence_artifact_revisions
        (user_id, artifact_id, revision, supersedes_revision_id,
         artifact_contract_id, artifact_contract_version, source_pack_id, payload,
         client_mutation_id, mutation_intent, mutation_locale, mutation_expected_revision)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9,'save',$10,$11)
       RETURNING id, revision, payload, client_mutation_id, mutation_intent,
                 mutation_locale, mutation_expected_revision`,
      [
        userId,
        artifact.id,
        input.expectedRevision + 1,
        previous?.id ?? null,
        contract.id,
        contract.version,
        EVIDENCE_SOURCE_PACK_ID,
        JSON.stringify(input.payload),
        input.clientMutationId,
        input.locale,
        input.expectedRevision,
      ],
    );
    return mutationExecution(
      {
        state: "saved",
        artifact: clientState(input.locale, "draft", parseRevision(inserted.rows[0])),
      } as const,
      "applied",
    );
  });
  return result.state === "authorized"
    ? result.value
    : mutationExecution({ state: "denied" } as const, "not-applied");
}

export async function saveEvidenceArtifact(
  rawInput: EvidenceSaveInput,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<EvidenceMutationResult> {
  return (await saveEvidenceArtifactWithExecution(rawInput, identityProvider)).result;
}

function exactLifecycleReplay(
  input: EvidenceLifecycleInput,
  artifact: NonNullable<ReturnType<typeof parseArtifact>>,
): boolean {
  return input.intent === "ready"
    ? artifact.readyMutationId === input.clientMutationId &&
        artifact.readyMutationLocale === input.locale &&
        artifact.readyExpectedRevision === input.expectedRevision
    : artifact.withdrawMutationId === input.clientMutationId &&
        artifact.withdrawMutationLocale === input.locale &&
        artifact.withdrawExpectedRevision === input.expectedRevision;
}

export async function mutateEvidenceLifecycleWithExecution(
  rawInput: EvidenceLifecycleInput,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<ServerMutationExecution<EvidenceMutationResult>> {
  const input = parseEvidenceLifecycleInput(rawInput);
  const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    if (!(await currentConsent(client, userId))) {
      return mutationExecution({ state: "not-ready" } as const, "not-applied");
    }
    const artifact = await findArtifact(client, userId, true);
    if (!artifact) return mutationExecution({ state: "not-ready" } as const, "not-applied");
    const revision = await latestRevision(client, artifact.id);
    if (exactLifecycleReplay(input, artifact)) {
      return mutationExecution(
        {
          state:
            artifact.status === "ready"
              ? "ready"
              : artifact.status === "withdrawn"
                ? "withdrawn"
                : "saved",
          artifact: clientState(input.locale, artifact.status, revision),
        } as const,
        "replayed",
      );
    }
    const mutationIds = [
      artifact.startMutationId,
      artifact.readyMutationId,
      artifact.withdrawMutationId,
    ];
    const revisionMutation = await client.query<{ present: boolean }>(
      `SELECT EXISTS(
         SELECT 1 FROM evidence_artifact_revisions
         WHERE artifact_id = $1 AND client_mutation_id = $2
       ) AS present`,
      [artifact.id, input.clientMutationId],
    );
    if (mutationIds.includes(input.clientMutationId) || revisionMutation.rows[0]?.present) {
      return mutationExecution({ state: "conflict" } as const, "not-applied");
    }
    if ((revision?.revision ?? 0) !== input.expectedRevision) {
      return mutationExecution({ state: "conflict" } as const, "not-applied");
    }
    if (input.intent === "ready") {
      if (
        artifact.status !== "draft" ||
        !revision ||
        !evaluateEvidenceArtifactPayload(revision.payload).ready
      ) {
        return mutationExecution({ state: "not-ready" } as const, "not-applied");
      }
      await client.query(
        `UPDATE evidence_artifacts
         SET status = 'ready', ready_mutation_id = $2, ready_mutation_locale = $3,
             ready_expected_revision = $4
         WHERE id = $1`,
        [artifact.id, input.clientMutationId, input.locale, input.expectedRevision],
      );
      return mutationExecution(
        {
          state: "ready",
          artifact: clientState(input.locale, "ready", revision),
        } as const,
        "applied",
      );
    }
    if (artifact.status !== "draft" && artifact.status !== "ready") {
      return mutationExecution({ state: "not-ready" } as const, "not-applied");
    }
    await client.query(
      `UPDATE evidence_artifacts
       SET status = 'withdrawn', withdraw_mutation_id = $2, withdraw_mutation_locale = $3,
           withdraw_expected_revision = $4
       WHERE id = $1`,
      [artifact.id, input.clientMutationId, input.locale, input.expectedRevision],
    );
    return mutationExecution(
      {
        state: "withdrawn",
        artifact: clientState(input.locale, "withdrawn", revision),
      } as const,
      "applied",
    );
  });
  return result.state === "authorized"
    ? result.value
    : mutationExecution({ state: "denied" } as const, "not-applied");
}

export async function mutateEvidenceLifecycle(
  rawInput: EvidenceLifecycleInput,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<EvidenceMutationResult> {
  return (await mutateEvidenceLifecycleWithExecution(rawInput, identityProvider)).result;
}
