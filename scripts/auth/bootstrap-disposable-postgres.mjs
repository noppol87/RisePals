import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import pg from "pg";

const { Pool } = pg;
const migrationDirectory = resolve("drizzle");
const migrationUrl = process.env.DATABASE_MIGRATION_URL;
const bootstrapUrl = process.env.RISE_PALS_DISPOSABLE_BOOTSTRAP_URL;

if (!migrationUrl || !bootstrapUrl) {
  throw new Error("Disposable smoke bootstrap requires migration and bootstrap URLs.");
}

const ownerPool = new Pool({ connectionString: migrationUrl, max: 1 });
const bootstrapPool = new Pool({ connectionString: bootstrapUrl, max: 1 });
const digest = "a".repeat(64);
const definition = JSON.parse(
  await readFile(
    resolve("src/modules/assessment/persistence/synthetic-published-definition.json"),
    "utf8",
  ),
);
const canonicalCompetencies = [
  ["critical-thinking-fact-checking", "core", 2000, 1],
  ["systematic-thinking", "core", 1500, 2],
  ["growth-mindset", "core", 1500, 3],
  ["emotional-intelligence", "core", 1000, 4],
  ["resilience-adaptability", "core", 1000, 5],
  ["curiosity", "core", 1000, 6],
  ["ethical-judgement-governance", "core", 1000, 7],
  ["strategic-storytelling-framing", "core", 1000, 8],
  ["ownership-thinking", "multiplier", null, 1],
  ["sense-of-urgency", "multiplier", null, 2],
];

