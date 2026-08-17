import { sql } from "drizzle-orm/sql/sql";
import { boolean } from "drizzle-orm/pg-core/columns/boolean";
import { pgEnum } from "drizzle-orm/pg-core/columns/enum";
import { integer } from "drizzle-orm/pg-core/columns/integer";
import { jsonb } from "drizzle-orm/pg-core/columns/jsonb";
import { text } from "drizzle-orm/pg-core/columns/text";
import { timestamp } from "drizzle-orm/pg-core/columns/timestamp";
import { uuid } from "drizzle-orm/pg-core/columns/uuid";
import { check } from "drizzle-orm/pg-core/checks";
import { foreignKey } from "drizzle-orm/pg-core/foreign-keys";
import { index, uniqueIndex } from "drizzle-orm/pg-core/indexes";
import { primaryKey } from "drizzle-orm/pg-core/primary-keys";
import { pgTable } from "drizzle-orm/pg-core/table";
import { unique } from "drizzle-orm/pg-core/unique-constraint";

export const accountStatus = pgEnum("account_status", [
  "active",
  "suspended",
  "deletion_pending",
  "deleted",
]);
export const consentDecision = pgEnum("consent_decision", ["granted", "declined", "withdrawn"]);
export const publicationStatus = pgEnum("publication_status", ["draft", "published", "retired"]);
export const competencyKind = pgEnum("competency_kind", ["core", "multiplier"]);
export const scoringMethod = pgEnum("scoring_method", ["deterministic_rubric"]);
export const assessmentItemType = pgEnum("assessment_item_type", [
  "scenario_choice",
  "self_reflection",
]);
export const assessmentSessionStatus = pgEnum("assessment_session_status", [
  "in_progress",
  "submitted",
]);

const utcTimestamp = (name: string) => timestamp(name, { withTimezone: true, mode: "date" });
const versionedJsonCheck = (column: { name: string }) =>
  sql`rise_pals_private.is_versioned_json_object(${sql.identifier(column.name)})`;

export const userAccounts = pgTable(
  "user_accounts",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    status: accountStatus("status").notNull().default("active"),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
    updatedAt: utcTimestamp("updated_at").notNull().defaultNow(),
    lastSeenAt: utcTimestamp("last_seen_at"),
    deletedAt: utcTimestamp("deleted_at"),
  },
  (table) => [
    check(
      "user_accounts_deleted_state_check",
      sql`(${table.status} = 'deleted' AND ${table.deletedAt} IS NOT NULL) OR (${table.status} <> 'deleted' AND ${table.deletedAt} IS NULL)`,
    ),
  ],
);

export const externalIdentities = pgTable(
  "external_identities",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: uuid("user_id")
      .notNull()
      .references(() => userAccounts.id, { onDelete: "restrict", onUpdate: "restrict" }),
    provider: text("provider").notNull(),
    providerSubject: text("provider_subject").notNull(),
    emailNormalized: text("email_normalized"),
    emailVerifiedAt: utcTimestamp("email_verified_at"),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
    lastAuthenticatedAt: utcTimestamp("last_authenticated_at").notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex("external_identities_provider_subject_unique").on(
      table.provider,
      table.providerSubject,
    ),
    index("external_identities_user_created_idx").on(table.userId, table.createdAt),
    check("external_identities_provider_not_blank", sql`btrim(${table.provider}) <> ''`),
    check("external_identities_subject_not_blank", sql`btrim(${table.providerSubject}) <> ''`),
  ],
);

export const consentRecords = pgTable(
  "consent_records",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: uuid("user_id")
      .notNull()
      .references(() => userAccounts.id, { onDelete: "restrict", onUpdate: "restrict" }),
    purposeCode: text("purpose_code").notNull(),
    noticeVersion: text("notice_version").notNull(),
    decision: consentDecision("decision").notNull(),
    occurredAt: utcTimestamp("occurred_at").notNull().defaultNow(),
    locale: text("locale").notNull(),
    sourceSurface: text("source_surface").notNull(),
    proofDigest: text("proof_digest").notNull(),
  },
  (table) => [
    index("consent_records_user_occurred_idx").on(table.userId, table.occurredAt),
    unique("consent_records_id_user_unique").on(table.id, table.userId),
    check("consent_records_purpose_not_blank", sql`btrim(${table.purposeCode}) <> ''`),
    check("consent_records_notice_not_blank", sql`btrim(${table.noticeVersion}) <> ''`),
    check(
      "consent_records_locale_check",
      sql`${table.locale} ~ '^[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$'`,
    ),
    check("consent_records_surface_not_blank", sql`btrim(${table.sourceSurface}) <> ''`),
    check("consent_records_digest_check", sql`${table.proofDigest} ~ '^[0-9a-f]{64}$'`),
  ],
);

