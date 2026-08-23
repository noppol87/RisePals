import "server-only";
import type { PoolClient } from "pg";
import type { Locale } from "@/lib/i18n/config";
import {
  withAuthorizedUserTransaction,
  type AuthorizationFailureReason,
} from "@/modules/account/authorization";
import { PRIVACY_NOTICE_VERSION, SERVICE_DATA_PURPOSE } from "@/modules/consent/notice";
import type { IdentityProvider } from "@/modules/identity/contract";
import { createClerkDevelopmentIdentityProvider } from "@/modules/identity/providers/clerk/server";
import { sourceVerificationLessonDefinition } from "@/modules/lesson/publication/registry";
import { evaluateSourceVerificationPractice } from "@/modules/lesson/source-verification/evaluate";
import type { SourceVerificationCriterionResult } from "@/modules/lesson/source-verification/types";
import { createSourceVerificationLessonView } from "@/modules/lesson/source-verification/view";
import {
  createClientSafePracticeView,
  getPersistedLessonMetadata,
  LEARNING_PROGRESS_EVENT_SCHEMA_VERSION,
  parsePersistedLessonMutationInput,
  parsePersistedLessonStartInput,
  parsePersistedPracticeSelections,
  PERSISTED_LESSON_RESPONSE_SCHEMA_VERSION,
  type PersistedLessonMutationInput,
  type PersistedPracticeSelection,
} from "./contract";

export type PersistedCriterionResult = Pick<
  SourceVerificationCriterionResult,
  "criterionId" | "selectedOptionId" | "status"
>;

export type PersistedLessonPageState =
  | Readonly<{ state: "denied"; reason: AuthorizationFailureReason }>
  | Readonly<{ state: "consent-required" }>
  | Readonly<{ state: "not-started"; view: ReturnType<typeof createClientSafePracticeView> }>
  | Readonly<{
      state: "in-progress" | "needs-retry" | "demonstrated";
      view: ReturnType<typeof createClientSafePracticeView>;
      revision: number;
      selections: readonly PersistedPracticeSelection[];
      results: readonly PersistedCriterionResult[] | null;
    }>;

export type PersistedLessonMutationResult =
  | Readonly<{
      state: "saved" | "needs-retry" | "demonstrated";
      revision: number;
      selections: readonly PersistedPracticeSelection[];
      results: readonly PersistedCriterionResult[] | null;
    }>
  | Readonly<{ state: "conflict" | "not-ready" | "denied" }>;

type ConsentRow = { id: unknown; decision: unknown };
type LessonRow = { id: unknown; status: unknown };
type PracticeRow = {
  id: unknown;
  revision: unknown;
  status: unknown;
  response_payload: unknown;
  criterion_results: unknown;
  demonstrated: unknown;
  client_mutation_id: unknown;
  mutation_intent: unknown;
  mutation_locale: unknown;
  mutation_expected_revision: unknown;
};

function requireString(value: unknown, label: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`Persisted lesson ${label} is invalid.`);
  }
  return value;
}

function parseResults(value: unknown): readonly PersistedCriterionResult[] | null {
  if (value === null) return null;
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Persisted lesson result is invalid.");
  }
  const record = value as Readonly<Record<string, unknown>>;
  if (
    record.schemaVersion !== "source-verification-evaluation-v1" ||
    !Array.isArray(record.criteria)
  ) {
    throw new Error("Persisted lesson result is invalid.");
  }
  return record.criteria.map((candidate) => {
    if (!candidate || typeof candidate !== "object" || Array.isArray(candidate)) {
      throw new Error("Persisted criterion result is invalid.");
    }
    const result = candidate as Readonly<Record<string, unknown>>;
    if (
      typeof result.criterionId !== "string" ||
      typeof result.selectedOptionId !== "string" ||
      (result.status !== "met" && result.status !== "not-met")
    ) {
      throw new Error("Persisted criterion result is invalid.");
    }
    return {
      criterionId: result.criterionId as PersistedCriterionResult["criterionId"],
      selectedOptionId: result.selectedOptionId,
      status: result.status,
    };
  });
}

