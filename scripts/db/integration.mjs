import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import pg from "pg";

const { Pool } = pg;
const migrationPath = resolve("drizzle/0000_slimy_dorian_gray.sql");
const migrationUrl = process.env.DATABASE_MIGRATION_URL;
const applicationUrl = process.env.DATABASE_URL;

if (!migrationUrl || !applicationUrl) {
  throw new Error("Disposable database integration requires both database URLs.");
}

const ownerPool = new Pool({ connectionString: migrationUrl, max: 2 });
const applicationPool = new Pool({ connectionString: applicationUrl, max: 2 });
const digest = "a".repeat(64);
const proofDigest = "b".repeat(64);
const userA = "10000000-0000-4000-8000-000000000001";
const userB = "10000000-0000-4000-8000-000000000002";

async function expectDatabaseRejection(operation, label, expectedCode) {
  try {
    await operation();
  } catch (error) {
    if (expectedCode) {
      assert.equal(error?.code, expectedCode, `${label} rejected with the expected SQLSTATE`);
    }
    return;
  }

  assert.fail(`${label} should have been rejected by PostgreSQL`);
}

async function withDatabaseUser(pool, userId, operation) {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");
    await client.query("SELECT set_config('app.current_user_id', $1, true)", [userId]);
    const result = await operation(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

const withApplicationUser = (userId, operation) =>
  withDatabaseUser(applicationPool, userId, operation);
const withOwnerUser = (userId, operation) => withDatabaseUser(ownerPool, userId, operation);

async function applyMigration() {
  const sql = await readFile(migrationPath, "utf8");
  const statements = sql
    .split("--> statement-breakpoint")
    .map((statement) => statement.trim())
    .filter(Boolean);
  const client = await ownerPool.connect();

  try {
    await client.query("BEGIN");
    for (const [index, statement] of statements.entries()) {
      try {
        await client.query(statement);
      } catch (error) {
        throw new Error(`Migration statement ${index + 1} failed.`, { cause: error });
      }
    }
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }

  return statements.length;
}

async function insertCanonicalFramework(client) {
  const framework = await client.query(
    `INSERT INTO framework_versions
      (framework_key, version, scoring_disclaimer_key, content_digest)
     VALUES ('rise-pals-8-plus-2', '2.0', 'assessment.limitations.v1', $1)
     RETURNING id`,
    [digest],
  );
  const frameworkId = framework.rows[0].id;
  const competencies = [
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
  const inserted = new Map();

  for (const [key, kind, weight, order] of competencies) {
    const result = await client.query(
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
    inserted.set(key, result.rows[0].id);
  }

  await client.query(
    `UPDATE framework_versions
     SET status = 'published', published_at = now()
     WHERE id = $1`,
    [frameworkId],
  );

  return { frameworkId, competencies: inserted };
}

async function verifySchemaConstraints() {
  const client = await ownerPool.connect();

  try {
    const tables = await client.query(
      `SELECT count(*)::integer AS count
       FROM information_schema.tables
       WHERE table_schema = 'public' AND table_type = 'BASE TABLE'`,
    );
    assert.equal(
      tables.rows[0].count,
      9,
      "the fresh migration creates exactly nine baseline tables",
    );

    const role = await client.query(
      `SELECT rolsuper, rolbypassrls
       FROM pg_roles
       WHERE rolname = 'rise_pals_app'`,
    );
    assert.deepEqual(role.rows[0], { rolsuper: false, rolbypassrls: false });

    const ownedTables = await client.query(
      `SELECT count(*)::integer AS count
       FROM pg_class AS relation
       JOIN pg_roles AS owner ON owner.oid = relation.relowner
       WHERE relation.relkind = 'r'
         AND relation.relnamespace = 'public'::regnamespace
         AND owner.rolname = 'rise_pals_app'`,
    );
    assert.equal(ownedTables.rows[0].count, 0, "the application role owns no tables");

    const forcedRls = await client.query(
      `SELECT relname, relrowsecurity, relforcerowsecurity
       FROM pg_class
       WHERE relname = ANY($1::text[])
       ORDER BY relname`,
      [["consent_records", "external_identities", "user_accounts"]],
    );
    assert.equal(forcedRls.rowCount, 3);
    assert.ok(forcedRls.rows.every((row) => row.relrowsecurity && row.relforcerowsecurity));

    await expectDatabaseRejection(
      () =>
        client
          .query(
            `INSERT INTO framework_versions
            (framework_key, version, scoring_disclaimer_key, content_digest)
           VALUES ('rise-pals-8-plus-2', 'invalid-json', 'notice', $1)
           RETURNING id`,
            [digest],
          )
          .then(async (result) => {
            await client.query(
              `INSERT INTO competency_versions
              (framework_version_id, competency_key, kind, weight_basis_points, display_order,
               definition_i18n, behavior_anchors, content_digest)
             VALUES ($1, 'critical-thinking-fact-checking', 'core', 2000, 1,
                     '{"th":"missing schema version"}'::jsonb,
                     '{"schemaVersion":"1"}'::jsonb, $2)`,
              [result.rows[0].id, digest],
            );
          }),
      "JSON without a schema version",
      "23514",
    );
    await expectDatabaseRejection(
      () =>
        client.query(
          `INSERT INTO framework_versions
            (framework_key, version, scoring_disclaimer_key, content_digest)
           VALUES ('rise-pals-8-plus-2', 'invalid-json', 'notice', $1)`,
          [digest],
        ),
      "a duplicate framework business version",
      "23505",
    );

    const incomplete = await client.query(
      `INSERT INTO framework_versions
        (framework_key, version, scoring_disclaimer_key, content_digest)
       VALUES ('rise-pals-8-plus-2', 'incomplete', 'notice', $1)
       RETURNING id`,
      [digest],
    );
    await expectDatabaseRejection(
      () =>
        client.query(
          `INSERT INTO competency_versions
            (framework_version_id, competency_key, kind, weight_basis_points, display_order,
             definition_i18n, behavior_anchors, content_digest)
           VALUES ($1, 'ownership-thinking', 'multiplier', 1, 1,
                   '{"schemaVersion":"1"}'::jsonb, '{"schemaVersion":"1"}'::jsonb, $2)`,
          [incomplete.rows[0].id, digest],
        ),
      "a weighted multiplier",
      "23514",
    );
    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE framework_versions SET status = 'published', published_at = now() WHERE id = $1`,
          [incomplete.rows[0].id],
        ),
      "an incomplete canonical framework publication",
      "23514",
    );

    const { frameworkId, competencies } = await insertCanonicalFramework(client);

    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE competency_versions SET weight_basis_points = 1999
           WHERE framework_version_id = $1 AND competency_key = 'critical-thinking-fact-checking'`,
          [frameworkId],
        ),
      "a published competency mutation",
      "55000",
    );
    await expectDatabaseRejection(
      () => client.query(`DELETE FROM framework_versions WHERE id = $1`, [frameworkId]),
      "a published framework deletion",
      "55000",
    );

    const scoring = await client.query(
      `INSERT INTO scoring_model_versions
        (framework_version_id, model_key, version, method, configuration, limitations_i18n,
         status, published_at, content_digest)
       VALUES ($1, 'deterministic-fixture', '1.0', 'deterministic_rubric', $2::jsonb,
               $3::jsonb, 'published', now(), $4)
       RETURNING id`,
      [
        frameworkId,
        JSON.stringify({ schemaVersion: "1", scale: [0, 1, 2] }),
        JSON.stringify({ schemaVersion: "1", th: "synthetic", en: "synthetic" }),
        digest,
      ],
    );
    const assessment = await client.query(
      `INSERT INTO assessment_versions
        (assessment_key, version, framework_version_id, scoring_model_version_id,
         estimated_minutes, content_digest)
       VALUES ('synthetic-assessment', '1.0', $1, $2, 5, $3)
       RETURNING id`,
      [frameworkId, scoring.rows[0].id, digest],
    );
    const item = await client.query(
      `INSERT INTO assessment_item_versions
        (assessment_version_id, framework_version_id, item_key, item_type, prompt_i18n,
         response_schema, display_order, content_digest)
       VALUES ($1, $2, 'synthetic-item-1', 'scenario_choice', $3::jsonb, $4::jsonb, 1, $5)
       RETURNING id`,
      [
        assessment.rows[0].id,
        frameworkId,
        JSON.stringify({ schemaVersion: "1", th: "synthetic", en: "synthetic" }),
        JSON.stringify({ schemaVersion: "1", type: "choice" }),
        digest,
      ],
    );
    await client.query(
      `INSERT INTO assessment_item_competencies
        (assessment_item_version_id, competency_version_id, framework_version_id,
         target_kind, rationale_key)
       VALUES ($1, $2, $3, 'core', 'synthetic.rationale')`,
      [item.rows[0].id, competencies.get("critical-thinking-fact-checking"), frameworkId],
    );
    await client.query(
      `UPDATE assessment_versions SET status = 'published', published_at = now() WHERE id = $1`,
      [assessment.rows[0].id],
    );
    await expectDatabaseRejection(
      () =>
        client.query(`UPDATE assessment_item_versions SET required = false WHERE id = $1`, [
          item.rows[0].id,
        ]),
      "a published assessment item mutation",
      "55000",
    );

    const ownerConsentUser = "10000000-0000-4000-8000-000000000099";
    const consent = await withOwnerUser(ownerConsentUser, async (ownerClient) => {
      await ownerClient.query(`INSERT INTO user_accounts (id) VALUES ($1)`, [ownerConsentUser]);
      return ownerClient.query(
        `INSERT INTO consent_records
          (user_id, purpose_code, notice_version, decision, locale, source_surface, proof_digest)
         VALUES ($1, 'required-service', '1.0', 'granted', 'en', 'synthetic-test', $2)
         RETURNING id`,
        [ownerConsentUser, proofDigest],
      );
    });
    await expectDatabaseRejection(
      () =>
        withOwnerUser(ownerConsentUser, (ownerClient) =>
          ownerClient.query(`UPDATE consent_records SET decision = 'withdrawn' WHERE id = $1`, [
            consent.rows[0].id,
          ]),
        ),
      "a consent update",
      "55000",
    );
    await expectDatabaseRejection(
      () =>
        withOwnerUser(ownerConsentUser, (ownerClient) =>
          ownerClient.query(`DELETE FROM user_accounts WHERE id = $1`, [ownerConsentUser]),
        ),
      "unsafe deletion through a referenced user",
      "23001",
    );
  } finally {
    client.release();
  }
}

async function verifyRowLevelSecurity() {
  await withApplicationUser(userA, (client) =>
    client.query(`INSERT INTO user_accounts (id) VALUES ($1)`, [userA]),
  );
  await withApplicationUser(userB, (client) =>
    client.query(`INSERT INTO user_accounts (id) VALUES ($1)`, [userB]),
  );

  await withApplicationUser(userA, async (client) => {
    await client.query(
      `INSERT INTO external_identities (user_id, provider, provider_subject)
       VALUES ($1, 'synthetic', 'user-a')`,
      [userA],
    );
    await client.query(
      `INSERT INTO consent_records
        (user_id, purpose_code, notice_version, decision, locale, source_surface, proof_digest)
       VALUES ($1, 'required-service', '1.0', 'granted', 'en', 'synthetic-test', $2)`,
      [userA, proofDigest],
    );
  });
  await withApplicationUser(userB, async (client) => {
    await client.query(
      `INSERT INTO external_identities (user_id, provider, provider_subject)
       VALUES ($1, 'synthetic', 'user-b')`,
      [userB],
    );
    await client.query(
      `INSERT INTO consent_records
        (user_id, purpose_code, notice_version, decision, locale, source_surface, proof_digest)
       VALUES ($1, 'required-service', '1.0', 'declined', 'th', 'synthetic-test', $2)`,
      [userB, proofDigest],
    );
  });

  await expectDatabaseRejection(
    () =>
      withApplicationUser(userB, (client) =>
        client.query(
          `INSERT INTO external_identities (user_id, provider, provider_subject)
           VALUES ($1, 'synthetic', 'user-a')`,
          [userB],
        ),
      ),
    "a duplicate provider/subject identity",
    "23505",
  );

  await withApplicationUser(userA, async (client) => {
    const accounts = await client.query(`SELECT id FROM user_accounts ORDER BY id`);
    const identities = await client.query(
      `SELECT user_id FROM external_identities ORDER BY user_id`,
    );
    const consents = await client.query(`SELECT user_id FROM consent_records ORDER BY user_id`);
    assert.deepEqual(accounts.rows, [{ id: userA }]);
    assert.deepEqual(identities.rows, [{ user_id: userA }]);
    assert.deepEqual(consents.rows, [{ user_id: userA }]);

    const accountUpdate = await client.query(
      `UPDATE user_accounts SET last_seen_at = now() WHERE id = $1`,
      [userB],
    );
    const identityUpdate = await client.query(
      `UPDATE external_identities SET last_authenticated_at = now() WHERE user_id = $1`,
      [userB],
    );
    const identityDelete = await client.query(
      `DELETE FROM external_identities WHERE user_id = $1`,
      [userB],
    );
    assert.equal(
      accountUpdate.rowCount,
      0,
      "cross-user UPDATE is invisible and changes no account",
    );
    assert.equal(
      identityUpdate.rowCount,
      0,
      "cross-user UPDATE is invisible and changes no identity",
    );
    assert.equal(
      identityDelete.rowCount,
      0,
      "cross-user DELETE is invisible and removes no identity",
    );
  });

  await expectDatabaseRejection(
    () =>
      withApplicationUser(userA, (client) =>
        client.query(
          `INSERT INTO external_identities (user_id, provider, provider_subject)
           VALUES ($1, 'synthetic', 'cross-user-insert')`,
          [userB],
        ),
      ),
    "a cross-user identity insert",
    "42501",
  );

  const noContext = await applicationPool.query(`SELECT id FROM user_accounts`);
  assert.equal(noContext.rowCount, 0, "a missing trusted context fails closed for SELECT");
  await expectDatabaseRejection(
    () =>
      applicationPool.query(`INSERT INTO user_accounts (id) VALUES ($1)`, [
        "10000000-0000-4000-8000-000000000003",
      ]),
    "an insert without trusted context",
    "42501",
  );
}

let migrationStatementCount = 0;

try {
  migrationStatementCount = await applyMigration();
  await verifySchemaConstraints();
  await verifyRowLevelSecurity();
  console.log(
    `PostgreSQL integration PASS (${migrationStatementCount} migration statements, 9 tables, two-user forced RLS).`,
  );
} finally {
  await Promise.allSettled([ownerPool.end(), applicationPool.end()]);
}
