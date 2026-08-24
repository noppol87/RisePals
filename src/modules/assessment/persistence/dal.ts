import "server-only";
import type { PoolClient } from "pg";
import type { Locale } from "@/lib/i18n/config";
import { mutationExecution, type ServerMutationExecution } from "@/lib/server/mutation-execution";
import type { IdentityProvider } from "@/modules/identity/contract";
import { createClerkDevelopmentIdentityProvider } from "@/modules/identity/providers/clerk/server";
import {
  withAuthorizedUserTransaction,
  type AuthorizationFailureReason,
} from "@/modules/account/authorization";
import { PRIVACY_NOTICE_VERSION, SERVICE_DATA_PURPOSE } from "@/modules/consent/notice";
import {
  createPersistedAssessmentView,
  getSyntheticPublishedDefinition,
  parseSavePersistedResponseInput,
  PERSISTED_RESPONSE_SCHEMA_VERSION,
  PUBLISHED_OPTION_SCHEMA_VERSION,
  type PersistedAssessmentView,
  type SavePersistedResponseInput,
} from "./contract";

export type PersistedSelection = Readonly<{
  itemKey: string;
  selectedOptionId: string;
  revision: number;
}>;

export type PersistedAssessmentPageState =
  | Readonly<{ state: "denied"; reason: AuthorizationFailureReason }>
  | Readonly<{ state: "consent-required" }>
  | Readonly<{ state: "unavailable" }>
  | Readonly<{ state: "not-started"; view: PersistedAssessmentView }>
  | Readonly<{
      state: "in-progress";
      view: PersistedAssessmentView;
      selections: readonly PersistedSelection[];
      currentItemKey: string;
    }>
  | Readonly<{
      state: "submitted";
      answeredCount: number;
      totalItems: number;
    }>;

export type SavePersistedResponseResult =
  | Readonly<{ state: "saved"; selection: PersistedSelection }>
  | Readonly<{ state: "conflict"; selection: PersistedSelection | null }>
  | Readonly<{ state: "not-ready" }>
  | Readonly<{ state: "denied" }>;

export type SubmitPersistedAssessmentResult =
  | Readonly<{ state: "submitted"; answeredCount: number; totalItems: number }>
  | Readonly<{ state: "incomplete" }>
  | Readonly<{ state: "not-ready" }>
  | Readonly<{ state: "denied" }>;

type ConsentRow = Readonly<{ id: unknown; decision: unknown }>;
type DefinitionRow = Readonly<{ id: unknown }>;
type ItemRow = Readonly<{
  id: unknown;
  item_key: unknown;
  display_order: unknown;
  required: unknown;
  response_schema: unknown;
}>;
type SessionRow = Readonly<{
  id: unknown;
  status: unknown;
  last_item_version_id: unknown;
}>;
type ResponseRow = Readonly<{
  id: unknown;
  assessment_item_version_id: unknown;
  item_key: unknown;
  response_payload: unknown;
  revision: unknown;
  client_mutation_id: unknown;
  is_active: unknown;
}>;

type InternalItem = Readonly<{
  id: string;
  key: string;
  displayOrder: number;
  required: boolean;
  optionIds: readonly string[];
}>;
type InternalSession = Readonly<{
  id: string;
  status: "in_progress" | "submitted";
  lastItemVersionId: string | null;
}>;
type InternalContext = Readonly<{
  consentId: string;
  assessmentVersionId: string;
  items: readonly InternalItem[];
  session: InternalSession | null;
  responses: readonly ResponseRow[];
  view: PersistedAssessmentView;
}>;

function stringValue(value: unknown, label: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`Persisted assessment ${label} is invalid.`);
  }
  return value;
}

function parseOptionIds(schema: unknown): readonly string[] {
  if (!schema || typeof schema !== "object" || Array.isArray(schema)) {
    throw new Error("Published assessment response schema is invalid.");
  }
  const candidate = schema as Readonly<Record<string, unknown>>;
  if (
    candidate.schemaVersion !== PUBLISHED_OPTION_SCHEMA_VERSION ||
    candidate.type !== "scenario-choice" ||
    !Array.isArray(candidate.optionIds) ||
    candidate.optionIds.length === 0 ||
    !candidate.optionIds.every((option) => typeof option === "string") ||
    new Set(candidate.optionIds).size !== candidate.optionIds.length ||
    JSON.stringify(Object.keys(candidate).sort()) !==
      JSON.stringify(["optionIds", "schemaVersion", "type"])
  ) {
    throw new Error("Published assessment response schema is invalid.");
  }
  return candidate.optionIds as readonly string[];
}