async function seedSyntheticPublishedDefinition(client) {
  const frameworkResult = await client.query(
    `INSERT INTO framework_versions
      (framework_key, version, scoring_disclaimer_key, content_digest)
     VALUES ($1, $2, 'assessment.limitations.v1', $3)
     RETURNING id`,
    [definition.frameworkKey, definition.frameworkVersion, digest],
  );
  const frameworkId = frameworkResult.rows[0].id;
  const competencyIds = new Map();
  for (const [key, kind, weight, order] of canonicalCompetencies) {
    const competency = await client.query(
      `INSERT INTO competency_versions
        (framework_version_id, competency_key, kind, weight_basis_points, display_order,
         definition_i18n, behavior_anchors, content_digest)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8)
       RETURNING id`,
      [
        frameworkId,
        key,
        kind,
        weight,
        order,
        JSON.stringify({ schemaVersion: "1", th: `synthetic-${key}`, en: `synthetic-${key}` }),
        JSON.stringify({ schemaVersion: "1", anchors: [] }),
        digest,
      ],
    );
    competencyIds.set(key, competency.rows[0].id);
  }
  await client.query(
    `UPDATE framework_versions SET status = 'published', published_at = now() WHERE id = $1`,
    [frameworkId],
  );
  const scoringResult = await client.query(
    `INSERT INTO scoring_model_versions
      (framework_version_id, model_key, version, method, configuration, limitations_i18n,
       content_digest)
     VALUES ($1, $2, $3, 'deterministic_rubric', $4::jsonb, $5::jsonb, $6)
     RETURNING id`,
    [
      frameworkId,
      definition.scoringModelKey,
      definition.scoringModelVersion,
      JSON.stringify({ schemaVersion: "1", scale: [0, 1, 2] }),
      JSON.stringify({ schemaVersion: "1", th: "synthetic", en: "synthetic" }),
      digest,
    ],
  );
  const scoringId = scoringResult.rows[0].id;
  await client.query(
    `UPDATE scoring_model_versions SET status = 'published', published_at = now() WHERE id = $1`,
    [scoringId],
  );
  const assessmentResult = await client.query(
    `INSERT INTO assessment_versions
      (assessment_key, version, framework_version_id, scoring_model_version_id,
       estimated_minutes, content_digest)
     VALUES ($1, $2, $3, $4, 8, $5)
     RETURNING id`,
    [definition.assessmentKey, definition.assessmentVersion, frameworkId, scoringId, digest],
  );
  const assessmentId = assessmentResult.rows[0].id;
  for (const item of definition.items) {
    const itemResult = await client.query(
      `INSERT INTO assessment_item_versions
        (assessment_version_id, framework_version_id, item_key, item_type, prompt_i18n,
         response_schema, display_order, required, content_digest)
       VALUES ($1, $2, $3, 'scenario_choice', $4::jsonb, $5::jsonb, $6, true, $7)
       RETURNING id`,
      [
        assessmentId,
        frameworkId,
        item.key,
        JSON.stringify({ schemaVersion: "1", th: "synthetic", en: "synthetic" }),
        JSON.stringify({
          schemaVersion: "assessment-response-options-v1",
          type: "scenario-choice",
          optionIds: item.optionIds,
        }),
        item.displayOrder,
        digest,
      ],
    );
    await client.query(
      `INSERT INTO assessment_item_competencies
        (assessment_item_version_id, competency_version_id, framework_version_id,
         target_kind, rationale_key)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        itemResult.rows[0].id,
        competencyIds.get(item.targetKey),
        frameworkId,
        item.targetKind,
        `synthetic.${item.key}`,
      ],
    );
  }
  await client.query(
    `UPDATE assessment_versions SET status = 'published', published_at = now() WHERE id = $1`,
    [assessmentId],
  );
}

try {
  const migrationFiles = (await readdir(migrationDirectory))
    .filter((fileName) => /^\d{4}_.+\.sql$/.test(fileName))
    .sort();
  const migrations = await Promise.all(
    migrationFiles.map(async (fileName) => ({
      fileName,
      statements: (await readFile(resolve(migrationDirectory, fileName), "utf8"))
        .split("--> statement-breakpoint")
        .map((statement) => statement.trim())
        .filter(Boolean),
    })),
  );
  const ownerClient = await ownerPool.connect();
  let statementCount = 0;

  try {
    await ownerClient.query("BEGIN");
    for (const migration of migrations) {
      for (const [index, statement] of migration.statements.entries()) {
        try {
          await ownerClient.query(statement);
          statementCount += 1;
        } catch (error) {
          throw new Error(`${migration.fileName} statement ${index + 1} failed.`, { cause: error });
        }
      }
    }
    await seedSyntheticPublishedDefinition(ownerClient);
    await ownerClient.query("COMMIT");
  } catch (error) {
    await ownerClient.query("ROLLBACK");
    throw error;
  } finally {
    ownerClient.release();
  }

  await bootstrapPool.query("REVOKE rise_pals_identity_resolver FROM rise_pals_owner");
  await bootstrapPool.query(
    "ALTER ROLE rise_pals_identity_resolver NOLOGIN NOBYPASSRLS PASSWORD NULL",
  );

  const tables = await bootstrapPool.query(
    `SELECT table_name
     FROM information_schema.tables
     WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
     ORDER BY table_name`,
  );
  assert.equal(tables.rowCount, 26, "the smoke database must contain exactly twenty-six tables");

  const expectedSeedCounts = {
    assessment_item_competencies: 6,
    assessment_item_versions: 6,
    assessment_versions: 1,
    competency_versions: 10,
    framework_versions: 1,
    scoring_model_versions: 1,
  };
  for (const { table_name: tableName } of tables.rows) {
    assert.match(tableName, /^[a-z][a-z0-9_]*$/, "table inventory must be identifier-safe");
    const result = await bootstrapPool.query(`SELECT count(*)::integer AS count FROM ${tableName}`);
    assert.equal(
      result.rows[0].count,
      expectedSeedCounts[tableName] ?? 0,
      `${tableName} must contain only the expected synthetic definition seed`,
    );
  }

  console.log(
    `Disposable smoke database PASS (${statementCount} statements across ${migrationFiles.length} migrations; ${tables.rowCount} tables with only the reviewed synthetic definition seed).`,
  );
} finally {
  await Promise.allSettled([ownerPool.end(), bootstrapPool.end()]);
}