export const userProfiles = pgTable(
  "user_profiles",
  {
    userId: uuid("user_id")
      .primaryKey()
      .references(() => userAccounts.id, { onDelete: "restrict", onUpdate: "restrict" }),
    preferredLocale: text("preferred_locale").notNull(),
    timezone: text("timezone").notNull(),
    roleFamily: text("role_family").notNull(),
    function: text("function").notNull(),
    experienceBand: text("experience_band").notNull(),
    goals: text("goals").array().notNull(),
    onboardingCompletedAt: utcTimestamp("onboarding_completed_at").notNull(),
    profileSchemaVersion: text("profile_schema_version").notNull(),
    updatedAt: utcTimestamp("updated_at").notNull().defaultNow(),
  },
  (table) => [
    check("user_profiles_locale_check", sql`${table.preferredLocale} IN ('th', 'en')`),
    check(
      "user_profiles_timezone_check",
      sql`${table.timezone} IN ('Asia/Bangkok', 'Europe/Berlin', 'UTC')`,
    ),
    check(
      "user_profiles_role_family_check",
      sql`${table.roleFamily} IN ('individual-contributor', 'people-manager', 'business-owner', 'student-transitioner', 'other')`,
    ),
    check(
      "user_profiles_function_check",
      sql`${table.function} IN ('operations', 'technology-data', 'sales-marketing', 'people-support', 'finance-risk', 'other')`,
    ),
    check(
      "user_profiles_experience_band_check",
      sql`${table.experienceBand} IN ('early', 'mid', 'senior', 'other')`,
    ),
    check(
      "user_profiles_goals_check",
      sql`cardinality(${table.goals}) BETWEEN 1 AND 3 AND ${table.goals} <@ ARRAY['adapt-to-change', 'improve-judgement', 'communicate-impact', 'build-evidence', 'other']::text[]`,
    ),
    check("user_profiles_schema_version_check", sql`${table.profileSchemaVersion} = 'profile-v1'`),
  ],
);

export const frameworkVersions = pgTable(
  "framework_versions",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    frameworkKey: text("framework_key").notNull(),
    version: text("version").notNull(),
    status: publicationStatus("status").notNull().default("draft"),
    scoringDisclaimerKey: text("scoring_disclaimer_key").notNull(),
    publishedAt: utcTimestamp("published_at"),
    contentDigest: text("content_digest").notNull(),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex("framework_versions_business_version_unique").on(table.frameworkKey, table.version),
    unique("framework_versions_id_key_unique").on(table.id, table.frameworkKey),
    check("framework_versions_key_not_blank", sql`btrim(${table.frameworkKey}) <> ''`),
    check("framework_versions_version_not_blank", sql`btrim(${table.version}) <> ''`),
    check(
      "framework_versions_disclaimer_not_blank",
      sql`btrim(${table.scoringDisclaimerKey}) <> ''`,
    ),
    check("framework_versions_digest_check", sql`${table.contentDigest} ~ '^[0-9a-f]{64}$'`),
    check(
      "framework_versions_publication_timestamp_check",
      sql`(${table.status} = 'draft' AND ${table.publishedAt} IS NULL) OR (${table.status} <> 'draft' AND ${table.publishedAt} IS NOT NULL)`,
    ),
  ],
);

