import "server-only";
import { randomUUID } from "node:crypto";
import type { PoolClient } from "pg";
import type { Locale } from "@/lib/i18n/config";
import { mutationExecution, type ServerMutationExecution } from "@/lib/server/mutation-execution";
import {
  withAuthorizedUserTransaction,
  type AuthorizationFailureReason,
} from "@/modules/account/authorization";
import { assessmentDefinition, scoringModelDefinition } from "@/modules/assessment/assessment";
import { limitationCopy } from "@/modules/assessment/explanations";
import { assessmentFramework } from "@/modules/assessment/framework";
import {
  PERSISTED_RESPONSE_SCHEMA_VERSION,
  getSyntheticPublishedDefinition,
} from "@/modules/assessment/persistence/contract";
import { persistedResultExplanationCopy } from "@/modules/assessment/persisted-result/copy";
import { derivePersistedSyntheticResult } from "@/modules/assessment/persisted-result/derive";
import {
  RESULT_PRIORITY_POLICY_DIGEST,
  RESULT_PRIORITY_POLICY_KEY,
  RESULT_PRIORITY_POLICY_VERSION,
} from "@/modules/assessment/persisted-result/policy";
import type {
  PersistedResultDerivation,
  PersistedResultDerivationInput,
  PersistedResultSemanticOutput,
} from "@/modules/assessment/persisted-result/types";
import type { IdentityProvider } from "@/modules/identity/contract";
import { createClerkDevelopmentIdentityProvider } from "@/modules/identity/providers/clerk/server";
import { PRIVACY_NOTICE_VERSION, SERVICE_DATA_PURPOSE } from "@/modules/consent/notice";

export type PersistedResultView = Readonly<{
  coreScores: readonly Readonly<{
    name: string;
    earnedPoints: number;
    availablePoints: number;
    evidenceCount: number;
    explanation: string;
  }>[];
  unassessedCoreNames: readonly string[];
  multiplierObservations: readonly Readonly<{
    name: string;
    evidenceCount: number;
    explanation: string;
  }>[];
  limitations: readonly string[];
  priority:
    | Readonly<{ state: "none"; explanation: string }>
    | Readonly<{
        state: "unique";
        competencyName: string;
        explanation: string;
        nextAction: "prototype-lesson" | "practice-unavailable";
      }>;
}>;

export type PersistedResultPageState =
  | Readonly<{ state: "denied"; reason: AuthorizationFailureReason }>
  | Readonly<{ state: "consent-required" }>
  | Readonly<{ state: "unavailable" }>
  | Readonly<{ state: "not-generated" }>
  | Readonly<{ state: "ready"; view: PersistedResultView }>;

export type GeneratePersistedResultResult =
  | Readonly<{ state: "ready" }>
  | Readonly<{ state: "consent-required" | "unavailable" | "denied" | "failed" }>;

type ConsentRow = Readonly<{ decision: unknown }>;
type SourceRow = Readonly<{
  session_id: unknown;
  assessment_version_id: unknown;
  assessment_content_digest: unknown;
  framework_version_id: unknown;
  framework_content_digest: unknown;
  scoring_model_version_id: unknown;
  scoring_content_digest: unknown;
}>;
type ResponseRow = Readonly<{
  item_key: unknown;
  display_order: unknown;
  response_payload: unknown;
  revision: unknown;
  target_kind: unknown;
  target_key: unknown;
}>;
type RunRow = Readonly<{
  id: unknown;
  run_number: unknown;
  input_digest: unknown;
  output_digest: unknown;
  result_policy_key: unknown;
  result_policy_version: unknown;
  result_policy_digest: unknown;
}>;

type InternalSource = Readonly<{
  userId: string;
  sessionId: string;
  assessmentVersionId: string;
  frameworkVersionId: string;
  scoringModelVersionId: string;
  derivationInput: PersistedResultDerivationInput;
}>;

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function requireString(value: unknown): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error("Persisted result source is invalid.");
  }
  return value;
}

function requireInteger(value: unknown): number {
  if (!Number.isInteger(value)) throw new Error("Persisted result source is invalid.");
  return value as number;
}