function parsePractice(row: PracticeRow | undefined) {
  if (!row) return null;
  if (
    !Number.isInteger(row.revision) ||
    !Number.isInteger(row.mutation_expected_revision) ||
    (row.status !== "draft" && row.status !== "evaluated") ||
    (row.mutation_intent !== "save" &&
      row.mutation_intent !== "evaluate" &&
      row.mutation_intent !== "retry") ||
    (row.mutation_locale !== "th" && row.mutation_locale !== "en")
  ) {
    throw new Error("Persisted practice revision is invalid.");
  }
  const payload = row.response_payload as Readonly<Record<string, unknown>> | null;
  if (!payload || payload.schemaVersion !== PERSISTED_LESSON_RESPONSE_SCHEMA_VERSION) {
    throw new Error("Persisted practice payload is invalid.");
  }
  return {
    id: requireString(row.id, "practice ID"),
    revision: row.revision as number,
    status: row.status,
    selections: parsePersistedPracticeSelections(payload.selections, true),
    results: parseResults(row.criterion_results),
    demonstrated: row.demonstrated === true,
    clientMutationId: requireString(row.client_mutation_id, "mutation ID"),
    mutationIntent: row.mutation_intent,
    mutationLocale: row.mutation_locale,
    mutationExpectedRevision: row.mutation_expected_revision as number,
  } as const;
}

function selectionsMatch(
  left: readonly PersistedPracticeSelection[],
  right: readonly PersistedPracticeSelection[],
): boolean {
  return (
    left.length === right.length &&
    left.every(
      (selection, index) =>
        selection.criterionId === right[index]?.criterionId &&
        selection.optionId === right[index]?.optionId,
    )
  );
}

function isExactMutationReplay(
  input: PersistedLessonMutationInput,
  replay: NonNullable<ReturnType<typeof parsePractice>>,
): boolean {
  if (
    replay.mutationIntent !== input.intent ||
    replay.mutationLocale !== input.locale ||
    replay.mutationExpectedRevision !== input.expectedRevision ||
    replay.revision !== input.expectedRevision + 1
  ) {
    return false;
  }
  return input.intent === "retry"
    ? input.selections === undefined
    : input.selections !== undefined && selectionsMatch(replay.selections, input.selections);
}

async function currentConsent(client: PoolClient, userId: string): Promise<string | null> {
  const result = await client.query<ConsentRow>(
    `SELECT id, decision FROM consent_records
     WHERE user_id = $1 AND purpose_code = $2 AND notice_version = $3
     ORDER BY occurred_at DESC, id DESC LIMIT 1`,
    [userId, SERVICE_DATA_PURPOSE, PRIVACY_NOTICE_VERSION],
  );
  return result.rows[0]?.decision === "granted"
    ? requireString(result.rows[0].id, "consent ID")
    : null;
}

async function findLesson(client: PoolClient, userId: string, lock = false) {
  const metadata = getPersistedLessonMetadata();
  const result = await client.query<LessonRow>(
    `SELECT id, status FROM lesson_attempts
     WHERE user_id = $1 AND lesson_key = $2 AND lesson_version = $3
     ${lock ? "FOR UPDATE" : ""}`,
    [userId, metadata.lessonKey, metadata.lessonVersion],
  );
  const row = result.rows[0];
  if (!row) return null;
  if (row.status !== "in_progress" && row.status !== "demonstrated") {
    throw new Error("Persisted lesson status is invalid.");
  }
  return { id: requireString(row.id, "attempt ID"), status: row.status } as const;
}

async function latestPractice(client: PoolClient, lessonId: string) {
  const result = await client.query<PracticeRow>(
    `SELECT id, revision, status, response_payload, criterion_results, demonstrated,
            client_mutation_id, mutation_intent, mutation_locale, mutation_expected_revision
     FROM practice_attempts WHERE lesson_attempt_id = $1
     ORDER BY revision DESC LIMIT 1`,
    [lessonId],
  );
  return parsePractice(result.rows[0]);
}

function stateFromPractice(
  lessonStatus: "in_progress" | "demonstrated",
  practice: NonNullable<ReturnType<typeof parsePractice>> | null,
) {
  if (lessonStatus === "demonstrated") return "demonstrated" as const;
  if (practice?.status === "evaluated" && !practice.demonstrated) return "needs-retry" as const;
  return "in-progress" as const;
}