export const competencyVersions = pgTable(
  "competency_versions",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    frameworkVersionId: uuid("framework_version_id")
      .notNull()
      .references(() => frameworkVersions.id, { onDelete: "restrict", onUpdate: "restrict" }),
    competencyKey: text("competency_key").notNull(),
    kind: competencyKind("kind").notNull(),
    weightBasisPoints: integer("weight_basis_points"),
    displayOrder: integer("display_order").notNull(),
    definitionI18n: jsonb("definition_i18n").notNull(),
    behaviorAnchors: jsonb("behavior_anchors").notNull(),
    contentDigest: text("content_digest").notNull(),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex("competency_versions_framework_key_unique").on(
      table.frameworkVersionId,
      table.competencyKey,
    ),
    uniqueIndex("competency_versions_framework_kind_order_unique").on(
      table.frameworkVersionId,
      table.kind,
      table.displayOrder,
    ),
    unique("competency_versions_id_framework_unique").on(table.id, table.frameworkVersionId),
    unique("competency_versions_id_framework_kind_unique").on(
      table.id,
      table.frameworkVersionId,
      table.kind,
    ),
    check("competency_versions_key_not_blank", sql`btrim(${table.competencyKey}) <> ''`),
    check("competency_versions_order_positive", sql`${table.displayOrder} > 0`),
    check(
      "competency_versions_weight_kind_check",
      sql`(${table.kind} = 'core' AND ${table.weightBasisPoints} BETWEEN 1 AND 10000) OR (${table.kind} = 'multiplier' AND ${table.weightBasisPoints} IS NULL)`,
    ),
    check("competency_versions_definition_json_check", versionedJsonCheck(table.definitionI18n)),
    check("competency_versions_anchors_json_check", versionedJsonCheck(table.behaviorAnchors)),
    check("competency_versions_digest_check", sql`${table.contentDigest} ~ '^[0-9a-f]{64}$'`),
  ],
);

export const scoringModelVersions = pgTable(
  "scoring_model_versions",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    frameworkVersionId: uuid("framework_version_id")
      .notNull()
      .references(() => frameworkVersions.id, { onDelete: "restrict", onUpdate: "restrict" }),
    modelKey: text("model_key").notNull(),
    version: text("version").notNull(),
    method: scoringMethod("method").notNull(),
    configuration: jsonb("configuration").notNull(),
    limitationsI18n: jsonb("limitations_i18n").notNull(),
    status: publicationStatus("status").notNull().default("draft"),
    publishedAt: utcTimestamp("published_at"),
    contentDigest: text("content_digest").notNull(),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex("scoring_model_versions_business_version_unique").on(table.modelKey, table.version),
    unique("scoring_model_versions_id_framework_unique").on(table.id, table.frameworkVersionId),
    check("scoring_model_versions_key_not_blank", sql`btrim(${table.modelKey}) <> ''`),
    check("scoring_model_versions_version_not_blank", sql`btrim(${table.version}) <> ''`),
    check(
      "scoring_model_versions_configuration_json_check",
      versionedJsonCheck(table.configuration),
    ),
    check(
      "scoring_model_versions_limitations_json_check",
      versionedJsonCheck(table.limitationsI18n),
    ),
    check("scoring_model_versions_digest_check", sql`${table.contentDigest} ~ '^[0-9a-f]{64}$'`),
    check(
      "scoring_model_versions_publication_timestamp_check",
      sql`(${table.status} = 'draft' AND ${table.publishedAt} IS NULL) OR (${table.status} <> 'draft' AND ${table.publishedAt} IS NOT NULL)`,
    ),
  ],
);