function parseSelectedOptionId(payload: unknown): string {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("Persisted result response is invalid.");
  }
  const candidate = payload as Readonly<Record<string, unknown>>;
  if (
    JSON.stringify(Object.keys(candidate).sort()) !==
      JSON.stringify(["schemaVersion", "selectedOptionId"].sort()) ||
    candidate.schemaVersion !== PERSISTED_RESPONSE_SCHEMA_VERSION ||
    typeof candidate.selectedOptionId !== "string"
  ) {
    throw new Error("Persisted result response is invalid.");
  }
  return candidate.selectedOptionId;
}

async function loadSource(
  client: PoolClient,
  userId: string,
  lockSession: boolean,
): Promise<InternalSource | "consent-required" | "unavailable"> {
  const consent = await client.query<ConsentRow>(
    `SELECT decision
     FROM consent_records
     WHERE user_id = $1 AND purpose_code = $2 AND notice_version = $3
     ORDER BY occurred_at DESC, id DESC
     LIMIT 1`,
    [userId, SERVICE_DATA_PURPOSE, PRIVACY_NOTICE_VERSION],
  );
  if (consent.rows[0]?.decision !== "granted") return "consent-required";

  const registry = getSyntheticPublishedDefinition();
  const source = await client.query<SourceRow>(
    `SELECT session.id AS session_id,
            assessment.id AS assessment_version_id,
            assessment.content_digest AS assessment_content_digest,
            framework.id AS framework_version_id,
            framework.content_digest AS framework_content_digest,
            scoring.id AS scoring_model_version_id,
            scoring.content_digest AS scoring_content_digest
     FROM assessment_sessions AS session
     JOIN assessment_versions AS assessment ON assessment.id = session.assessment_version_id
     JOIN framework_versions AS framework ON framework.id = assessment.framework_version_id
     JOIN scoring_model_versions AS scoring ON scoring.id = assessment.scoring_model_version_id
     WHERE session.user_id = $1 AND session.status = 'submitted'
       AND assessment.assessment_key = $2 AND assessment.version = $3
       AND framework.framework_key = $4 AND framework.version = $5
       AND scoring.model_key = $6 AND scoring.version = $7
       AND assessment.status = 'published' AND framework.status = 'published'
       AND scoring.status = 'published'
     ORDER BY session.submitted_at DESC, session.id DESC
     LIMIT 1${lockSession ? " FOR UPDATE OF session" : ""}`,
    [
      userId,
      registry.assessmentKey,
      registry.assessmentVersion,
      registry.frameworkKey,
      registry.frameworkVersion,
      registry.scoringModelKey,
      registry.scoringModelVersion,
    ],
  );
  const row = source.rows[0];
  if (!row) return "unavailable";

  const sessionId = requireString(row.session_id);
  const responses = await client.query<ResponseRow>(
    `SELECT item.item_key, item.display_order, response.response_payload, response.revision,
            mapping.target_kind, competency.competency_key AS target_key
     FROM assessment_responses AS response
     JOIN assessment_item_versions AS item ON item.id = response.assessment_item_version_id
     JOIN assessment_item_competencies AS mapping
       ON mapping.assessment_item_version_id = item.id
     JOIN competency_versions AS competency ON competency.id = mapping.competency_version_id
     WHERE response.session_id = $1 AND response.is_active
     ORDER BY item.display_order`,
    [sessionId],
  );
  if (responses.rows.length !== registry.items.length) {
    throw new Error("Persisted result requires complete submitted evidence.");
  }

  const derivationResponses = responses.rows.map((response, index) => {
    const registered = registry.items[index];
    if (
      !registered ||
      response.item_key !== registered.key ||
      response.display_order !== registered.displayOrder ||
      response.target_kind !== registered.targetKind ||
      response.target_key !== registered.targetKey
    ) {
      throw new Error("Persisted result definition compatibility failed.");
    }
    return {
      itemKey: registered.key,
      displayOrder: registered.displayOrder,
      revision: requireInteger(response.revision),
      selectedOptionId: parseSelectedOptionId(response.response_payload),
    };
  });

  return {
    userId,
    sessionId,
    assessmentVersionId: requireString(row.assessment_version_id),
    frameworkVersionId: requireString(row.framework_version_id),
    scoringModelVersionId: requireString(row.scoring_model_version_id),
    derivationInput: {
      assessment: {
        contentId: assessmentDefinition.id,
        key: assessmentDefinition.assessmentKey,
        version: assessmentDefinition.version,
        contentDigest: requireString(row.assessment_content_digest),
      },
      framework: {
        contentId: assessmentFramework.id,
        key: assessmentFramework.frameworkKey,
        version: assessmentFramework.version,
        contentDigest: requireString(row.framework_content_digest),
      },
      scoringModel: {
        contentId: scoringModelDefinition.id,
        key: scoringModelDefinition.scoringKey,
        version: scoringModelDefinition.version,
        contentDigest: requireString(row.scoring_content_digest),
      },
      responses: derivationResponses,
    },
  };
}

