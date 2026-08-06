import assert from "node:assert/strict";
import { setTimeout as delay } from "node:timers/promises";
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

const ownerPool = new Pool({ connectionString: migrationUrl, max: 6 });
const applicationPool = new Pool({ connectionString: applicationUrl, max: 4 });
const digest = "a".repeat(64);
const alternateDigest = "c".repeat(64);
const proofDigest = "b".repeat(64);
const userA = "10000000-0000-4000-8000-000000000001";
const userB = "10000000-0000-4000-8000-000000000002";
const userC = "10000000-0000-4000-8000-000000000003";

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

async function expectDatabaseRejection(operation, label, expectedCode) {
  try {
    await operation();
  } catch (error) {
    if (expectedCode) {
      assert.equal(error?.code, expectedCode, `${label} rejected with the expected SQLSTATE`);
    }
    return error;
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

async function insertCanonicalFramework(client, version, publish = true) {
  const framework = await client.query(
    `INSERT INTO framework_versions
      (framework_key, version, scoring_disclaimer_key, content_digest)
     VALUES ('rise-pals-8-plus-2', $1, 'assessment.limitations.v1', $2)
     RETURNING id`,
    [version, digest],
  );
  const frameworkId = framework.rows[0].id;
  const competencies = new Map();

  for (const [key, kind, weight, order] of canonicalCompetencies) {
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
    competencies.set(key, result.rows[0].id);
  }

  if (publish) {
    await client.query(
      `UPDATE framework_versions SET status = 'published', published_at = now() WHERE id = $1`,
      [frameworkId],
    );
  }

  return { frameworkId, competencies };
}

async function insertScoringModel(client, frameworkId, version, publish = true) {
  const scoring = await client.query(
    `INSERT INTO scoring_model_versions
      (framework_version_id, model_key, version, method, configuration, limitations_i18n,
       content_digest)
     VALUES ($1, 'deterministic-fixture', $2, 'deterministic_rubric', $3::jsonb,
             $4::jsonb, $5)
     RETURNING id`,
    [
      frameworkId,
      version,
      JSON.stringify({ schemaVersion: "1", scale: [0, 1, 2] }),
      JSON.stringify({ schemaVersion: "1", th: "synthetic", en: "synthetic" }),
      digest,
    ],
  );
  const scoringId = scoring.rows[0].id;

  if (publish) {
    await client.query(
      `UPDATE scoring_model_versions SET status = 'published', published_at = now() WHERE id = $1`,
      [scoringId],
    );
  }

  return scoringId;
}

async function insertAssessmentFixture(
  client,
  { frameworkId, scoringId, competencyId, version, itemKey, publish = true },
) {
  const assessment = await client.query(
    `INSERT INTO assessment_versions
      (assessment_key, version, framework_version_id, scoring_model_version_id,
       estimated_minutes, content_digest)
     VALUES ('synthetic-assessment', $1, $2, $3, 5, $4)
     RETURNING id`,
    [version, frameworkId, scoringId, digest],
  );
  const assessmentId = assessment.rows[0].id;
  const item = await client.query(
    `INSERT INTO assessment_item_versions
      (assessment_version_id, framework_version_id, item_key, item_type, prompt_i18n,
       response_schema, display_order, content_digest)
     VALUES ($1, $2, $3, 'scenario_choice', $4::jsonb, $5::jsonb, 1, $6)
     RETURNING id`,
    [
      assessmentId,
      frameworkId,
      itemKey,
      JSON.stringify({ schemaVersion: "1", th: "synthetic", en: "synthetic" }),
      JSON.stringify({ schemaVersion: "1", type: "choice" }),
      digest,
    ],
  );
  const itemId = item.rows[0].id;
  await client.query(
    `INSERT INTO assessment_item_competencies
      (assessment_item_version_id, competency_version_id, framework_version_id,
       target_kind, rationale_key)
     VALUES ($1, $2, $3, 'core', 'synthetic.rationale')`,
    [itemId, competencyId, frameworkId],
  );

  if (publish) {
    await client.query(
      `UPDATE assessment_versions SET status = 'published', published_at = now() WHERE id = $1`,
      [assessmentId],
    );
  }

  return { assessmentId, itemId };
}

async function verifyRoleAndSchemaBaseline(client) {
  const tables = await client.query(
    `SELECT count(*)::integer AS count
     FROM information_schema.tables
     WHERE table_schema = 'public' AND table_type = 'BASE TABLE'`,
  );
  assert.equal(tables.rows[0].count, 9, "the fresh migration creates exactly nine tables");

  const listener = await client.query(
    `SELECT host(inet_server_addr()) AS address,
            current_setting('listen_addresses') AS listeners,
            current_setting('ssl') AS ssl`,
  );
  assert.deepEqual(listener.rows[0], {
    address: "127.0.0.1",
    listeners: "127.0.0.1",
    ssl: "off",
  });

  const role = await applicationPool.query(
    `SELECT rolsuper, rolcreatedb, rolcreaterole, rolinherit, rolbypassrls
     FROM pg_roles
     WHERE rolname = current_user`,
  );
  assert.deepEqual(role.rows[0], {
    rolsuper: false,
    rolcreatedb: false,
    rolcreaterole: false,
    rolinherit: false,
    rolbypassrls: false,
  });

  const ownedTables = await applicationPool.query(
    `SELECT count(*)::integer AS count
     FROM pg_class AS relation
     JOIN pg_roles AS owner ON owner.oid = relation.relowner
     WHERE relation.relkind = 'r'
       AND relation.relnamespace = 'public'::regnamespace
       AND owner.rolname = current_user`,
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
}

async function verifyConstraintsAndLifecycle() {
  const client = await ownerPool.connect();

  try {
    await verifyRoleAndSchemaBaseline(client);

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
          .then((result) =>
            client.query(
              `INSERT INTO competency_versions
                (framework_version_id, competency_key, kind, weight_basis_points, display_order,
                 definition_i18n, behavior_anchors, content_digest)
               VALUES ($1, 'critical-thinking-fact-checking', 'core', 2000, 1,
                       '{"th":"missing schema version"}'::jsonb,
                       '{"schemaVersion":"1"}'::jsonb, $2)`,
              [result.rows[0].id, digest],
            ),
          ),
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
    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE framework_versions SET status = 'retired', published_at = now() WHERE id = $1`,
          [incomplete.rows[0].id],
        ),
      "a draft-to-retired transition",
      "55000",
    );
    await expectDatabaseRejection(
      () =>
        client.query(
          `INSERT INTO framework_versions
            (framework_key, version, status, scoring_disclaimer_key, published_at, content_digest)
           VALUES ('rise-pals-8-plus-2', 'direct-retired', 'retired', 'notice', now(), $1)`,
          [digest],
        ),
      "direct insertion as retired",
      "23514",
    );

    const published = await insertCanonicalFramework(client, "2.0");
    const draft = await insertCanonicalFramework(client, "2.1-draft", false);

    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE competency_versions SET framework_version_id = $1
           WHERE id = $2`,
          [draft.frameworkId, published.competencies.get("critical-thinking-fact-checking")],
        ),
      "moving a competency out of a published framework",
      "55000",
    );
    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE competency_versions SET framework_version_id = $1
           WHERE id = $2`,
          [published.frameworkId, draft.competencies.get("critical-thinking-fact-checking")],
        ),
      "moving a competency into a published framework",
      "55000",
    );
    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE framework_versions SET status = 'retired', content_digest = $2 WHERE id = $1`,
          [published.frameworkId, alternateDigest],
        ),
      "framework retirement with a content mutation",
      "55000",
    );

    const scoringId = await insertScoringModel(client, published.frameworkId, "1.0");
    await expectDatabaseRejection(
      () =>
        client.query(
          `INSERT INTO scoring_model_versions
            (framework_version_id, model_key, version, method, configuration,
             limitations_i18n, status, published_at, content_digest)
           VALUES ($1, 'direct-retired', '1.0', 'deterministic_rubric', $2::jsonb,
                   $3::jsonb, 'retired', now(), $4)`,
          [
            published.frameworkId,
            JSON.stringify({ schemaVersion: "1" }),
            JSON.stringify({ schemaVersion: "1" }),
            digest,
          ],
        ),
      "direct scoring-model insertion as retired",
      "23514",
    );
    await expectDatabaseRejection(
      () =>
        client.query(
          `INSERT INTO scoring_model_versions
            (framework_version_id, model_key, version, method, configuration,
             limitations_i18n, status, published_at, content_digest)
           VALUES ($1, 'direct-published', '1.0', 'deterministic_rubric', $2::jsonb,
                   $3::jsonb, 'published', now(), $4)`,
          [
            published.frameworkId,
            JSON.stringify({ schemaVersion: "1" }),
            JSON.stringify({ schemaVersion: "1" }),
            digest,
          ],
        ),
      "direct insertion as published",
      "23514",
    );

    const mainAssessment = await insertAssessmentFixture(client, {
      frameworkId: published.frameworkId,
      scoringId,
      competencyId: published.competencies.get("critical-thinking-fact-checking"),
      version: "1.0",
      itemKey: "synthetic-item-published",
    });
    await expectDatabaseRejection(
      () =>
        client.query(
          `INSERT INTO assessment_versions
            (assessment_key, version, framework_version_id, scoring_model_version_id,
             status, estimated_minutes, published_at, content_digest)
           VALUES ('direct-retired', '1.0', $1, $2, 'retired', 5, now(), $3)`,
          [published.frameworkId, scoringId, digest],
        ),
      "direct assessment insertion as retired",
      "23514",
    );
    const draftAssessment = await insertAssessmentFixture(client, {
      frameworkId: published.frameworkId,
      scoringId,
      competencyId: published.competencies.get("systematic-thinking"),
      version: "1.1-draft",
      itemKey: "synthetic-item-draft",
      publish: false,
    });

    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE assessment_item_versions SET assessment_version_id = $1 WHERE id = $2`,
          [draftAssessment.assessmentId, mainAssessment.itemId],
        ),
      "moving an item out of a published assessment",
      "55000",
    );
    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE assessment_item_versions SET assessment_version_id = $1 WHERE id = $2`,
          [mainAssessment.assessmentId, draftAssessment.itemId],
        ),
      "moving an item into a published assessment",
      "55000",
    );
    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE assessment_item_competencies
           SET assessment_item_version_id = $1
           WHERE assessment_item_version_id = $2`,
          [draftAssessment.itemId, mainAssessment.itemId],
        ),
      "moving a mapping out of a published assessment",
      "55000",
    );
    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE assessment_item_competencies
           SET assessment_item_version_id = $1
           WHERE assessment_item_version_id = $2`,
          [mainAssessment.itemId, draftAssessment.itemId],
        ),
      "moving a mapping into a published assessment",
      "55000",
    );

    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE assessment_versions
           SET status = 'retired', estimated_minutes = estimated_minutes + 1
           WHERE id = $1`,
          [mainAssessment.assessmentId],
        ),
      "assessment retirement with a content mutation",
      "55000",
    );
    const assessmentBeforeRetirement = await client.query(
      `SELECT published_at, content_digest FROM assessment_versions WHERE id = $1`,
      [mainAssessment.assessmentId],
    );
    await client.query(`UPDATE assessment_versions SET status = 'retired' WHERE id = $1`, [
      mainAssessment.assessmentId,
    ]);
    const assessmentAfterRetirement = await client.query(
      `SELECT status, published_at, content_digest FROM assessment_versions WHERE id = $1`,
      [mainAssessment.assessmentId],
    );
    assert.deepEqual(assessmentAfterRetirement.rows[0], {
      status: "retired",
      ...assessmentBeforeRetirement.rows[0],
    });
    await expectDatabaseRejection(
      () =>
        client.query(`UPDATE assessment_item_versions SET required = false WHERE id = $1`, [
          mainAssessment.itemId,
        ]),
      "a retired assessment item mutation",
      "55000",
    );
    await expectDatabaseRejection(
      () =>
        client.query(`UPDATE assessment_versions SET estimated_minutes = 10 WHERE id = $1`, [
          mainAssessment.assessmentId,
        ]),
      "a retired assessment mutation",
      "55000",
    );
    await expectDatabaseRejection(
      () =>
        client.query(`DELETE FROM assessment_versions WHERE id = $1`, [
          mainAssessment.assessmentId,
        ]),
      "a retired assessment deletion",
      "55000",
    );

    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE scoring_model_versions
           SET status = 'retired', content_digest = $2 WHERE id = $1`,
          [scoringId, alternateDigest],
        ),
      "scoring-model retirement with a provenance mutation",
      "55000",
    );
    await client.query(`UPDATE scoring_model_versions SET status = 'retired' WHERE id = $1`, [
      scoringId,
    ]);
    await expectDatabaseRejection(
      () =>
        client.query(`UPDATE scoring_model_versions SET content_digest = $2 WHERE id = $1`, [
          scoringId,
          alternateDigest,
        ]),
      "a retired scoring-model mutation",
      "55000",
    );
    await expectDatabaseRejection(
      () => client.query(`DELETE FROM scoring_model_versions WHERE id = $1`, [scoringId]),
      "a retired scoring-model deletion",
      "55000",
    );

    await client.query(`UPDATE framework_versions SET status = 'retired' WHERE id = $1`, [
      published.frameworkId,
    ]);
    await expectDatabaseRejection(
      () =>
        client.query(`UPDATE competency_versions SET display_order = 9 WHERE id = $1`, [
          published.competencies.get("critical-thinking-fact-checking"),
        ]),
      "a retired framework competency mutation",
      "55000",
    );
    await expectDatabaseRejection(
      () =>
        client.query(
          `UPDATE framework_versions SET scoring_disclaimer_key = 'changed' WHERE id = $1`,
          [published.frameworkId],
        ),
      "a retired framework mutation",
      "55000",
    );
    await expectDatabaseRejection(
      () => client.query(`DELETE FROM framework_versions WHERE id = $1`, [published.frameworkId]),
      "a retired framework deletion",
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

async function expectBlockedUntilRelease(queryPromise, release, label, expectedCode) {
  let outcome;
  const observed = queryPromise.then(
    (value) => {
      outcome = { value };
    },
    (error) => {
      outcome = { error };
    },
  );

  await delay(150);
  assert.equal(outcome, undefined, `${label} waits for the deterministically locked parent`);
  await release();
  await observed;
  assert.equal(outcome?.error?.code, expectedCode, `${label} fails with the expected SQLSTATE`);
}

async function verifyConcurrentPublicationGuards() {
  const setup = await ownerPool.connect();
  const publisher = await ownerPool.connect();
  const mutator = await ownerPool.connect();

  try {
    const frameworkPublicationFirst = await insertCanonicalFramework(
      setup,
      "concurrency-publication-first",
      false,
    );
    await publisher.query("BEGIN");
    await publisher.query(
      `UPDATE framework_versions SET status = 'published', published_at = now() WHERE id = $1`,
      [frameworkPublicationFirst.frameworkId],
    );
    await expectBlockedUntilRelease(
      mutator.query(`UPDATE competency_versions SET weight_basis_points = 1999 WHERE id = $1`, [
        frameworkPublicationFirst.competencies.get("critical-thinking-fact-checking"),
      ]),
      () => publisher.query("COMMIT"),
      "a competency mutation racing committed publication",
      "55000",
    );

    const mutationFirst = await insertCanonicalFramework(
      setup,
      "concurrency-mutation-first",
      false,
    );
    await mutator.query("BEGIN");
    await mutator.query(`UPDATE competency_versions SET weight_basis_points = 1999 WHERE id = $1`, [
      mutationFirst.competencies.get("critical-thinking-fact-checking"),
    ]);
    await expectBlockedUntilRelease(
      publisher.query(
        `UPDATE framework_versions SET status = 'published', published_at = now() WHERE id = $1`,
        [mutationFirst.frameworkId],
      ),
      () => mutator.query("COMMIT"),
      "publication racing an invalid competency mutation",
      "23514",
    );

    const assessmentFramework = await insertCanonicalFramework(
      setup,
      "concurrency-assessment-framework",
    );
    const scoringId = await insertScoringModel(
      setup,
      assessmentFramework.frameworkId,
      "concurrency-assessment-scoring",
    );
    const assessment = await insertAssessmentFixture(setup, {
      frameworkId: assessmentFramework.frameworkId,
      scoringId,
      competencyId: assessmentFramework.competencies.get("critical-thinking-fact-checking"),
      version: "concurrency-publication-first",
      itemKey: "concurrency-item",
      publish: false,
    });
    await publisher.query("BEGIN");
    await publisher.query(
      `UPDATE assessment_versions SET status = 'published', published_at = now() WHERE id = $1`,
      [assessment.assessmentId],
    );
    await expectBlockedUntilRelease(
      mutator.query(`UPDATE assessment_item_versions SET required = false WHERE id = $1`, [
        assessment.itemId,
      ]),
      () => publisher.query("COMMIT"),
      "an assessment-item mutation racing committed publication",
      "55000",
    );
  } finally {
    await Promise.allSettled([publisher.query("ROLLBACK"), mutator.query("ROLLBACK")]);
    setup.release();
    publisher.release();
    mutator.release();
  }
}

async function withMalformedContext(operation) {
  const client = await applicationPool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT set_config('app.current_user_id', 'not-a-uuid', true)");
    return await operation(client);
  } finally {
    await client.query("ROLLBACK");
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

  for (const [userId, subject, decision, locale] of [
    [userA, "user-a", "granted", "en"],
    [userB, "user-b", "declined", "th"],
  ]) {
    await withApplicationUser(userId, async (client) => {
      await client.query(
        `INSERT INTO external_identities (user_id, provider, provider_subject)
         VALUES ($1, 'synthetic', $2)`,
        [userId, subject],
      );
      await client.query(
        `INSERT INTO consent_records
          (user_id, purpose_code, notice_version, decision, locale, source_surface, proof_digest)
         VALUES ($1, 'required-service', '1.0', $2, $3, 'synthetic-test', $4)`,
        [userId, decision, locale, proofDigest],
      );
    });
  }

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
      [userA],
    );
    const identityUpdate = await client.query(
      `UPDATE external_identities SET last_authenticated_at = now() WHERE user_id = $1`,
      [userA],
    );
    assert.equal(accountUpdate.rowCount, 1, "own account UPDATE succeeds");
    assert.equal(identityUpdate.rowCount, 1, "own identity UPDATE succeeds");
  });

  await expectDatabaseRejection(
    () =>
      withApplicationUser(userA, (client) =>
        client.query(`UPDATE consent_records SET decision = 'withdrawn' WHERE user_id = $1`, [
          userA,
        ]),
      ),
    "an own consent UPDATE through the append-only application role",
    "42501",
  );
  await expectDatabaseRejection(
    () =>
      withApplicationUser(userA, (client) =>
        client.query(`DELETE FROM consent_records WHERE user_id = $1`, [userA]),
      ),
    "an own consent DELETE through the append-only application role",
    "42501",
  );

  await withApplicationUser(userA, async (client) => {
    const accountUpdate = await client.query(
      `UPDATE user_accounts SET last_seen_at = now() WHERE id = $1`,
      [userB],
    );
    const accountDelete = await client.query(`DELETE FROM user_accounts WHERE id = $1`, [userB]);
    const identityUpdate = await client.query(
      `UPDATE external_identities SET last_authenticated_at = now() WHERE user_id = $1`,
      [userB],
    );
    const identityDelete = await client.query(
      `DELETE FROM external_identities WHERE user_id = $1`,
      [userB],
    );
    assert.equal(accountUpdate.rowCount, 0, "cross-user account UPDATE changes no row");
    assert.equal(accountDelete.rowCount, 0, "cross-user account DELETE changes no row");
    assert.equal(identityUpdate.rowCount, 0, "cross-user identity UPDATE changes no row");
    assert.equal(identityDelete.rowCount, 0, "cross-user identity DELETE changes no row");
  });

  for (const [label, query, parameters] of [
    ["account", `INSERT INTO user_accounts (id) VALUES ($1)`, [userB]],
    [
      "identity",
      `INSERT INTO external_identities (user_id, provider, provider_subject)
       VALUES ($1, 'synthetic', 'cross-user-insert')`,
      [userB],
    ],
    [
      "consent",
      `INSERT INTO consent_records
        (user_id, purpose_code, notice_version, decision, locale, source_surface, proof_digest)
       VALUES ($1, 'cross-user', '1.0', 'granted', 'en', 'synthetic-test', $2)`,
      [userB, proofDigest],
    ],
  ]) {
    await expectDatabaseRejection(
      () => withApplicationUser(userA, (client) => client.query(query, parameters)),
      `a cross-user ${label} INSERT`,
      "42501",
    );
  }

  await expectDatabaseRejection(
    () =>
      withApplicationUser(userA, (client) =>
        client.query(`UPDATE consent_records SET decision = 'withdrawn' WHERE user_id = $1`, [
          userB,
        ]),
      ),
    "a cross-user consent UPDATE",
    "42501",
  );
  await expectDatabaseRejection(
    () =>
      withApplicationUser(userA, (client) =>
        client.query(`DELETE FROM consent_records WHERE user_id = $1`, [userB]),
      ),
    "a cross-user consent DELETE",
    "42501",
  );

  await withApplicationUser(userA, async (client) => {
    const identityDelete = await client.query(
      `DELETE FROM external_identities WHERE user_id = $1`,
      [userA],
    );
    assert.equal(identityDelete.rowCount, 1, "own identity DELETE succeeds");
    await client.query(
      `INSERT INTO external_identities (user_id, provider, provider_subject)
       VALUES ($1, 'synthetic', 'user-a')`,
      [userA],
    );
  });
  await withApplicationUser(userC, async (client) => {
    await client.query(`INSERT INTO user_accounts (id) VALUES ($1)`, [userC]);
    const accountDelete = await client.query(`DELETE FROM user_accounts WHERE id = $1`, [userC]);
    assert.equal(accountDelete.rowCount, 1, "an unreferenced own account DELETE succeeds");
  });

  for (const table of ["user_accounts", "external_identities", "consent_records"]) {
    const noContext = await applicationPool.query(`SELECT * FROM ${table}`);
    assert.equal(noContext.rowCount, 0, `missing context hides ${table}`);
    await expectDatabaseRejection(
      () => withMalformedContext((client) => client.query(`SELECT * FROM ${table}`)),
      `malformed context for ${table}`,
      "22P02",
    );
  }

  for (const [label, query, parameters] of [
    ["account", `INSERT INTO user_accounts (id) VALUES ($1)`, [userC]],
    [
      "identity",
      `INSERT INTO external_identities (user_id, provider, provider_subject)
       VALUES ($1, 'synthetic', 'missing-context')`,
      [userA],
    ],
    [
      "consent",
      `INSERT INTO consent_records
        (user_id, purpose_code, notice_version, decision, locale, source_surface, proof_digest)
       VALUES ($1, 'missing-context', '1.0', 'granted', 'en', 'synthetic-test', $2)`,
      [userA, proofDigest],
    ],
  ]) {
    await expectDatabaseRejection(
      () => applicationPool.query(query, parameters),
      `a ${label} INSERT without trusted context`,
      "42501",
    );
    await expectDatabaseRejection(
      () => withMalformedContext((client) => client.query(query, parameters)),
      `a ${label} INSERT with malformed trusted context`,
      "22P02",
    );
  }
}

let migrationStatementCount = 0;

try {
  migrationStatementCount = await applyMigration();
  await verifyConstraintsAndLifecycle();
  await verifyConcurrentPublicationGuards();
  await verifyRowLevelSecurity();
  console.log(
    `PostgreSQL integration PASS (${migrationStatementCount} migration statements, 9 tables, lifecycle/reparent/concurrency enforcement and complete two-user forced-RLS matrix).`,
  );
} finally {
  await Promise.allSettled([ownerPool.end(), applicationPool.end()]);
}