export async function loadPersistedLessonPageState(
  locale: Locale,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<PersistedLessonPageState> {
  const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    if (!(await currentConsent(client, userId))) return { state: "consent-required" } as const;
    const lesson = await findLesson(client, userId);
    const view = createClientSafePracticeView(locale);
    if (!lesson) return { state: "not-started", view } as const;
    const practice = await latestPractice(client, lesson.id);
    return {
      state: stateFromPractice(lesson.status, practice),
      view,
      revision: practice?.revision ?? 0,
      selections: practice?.selections ?? [],
      results: practice?.results ?? null,
    } as const;
  });
  return result.state === "authorized" ? result.value : { state: "denied", reason: result.reason };
}

export async function startPersistedLesson(
  locale: Locale,
  mutationId: string,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<PersistedLessonMutationResult> {
  const parsed = parsePersistedLessonStartInput({ locale, clientMutationId: mutationId });
  const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    const consentId = await currentConsent(client, userId);
    if (!consentId) return { state: "not-ready" } as const;
    const metadata = getPersistedLessonMetadata();
    await client.query(`SELECT pg_advisory_xact_lock(hashtextextended($1, 0))`, [
      `${userId}:${metadata.lessonKey}:${metadata.lessonVersion}`,
    ]);
    const existing = await findLesson(client, userId, true);
    if (existing) {
      const practice = await latestPractice(client, existing.id);
      const existingState = stateFromPractice(existing.status, practice);
      return {
        state: existingState === "in-progress" ? "saved" : existingState,
        revision: practice?.revision ?? 0,
        selections: practice?.selections ?? [],
        results: practice?.results ?? null,
      } as const;
    }
    const inserted = await client.query<{ id: string }>(
      `INSERT INTO lesson_attempts
        (user_id, consent_record_id, lesson_key, lesson_version_id, lesson_version,
         lesson_digest, practice_id, practice_version, rubric_version_id, rubric_version,
         evaluation_contract_version_id, start_mutation_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING id`,
      [
        userId,
        consentId,
        metadata.lessonKey,
        metadata.lessonVersionId,
        metadata.lessonVersion,
        metadata.lessonDigest,
        metadata.practiceId,
        metadata.practiceVersion,
        metadata.rubricVersionId,
        metadata.rubricVersion,
        metadata.evaluationContractVersionId,
        parsed.clientMutationId,
      ],
    );
    await client.query(
      `INSERT INTO learning_progress_events
        (user_id, lesson_attempt_id, event_kind, event_schema_version, source_mutation_id)
       VALUES ($1,$2,'lesson_started',$3,$4)`,
      [
        userId,
        inserted.rows[0]!.id,
        LEARNING_PROGRESS_EVENT_SCHEMA_VERSION,
        parsed.clientMutationId,
      ],
    );
    return { state: "saved", revision: 0, selections: [], results: null } as const;
  });
  return result.state === "authorized" ? result.value : { state: "denied" };
}

function responsePayload(selections: readonly PersistedPracticeSelection[]) {
  return { schemaVersion: PERSISTED_LESSON_RESPONSE_SCHEMA_VERSION, selections };
}