export const assessmentVersions = pgTable(
  "assessment_versions",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    assessmentKey: text("assessment_key").notNull(),
    version: text("version").notNull(),
    frameworkVersionId: uuid("framework_version_id").notNull(),
    scoringModelVersionId: uuid("scoring_model_version_id").notNull(),
    status: publicationStatus("status").notNull().default("draft"),
    estimatedMinutes: integer("estimated_minutes").notNull(),
    publishedAt: utcTimestamp("published_at"),
    contentDigest: text("content_digest").notNull(),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex("assessment_versions_business_version_unique").on(
      table.assessmentKey,
      table.version,
    ),
    unique("assessment_versions_id_framework_unique").on(table.id, table.frameworkVersionId),
    foreignKey({
      name: "assessment_versions_framework_fk",
      columns: [table.frameworkVersionId],
      foreignColumns: [frameworkVersions.id],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "assessment_versions_scoring_framework_fk",
      columns: [table.scoringModelVersionId, table.frameworkVersionId],
      foreignColumns: [scoringModelVersions.id, scoringModelVersions.frameworkVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    check("assessment_versions_key_not_blank", sql`btrim(${table.assessmentKey}) <> ''`),
    check("assessment_versions_version_not_blank", sql`btrim(${table.version}) <> ''`),
    check(
      "assessment_versions_estimated_minutes_check",
      sql`${table.estimatedMinutes} BETWEEN 1 AND 240`,
    ),
    check("assessment_versions_digest_check", sql`${table.contentDigest} ~ '^[0-9a-f]{64}$'`),
    check(
      "assessment_versions_publication_timestamp_check",
      sql`(${table.status} = 'draft' AND ${table.publishedAt} IS NULL) OR (${table.status} <> 'draft' AND ${table.publishedAt} IS NOT NULL)`,
    ),
  ],
);

export const assessmentItemVersions = pgTable(
  "assessment_item_versions",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    assessmentVersionId: uuid("assessment_version_id").notNull(),
    frameworkVersionId: uuid("framework_version_id").notNull(),
    itemKey: text("item_key").notNull(),
    itemType: assessmentItemType("item_type").notNull(),
    promptI18n: jsonb("prompt_i18n").notNull(),
    responseSchema: jsonb("response_schema").notNull(),
    displayOrder: integer("display_order").notNull(),
    required: boolean("required").notNull().default(true),
    contentDigest: text("content_digest").notNull(),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex("assessment_item_versions_assessment_key_unique").on(
      table.assessmentVersionId,
      table.itemKey,
    ),
    uniqueIndex("assessment_item_versions_assessment_order_unique").on(
      table.assessmentVersionId,
      table.displayOrder,
    ),
    unique("assessment_item_versions_id_framework_unique").on(table.id, table.frameworkVersionId),
    unique("assessment_item_versions_id_assessment_unique").on(table.id, table.assessmentVersionId),
    foreignKey({
      name: "assessment_item_versions_assessment_framework_fk",
      columns: [table.assessmentVersionId, table.frameworkVersionId],
      foreignColumns: [assessmentVersions.id, assessmentVersions.frameworkVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    check("assessment_item_versions_key_not_blank", sql`btrim(${table.itemKey}) <> ''`),
    check("assessment_item_versions_order_positive", sql`${table.displayOrder} > 0`),
    check("assessment_item_versions_prompt_json_check", versionedJsonCheck(table.promptI18n)),
    check("assessment_item_versions_response_json_check", versionedJsonCheck(table.responseSchema)),
    check("assessment_item_versions_digest_check", sql`${table.contentDigest} ~ '^[0-9a-f]{64}$'`),
  ],
);

export const assessmentItemCompetencies = pgTable(
  "assessment_item_competencies",
  {
    assessmentItemVersionId: uuid("assessment_item_version_id").notNull(),
    competencyVersionId: uuid("competency_version_id").notNull(),
    frameworkVersionId: uuid("framework_version_id").notNull(),
    targetKind: competencyKind("target_kind").notNull(),
    contributionDirection: integer("contribution_direction").notNull().default(1),
    rationaleKey: text("rationale_key").notNull(),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
  },
  (table) => [
    primaryKey({
      name: "assessment_item_competencies_pk",
      columns: [table.assessmentItemVersionId, table.competencyVersionId],
    }),
    foreignKey({
      name: "assessment_item_competencies_item_framework_fk",
      columns: [table.assessmentItemVersionId, table.frameworkVersionId],
      foreignColumns: [assessmentItemVersions.id, assessmentItemVersions.frameworkVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "assessment_item_competencies_target_framework_kind_fk",
      columns: [table.competencyVersionId, table.frameworkVersionId, table.targetKind],
      foreignColumns: [
        competencyVersions.id,
        competencyVersions.frameworkVersionId,
        competencyVersions.kind,
      ],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    index("assessment_item_competencies_competency_idx").on(table.competencyVersionId),
    check(
      "assessment_item_competencies_direction_check",
      sql`${table.contributionDirection} IN (-1, 1)`,
    ),
    check(
      "assessment_item_competencies_rationale_not_blank",
      sql`btrim(${table.rationaleKey}) <> ''`,
    ),
  ],
);

export const assessmentSessions = pgTable(
  "assessment_sessions",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: uuid("user_id").notNull(),
    assessmentVersionId: uuid("assessment_version_id").notNull(),
    consentRecordId: uuid("consent_record_id").notNull(),
    status: assessmentSessionStatus("status").notNull().default("in_progress"),
    lastItemVersionId: uuid("last_item_version_id"),
    startedAt: utcTimestamp("started_at").notNull().defaultNow(),
    updatedAt: utcTimestamp("updated_at").notNull().defaultNow(),
    submittedAt: utcTimestamp("submitted_at"),
  },
  (table) => [
    unique("assessment_sessions_id_user_unique").on(table.id, table.userId),
    unique("assessment_sessions_id_assessment_unique").on(table.id, table.assessmentVersionId),
    uniqueIndex("assessment_sessions_one_active_per_owner_version")
      .on(table.userId, table.assessmentVersionId)
      .where(sql`${table.status} = 'in_progress'`),
    index("assessment_sessions_user_started_idx").on(table.userId, table.startedAt),
    foreignKey({
      name: "assessment_sessions_user_fk",
      columns: [table.userId],
      foreignColumns: [userAccounts.id],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "assessment_sessions_assessment_fk",
      columns: [table.assessmentVersionId],
      foreignColumns: [assessmentVersions.id],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "assessment_sessions_consent_owner_fk",
      columns: [table.consentRecordId, table.userId],
      foreignColumns: [consentRecords.id, consentRecords.userId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "assessment_sessions_last_item_assessment_fk",
      columns: [table.lastItemVersionId, table.assessmentVersionId],
      foreignColumns: [assessmentItemVersions.id, assessmentItemVersions.assessmentVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    check(
      "assessment_sessions_submission_timestamp_check",
      sql`(${table.status} = 'in_progress' AND ${table.submittedAt} IS NULL) OR (${table.status} = 'submitted' AND ${table.submittedAt} IS NOT NULL)`,
    ),
  ],
);

export const assessmentResponses = pgTable(
  "assessment_responses",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    sessionId: uuid("session_id").notNull(),
    assessmentVersionId: uuid("assessment_version_id").notNull(),
    assessmentItemVersionId: uuid("assessment_item_version_id").notNull(),
    responsePayload: jsonb("response_payload").notNull(),
    revision: integer("revision").notNull(),
    supersedesResponseId: uuid("supersedes_response_id"),
    clientMutationId: uuid("client_mutation_id").notNull(),
    isActive: boolean("is_active").notNull().default(true),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
  },
  (table) => [
    unique("assessment_responses_id_session_unique").on(table.id, table.sessionId),
    uniqueIndex("assessment_responses_session_mutation_unique").on(
      table.sessionId,
      table.clientMutationId,
    ),
    uniqueIndex("assessment_responses_one_active_per_item")
      .on(table.sessionId, table.assessmentItemVersionId)
      .where(sql`${table.isActive} = true`),
    index("assessment_responses_session_created_idx").on(table.sessionId, table.createdAt),
    foreignKey({
      name: "assessment_responses_session_assessment_fk",
      columns: [table.sessionId, table.assessmentVersionId],
      foreignColumns: [assessmentSessions.id, assessmentSessions.assessmentVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "assessment_responses_item_assessment_fk",
      columns: [table.assessmentItemVersionId, table.assessmentVersionId],
      foreignColumns: [assessmentItemVersions.id, assessmentItemVersions.assessmentVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "assessment_responses_supersedes_session_fk",
      columns: [table.supersedesResponseId, table.sessionId],
      foreignColumns: [table.id, table.sessionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    check("assessment_responses_revision_positive", sql`${table.revision} > 0`),
    check(
      "assessment_responses_supersession_shape_check",
      sql`(${table.revision} = 1 AND ${table.supersedesResponseId} IS NULL) OR (${table.revision} > 1 AND ${table.supersedesResponseId} IS NOT NULL)`,
    ),
    check("assessment_responses_payload_json_check", versionedJsonCheck(table.responsePayload)),
  ],
);

export const scoringRuns = pgTable(
  "scoring_runs",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: uuid("user_id").notNull(),
    assessmentSessionId: uuid("assessment_session_id").notNull(),
    assessmentVersionId: uuid("assessment_version_id").notNull(),
    frameworkVersionId: uuid("framework_version_id").notNull(),
    scoringModelVersionId: uuid("scoring_model_version_id").notNull(),
    runNumber: integer("run_number").notNull(),
    runKind: text("run_kind").notNull(),
    supersedesScoringRunId: uuid("supersedes_scoring_run_id"),
    clientMutationId: uuid("client_mutation_id").notNull(),
    inputDigest: text("input_digest").notNull(),
    outputDigest: text("output_digest").notNull(),
    resultPolicyKey: text("result_policy_key").notNull(),
    resultPolicyVersion: text("result_policy_version").notNull(),
    resultPolicyDigest: text("result_policy_digest").notNull(),
    computedAt: utcTimestamp("computed_at").notNull().defaultNow(),
  },
  (table) => [
    unique("scoring_runs_id_user_unique").on(table.id, table.userId),
    unique("scoring_runs_id_session_unique").on(table.id, table.assessmentSessionId),
    unique("scoring_runs_id_framework_unique").on(table.id, table.frameworkVersionId),
    uniqueIndex("scoring_runs_session_number_unique").on(
      table.assessmentSessionId,
      table.runNumber,
    ),
    uniqueIndex("scoring_runs_session_mutation_unique").on(
      table.assessmentSessionId,
      table.clientMutationId,
    ),
    index("scoring_runs_user_computed_idx").on(table.userId, table.computedAt),
    foreignKey({
      name: "scoring_runs_session_owner_fk",
      columns: [table.assessmentSessionId, table.userId],
      foreignColumns: [assessmentSessions.id, assessmentSessions.userId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "scoring_runs_session_assessment_fk",
      columns: [table.assessmentSessionId, table.assessmentVersionId],
      foreignColumns: [assessmentSessions.id, assessmentSessions.assessmentVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "scoring_runs_assessment_framework_fk",
      columns: [table.assessmentVersionId, table.frameworkVersionId],
      foreignColumns: [assessmentVersions.id, assessmentVersions.frameworkVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "scoring_runs_scoring_framework_fk",
      columns: [table.scoringModelVersionId, table.frameworkVersionId],
      foreignColumns: [scoringModelVersions.id, scoringModelVersions.frameworkVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "scoring_runs_supersedes_session_fk",
      columns: [table.supersedesScoringRunId, table.assessmentSessionId],
      foreignColumns: [table.id, table.assessmentSessionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    check("scoring_runs_number_positive", sql`${table.runNumber} > 0`),
    check("scoring_runs_kind_check", sql`${table.runKind} IN ('normal', 'rescore')`),
    check(
      "scoring_runs_supersession_shape_check",
      sql`(${table.runNumber} = 1 AND ${table.runKind} = 'normal' AND ${table.supersedesScoringRunId} IS NULL) OR (${table.runNumber} > 1 AND ${table.runKind} = 'rescore' AND ${table.supersedesScoringRunId} IS NOT NULL)`,
    ),
    check("scoring_runs_input_digest_check", sql`${table.inputDigest} ~ '^[0-9a-f]{64}$'`),
    check("scoring_runs_output_digest_check", sql`${table.outputDigest} ~ '^[0-9a-f]{64}$'`),
    check(
      "scoring_runs_policy_check",
      sql`${table.resultPolicyKey} = 'persisted-synthetic-priority-v1' AND ${table.resultPolicyVersion} = '1.0.0' AND ${table.resultPolicyDigest} = '10f2ab076828d50b228ff53d57332527dfe9d1b2769c4b57bd0476dd3c263157'`,
    ),
  ],
);

export const competencyScores = pgTable(
  "competency_scores",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: uuid("user_id").notNull(),
    scoringRunId: uuid("scoring_run_id").notNull(),
    frameworkVersionId: uuid("framework_version_id").notNull(),
    competencyVersionId: uuid("competency_version_id").notNull(),
    targetKind: competencyKind("target_kind").notNull(),
    earnedPoints: integer("earned_points").notNull(),
    availablePoints: integer("available_points").notNull(),
    evidenceCount: integer("evidence_count").notNull(),
    normalizedBasisPoints: integer("normalized_basis_points").notNull(),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex("competency_scores_run_competency_unique").on(
      table.scoringRunId,
      table.competencyVersionId,
    ),
    foreignKey({
      name: "competency_scores_run_owner_fk",
      columns: [table.scoringRunId, table.userId],
      foreignColumns: [scoringRuns.id, scoringRuns.userId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "competency_scores_run_framework_fk",
      columns: [table.scoringRunId, table.frameworkVersionId],
      foreignColumns: [scoringRuns.id, scoringRuns.frameworkVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "competency_scores_target_framework_kind_fk",
      columns: [table.competencyVersionId, table.frameworkVersionId, table.targetKind],
      foreignColumns: [
        competencyVersions.id,
        competencyVersions.frameworkVersionId,
        competencyVersions.kind,
      ],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    check("competency_scores_core_kind_check", sql`${table.targetKind} = 'core'`),
    check(
      "competency_scores_points_check",
      sql`${table.availablePoints} > 0 AND ${table.earnedPoints} BETWEEN 0 AND ${table.availablePoints} AND ${table.evidenceCount} > 0`,
    ),
    check(
      "competency_scores_basis_points_check",
      sql`${table.normalizedBasisPoints} = floor((${table.earnedPoints}::numeric * 10000) / ${table.availablePoints})::integer`,
    ),
  ],
);

export const multiplierObservations = pgTable(
  "multiplier_observations",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: uuid("user_id").notNull(),
    scoringRunId: uuid("scoring_run_id").notNull(),
    frameworkVersionId: uuid("framework_version_id").notNull(),
    competencyVersionId: uuid("competency_version_id").notNull(),
    targetKind: competencyKind("target_kind").notNull(),
    earnedRubricPoints: integer("earned_rubric_points").notNull(),
    availableRubricPoints: integer("available_rubric_points").notNull(),
    evidenceCount: integer("evidence_count").notNull(),
    limitationCode: text("limitation_code").notNull(),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex("multiplier_observations_run_competency_unique").on(
      table.scoringRunId,
      table.competencyVersionId,
    ),
    foreignKey({
      name: "multiplier_observations_run_owner_fk",
      columns: [table.scoringRunId, table.userId],
      foreignColumns: [scoringRuns.id, scoringRuns.userId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "multiplier_observations_run_framework_fk",
      columns: [table.scoringRunId, table.frameworkVersionId],
      foreignColumns: [scoringRuns.id, scoringRuns.frameworkVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "multiplier_observations_target_framework_kind_fk",
      columns: [table.competencyVersionId, table.frameworkVersionId, table.targetKind],
      foreignColumns: [
        competencyVersions.id,
        competencyVersions.frameworkVersionId,
        competencyVersions.kind,
      ],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    check("multiplier_observations_kind_check", sql`${table.targetKind} = 'multiplier'`),
    check(
      "multiplier_observations_points_check",
      sql`${table.availableRubricPoints} > 0 AND ${table.earnedRubricPoints} BETWEEN 0 AND ${table.availableRubricPoints} AND ${table.evidenceCount} = 1`,
    ),
    check(
      "multiplier_observations_limitation_check",
      sql`${table.limitationCode} = 'single-scenario-not-behavior-pattern'`,
    ),
  ],
);

export const scoreExplanations = pgTable(
  "score_explanations",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: uuid("user_id").notNull(),
    scoringRunId: uuid("scoring_run_id").notNull(),
    frameworkVersionId: uuid("framework_version_id").notNull(),
    targetKind: text("target_kind").notNull(),
    targetCompetencyKind: competencyKind("target_competency_kind"),
    competencyVersionId: uuid("competency_version_id"),
    explanationCode: text("explanation_code").notNull(),
    messageParams: jsonb("message_params").notNull(),
    supportingItemKeys: text("supporting_item_keys").array().notNull(),
    limitationCodes: text("limitation_codes").array().notNull(),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex("score_explanations_run_target_unique").on(
      table.scoringRunId,
      table.targetKind,
      table.competencyVersionId,
    ),
    foreignKey({
      name: "score_explanations_run_owner_fk",
      columns: [table.scoringRunId, table.userId],
      foreignColumns: [scoringRuns.id, scoringRuns.userId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "score_explanations_run_framework_fk",
      columns: [table.scoringRunId, table.frameworkVersionId],
      foreignColumns: [scoringRuns.id, scoringRuns.frameworkVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "score_explanations_target_framework_kind_fk",
      columns: [table.competencyVersionId, table.frameworkVersionId, table.targetCompetencyKind],
      foreignColumns: [
        competencyVersions.id,
        competencyVersions.frameworkVersionId,
        competencyVersions.kind,
      ],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    check(
      "score_explanations_target_shape_check",
      sql`(${table.targetKind} = 'run' AND ${table.competencyVersionId} IS NULL AND ${table.targetCompetencyKind} IS NULL AND ${table.explanationCode} = 'synthetic-partial-result-limitation') OR (${table.targetKind} = 'core' AND ${table.competencyVersionId} IS NOT NULL AND ${table.targetCompetencyKind} = 'core' AND ${table.explanationCode} = 'assessed-core-raw-signal') OR (${table.targetKind} = 'multiplier' AND ${table.competencyVersionId} IS NOT NULL AND ${table.targetCompetencyKind} = 'multiplier' AND ${table.explanationCode} = 'single-scenario-multiplier-observation') OR (${table.targetKind} = 'priority' AND ((${table.competencyVersionId} IS NOT NULL AND ${table.targetCompetencyKind} = 'core' AND ${table.explanationCode} = 'unique-lowest-assessed-core-signal') OR (${table.competencyVersionId} IS NULL AND ${table.targetCompetencyKind} IS NULL AND ${table.explanationCode} = 'no-distinct-priority')))`,
    ),
    check(
      "score_explanations_params_check",
      sql`jsonb_typeof(${table.messageParams}) = 'object' AND ${table.messageParams} = '{"schemaVersion":"persisted-result-explanation-params-v1"}'::jsonb`,
    ),
    check("score_explanations_limitations_check", sql`cardinality(${table.limitationCodes}) > 0`),
  ],
);

export const priorityRecommendations = pgTable(
  "priority_recommendations",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: uuid("user_id").notNull(),
    scoringRunId: uuid("scoring_run_id").notNull(),
    frameworkVersionId: uuid("framework_version_id").notNull(),
    competencyVersionId: uuid("competency_version_id").notNull(),
    targetKind: competencyKind("target_kind").notNull(),
    rank: integer("rank").notNull(),
    reasonCode: text("reason_code").notNull(),
    supportingItemKeys: text("supporting_item_keys").array().notNull(),
    nextAction: jsonb("next_action").notNull(),
    createdAt: utcTimestamp("created_at").notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex("priority_recommendations_one_per_run").on(table.scoringRunId),
    foreignKey({
      name: "priority_recommendations_run_owner_fk",
      columns: [table.scoringRunId, table.userId],
      foreignColumns: [scoringRuns.id, scoringRuns.userId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "priority_recommendations_run_framework_fk",
      columns: [table.scoringRunId, table.frameworkVersionId],
      foreignColumns: [scoringRuns.id, scoringRuns.frameworkVersionId],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    foreignKey({
      name: "priority_recommendations_target_framework_kind_fk",
      columns: [table.competencyVersionId, table.frameworkVersionId, table.targetKind],
      foreignColumns: [
        competencyVersions.id,
        competencyVersions.frameworkVersionId,
        competencyVersions.kind,
      ],
    })
      .onDelete("restrict")
      .onUpdate("restrict"),
    check("priority_recommendations_core_kind_check", sql`${table.targetKind} = 'core'`),
    check("priority_recommendations_rank_check", sql`${table.rank} = 1`),
    check(
      "priority_recommendations_reason_check",
      sql`${table.reasonCode} = 'unique-lowest-assessed-core-signal'`,
    ),
    check(
      "priority_recommendations_items_check",
      sql`cardinality(${table.supportingItemKeys}) > 0`,
    ),
    check(
      "priority_recommendations_action_check",
      sql`jsonb_typeof(${table.nextAction}) = 'object' AND ${table.nextAction}->>'kind' IN ('prototype-lesson', 'practice-unavailable')`,
    ),
  ],
);

export const databaseSchema = {
  userAccounts,
  externalIdentities,
  consentRecords,
  userProfiles,
  frameworkVersions,
  competencyVersions,
  scoringModelVersions,
  assessmentVersions,
  assessmentItemVersions,
  assessmentItemCompetencies,
  assessmentSessions,
  assessmentResponses,
  scoringRuns,
  competencyScores,
  multiplierObservations,
  scoreExplanations,
  priorityRecommendations,
} as const;