async function latestRun(client: PoolClient, sessionId: string): Promise<RunRow | null> {
  const result = await client.query<RunRow>(
    `SELECT id, run_number, input_digest, output_digest,
            result_policy_key, result_policy_version, result_policy_digest
     FROM scoring_runs
     WHERE assessment_session_id = $1
     ORDER BY run_number DESC
     LIMIT 1`,
    [sessionId],
  );
  return result.rows[0] ?? null;
}

async function assertPersistedRunMatches(
  client: PoolClient,
  run: RunRow,
  derivation: PersistedResultDerivation,
): Promise<void> {
  if (
    run.input_digest !== derivation.inputDigest ||
    run.output_digest !== derivation.outputDigest ||
    run.result_policy_key !== RESULT_PRIORITY_POLICY_KEY ||
    run.result_policy_version !== RESULT_PRIORITY_POLICY_VERSION ||
    run.result_policy_digest !== RESULT_PRIORITY_POLICY_DIGEST
  ) {
    throw new Error("Persisted result provenance does not match the current immutable contract.");
  }
  const runId = requireString(run.id);
  const shape = await client.query<{
    core_count: number;
    multiplier_count: number;
    explanation_count: number;
    priority_count: number;
  }>(
    `SELECT
       (SELECT count(*)::integer FROM competency_scores WHERE scoring_run_id = $1) AS core_count,
       (SELECT count(*)::integer FROM multiplier_observations WHERE scoring_run_id = $1) AS multiplier_count,
       (SELECT count(*)::integer FROM score_explanations WHERE scoring_run_id = $1) AS explanation_count,
       (SELECT count(*)::integer FROM priority_recommendations WHERE scoring_run_id = $1) AS priority_count`,
    [runId],
  );
  const expectedPriorityCount = derivation.semanticOutput.priorityRecommendation ? 1 : 0;
  if (
    shape.rows[0]?.core_count !== 2 ||
    shape.rows[0]?.multiplier_count !== 2 ||
    shape.rows[0]?.explanation_count !== 6 ||
    shape.rows[0]?.priority_count !== expectedPriorityCount
  ) {
    throw new Error("Persisted result child records are incomplete.");
  }
}