function parseSelection(row: ResponseRow): PersistedSelection {
  if (!row.response_payload || typeof row.response_payload !== "object") {
    throw new Error("Persisted response payload is invalid.");
  }
  const payload = row.response_payload as Readonly<Record<string, unknown>>;
  if (
    payload.schemaVersion !== PERSISTED_RESPONSE_SCHEMA_VERSION ||
    typeof payload.selectedOptionId !== "string" ||
    !Number.isInteger(row.revision)
  ) {
    throw new Error("Persisted response payload is invalid.");
  }
  return {
    itemKey: stringValue(row.item_key, "item key"),
    selectedOptionId: payload.selectedOptionId,
    revision: row.revision as number,
  };
}

function parseSession(row: SessionRow | undefined): InternalSession | null {
  if (!row) return null;
  if (row.status !== "in_progress" && row.status !== "submitted") {
    throw new Error("Persisted assessment session status is invalid.");
  }
  return {
    id: stringValue(row.id, "session ID"),
    status: row.status,
    lastItemVersionId:
      row.last_item_version_id === null
        ? null
        : stringValue(row.last_item_version_id, "last item ID"),
  };
}

async function loadInternalContext(
  client: PoolClient,
  userId: string,
  locale: Locale,
  lockSession = false,
): Promise<InternalContext | "consent-required" | "unavailable"> {
  const definition = getSyntheticPublishedDefinition();
  const consentResult = await client.query<ConsentRow>(
    `SELECT id, decision
     FROM consent_records
     WHERE user_id = $1 AND purpose_code = $2 AND notice_version = $3
     ORDER BY occurred_at DESC, id DESC
     LIMIT 1`,
    [userId, SERVICE_DATA_PURPOSE, PRIVACY_NOTICE_VERSION],
  );
  const currentConsent = consentResult.rows[0];
  if (currentConsent?.decision !== "granted") return "consent-required";
  const consentId = stringValue(currentConsent.id, "consent ID");

  const definitionResult = await client.query<DefinitionRow>(
    `SELECT assessment.id
     FROM assessment_versions AS assessment
     JOIN framework_versions AS framework ON framework.id = assessment.framework_version_id
     JOIN scoring_model_versions AS scoring ON scoring.id = assessment.scoring_model_version_id
     WHERE assessment.assessment_key = $1 AND assessment.version = $2
       AND assessment.status = 'published'
       AND framework.framework_key = $3 AND framework.version = $4
       AND framework.status = 'published'
       AND scoring.model_key = $5 AND scoring.version = $6
       AND scoring.status = 'published'`,
    [
      definition.assessmentKey,
      definition.assessmentVersion,
      definition.frameworkKey,
      definition.frameworkVersion,
      definition.scoringModelKey,
      definition.scoringModelVersion,
    ],
  );
  if (definitionResult.rows.length !== 1) return "unavailable";
  const assessmentVersionId = stringValue(definitionResult.rows[0]?.id, "assessment version ID");

  const itemResult = await client.query<ItemRow>(
    `SELECT id, item_key, display_order, required, response_schema
     FROM assessment_item_versions
     WHERE assessment_version_id = $1
     ORDER BY display_order`,
    [assessmentVersionId],
  );
  if (itemResult.rows.length !== definition.items.length) return "unavailable";
  const items = itemResult.rows.map((row, index): InternalItem => {
    const registered = definition.items[index];
    const key = stringValue(row.item_key, "item key");
    const optionIds = parseOptionIds(row.response_schema);
    if (
      !registered ||
      key !== registered.key ||
      row.display_order !== registered.displayOrder ||
      row.required !== true ||
      JSON.stringify(optionIds) !== JSON.stringify(registered.optionIds)
    ) {
      throw new Error("Published assessment items do not match the accepted fixture registry.");
    }
    return {
      id: stringValue(row.id, "item ID"),
      key,
      displayOrder: row.display_order as number,
      required: true,
      optionIds,
    };
  });

  const sessionResult = await client.query<SessionRow>(
    `SELECT id, status, last_item_version_id
     FROM assessment_sessions
     WHERE user_id = $1 AND assessment_version_id = $2
     ORDER BY started_at DESC, id DESC
     LIMIT 1${lockSession ? " FOR UPDATE" : ""}`,
    [userId, assessmentVersionId],
  );
  const session = parseSession(sessionResult.rows[0]);
  const responses = session
    ? (
        await client.query<ResponseRow>(
          `SELECT response.id, response.assessment_item_version_id, item.item_key,
                  response.response_payload, response.revision,
                  response.client_mutation_id, response.is_active
           FROM assessment_responses AS response
           JOIN assessment_item_versions AS item ON item.id = response.assessment_item_version_id
           WHERE response.session_id = $1 AND response.is_active
           ORDER BY item.display_order`,
          [session.id],
        )
      ).rows
    : [];

  return {
    consentId,
    assessmentVersionId,
    items,
    session,
    responses,
    view: createPersistedAssessmentView(locale),
  };
}

