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

export const databaseSchema = {
  userAccounts,
  externalIdentities,
  consentRecords,
  frameworkVersions,
  competencyVersions,
  scoringModelVersions,
  assessmentVersions,
  assessmentItemVersions,
  assessmentItemCompetencies,
} as const;