async function persistDerivation(
  client: PoolClient,
  source: InternalSource,
  derivation: PersistedResultDerivation,
  mutationId: string,
  previous: RunRow | null,
): Promise<void> {
  const runNumber = previous ? requireInteger(previous.run_number) + 1 : 1;
  const runKind = previous ? "rescore" : "normal";
  const inserted = await client.query<{ id: string }>(
    `INSERT INTO scoring_runs
      (user_id, assessment_session_id, assessment_version_id, framework_version_id,
       scoring_model_version_id, run_number, run_kind, supersedes_scoring_run_id,
       client_mutation_id, input_digest, output_digest, result_policy_key,
       result_policy_version, result_policy_digest)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
     RETURNING id`,
    [
      source.userId,
      source.sessionId,
      source.assessmentVersionId,
      source.frameworkVersionId,
      source.scoringModelVersionId,
      runNumber,
      runKind,
      previous ? requireString(previous.id) : null,
      mutationId,
      derivation.inputDigest,
      derivation.outputDigest,
      RESULT_PRIORITY_POLICY_KEY,
      RESULT_PRIORITY_POLICY_VERSION,
      RESULT_PRIORITY_POLICY_DIGEST,
    ],
  );
  const runId = inserted.rows[0]!.id;
  const competencies = await client.query<{
    id: string;
    competency_key: string;
    kind: "core" | "multiplier";
  }>(
    `SELECT id, competency_key, kind
     FROM competency_versions
     WHERE framework_version_id = $1`,
    [source.frameworkVersionId],
  );
  const competencyByKey = new Map(competencies.rows.map((row) => [row.competency_key, row]));

  for (const score of derivation.semanticOutput.coreScores) {
    const competency = competencyByKey.get(score.competencyId);
    if (!competency || competency.kind !== "core") throw new Error("Core target is unavailable.");
    await client.query(
      `INSERT INTO competency_scores
        (user_id, scoring_run_id, framework_version_id, competency_version_id, target_kind,
         earned_points, available_points, evidence_count, normalized_basis_points)
       VALUES ($1, $2, $3, $4, 'core', $5, $6, $7, $8)`,
      [
        source.userId,
        runId,
        source.frameworkVersionId,
        competency.id,
        score.earnedPoints,
        score.availablePoints,
        score.evidenceCount,
        score.normalizedBasisPoints,
      ],
    );
  }

  for (const observation of derivation.semanticOutput.multiplierObservations) {
    const competency = competencyByKey.get(observation.multiplierId);
    if (!competency || competency.kind !== "multiplier") {
      throw new Error("Multiplier target is unavailable.");
    }
    await client.query(
      `INSERT INTO multiplier_observations
        (user_id, scoring_run_id, framework_version_id, competency_version_id, target_kind,
         earned_rubric_points, available_rubric_points, evidence_count, limitation_code)
       VALUES ($1, $2, $3, $4, 'multiplier', $5, $6, $7,
               'single-scenario-not-behavior-pattern')`,
      [
        source.userId,
        runId,
        source.frameworkVersionId,
        competency.id,
        observation.earnedRubricPoints,
        observation.availableRubricPoints,
        observation.evidenceCount,
      ],
    );
  }

  for (const explanation of derivation.semanticOutput.explanations) {
    const targetId = explanation.target.id;
    const competency =
      explanation.target.kind === "core" ||
      explanation.target.kind === "multiplier" ||
      (explanation.target.kind === "priority" && targetId !== "none")
        ? competencyByKey.get(targetId)
        : null;
    await client.query(
      `INSERT INTO score_explanations
        (user_id, scoring_run_id, framework_version_id, target_kind,
         target_competency_kind, competency_version_id, explanation_code,
         message_params, supporting_item_keys, limitation_codes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb, $9::text[], $10::text[])`,
      [
        source.userId,
        runId,
        source.frameworkVersionId,
        explanation.target.kind,
        competency?.kind ?? null,
        competency?.id ?? null,
        explanation.explanationCode,
        JSON.stringify(explanation.messageParams),
        explanation.supportingItemKeys,
        explanation.limitationCodes,
      ],
    );
  }

  const priority = derivation.semanticOutput.priorityRecommendation;
  if (priority) {
    const competency = competencyByKey.get(priority.competencyId);
    if (!competency || competency.kind !== "core")
      throw new Error("Priority target is unavailable.");
    await client.query(
      `INSERT INTO priority_recommendations
        (user_id, scoring_run_id, framework_version_id, competency_version_id, target_kind,
         rank, reason_code, supporting_item_keys, next_action)
       VALUES ($1, $2, $3, $4, 'core', 1, $5, $6::text[], $7::jsonb)`,
      [
        source.userId,
        runId,
        source.frameworkVersionId,
        competency.id,
        priority.reasonCode,
        priority.supportingItemKeys,
        JSON.stringify(priority.nextAction),
      ],
    );
  }

  await client.query("SET CONSTRAINTS ALL IMMEDIATE");
}