export async function mutatePersistedLesson(
  rawInput: PersistedLessonMutationInput,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<PersistedLessonMutationResult> {
  const input = parsePersistedLessonMutationInput(rawInput);
  const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    if (!(await currentConsent(client, userId))) return { state: "not-ready" } as const;
    const lesson = await findLesson(client, userId, true);
    if (!lesson) return { state: "not-ready" } as const;

    const replayResult = await client.query<PracticeRow>(
      `SELECT id, revision, status, response_payload, criterion_results, demonstrated,
              client_mutation_id, mutation_intent, mutation_locale, mutation_expected_revision
       FROM practice_attempts
       WHERE lesson_attempt_id = $1 AND client_mutation_id = $2`,
      [lesson.id, input.clientMutationId],
    );
    const replay = parsePractice(replayResult.rows[0]);
    if (replay) {
      if (!isExactMutationReplay(input, replay)) return { state: "conflict" } as const;
      return {
        state: replay.demonstrated
          ? "demonstrated"
          : replay.status === "evaluated"
            ? "needs-retry"
            : "saved",
        revision: replay.revision,
        selections: replay.selections,
        results: replay.results,
      } as const;
    }
    if (lesson.status === "demonstrated") return { state: "not-ready" } as const;

    const previous = await latestPractice(client, lesson.id);
    if ((previous?.revision ?? 0) !== input.expectedRevision) return { state: "conflict" } as const;
    if (previous?.status === "evaluated" && !previous.demonstrated && input.intent !== "retry") {
      return { state: "not-ready" } as const;
    }

    let selections: readonly PersistedPracticeSelection[];
    let status: "draft" | "evaluated";
    let results: readonly PersistedCriterionResult[] | null = null;
    let demonstrated: boolean | null = null;
    if (input.intent === "save") {
      selections = input.selections!;
      status = "draft";
    } else if (input.intent === "retry") {
      if (!previous || previous.status !== "evaluated" || previous.demonstrated) {
        return { state: "not-ready" } as const;
      }
      selections = previous.selections;
      status = "draft";
    } else {
      selections = input.selections!;
      const evaluation = evaluateSourceVerificationPractice(
        createSourceVerificationLessonView(input.locale, sourceVerificationLessonDefinition),
        selections,
      );
      if (!evaluation.ok) return { state: "not-ready" } as const;
      status = "evaluated";
      results = evaluation.evaluation.criterionResults;
      demonstrated = evaluation.evaluation.demonstrated;
    }

    const metadata = getPersistedLessonMetadata();
    const nextRevision = (previous?.revision ?? 0) + 1;
    const resultJson = results
      ? { schemaVersion: metadata.evaluationContractVersionId, criteria: results }
      : null;
    const inserted = await client.query<{ id: string }>(
      `INSERT INTO practice_attempts
        (user_id, lesson_attempt_id, revision, supersedes_practice_attempt_id, status,
         response_payload, practice_id, practice_version, rubric_version_id, rubric_version,
         evaluation_contract_version_id, criterion_results, demonstrated, client_mutation_id,
         mutation_intent, mutation_locale, mutation_expected_revision)
       VALUES ($1,$2,$3,$4,$5,$6::jsonb,$7,$8,$9,$10,$11,$12::jsonb,$13,$14,$15,$16,$17)
       RETURNING id`,
      [
        userId,
        lesson.id,
        nextRevision,
        previous?.id ?? null,
        status,
        JSON.stringify(responsePayload(selections)),
        metadata.practiceId,
        metadata.practiceVersion,
        metadata.rubricVersionId,
        metadata.rubricVersion,
        metadata.evaluationContractVersionId,
        resultJson ? JSON.stringify(resultJson) : null,
        demonstrated,
        input.clientMutationId,
        input.intent,
        input.locale,
        input.expectedRevision,
      ],
    );

    await client.query(
      `UPDATE lesson_attempts SET last_meaningful_activity_at = clock_timestamp(),
         status = CASE WHEN $2::boolean THEN 'demonstrated' ELSE status END,
         demonstrated_at = CASE WHEN $2::boolean THEN clock_timestamp() ELSE demonstrated_at END
       WHERE id = $1`,
      [lesson.id, demonstrated === true],
    );
    if (status === "evaluated") {
      await client.query(
        `INSERT INTO learning_progress_events
          (user_id, lesson_attempt_id, practice_attempt_id, event_kind,
           event_schema_version, source_mutation_id)
         VALUES ($1,$2,$3,'practice_evaluated',$4,$5)`,
        [
          userId,
          lesson.id,
          inserted.rows[0]!.id,
          LEARNING_PROGRESS_EVENT_SCHEMA_VERSION,
          input.clientMutationId,
        ],
      );
      if (demonstrated) {
        await client.query(
          `INSERT INTO learning_progress_events
            (user_id, lesson_attempt_id, practice_attempt_id, event_kind,
             event_schema_version, source_mutation_id)
           VALUES ($1,$2,$3,'practice_demonstrated',$4,$5)`,
          [
            userId,
            lesson.id,
            inserted.rows[0]!.id,
            LEARNING_PROGRESS_EVENT_SCHEMA_VERSION,
            input.clientMutationId,
          ],
        );
      }
    }
    return {
      state: demonstrated ? "demonstrated" : status === "evaluated" ? "needs-retry" : "saved",
      revision: nextRevision,
      selections,
      results,
    } as const;
  });
  return result.state === "authorized" ? result.value : { state: "denied" };
}