function clientState(context: InternalContext): PersistedAssessmentPageState {
  if (!context.session) return { state: "not-started", view: context.view };
  const selections = context.responses.map(parseSelection);
  if (context.session.status === "submitted") {
    return {
      state: "submitted",
      answeredCount: selections.length,
      totalItems: context.items.length,
    };
  }
  const lastItem = context.items.find((item) => item.id === context.session?.lastItemVersionId);
  const firstUnanswered = context.items.find(
    (item) => !selections.some((selection) => selection.itemKey === item.key),
  );
  return {
    state: "in-progress",
    view: context.view,
    selections,
    currentItemKey: firstUnanswered?.key ?? lastItem?.key ?? context.items[0]!.key,
  };
}

function pageStateFromContext(
  context: InternalContext | "consent-required" | "unavailable",
): PersistedAssessmentPageState {
  return typeof context === "string" ? { state: context } : clientState(context);
}

export async function loadPersistedAssessmentPageState(
  locale: Locale,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<PersistedAssessmentPageState> {
  const result = await withAuthorizedUserTransaction(identityProvider, (client, userId) =>
    loadInternalContext(client, userId, locale),
  );
  return result.state === "authorized"
    ? pageStateFromContext(result.value)
    : { state: "denied", reason: result.reason };
}

export async function startPersistedAssessment(
  locale: Locale,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<PersistedAssessmentPageState> {
  const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    let context = await loadInternalContext(client, userId, locale);
    if (typeof context === "string") return context;
    await client.query(
      `SELECT pg_advisory_xact_lock(hashtextextended('assessment-session:' || $1 || ':' || $2, 0))`,
      [userId, context.assessmentVersionId],
    );
    context = await loadInternalContext(client, userId, locale, true);
    if (typeof context === "string" || context.session) return context;

    await client.query(
      `INSERT INTO assessment_sessions (user_id, assessment_version_id, consent_record_id)
       VALUES ($1, $2, $3)`,
      [userId, context.assessmentVersionId, context.consentId],
    );
    return loadInternalContext(client, userId, locale, true);
  });
  return result.state === "authorized"
    ? pageStateFromContext(result.value)
    : { state: "denied", reason: result.reason };
}