function toView(output: PersistedResultSemanticOutput, locale: Locale): PersistedResultView {
  const coreName = new Map(
    assessmentFramework.coreCompetencies.map((competency) => [
      competency.id,
      competency.name[locale],
    ]),
  );
  const multiplierName = new Map(
    assessmentFramework.multipliers.map((multiplier) => [multiplier.id, multiplier.name[locale]]),
  );
  const priorityExplanation = output.explanations.find(
    (explanation) => explanation.target.kind === "priority",
  );
  if (!priorityExplanation)
    throw new Error("Persisted result priority explanation is unavailable.");

  return {
    coreScores: output.coreScores.map((score) => ({
      name: coreName.get(score.competencyId)!,
      earnedPoints: score.earnedPoints,
      availablePoints: score.availablePoints,
      evidenceCount: score.evidenceCount,
      explanation: persistedResultExplanationCopy["assessed-core-raw-signal"][locale],
    })),
    unassessedCoreNames: output.unassessedCoreCompetencyIds.map((id) => coreName.get(id)!),
    multiplierObservations: output.multiplierObservations.map((observation) => ({
      name: multiplierName.get(observation.multiplierId)!,
      evidenceCount: observation.evidenceCount,
      explanation: persistedResultExplanationCopy["single-scenario-multiplier-observation"][locale],
    })),
    limitations: [
      "not-validated-assessment",
      "partial-core-slice",
      "single-scenario-not-behavior-pattern",
      "cannot-predict-job-loss",
      "cannot-predict-job-performance",
      "cannot-determine-employability",
      "cannot-determine-hiring-eligibility",
    ].map((code) => limitationCopy[code as keyof typeof limitationCopy].body[locale]),
    priority: output.priorityRecommendation
      ? {
          state: "unique",
          competencyName: coreName.get(output.priorityRecommendation.competencyId)!,
          explanation: persistedResultExplanationCopy[priorityExplanation.explanationCode][locale],
          nextAction: output.priorityRecommendation.nextAction.kind,
        }
      : {
          state: "none",
          explanation: persistedResultExplanationCopy[priorityExplanation.explanationCode][locale],
        },
  };
}

export async function loadPersistedResultPageState(
  locale: Locale,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<PersistedResultPageState> {
  const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    const source = await loadSource(client, userId, false);
    if (typeof source === "string") return { state: source } as const;
    const run = await latestRun(client, source.sessionId);
    if (!run) return { state: "not-generated" } as const;
    const derivation = derivePersistedSyntheticResult(source.derivationInput);
    await assertPersistedRunMatches(client, run, derivation);
    return { state: "ready", view: toView(derivation.semanticOutput, locale) } as const;
  });
  return result.state === "authorized" ? result.value : { state: "denied", reason: result.reason };
}

export async function generatePersistedResultWithExecution(
  locale: Locale,
  mutationId: string,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<ServerMutationExecution<GeneratePersistedResultResult>> {
  if (!uuidPattern.test(mutationId)) {
    return mutationExecution({ state: "failed" } as const, "not-applied");
  }
  try {
    const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
      let source = await loadSource(client, userId, true);
      if (typeof source === "string") {
        return mutationExecution({ state: source } as const, "not-applied");
      }
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtextextended('assessment-scoring:' || $1, 0))`,
        [source.sessionId],
      );
      source = await loadSource(client, userId, true);
      if (typeof source === "string") {
        return mutationExecution({ state: source } as const, "not-applied");
      }
      const derivation = derivePersistedSyntheticResult(source.derivationInput);
      const existing = await latestRun(client, source.sessionId);
      if (existing) {
        await assertPersistedRunMatches(client, existing, derivation);
        return mutationExecution({ state: "ready" } as const, "replayed");
      }
      await persistDerivation(client, source, derivation, mutationId, null);
      return mutationExecution({ state: "ready" } as const, "applied");
    });
    return result.state === "authorized"
      ? result.value
      : mutationExecution({ state: "denied" } as const, "not-applied");
  } catch {
    return mutationExecution({ state: "failed" } as const, "not-applied");
  }
}

export async function generatePersistedResult(
  locale: Locale,
  mutationId: string,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<GeneratePersistedResultResult> {
  return (await generatePersistedResultWithExecution(locale, mutationId, identityProvider)).result;
}

export async function rescorePersistedResultForAuthorizedUser(
  identityProvider: IdentityProvider,
): Promise<GeneratePersistedResultResult> {
  try {
    const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
      let source = await loadSource(client, userId, true);
      if (typeof source === "string") return { state: source } as const;
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtextextended('assessment-scoring:' || $1, 0))`,
        [source.sessionId],
      );
      source = await loadSource(client, userId, true);
      if (typeof source === "string") return { state: source } as const;
      const previous = await latestRun(client, source.sessionId);
      if (!previous) return { state: "unavailable" } as const;
      const derivation = derivePersistedSyntheticResult(source.derivationInput);
      await assertPersistedRunMatches(client, previous, derivation);
      await persistDerivation(client, source, derivation, randomUUID(), previous);
      return { state: "ready" } as const;
    });
    return result.state === "authorized" ? result.value : { state: "denied" };
  } catch {
    return { state: "failed" };
  }
}