export async function savePersistedAssessmentResponseWithExecution(
  rawInput: SavePersistedResponseInput,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<ServerMutationExecution<SavePersistedResponseResult>> {
  const input = parseSavePersistedResponseInput(rawInput);
  const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    const context = await loadInternalContext(client, userId, input.locale, true);
    if (
      typeof context === "string" ||
      !context.session ||
      context.session.status !== "in_progress"
    ) {
      return mutationExecution({ state: "not-ready" } as const, "not-applied");
    }
    const item = context.items.find((entry) => entry.key === input.itemKey);
    if (!item || !item.optionIds.includes(input.selectedOptionId)) {
      throw new Error("Persisted response does not belong to the accepted assessment version.");
    }

    const replayResult = await client.query<ResponseRow>(
      `SELECT response.id, response.assessment_item_version_id, item.item_key,
              response.response_payload, response.revision,
              response.client_mutation_id, response.is_active
       FROM assessment_responses AS response
       JOIN assessment_item_versions AS item ON item.id = response.assessment_item_version_id
       WHERE response.session_id = $1 AND response.client_mutation_id = $2`,
      [context.session.id, input.clientMutationId],
    );
    if (replayResult.rows[0]) {
      const replay = parseSelection(replayResult.rows[0]);
      if (
        replay.itemKey !== input.itemKey ||
        replay.selectedOptionId !== input.selectedOptionId ||
        replay.revision !== input.expectedRevision + 1
      ) {
        throw new Error("A client mutation ID cannot represent two different responses.");
      }
      return mutationExecution({ state: "saved", selection: replay } as const, "replayed");
    }

    const activeRow = context.responses.find(
      (row) => row.assessment_item_version_id === item.id && row.is_active === true,
    );
    const activeSelection = activeRow ? parseSelection(activeRow) : null;
    if ((activeSelection?.revision ?? 0) !== input.expectedRevision) {
      return mutationExecution(
        { state: "conflict", selection: activeSelection } as const,
        "not-applied",
      );
    }

    if (activeRow) {
      await client.query(`UPDATE assessment_responses SET is_active = false WHERE id = $1`, [
        stringValue(activeRow.id, "response ID"),
      ]);
    }
    const inserted = await client.query<ResponseRow>(
      `INSERT INTO assessment_responses
        (session_id, assessment_version_id, assessment_item_version_id, response_payload,
         revision, supersedes_response_id, client_mutation_id, is_active)
       VALUES ($1, $2, $3, $4::jsonb, $5, $6, $7, true)
       RETURNING id, assessment_item_version_id, $8::text AS item_key, response_payload,
                 revision, client_mutation_id, is_active`,
      [
        context.session.id,
        context.assessmentVersionId,
        item.id,
        JSON.stringify({
          schemaVersion: PERSISTED_RESPONSE_SCHEMA_VERSION,
          selectedOptionId: input.selectedOptionId,
        }),
        input.expectedRevision + 1,
        activeRow ? stringValue(activeRow.id, "response ID") : null,
        input.clientMutationId,
        item.key,
      ],
    );
    await client.query(
      `UPDATE assessment_sessions SET last_item_version_id = $1, updated_at = clock_timestamp()
       WHERE id = $2`,
      [item.id, context.session.id],
    );
    return mutationExecution(
      { state: "saved", selection: parseSelection(inserted.rows[0]!) } as const,
      "applied",
    );
  });
  return result.state === "authorized"
    ? result.value
    : mutationExecution({ state: "denied" } as const, "not-applied");
}

export async function savePersistedAssessmentResponse(
  rawInput: SavePersistedResponseInput,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<SavePersistedResponseResult> {
  return (await savePersistedAssessmentResponseWithExecution(rawInput, identityProvider)).result;
}

export async function submitPersistedAssessment(
  locale: Locale,
  identityProvider: IdentityProvider = createClerkDevelopmentIdentityProvider(),
): Promise<SubmitPersistedAssessmentResult> {
  const result = await withAuthorizedUserTransaction(identityProvider, async (client, userId) => {
    const context = await loadInternalContext(client, userId, locale, true);
    if (typeof context === "string" || !context.session) return { state: "not-ready" } as const;
    if (context.session.status === "submitted") {
      return {
        state: "submitted",
        answeredCount: context.responses.length,
        totalItems: context.items.length,
      } as const;
    }
    if (context.responses.length !== context.items.filter((item) => item.required).length) {
      return { state: "incomplete" } as const;
    }
    await client.query(
      `UPDATE assessment_sessions SET status = 'submitted', submitted_at = clock_timestamp(),
              updated_at = clock_timestamp()
       WHERE id = $1`,
      [context.session.id],
    );
    return {
      state: "submitted",
      answeredCount: context.responses.length,
      totalItems: context.items.length,
    } as const;
  });
  return result.state === "authorized" ? result.value : { state: "denied" };
}
