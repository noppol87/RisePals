import assert from "node:assert/strict";
import { setTimeout as delay } from "node:timers/promises";
import { readdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import pg from "pg";

const { Pool } = pg;
const migrationDirectory = resolve("drizzle");
const migrationUrl = process.env.DATABASE_MIGRATION_URL;
const applicationUrl = process.env.DATABASE_URL;
const disposableBootstrapUrl = process.env.RISE_PALS_DISPOSABLE_BOOTSTRAP_URL;

if (!migrationUrl || !applicationUrl || !disposableBootstrapUrl) {
  throw new Error(
    "Disposable database integration requires application, migration and test-bootstrap URLs.",
  );
}

const ownerPool = new Pool({ connectionString: migrationUrl, max: 6 });
const applicationPool = new Pool({ connectionString: applicationUrl, max: 4 });
const disposableBootstrapPool = new Pool({ connectionString: disposableBootstrapUrl, max: 1 });
const digest = "a".repeat(64);
const alternateDigest = "c".repeat(64);
const proofDigest = "b".repeat(64);
const userA = "10000000-0000-4000-8000-000000000001";
const userB = "10000000-0000-4000-8000-000000000002";
const userC = "10000000-0000-4000-8000-000000000003";
const persistedUserA = "20000000-0000-4000-8000-000000000001";
const persistedUserB = "20000000-0000-4000-8000-000000000002";
const derivedUserA = "20000000-0000-4000-8000-000000000003";
const derivedUserB = "20000000-0000-4000-8000-000000000004";
const derivedUserC = "20000000-0000-4000-8000-000000000005";
const lessonUserA = "20000000-0000-4000-8000-000000000006";
const lessonUserB = "20000000-0000-4000-8000-000000000007";
const resultPolicyDigest = "10f2ab076828d50b228ff53d57332527dfe9d1b2769c4b57bd0476dd3c263157";
const persistedDefinition = JSON.parse(
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
  const client = await ownerPool.connect();
  let statementCount = 0;

  try {
    await client.query("BEGIN");
    for (const migration of migrations) {
      for (const [index, statement] of migration.statements.entries()) {
        try {
          await client.query(statement);
          statementCount += 1;
        } catch (error) {
          throw new Error(`${migration.fileName} statement ${index + 1} failed.`, { cause: error });
        }
      }
    }
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }

  return { migrationFiles, statementCount };
}

async function finalizeDisposableIdentityResolverBootstrap() {
  await disposableBootstrapPool.query(`REVOKE rise_pals_identity_resolver FROM rise_pals_owner`);
  await disposableBootstrapPool.query(
    `ALTER ROLE rise_pals_identity_resolver NOLOGIN NOBYPASSRLS PASSWORD NULL`,
  );
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

async function insertPersistedAssessmentDefinition(client) {
  const framework = await insertCanonicalFramework(client, persistedDefinition.frameworkVersion);
  const scoring = await client.query(
    `INSERT INTO scoring_model_versions
      (framework_version_id, model_key, version, method, configuration, limitations_i18n,
       content_digest)
     VALUES ($1, $2, $3, 'deterministic_rubric', $4::jsonb, $5::jsonb, $6)
     RETURNING id`,
    [
      framework.frameworkId,
      persistedDefinition.scoringModelKey,
      persistedDefinition.scoringModelVersion,
      JSON.stringify({ schemaVersion: "1", scale: [0, 1, 2] }),
      JSON.stringify({ schemaVersion: "1", th: "synthetic", en: "synthetic" }),
      digest,
    ],
  );
  const scoringId = scoring.rows[0].id;
  await client.query(
    `UPDATE scoring_model_versions SET status = 'published', published_at = now() WHERE id = $1`,
    [scoringId],
  );
  const assessment = await client.query(
    `INSERT INTO assessment_versions
      (assessment_key, version, framework_version_id, scoring_model_version_id,
       estimated_minutes, content_digest)
     VALUES ($1, $2, $3, $4, 8, $5)
     RETURNING id`,
    [
      persistedDefinition.assessmentKey,
      persistedDefinition.assessmentVersion,
      framework.frameworkId,
      scoringId,
      digest,
    ],
  );
  const assessmentId = assessment.rows[0].id;
  const items = new Map();

  for (const item of persistedDefinition.items) {
    const inserted = await client.query(
      `INSERT INTO assessment_item_versions
        (assessment_version_id, framework_version_id, item_key, item_type, prompt_i18n,
         response_schema, display_order, required, content_digest)
       VALUES ($1, $2, $3, 'scenario_choice', $4::jsonb, $5::jsonb, $6, true, $7)
       RETURNING id`,
      [
        assessmentId,
        framework.frameworkId,
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
    const itemId = inserted.rows[0].id;
    items.set(item.key, { id: itemId, optionIds: item.optionIds });
    await client.query(
      `INSERT INTO assessment_item_competencies
        (assessment_item_version_id, competency_version_id, framework_version_id,
         target_kind, rationale_key)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        itemId,
        framework.competencies.get(item.targetKey),
        framework.frameworkId,
        item.targetKind,
        `synthetic.${item.key}`,
      ],
    );
  }
  await client.query(
    `UPDATE assessment_versions SET status = 'published', published_at = now() WHERE id = $1`,
    [assessmentId],
  );
  return {
    assessmentId,
    frameworkId: framework.frameworkId,
    scoringId,
    competencies: framework.competencies,
    items,
  };
}

async function verifyRoleAndSchemaBaseline(client) {
  const tables = await client.query(
    `SELECT count(*)::integer AS count
     FROM information_schema.tables
     WHERE table_schema = 'public' AND table_type = 'BASE TABLE'`,
  );
  assert.equal(tables.rows[0].count, 20, "the five fresh migrations create exactly twenty tables");

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

  const resolverRole = await client.query(
    `SELECT rolcanlogin, rolsuper, rolcreatedb, rolcreaterole, rolinherit, rolbypassrls
     FROM pg_roles
     WHERE rolname = 'rise_pals_identity_resolver'`,
  );
  assert.deepEqual(resolverRole.rows, [
    {
      rolcanlogin: false,
      rolsuper: false,
      rolcreatedb: false,
      rolcreaterole: false,
      rolinherit: false,
      rolbypassrls: false,
    },
  ]);

  const resolverCredentialState = await disposableBootstrapPool.query(
    `SELECT rolcanlogin, rolbypassrls, rolpassword IS NOT NULL AS has_password
     FROM pg_authid
     WHERE rolname = 'rise_pals_identity_resolver'`,
  );
  assert.deepEqual(resolverCredentialState.rows, [
    { rolcanlogin: false, rolbypassrls: false, has_password: false },
  ]);

  const resolverMembership = await client.query(
    `SELECT pg_has_role('rise_pals_app', 'rise_pals_identity_resolver', 'MEMBER')
              AS app_member,
            pg_has_role('rise_pals_owner', 'rise_pals_identity_resolver', 'MEMBER')
              AS owner_member`,
  );
  assert.deepEqual(resolverMembership.rows[0], {
    app_member: false,
    owner_member: false,
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
    [
      [
        "assessment_responses",
        "assessment_sessions",
        "competency_scores",
        "consent_records",
        "external_identities",
        "learning_progress_events",
        "lesson_attempts",
        "multiplier_observations",
        "practice_attempts",
        "priority_recommendations",
        "score_explanations",
        "scoring_runs",
        "user_accounts",
        "user_profiles",
      ],
    ],
  );
  assert.equal(forcedRls.rowCount, 14);
  assert.ok(forcedRls.rows.every((row) => row.relrowsecurity && row.relforcerowsecurity));
}

async function resolveClerkIdentity(subject) {
  const client = await applicationPool.connect();
  try {
    await client.query("BEGIN");
    await client.query(`SELECT pg_advisory_xact_lock(hashtextextended('clerk:' || $1, 0))`, [
      subject,
    ]);
    const result = await client.query(
      `SELECT user_id, status
       FROM rise_pals_private.resolve_or_provision_clerk_identity('clerk', $1)`,
      [subject],
    );
    await client.query("COMMIT");
    assert.equal(result.rowCount, 1);
    return result.rows[0];
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function verifyIdentityProvisioningBoundary() {
  const subject = "user_syntheticconcurrent0001";
  const resolutions = await Promise.all(
    Array.from({ length: 8 }, () => resolveClerkIdentity(subject)),
  );
  const resolvedUserIds = new Set(resolutions.map((resolution) => resolution.user_id));

  assert.equal(resolvedUserIds.size, 1, "concurrent first sign-ins resolve to one internal user");
  assert.ok(resolutions.every((resolution) => resolution.status === "active"));

  const internalUserId = resolutions[0].user_id;
  const mapping = await withApplicationUser(internalUserId, (client) =>
    client.query(
      `SELECT user_id, provider, provider_subject, email_normalized
       FROM external_identities`,
    ),
  );
  assert.deepEqual(mapping.rows, [
    {
      user_id: internalUserId,
      provider: "clerk",
      provider_subject: subject,
      email_normalized: null,
    },
  ]);

  const [ownerWithoutContext, applicationWithoutContext] = await Promise.all([
    ownerPool.query(`SELECT user_id FROM external_identities`),
    applicationPool.query(`SELECT user_id FROM external_identities`),
  ]);
  assert.equal(
    ownerWithoutContext.rowCount,
    0,
    "the forced-RLS table owner cannot enumerate provider identities without context",
  );
  assert.equal(
    applicationWithoutContext.rowCount,
    0,
    "the application role cannot enumerate provider identities without context",
  );

  await expectDatabaseRejection(
    () =>
      applicationPool.query(
        `SELECT * FROM rise_pals_private.resolve_or_provision_clerk_identity('other', $1)`,
        [subject],
      ),
    "an unsupported identity provider",
    "22023",
  );
  await expectDatabaseRejection(
    () =>
      applicationPool.query(
        `SELECT * FROM rise_pals_private.resolve_or_provision_clerk_identity('clerk', $1)`,
        ["browser-supplied-subject"],
      ),
    "a malformed provider subject",
    "22023",
  );

  const functionAcl = await ownerPool.query(
    `SELECT owner.rolname AS function_owner,
            function.prosecdef AS security_definer,
            function.proconfig AS function_configuration,
            coalesce(bool_or(acl.grantee = 0 AND acl.privilege_type = 'EXECUTE'), false)
              AS public_execute,
            has_function_privilege(
              'rise_pals_app', function.oid, 'EXECUTE'
            ) AS app_execute
     FROM pg_proc AS function
     JOIN pg_roles AS owner ON owner.oid = function.proowner
     CROSS JOIN LATERAL aclexplode(
       coalesce(function.proacl, acldefault('f', function.proowner))
     ) AS acl
     WHERE function.oid =
       'rise_pals_private.resolve_or_provision_clerk_identity(text,text)'::regprocedure
     GROUP BY function.oid, owner.rolname`,
  );
  assert.deepEqual(functionAcl.rows[0], {
    function_owner: "rise_pals_identity_resolver",
    security_definer: true,
    function_configuration: ["search_path=pg_catalog"],
    public_execute: false,
    app_execute: true,
  });

  const applicationSecurityDefinerFunctions = await ownerPool.query(
    `SELECT function.proname
     FROM pg_proc AS function
     JOIN pg_namespace AS namespace ON namespace.oid = function.pronamespace
     WHERE namespace.nspname = 'rise_pals_private'
       AND function.prosecdef
       AND has_function_privilege('rise_pals_app', function.oid, 'EXECUTE')
     ORDER BY function.proname`,
  );
  assert.deepEqual(applicationSecurityDefinerFunctions.rows, [
    { proname: "resolve_or_provision_clerk_identity" },
  ]);

  const resolverPrivileges = await ownerPool.query(
    `SELECT has_table_privilege(
              'rise_pals_identity_resolver', 'public.user_accounts',
              'SELECT,INSERT,UPDATE,DELETE'
            ) AS account_privileges,
            has_table_privilege(
              'rise_pals_identity_resolver', 'public.external_identities',
              'SELECT,INSERT,UPDATE'
            ) AS identity_privileges,
            has_table_privilege(
              'rise_pals_identity_resolver', 'public.external_identities', 'DELETE'
            ) AS identity_delete`,
  );
  assert.deepEqual(resolverPrivileges.rows[0], {
    account_privileges: true,
    identity_privileges: true,
    identity_delete: false,
  });

  await expectDatabaseRejection(
    () => applicationPool.query(`SET ROLE rise_pals_identity_resolver`),
    "application role assumption of the credentialless resolver role",
    "42501",
  );
  await expectDatabaseRejection(
    () => ownerPool.query(`SET ROLE rise_pals_identity_resolver`),
    "migration owner assumption of the credentialless resolver role after migration",
    "42501",
  );
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

    const published = await insertCanonicalFramework(client, "2.0-lifecycle");
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
      await client.query(
        `INSERT INTO user_profiles
          (user_id, preferred_locale, timezone, role_family, function, experience_band,
           goals, onboarding_completed_at, profile_schema_version)
         VALUES ($1, $2, 'Asia/Bangkok', 'individual-contributor', 'operations', 'mid',
                 ARRAY['adapt-to-change'], now(), 'profile-v1')`,
        [userId, locale],
      );
    });
  }

  await withApplicationUser(userA, async (client) => {
    const accounts = await client.query(`SELECT id FROM user_accounts ORDER BY id`);
    const identities = await client.query(
      `SELECT user_id FROM external_identities ORDER BY user_id`,
    );
    const consents = await client.query(`SELECT user_id FROM consent_records ORDER BY user_id`);
    const profiles = await client.query(`SELECT user_id FROM user_profiles ORDER BY user_id`);
    assert.deepEqual(accounts.rows, [{ id: userA }]);
    assert.deepEqual(identities.rows, [{ user_id: userA }]);
    assert.deepEqual(consents.rows, [{ user_id: userA }]);
    assert.deepEqual(profiles.rows, [{ user_id: userA }]);

    const accountUpdate = await client.query(
      `UPDATE user_accounts SET last_seen_at = now() WHERE id = $1`,
      [userA],
    );
    const identityUpdate = await client.query(
      `UPDATE external_identities SET last_authenticated_at = now() WHERE user_id = $1`,
      [userA],
    );
    const profileUpdate = await client.query(
      `UPDATE user_profiles SET experience_band = 'senior' WHERE user_id = $1`,
      [userA],
    );
    assert.equal(accountUpdate.rowCount, 1, "own account UPDATE succeeds");
    assert.equal(identityUpdate.rowCount, 1, "own identity UPDATE succeeds");
    assert.equal(profileUpdate.rowCount, 1, "own profile UPDATE succeeds");
  });

  await expectDatabaseRejection(
    () =>
      withApplicationUser(userA, (client) =>
        client.query(`UPDATE user_profiles SET role_family = 'not-controlled' WHERE user_id = $1`, [
          userA,
        ]),
      ),
    "an uncontrolled profile code",
    "23514",
  );

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
    const profileUpdate = await client.query(
      `UPDATE user_profiles SET experience_band = 'early' WHERE user_id = $1`,
      [userB],
    );
    assert.equal(accountUpdate.rowCount, 0, "cross-user account UPDATE changes no row");
    assert.equal(accountDelete.rowCount, 0, "cross-user account DELETE changes no row");
    assert.equal(identityUpdate.rowCount, 0, "cross-user identity UPDATE changes no row");
    assert.equal(identityDelete.rowCount, 0, "cross-user identity DELETE changes no row");
    assert.equal(profileUpdate.rowCount, 0, "cross-user profile UPDATE changes no row");
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
    [
      "profile",
      `INSERT INTO user_profiles
        (user_id, preferred_locale, timezone, role_family, function, experience_band,
         goals, onboarding_completed_at, profile_schema_version)
       VALUES ($1, 'th', 'Asia/Bangkok', 'other', 'other', 'other',
               ARRAY['other'], now(), 'profile-v1')`,
      [userB],
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

  for (const table of [
    "user_accounts",
    "external_identities",
    "consent_records",
    "user_profiles",
  ]) {
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
    [
      "profile",
      `INSERT INTO user_profiles
        (user_id, preferred_locale, timezone, role_family, function, experience_band,
         goals, onboarding_completed_at, profile_schema_version)
       VALUES ($1, 'en', 'UTC', 'other', 'other', 'other',
               ARRAY['other'], now(), 'profile-v1')`,
      [userA],
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

async function verifySerializedConsentReceipts() {
  const first = await applicationPool.connect();
  const second = await applicationPool.connect();

  try {
    await first.query("BEGIN");
    await second.query("BEGIN");
    await first.query("SELECT set_config('app.current_user_id', $1, true)", [userA]);
    await second.query("SELECT set_config('app.current_user_id', $1, true)", [userA]);
    await first.query(`SELECT id FROM user_accounts WHERE id = $1 FOR UPDATE`, [userA]);

    let secondLockAcquired = false;
    const secondLock = second
      .query(`SELECT id FROM user_accounts WHERE id = $1 FOR UPDATE`, [userA])
      .then(() => {
        secondLockAcquired = true;
      });
    await delay(150);
    assert.equal(secondLockAcquired, false, "concurrent consent writes serialize on the user row");

    await first.query(
      `INSERT INTO consent_records
        (user_id, purpose_code, notice_version, decision, occurred_at, locale,
         source_surface, proof_digest)
       VALUES ($1, 'service-profile-learning-state', 'alpha-privacy-v1', 'withdrawn',
               clock_timestamp(), 'en', 'synthetic-test', $2)`,
      [userA, proofDigest],
    );
    await first.query("COMMIT");

    await secondLock;
    await second.query(
      `INSERT INTO consent_records
        (user_id, purpose_code, notice_version, decision, occurred_at, locale,
         source_surface, proof_digest)
       VALUES ($1, 'service-profile-learning-state', 'alpha-privacy-v1', 'granted',
               clock_timestamp(), 'en', 'synthetic-test', $2)`,
      [userA, proofDigest],
    );
    await second.query("COMMIT");

    const current = await withApplicationUser(userA, (client) =>
      client.query(
        `SELECT decision
         FROM consent_records
         WHERE purpose_code = 'service-profile-learning-state'
         ORDER BY occurred_at DESC, id DESC`,
      ),
    );
    assert.deepEqual(
      current.rows.map((row) => row.decision),
      ["granted", "withdrawn"],
      "serialized append-only receipts derive a deterministic current state",
    );
  } finally {
    await Promise.allSettled([first.query("ROLLBACK"), second.query("ROLLBACK")]);
    first.release();
    second.release();
  }
}

async function provisionPersistedTestUser(userId, decision = "granted") {
  return withApplicationUser(userId, async (client) => {
    await client.query(`INSERT INTO user_accounts (id) VALUES ($1)`, [userId]);
    const consent = await client.query(
      `INSERT INTO consent_records
        (user_id, purpose_code, notice_version, decision, occurred_at, locale,
         source_surface, proof_digest)
       VALUES ($1, 'service-profile-learning-state', 'alpha-privacy-v1', $2,
               clock_timestamp(), 'en', 'synthetic-test', $3)
       RETURNING id`,
      [userId, decision, proofDigest],
    );
    return consent.rows[0].id;
  });
}

async function insertPersistedSession(userId, assessmentId, consentId) {
  return withApplicationUser(userId, (client) =>
    client.query(
      `INSERT INTO assessment_sessions (user_id, assessment_version_id, consent_record_id)
       VALUES ($1, $2, $3)
       RETURNING id`,
      [userId, assessmentId, consentId],
    ),
  );
}

async function savePersistedRevision({
  userId,
  sessionId,
  assessmentId,
  itemId,
  itemKey,
  optionId,
  expectedRevision,
  mutationId,
}) {
  return withApplicationUser(userId, async (client) => {
    await client.query(`SELECT id FROM assessment_sessions WHERE id = $1 FOR UPDATE`, [sessionId]);
    const replay = await client.query(
      `SELECT revision, response_payload
       FROM assessment_responses
       WHERE session_id = $1 AND client_mutation_id = $2`,
      [sessionId, mutationId],
    );
    if (replay.rows[0]) {
      assert.equal(replay.rows[0].revision, expectedRevision + 1);
      assert.equal(replay.rows[0].response_payload.selectedOptionId, optionId);
      return { state: "saved", revision: replay.rows[0].revision, replay: true };
    }
    const active = await client.query(
      `SELECT id, revision
       FROM assessment_responses
       WHERE session_id = $1 AND assessment_item_version_id = $2 AND is_active`,
      [sessionId, itemId],
    );
    const currentRevision = active.rows[0]?.revision ?? 0;
    if (currentRevision !== expectedRevision) {
      return { state: "conflict", revision: currentRevision };
    }
    if (active.rows[0]) {
      await client.query(`UPDATE assessment_responses SET is_active = false WHERE id = $1`, [
        active.rows[0].id,
      ]);
    }
    await client.query(
      `INSERT INTO assessment_responses
        (session_id, assessment_version_id, assessment_item_version_id, response_payload,
         revision, supersedes_response_id, client_mutation_id)
       VALUES ($1, $2, $3, $4::jsonb, $5, $6, $7)`,
      [
        sessionId,
        assessmentId,
        itemId,
        JSON.stringify({ schemaVersion: "assessment-response-v1", selectedOptionId: optionId }),
        expectedRevision + 1,
        active.rows[0]?.id ?? null,
        mutationId,
      ],
    );
    await client.query(
      `UPDATE assessment_sessions SET last_item_version_id = $1, updated_at = clock_timestamp()
       WHERE id = $2`,
      [itemId, sessionId],
    );
    return { state: "saved", revision: expectedRevision + 1, replay: false, itemKey };
  });
}

async function createSubmittedSyntheticSession(userId, definition, optionIndexes) {
  const consentId = await provisionPersistedTestUser(userId);
  const session = await insertPersistedSession(userId, definition.assessmentId, consentId);
  const sessionId = session.rows[0].id;

  for (const [index, item] of persistedDefinition.items.entries()) {
    const itemRecord = definition.items.get(item.key);
    const optionIndex = optionIndexes[index] ?? 1;
    const saved = await savePersistedRevision({
      userId,
      sessionId,
      assessmentId: definition.assessmentId,
      itemId: itemRecord.id,
      itemKey: item.key,
      optionId: item.optionIds[optionIndex],
      expectedRevision: 0,
      mutationId: `60000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`,
    });
    assert.equal(saved.state, "saved");
  }

  await withApplicationUser(userId, (client) =>
    client.query(`UPDATE assessment_sessions SET status = 'submitted' WHERE id = $1`, [sessionId]),
  );
  return { consentId, sessionId };
}

async function insertSyntheticDerivedRun({
  userId,
  sessionId,
  definition,
  runNumber,
  previousRunId = null,
  coreEarned,
  multiplierEarned = [1, 1],
  mutationId,
  inputDigest = digest,
  outputDigest = alternateDigest,
  forcedPriorityKey,
}) {
  return withApplicationUser(userId, async (client) => {
    const run = await client.query(
      `INSERT INTO scoring_runs
        (user_id, assessment_session_id, assessment_version_id, framework_version_id,
         scoring_model_version_id, run_number, run_kind, supersedes_scoring_run_id,
         client_mutation_id, input_digest, output_digest, result_policy_key,
         result_policy_version, result_policy_digest)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
               'persisted-synthetic-priority-v1', '1.0.0', $12)
       RETURNING id`,
      [
        userId,
        sessionId,
        definition.assessmentId,
        definition.frameworkId,
        definition.scoringId,
        runNumber,
        runNumber === 1 ? "normal" : "rescore",
        previousRunId,
        mutationId,
        inputDigest,
        outputDigest,
        resultPolicyDigest,
      ],
    );
    const runId = run.rows[0].id;
    const coreDefinitions = [
      {
        key: "critical-thinking-fact-checking",
        earned: coreEarned[0],
        items: ["verify-ai-summary-source", "test-process-assumption"],
      },
      {
        key: "systematic-thinking",
        earned: coreEarned[1],
        items: ["map-downstream-impact", "trace-recurring-bottleneck"],
      },
    ];
    for (const core of coreDefinitions) {
      await client.query(
        `INSERT INTO competency_scores
          (user_id, scoring_run_id, framework_version_id, competency_version_id, target_kind,
           earned_points, available_points, evidence_count, normalized_basis_points)
         VALUES ($1, $2, $3, $4, 'core', $5::integer, 4, 2,
                 floor(($5::integer::numeric * 10000) / 4)::integer)`,
        [userId, runId, definition.frameworkId, definition.competencies.get(core.key), core.earned],
      );
    }
    for (const multiplier of [
      { key: "ownership-thinking", earned: multiplierEarned[0] },
      { key: "sense-of-urgency", earned: multiplierEarned[1] },
    ]) {
      await client.query(
        `INSERT INTO multiplier_observations
          (user_id, scoring_run_id, framework_version_id, competency_version_id, target_kind,
           earned_rubric_points, available_rubric_points, evidence_count, limitation_code)
         VALUES ($1, $2, $3, $4, 'multiplier', $5, 2, 1,
                 'single-scenario-not-behavior-pattern')`,
        [
          userId,
          runId,
          definition.frameworkId,
          definition.competencies.get(multiplier.key),
          multiplier.earned,
        ],
      );
    }

    const params = JSON.stringify({ schemaVersion: "persisted-result-explanation-params-v1" });
    const explanations = [
      {
        targetKind: "run",
        targetCompetencyKind: null,
        competencyId: null,
        code: "synthetic-partial-result-limitation",
        items: persistedDefinition.items.map((item) => item.key),
        limitations: ["not-validated-assessment", "partial-core-slice"],
      },
      ...coreDefinitions.map((core) => ({
        targetKind: "core",
        targetCompetencyKind: "core",
        competencyId: definition.competencies.get(core.key),
        code: "assessed-core-raw-signal",
        items: core.items,
        limitations: ["not-validated-assessment", "partial-core-slice"],
      })),
      {
        targetKind: "multiplier",
        targetCompetencyKind: "multiplier",
        competencyId: definition.competencies.get("ownership-thinking"),
        code: "single-scenario-multiplier-observation",
        items: ["own-shared-outcome"],
        limitations: ["not-validated-assessment", "single-scenario-not-behavior-pattern"],
      },
      {
        targetKind: "multiplier",
        targetCompetencyKind: "multiplier",
        competencyId: definition.competencies.get("sense-of-urgency"),
        code: "single-scenario-multiplier-observation",
        items: ["move-with-safe-urgency"],
        limitations: ["not-validated-assessment", "single-scenario-not-behavior-pattern"],
      },
    ];

    const comparison = coreEarned[0] * 4 - coreEarned[1] * 4;
    const lowestKey =
      forcedPriorityKey ??
      (comparison < 0
        ? "critical-thinking-fact-checking"
        : comparison > 0
          ? "systematic-thinking"
          : null);
    const priorityItems =
      lowestKey === "critical-thinking-fact-checking"
        ? ["verify-ai-summary-source", "test-process-assumption"]
        : lowestKey === "systematic-thinking"
          ? ["map-downstream-impact", "trace-recurring-bottleneck"]
          : [];
    explanations.push({
      targetKind: "priority",
      targetCompetencyKind: lowestKey ? "core" : null,
      competencyId: lowestKey ? definition.competencies.get(lowestKey) : null,
      code: lowestKey ? "unique-lowest-assessed-core-signal" : "no-distinct-priority",
      items: priorityItems,
      limitations: ["not-validated-assessment", "partial-core-slice"],
    });

    for (const explanation of explanations) {
      await client.query(
        `INSERT INTO score_explanations
          (user_id, scoring_run_id, framework_version_id, target_kind,
           target_competency_kind, competency_version_id, explanation_code,
           message_params, supporting_item_keys, limitation_codes)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb, $9::text[], $10::text[])`,
        [
          userId,
          runId,
          definition.frameworkId,
          explanation.targetKind,
          explanation.targetCompetencyKind,
          explanation.competencyId,
          explanation.code,
          params,
          explanation.items,
          explanation.limitations,
        ],
      );
    }

    if (lowestKey) {
      const nextAction =
        lowestKey === "critical-thinking-fact-checking"
          ? {
              kind: "prototype-lesson",
              lessonVersionId: "lesson-source-verification-practice-v1",
              lessonVersion: "1.0.0",
            }
          : { kind: "practice-unavailable" };
      await client.query(
        `INSERT INTO priority_recommendations
          (user_id, scoring_run_id, framework_version_id, competency_version_id, target_kind,
           rank, reason_code, supporting_item_keys, next_action)
         VALUES ($1, $2, $3, $4, 'core', 1, 'unique-lowest-assessed-core-signal',
                 $5::text[], $6::jsonb)`,
        [
          userId,
          runId,
          definition.frameworkId,
          definition.competencies.get(lowestKey),
          priorityItems,
          JSON.stringify(nextAction),
        ],
      );
    }
    await client.query("SET CONSTRAINTS ALL IMMEDIATE");
    return runId;
  });
}

async function verifyDerivedScoringContract(definition) {
  const uniqueSession = await createSubmittedSyntheticSession(
    derivedUserA,
    definition,
    [0, 2, 1, 1, 2, 2],
  );
  const concurrentNormal = await Promise.allSettled([
    insertSyntheticDerivedRun({
      userId: derivedUserA,
      sessionId: uniqueSession.sessionId,
      definition,
      runNumber: 1,
      coreEarned: [1, 4],
      mutationId: "70000000-0000-4000-8000-000000000001",
    }),
    insertSyntheticDerivedRun({
      userId: derivedUserA,
      sessionId: uniqueSession.sessionId,
      definition,
      runNumber: 1,
      coreEarned: [1, 4],
      mutationId: "70000000-0000-4000-8000-000000000002",
    }),
  ]);
  assert.equal(
    concurrentNormal.filter((result) => result.status === "fulfilled").length,
    1,
    `concurrent normal generation persists one complete run (${concurrentNormal
      .filter((result) => result.status === "rejected")
      .map(
        (result) => `${result.reason?.code ?? "no-code"}:${result.reason?.message ?? "no-message"}`,
      )
      .join(" | ")})`,
  );
  const initialRunId = concurrentNormal.find((result) => result.status === "fulfilled").value;
  const initialRows = await withApplicationUser(derivedUserA, (client) =>
    client.query(
      `SELECT run_number, run_kind, input_digest, output_digest, supersedes_scoring_run_id
       FROM scoring_runs ORDER BY run_number`,
    ),
  );
  assert.deepEqual(initialRows.rows, [
    {
      run_number: 1,
      run_kind: "normal",
      input_digest: digest,
      output_digest: alternateDigest,
      supersedes_scoring_run_id: null,
    },
  ]);

  const rescoreId = await insertSyntheticDerivedRun({
    userId: derivedUserA,
    sessionId: uniqueSession.sessionId,
    definition,
    runNumber: 2,
    previousRunId: initialRunId,
    coreEarned: [1, 4],
    mutationId: "70000000-0000-4000-8000-000000000003",
  });
  const semanticRows = await withApplicationUser(derivedUserA, (client) =>
    client.query(
      `SELECT run.run_number, run.input_digest, run.output_digest,
              score.earned_points, score.available_points, competency.competency_key
       FROM scoring_runs AS run
       JOIN competency_scores AS score ON score.scoring_run_id = run.id
       JOIN competency_versions AS competency ON competency.id = score.competency_version_id
       ORDER BY run.run_number, competency.display_order`,
    ),
  );
  assert.equal(semanticRows.rowCount, 4);
  assert.deepEqual(
    semanticRows.rows.slice(0, 2).map((row) => ({
      input_digest: row.input_digest,
      output_digest: row.output_digest,
      earned_points: row.earned_points,
      available_points: row.available_points,
      competency_key: row.competency_key,
    })),
    semanticRows.rows.slice(2).map((row) => ({
      input_digest: row.input_digest,
      output_digest: row.output_digest,
      earned_points: row.earned_points,
      available_points: row.available_points,
      competency_key: row.competency_key,
    })),
    "identical explicit re-score reproduces the semantic core rows and digests",
  );

  const updateError = await expectDatabaseRejection(
    () =>
      disposableBootstrapPool.query(`UPDATE scoring_runs SET output_digest = $1 WHERE id = $2`, [
        digest,
        rescoreId,
      ]),
    "a completed scoring run update",
    "55000",
  );
  assert.equal(
    String(updateError.message).includes(digest),
    false,
    "failure text excludes digests",
  );
  await expectDatabaseRejection(
    () =>
      disposableBootstrapPool.query(`DELETE FROM competency_scores WHERE scoring_run_id = $1`, [
        rescoreId,
      ]),
    "a completed derived-child delete",
    "55000",
  );

  const tiedSession = await createSubmittedSyntheticSession(
    derivedUserB,
    definition,
    [1, 1, 1, 1, 1, 1],
  );
  const tiedRunId = await insertSyntheticDerivedRun({
    userId: derivedUserB,
    sessionId: tiedSession.sessionId,
    definition,
    runNumber: 1,
    coreEarned: [4, 4],
    multiplierEarned: [2, 2],
    mutationId: "70000000-0000-4000-8000-000000000004",
  });
  const tiedPriority = await withApplicationUser(derivedUserB, (client) =>
    client.query(
      `SELECT
        (SELECT count(*)::integer FROM priority_recommendations WHERE scoring_run_id = $1)
          AS recommendations,
        (SELECT explanation_code FROM score_explanations
         WHERE scoring_run_id = $1 AND target_kind = 'priority') AS explanation`,
      [tiedRunId],
    ),
  );
  assert.deepEqual(tiedPriority.rows[0], {
    recommendations: 0,
    explanation: "no-distinct-priority",
  });

  const invalidSession = await createSubmittedSyntheticSession(
    derivedUserC,
    definition,
    [1, 1, 1, 1, 1, 1],
  );
  await expectDatabaseRejection(
    () =>
      insertSyntheticDerivedRun({
        userId: derivedUserC,
        sessionId: invalidSession.sessionId,
        definition,
        runNumber: 1,
        coreEarned: [4, 4],
        forcedPriorityKey: "critical-thinking-fact-checking",
        mutationId: "70000000-0000-4000-8000-000000000005",
      }),
    "a forced priority for tied core evidence",
    "23514",
  );
  const noPartialRun = await withApplicationUser(derivedUserC, (client) =>
    client.query(`SELECT id FROM scoring_runs`),
  );
  assert.equal(noPartialRun.rowCount, 0, "a rejected derivation leaves no partial run");

  const crossUserTables = [
    "scoring_runs",
    "competency_scores",
    "multiplier_observations",
    "score_explanations",
    "priority_recommendations",
  ];
  for (const table of crossUserTables) {
    const own = await withApplicationUser(derivedUserA, (client) =>
      client.query(`SELECT id FROM ${table}`),
    );
    const cross = await withApplicationUser(derivedUserB, (client) =>
      client.query(`SELECT id FROM ${table} WHERE user_id = $1`, [derivedUserA]),
    );
    const missing = await applicationPool.query(`SELECT id FROM ${table}`);
    assert.ok(own.rowCount > 0, `${table} exposes owner rows`);
    assert.equal(cross.rowCount, 0, `${table} hides cross-owner rows`);
    assert.equal(missing.rowCount, 0, `${table} fails closed without context`);
    await expectDatabaseRejection(
      () => withMalformedContext((client) => client.query(`SELECT id FROM ${table}`)),
      `${table} rejects malformed context`,
      "22P02",
    );
  }

  const privileges = await ownerPool.query(
    `SELECT table_name,
            has_table_privilege('rise_pals_app', table_name, 'UPDATE') AS can_update,
            has_table_privilege('rise_pals_app', table_name, 'DELETE') AS can_delete
     FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name = ANY($1::text[])
     ORDER BY table_name`,
    [crossUserTables],
  );
  assert.equal(privileges.rowCount, 5);
  assert.ok(privileges.rows.every((row) => !row.can_update && !row.can_delete));

  await withApplicationUser(derivedUserA, (client) =>
    client.query(
      `INSERT INTO consent_records
        (user_id, purpose_code, notice_version, decision, occurred_at, locale,
         source_surface, proof_digest)
       VALUES ($1, 'service-profile-learning-state', 'alpha-privacy-v1', 'withdrawn',
               clock_timestamp(), 'en', 'synthetic-test', $2)`,
      [derivedUserA, proofDigest],
    ),
  );
  const hiddenAfterWithdrawal = await withApplicationUser(derivedUserA, (client) =>
    client.query(`SELECT id FROM scoring_runs`),
  );
  assert.equal(hiddenAfterWithdrawal.rowCount, 0, "current consent withdrawal hides derived rows");
}

async function verifyPersistedAssessmentContract() {
  const definitionClient = await ownerPool.connect();
  let definition;
  try {
    definition = await insertPersistedAssessmentDefinition(definitionClient);
  } finally {
    definitionClient.release();
  }
  const consentA = await provisionPersistedTestUser(persistedUserA);
  const consentB = await provisionPersistedTestUser(persistedUserB);

  const concurrentStarts = await Promise.allSettled([
    insertPersistedSession(persistedUserA, definition.assessmentId, consentA),
    insertPersistedSession(persistedUserA, definition.assessmentId, consentA),
  ]);
  assert.equal(
    concurrentStarts.filter((result) => result.status === "fulfilled").length,
    1,
    "concurrent starts create exactly one owner/version session",
  );
  assert.equal(
    concurrentStarts.filter(
      (result) => result.status === "rejected" && result.reason?.code === "23505",
    ).length,
    1,
    "the competing start fails through the database uniqueness contract",
  );

  const sessionA = await withApplicationUser(persistedUserA, (client) =>
    client.query(
      `SELECT id, status, started_at, updated_at, submitted_at
       FROM assessment_sessions`,
    ),
  );
  assert.equal(sessionA.rowCount, 1);
  assert.equal(sessionA.rows[0].status, "in_progress");
  assert.equal(sessionA.rows[0].submitted_at, null);
  const sessionId = sessionA.rows[0].id;

  const sessionB = await insertPersistedSession(persistedUserB, definition.assessmentId, consentB);
  const sessionBId = sessionB.rows[0].id;
  await expectDatabaseRejection(
    () =>
      withApplicationUser(persistedUserB, (client) =>
        client.query(`UPDATE assessment_sessions SET status = 'submitted' WHERE id = $1`, [
          sessionBId,
        ]),
      ),
    "submission with missing required responses",
    "23514",
  );

  const firstItem = persistedDefinition.items[0];
  const firstItemRecord = definition.items.get(firstItem.key);
  const sameMutation = "30000000-0000-4000-8000-000000000001";
  const replayResults = await Promise.all([
    savePersistedRevision({
      userId: persistedUserA,
      sessionId,
      assessmentId: definition.assessmentId,
      itemId: firstItemRecord.id,
      itemKey: firstItem.key,
      optionId: firstItem.optionIds[0],
      expectedRevision: 0,
      mutationId: sameMutation,
    }),
    savePersistedRevision({
      userId: persistedUserA,
      sessionId,
      assessmentId: definition.assessmentId,
      itemId: firstItemRecord.id,
      itemKey: firstItem.key,
      optionId: firstItem.optionIds[0],
      expectedRevision: 0,
      mutationId: sameMutation,
    }),
  ]);
  assert.ok(replayResults.every((result) => result.state === "saved" && result.revision === 1));
  assert.equal(
    replayResults.filter((result) => result.replay).length,
    1,
    "the same client mutation retries to the existing stored revision",
  );

  const competingSaves = await Promise.all([
    savePersistedRevision({
      userId: persistedUserA,
      sessionId,
      assessmentId: definition.assessmentId,
      itemId: firstItemRecord.id,
      itemKey: firstItem.key,
      optionId: firstItem.optionIds[1],
      expectedRevision: 1,
      mutationId: "30000000-0000-4000-8000-000000000002",
    }),
    savePersistedRevision({
      userId: persistedUserA,
      sessionId,
      assessmentId: definition.assessmentId,
      itemId: firstItemRecord.id,
      itemKey: firstItem.key,
      optionId: firstItem.optionIds[2],
      expectedRevision: 1,
      mutationId: "30000000-0000-4000-8000-000000000003",
    }),
  ]);
  assert.equal(
    competingSaves.filter((result) => result.state === "saved").length,
    1,
    "one concurrent save wins",
  );
  assert.equal(
    competingSaves.filter((result) => result.state === "conflict" && result.revision === 2).length,
    1,
    "the stale concurrent save receives the current revision",
  );

  const firstHistory = await withApplicationUser(persistedUserA, (client) =>
    client.query(
      `SELECT revision, is_active, supersedes_response_id
       FROM assessment_responses
       WHERE session_id = $1 AND assessment_item_version_id = $2
       ORDER BY revision`,
      [sessionId, firstItemRecord.id],
    ),
  );
  assert.equal(firstHistory.rowCount, 2);
  assert.deepEqual(
    firstHistory.rows.map((row) => [row.revision, row.is_active]),
    [
      [1, false],
      [2, true],
    ],
    "response revisions retain history with exactly one active row",
  );
  assert.equal(firstHistory.rows[1].supersedes_response_id !== null, true);

  await expectDatabaseRejection(
    () =>
      withApplicationUser(persistedUserA, (client) =>
        client.query(
          `UPDATE assessment_responses SET is_active = false
           WHERE session_id = $1 AND assessment_item_version_id = $2 AND is_active`,
          [sessionId, firstItemRecord.id],
        ),
      ),
    "a committed response deactivation without a successor",
    "23514",
  );

  const secondItem = persistedDefinition.items[1];
  const secondItemRecord = definition.items.get(secondItem.key);
  await expectDatabaseRejection(
    () =>
      withApplicationUser(persistedUserA, (client) =>
        client.query(
          `INSERT INTO assessment_responses
            (session_id, assessment_version_id, assessment_item_version_id, response_payload,
             revision, client_mutation_id)
           VALUES ($1, $2, $3, $4::jsonb, 1, $5)`,
          [
            sessionId,
            definition.assessmentId,
            secondItemRecord.id,
            JSON.stringify({
              schemaVersion: "assessment-response-v1",
              selectedOptionId: "unknown-option",
            }),
            "30000000-0000-4000-8000-000000000004",
          ],
        ),
      ),
    "an option outside the exact published item version",
    "23514",
  );
  await expectDatabaseRejection(
    () =>
      withApplicationUser(persistedUserA, (client) =>
        client.query(
          `INSERT INTO assessment_responses
            (session_id, assessment_version_id, assessment_item_version_id, response_payload,
             revision, client_mutation_id)
           VALUES ($1, $2, $3, $4::jsonb, 1, $5)`,
          [
            sessionId,
            definition.assessmentId,
            secondItemRecord.id,
            JSON.stringify({
              schemaVersion: "assessment-response-v1",
              selectedOptionId: secondItem.optionIds[0],
              unexpected: "not-allowed",
            }),
            "30000000-0000-4000-8000-000000000005",
          ],
        ),
      ),
    "a response payload with an extra field",
    "23514",
  );

  for (const [index, item] of persistedDefinition.items.slice(1).entries()) {
    const itemRecord = definition.items.get(item.key);
    const result = await savePersistedRevision({
      userId: persistedUserA,
      sessionId,
      assessmentId: definition.assessmentId,
      itemId: itemRecord.id,
      itemKey: item.key,
      optionId: item.optionIds[1],
      expectedRevision: 0,
      mutationId: `40000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`,
    });
    assert.equal(result.state, "saved");
  }

  await withApplicationUser(persistedUserA, (client) =>
    client.query(`UPDATE assessment_sessions SET status = 'submitted' WHERE id = $1`, [sessionId]),
  );
  const submitted = await withApplicationUser(persistedUserA, (client) =>
    client.query(
      `SELECT status, started_at, updated_at, submitted_at
       FROM assessment_sessions WHERE id = $1`,
      [sessionId],
    ),
  );
  assert.equal(submitted.rows[0].status, "submitted");
  assert.ok(submitted.rows[0].submitted_at instanceof Date);
  assert.ok(submitted.rows[0].updated_at >= submitted.rows[0].started_at);

  await expectDatabaseRejection(
    () => insertPersistedSession(persistedUserA, definition.assessmentId, consentA),
    "a second alpha session after submission",
    "23505",
  );
  await expectDatabaseRejection(
    () =>
      withApplicationUser(persistedUserA, (client) =>
        client.query(`UPDATE assessment_sessions SET last_item_version_id = $1 WHERE id = $2`, [
          firstItemRecord.id,
          sessionId,
        ]),
      ),
    "a submitted session mutation",
    "55000",
  );
  await expectDatabaseRejection(
    () =>
      withApplicationUser(persistedUserA, (client) =>
        client.query(
          `UPDATE assessment_responses SET is_active = false
           WHERE session_id = $1 AND assessment_item_version_id = $2 AND is_active`,
          [sessionId, firstItemRecord.id],
        ),
      ),
    "a post-submission response mutation",
    "55000",
  );
  await expectDatabaseRejection(
    () =>
      withApplicationUser(persistedUserA, (client) =>
        client.query(
          `INSERT INTO assessment_responses
            (session_id, assessment_version_id, assessment_item_version_id, response_payload,
             revision, supersedes_response_id, client_mutation_id)
           VALUES ($1, $2, $3, $4::jsonb, 3,
                   (SELECT id FROM assessment_responses
                    WHERE session_id = $1 AND assessment_item_version_id = $3 AND is_active), $5)`,
          [
            sessionId,
            definition.assessmentId,
            firstItemRecord.id,
            JSON.stringify({
              schemaVersion: "assessment-response-v1",
              selectedOptionId: firstItem.optionIds[0],
            }),
            "50000000-0000-4000-8000-000000000003",
          ],
        ),
      ),
    "a post-submission response insertion",
    "55000",
  );

  const crossUserSessions = await withApplicationUser(persistedUserB, (client) =>
    client.query(`SELECT id FROM assessment_sessions WHERE id = $1`, [sessionId]),
  );
  const crossUserResponses = await withApplicationUser(persistedUserB, (client) =>
    client.query(`SELECT id FROM assessment_responses WHERE session_id = $1`, [sessionId]),
  );
  assert.equal(crossUserSessions.rowCount, 0, "cross-user session reads are hidden by RLS");
  assert.equal(crossUserResponses.rowCount, 0, "cross-user response reads are hidden by RLS");
  await expectDatabaseRejection(
    () =>
      withApplicationUser(persistedUserB, (client) =>
        client.query(
          `INSERT INTO assessment_responses
            (session_id, assessment_version_id, assessment_item_version_id, response_payload,
             revision, client_mutation_id)
           VALUES ($1, $2, $3, $4::jsonb, 1, $5)`,
          [
            sessionId,
            definition.assessmentId,
            secondItemRecord.id,
            JSON.stringify({
              schemaVersion: "assessment-response-v1",
              selectedOptionId: secondItem.optionIds[0],
            }),
            "50000000-0000-4000-8000-000000000001",
          ],
        ),
      ),
    "a cross-user response insert",
    "42501",
  );

  await withApplicationUser(persistedUserB, (client) =>
    client.query(
      `INSERT INTO consent_records
        (user_id, purpose_code, notice_version, decision, occurred_at, locale,
         source_surface, proof_digest)
       VALUES ($1, 'service-profile-learning-state', 'alpha-privacy-v1', 'withdrawn',
               clock_timestamp(), 'en', 'synthetic-test', $2)`,
      [persistedUserB, proofDigest],
    ),
  );
  await expectDatabaseRejection(
    () =>
      savePersistedRevision({
        userId: persistedUserB,
        sessionId: sessionBId,
        assessmentId: definition.assessmentId,
        itemId: firstItemRecord.id,
        itemKey: firstItem.key,
        optionId: firstItem.optionIds[0],
        expectedRevision: 0,
        mutationId: "50000000-0000-4000-8000-000000000002",
      }),
    "a response write after current consent withdrawal",
    "42501",
  );

  const privileges = await ownerPool.query(
    `SELECT has_table_privilege('rise_pals_app', 'assessment_sessions', 'DELETE')
              AS session_delete,
            has_table_privilege('rise_pals_app', 'assessment_responses', 'DELETE')
              AS response_delete,
            has_column_privilege('rise_pals_app', 'assessment_responses', 'response_payload', 'UPDATE')
              AS payload_update,
            has_column_privilege('rise_pals_app', 'assessment_responses', 'is_active', 'UPDATE')
              AS active_update`,
  );
  assert.deepEqual(privileges.rows[0], {
    session_delete: false,
    response_delete: false,
    payload_update: false,
    active_update: true,
  });

  await verifyDerivedScoringContract(definition);
}

async function verifyPersistedLessonContract() {
  const consentA = await provisionPersistedTestUser(lessonUserA);
  await provisionPersistedTestUser(lessonUserB);
  const startMutation = "70000000-0000-4000-8000-000000000001";
  const lessonId = await withApplicationUser(lessonUserA, async (client) => {
    const lesson = await client.query(
      `INSERT INTO lesson_attempts
        (user_id, consent_record_id, lesson_key, lesson_version_id, lesson_version,
         lesson_digest, practice_id, practice_version, rubric_version_id, rubric_version,
         evaluation_contract_version_id, start_mutation_id)
       VALUES ($1,$2,'source-verification-practice','lesson-source-verification-practice-v1',
         '1.0.0','51903ea9e6053a1102b4d60ad072c9a1dcde26a90d6a0ca7ae36cba8a6995e91',
         'source-verification-decision-v1','1.0.0','source-verification-rubric-v1','1.0.0',
         'source-verification-evaluation-v1',$3) RETURNING id`,
      [lessonUserA, consentA, startMutation],
    );
    await client.query(
      `INSERT INTO learning_progress_events
        (user_id, lesson_attempt_id, event_kind, event_schema_version, source_mutation_id)
       VALUES ($1,$2,'lesson_started','learning-progress-event-v1',$3)`,
      [lessonUserA, lesson.rows[0].id, startMutation],
    );
    return lesson.rows[0].id;
  });

  const payloads = {
    partial: {
      schemaVersion: "source-verification-practice-response-v1",
      selections: [{ criterionId: "evidence-traceability", optionId: "trace-claim-to-source-map" }],
    },
    failing: {
      schemaVersion: "source-verification-practice-response-v1",
      selections: [
        { criterionId: "evidence-traceability", optionId: "trace-claim-to-source-map" },
        { criterionId: "claim-source-fit", optionId: "fit-keep-all-team-claim" },
        { criterionId: "safe-next-action", optionId: "safe-hold-and-resolve-gaps" },
      ],
    },
    passing: {
      schemaVersion: "source-verification-practice-response-v1",
      selections: [
        { criterionId: "evidence-traceability", optionId: "trace-claim-to-source-map" },
        { criterionId: "claim-source-fit", optionId: "fit-narrow-to-supported-teams" },
        { criterionId: "safe-next-action", optionId: "safe-hold-and-resolve-gaps" },
      ],
    },
  };
  const evaluation = (payload, statuses) => ({
    schemaVersion: "source-verification-evaluation-v1",
    criteria: payload.selections.map((selection, index) => ({
      criterionId: selection.criterionId,
      selectedOptionId: selection.optionId,
      status: statuses[index],
    })),
  });

  const insertPractice = async ({
    revision,
    previousId,
    status,
    payload,
    results,
    demonstrated,
    mutationId,
    intent,
    locale = "en",
    expectedRevision = revision - 1,
  }) =>
    withApplicationUser(lessonUserA, async (client) => {
      const practice = await client.query(
        `INSERT INTO practice_attempts
          (user_id, lesson_attempt_id, revision, supersedes_practice_attempt_id, status,
           response_payload, practice_id, practice_version, rubric_version_id, rubric_version,
           evaluation_contract_version_id, criterion_results, demonstrated, client_mutation_id,
           mutation_intent, mutation_locale, mutation_expected_revision)
         VALUES ($1,$2,$3,$4,$5,$6::jsonb,'source-verification-decision-v1','1.0.0',
           'source-verification-rubric-v1','1.0.0','source-verification-evaluation-v1',
           $7::jsonb,$8,$9,$10,$11,$12) RETURNING id`,
        [
          lessonUserA,
          lessonId,
          revision,
          previousId,
          status,
          JSON.stringify(payload),
          results ? JSON.stringify(results) : null,
          demonstrated,
          mutationId,
          intent,
          locale,
          expectedRevision,
        ],
      );
      if (status === "evaluated") {
        await client.query(
          `INSERT INTO learning_progress_events
            (user_id, lesson_attempt_id, practice_attempt_id, event_kind,
             event_schema_version, source_mutation_id)
           VALUES ($1,$2,$3,'practice_evaluated','learning-progress-event-v1',$4)`,
          [lessonUserA, lessonId, practice.rows[0].id, mutationId],
        );
        if (demonstrated) {
          await client.query(
            `INSERT INTO learning_progress_events
              (user_id, lesson_attempt_id, practice_attempt_id, event_kind,
               event_schema_version, source_mutation_id)
             VALUES ($1,$2,$3,'practice_demonstrated','learning-progress-event-v1',$4)`,
            [lessonUserA, lessonId, practice.rows[0].id, mutationId],
          );
          await client.query(
            `UPDATE lesson_attempts SET status='demonstrated',
               last_meaningful_activity_at=clock_timestamp(), demonstrated_at=clock_timestamp()
             WHERE id=$1`,
            [lessonId],
          );
        } else {
          await client.query(
            `UPDATE lesson_attempts SET last_meaningful_activity_at=clock_timestamp() WHERE id=$1`,
            [lessonId],
          );
        }
      }
      return practice.rows[0].id;
    });

  const draftId = await insertPractice({
    revision: 1,
    previousId: null,
    status: "draft",
    payload: payloads.partial,
    results: null,
    demonstrated: null,
    mutationId: "70000000-0000-4000-8000-000000000002",
    intent: "save",
  });

  await expectDatabaseRejection(
    () =>
      insertPractice({
        revision: 2,
        previousId: draftId,
        status: "draft",
        payload: payloads.partial,
        results: null,
        demonstrated: null,
        mutationId: "70000000-0000-4000-8000-000000000020",
        intent: "evaluate",
      }),
    "evaluate intent attached to a draft row",
  );
  await expectDatabaseRejection(
    () =>
      insertPractice({
        revision: 2,
        previousId: draftId,
        status: "evaluated",
        payload: payloads.failing,
        results: evaluation(payloads.failing, ["met", "not-met", "met"]),
        demonstrated: false,
        mutationId: "70000000-0000-4000-8000-000000000021",
        intent: "save",
      }),
    "save intent attached to an evaluated row",
  );
  await expectDatabaseRejection(
    () =>
      insertPractice({
        revision: 2,
        previousId: draftId,
        status: "draft",
        payload: payloads.partial,
        results: null,
        demonstrated: null,
        mutationId: "70000000-0000-4000-8000-000000000022",
        intent: "retry",
      }),
    "retry without an eligible evaluated predecessor",
  );
  await expectDatabaseRejection(
    () =>
      insertPractice({
        revision: 2,
        previousId: draftId,
        status: "draft",
        payload: payloads.partial,
        results: null,
        demonstrated: null,
        mutationId: "70000000-0000-4000-8000-000000000023",
        intent: "archive",
      }),
    "an unsupported mutation intent",
  );
  await expectDatabaseRejection(
    () =>
      insertPractice({
        revision: 2,
        previousId: draftId,
        status: "draft",
        payload: payloads.partial,
        results: null,
        demonstrated: null,
        mutationId: "70000000-0000-4000-8000-000000000024",
        intent: "save",
        locale: "fr",
      }),
    "an unsupported mutation locale",
  );
  await expectDatabaseRejection(
    () =>
      insertPractice({
        revision: 2,
        previousId: draftId,
        status: "draft",
        payload: payloads.partial,
        results: null,
        demonstrated: null,
        mutationId: "70000000-0000-4000-8000-000000000025",
        intent: "save",
        expectedRevision: 0,
      }),
    "a revision that does not equal expected revision plus one",
  );
  const failedId = await insertPractice({
    revision: 2,
    previousId: draftId,
    status: "evaluated",
    payload: payloads.failing,
    results: evaluation(payloads.failing, ["met", "not-met", "met"]),
    demonstrated: false,
    mutationId: "70000000-0000-4000-8000-000000000003",
    intent: "evaluate",
  });
  const learningMutationSnapshot = () =>
    withApplicationUser(lessonUserA, async (client) => {
      const lesson = await client.query(
        `SELECT status, last_meaningful_activity_at::text AS last_meaningful_activity_at,
                demonstrated_at::text AS demonstrated_at
         FROM lesson_attempts WHERE id=$1`,
        [lessonId],
      );
      const practices = await client.query(
        `SELECT count(*)::integer AS count FROM practice_attempts WHERE lesson_attempt_id=$1`,
        [lessonId],
      );
      const events = await client.query(
        `SELECT count(*)::integer AS count FROM learning_progress_events WHERE lesson_attempt_id=$1`,
        [lessonId],
      );
      return {
        lesson: lesson.rows[0],
        practiceCount: practices.rows[0].count,
        eventCount: events.rows[0].count,
      };
    });
  const beforeDeniedSuccessor = await learningMutationSnapshot();
  await expectDatabaseRejection(
    () =>
      insertPractice({
        revision: 3,
        previousId: failedId,
        status: "draft",
        payload: payloads.passing,
        results: null,
        demonstrated: null,
        mutationId: "70000000-0000-4000-8000-000000000027",
        intent: "save",
      }),
    "a direct save after a failed evaluation",
  );
  await expectDatabaseRejection(
    () =>
      insertPractice({
        revision: 3,
        previousId: failedId,
        status: "evaluated",
        payload: payloads.passing,
        results: evaluation(payloads.passing, ["met", "met", "met"]),
        demonstrated: true,
        mutationId: "70000000-0000-4000-8000-000000000028",
        intent: "evaluate",
      }),
    "a direct evaluation after a failed evaluation",
  );
  await expectDatabaseRejection(
    () =>
      insertPractice({
        revision: 3,
        previousId: failedId,
        status: "draft",
        payload: payloads.passing,
        results: null,
        demonstrated: null,
        mutationId: "70000000-0000-4000-8000-000000000026",
        intent: "retry",
      }),
    "a retry whose payload differs from its predecessor",
  );
  assert.deepEqual(
    await learningMutationSnapshot(),
    beforeDeniedSuccessor,
    "denied failed-evaluation successors preserve row, event, lesson state and activity time",
  );
  const retryId = await insertPractice({
    revision: 3,
    previousId: failedId,
    status: "draft",
    payload: payloads.failing,
    results: null,
    demonstrated: null,
    mutationId: "70000000-0000-4000-8000-000000000004",
    intent: "retry",
  });
  const savedAfterRetryId = await insertPractice({
    revision: 4,
    previousId: retryId,
    status: "draft",
    payload: payloads.passing,
    results: null,
    demonstrated: null,
    mutationId: "70000000-0000-4000-8000-000000000029",
    intent: "save",
  });
  await expectDatabaseRejection(
    () =>
      insertPractice({
        revision: 6,
        previousId: savedAfterRetryId,
        status: "draft",
        payload: payloads.passing,
        results: null,
        demonstrated: null,
        mutationId: "70000000-0000-4000-8000-000000000005",
        intent: "save",
        expectedRevision: 4,
      }),
    "a stale or skipped practice revision",
  );
  await expectDatabaseRejection(
    () =>
      insertPractice({
        revision: 5,
        previousId: savedAfterRetryId,
        status: "evaluated",
        payload: payloads.passing,
        results: evaluation(payloads.passing, ["not-met", "met", "met"]),
        demonstrated: true,
        mutationId: "70000000-0000-4000-8000-000000000006",
        intent: "evaluate",
      }),
    "a forged server evaluation",
  );
  await insertPractice({
    revision: 5,
    previousId: savedAfterRetryId,
    status: "evaluated",
    payload: payloads.passing,
    results: evaluation(payloads.passing, ["met", "met", "met"]),
    demonstrated: true,
    mutationId: "70000000-0000-4000-8000-000000000007",
    intent: "evaluate",
  });

  const final = await withApplicationUser(lessonUserA, async (client) => {
    const lesson = await client.query(`SELECT status FROM lesson_attempts WHERE id=$1`, [lessonId]);
    const practices = await client.query(
      `SELECT revision, status, demonstrated, mutation_intent
       FROM practice_attempts WHERE lesson_attempt_id=$1 ORDER BY revision`,
      [lessonId],
    );
    const events = await client.query(
      `SELECT event_kind FROM learning_progress_events WHERE lesson_attempt_id=$1 ORDER BY occurred_at, event_kind`,
      [lessonId],
    );
    return { lesson: lesson.rows, practices: practices.rows, events: events.rows };
  });
  assert.equal(final.lesson[0].status, "demonstrated");
  assert.equal(final.practices.length, 5, "append-only history retains five exact revisions");
  assert.deepEqual(
    final.practices.map((row) => row.mutation_intent),
    ["save", "evaluate", "retry", "save", "evaluate"],
    "failed evaluation requires retry before another editable draft and evaluation",
  );
  assert.deepEqual(final.events.map((row) => row.event_kind).sort(), [
    "lesson_started",
    "practice_demonstrated",
    "practice_evaluated",
    "practice_evaluated",
  ]);

  await expectDatabaseRejection(
    () =>
      withApplicationUser(lessonUserA, (client) =>
        client.query(`UPDATE practice_attempts SET revision=9 WHERE lesson_attempt_id=$1`, [
          lessonId,
        ]),
      ),
    "an in-place practice history update",
    "42501",
  );
  await expectDatabaseRejection(
    () =>
      withApplicationUser(lessonUserA, (client) =>
        client.query(
          `UPDATE practice_attempts SET mutation_locale='th' WHERE lesson_attempt_id=$1`,
          [lessonId],
        ),
      ),
    "an in-place mutation provenance update",
    "42501",
  );
  await expectDatabaseRejection(
    () =>
      withApplicationUser(lessonUserA, (client) =>
        client.query(`DELETE FROM learning_progress_events WHERE lesson_attempt_id=$1`, [lessonId]),
      ),
    "a progress-event delete",
    "42501",
  );
  const hidden = await withApplicationUser(lessonUserB, async (client) => ({
    lessons: (await client.query(`SELECT id FROM lesson_attempts WHERE id=$1`, [lessonId]))
      .rowCount,
    practices: (
      await client.query(`SELECT id FROM practice_attempts WHERE lesson_attempt_id=$1`, [lessonId])
    ).rowCount,
    events: (
      await client.query(`SELECT id FROM learning_progress_events WHERE lesson_attempt_id=$1`, [
        lessonId,
      ])
    ).rowCount,
  }));
  assert.deepEqual(
    hidden,
    { lessons: 0, practices: 0, events: 0 },
    "forced RLS hides every learning row from another user",
  );

  for (const table of ["lesson_attempts", "practice_attempts", "learning_progress_events"]) {
    const missing = await applicationPool.query(`SELECT id FROM ${table}`);
    assert.equal(missing.rowCount, 0, `${table} fails closed without trusted context`);
    await expectDatabaseRejection(
      () => withApplicationUser("not-a-uuid", (client) => client.query(`SELECT id FROM ${table}`)),
      `${table} rejects malformed trusted context`,
      "22P02",
    );
  }

  await withApplicationUser(lessonUserA, (client) =>
    client.query(
      `INSERT INTO consent_records
      (user_id,purpose_code,notice_version,decision,occurred_at,locale,source_surface,proof_digest)
     VALUES ($1,'service-profile-learning-state','alpha-privacy-v1','withdrawn',clock_timestamp(),'en','synthetic-test',$2)`,
      [lessonUserA, proofDigest],
    ),
  );
  const hiddenAfterWithdrawal = await withApplicationUser(lessonUserA, (client) =>
    client.query(`SELECT id FROM lesson_attempts WHERE id=$1`, [lessonId]),
  );
  assert.equal(
    hiddenAfterWithdrawal.rowCount,
    0,
    "current consent withdrawal hides persisted lesson state",
  );

  const privileges = await ownerPool.query(
    `SELECT has_table_privilege('rise_pals_app','lesson_attempts','DELETE') AS lesson_delete,
            has_table_privilege('rise_pals_app','practice_attempts','UPDATE') AS practice_update,
            has_table_privilege('rise_pals_app','practice_attempts','DELETE') AS practice_delete,
            has_column_privilege('rise_pals_app','practice_attempts','mutation_intent','UPDATE')
              AS mutation_intent_update,
            has_column_privilege('rise_pals_app','practice_attempts','mutation_locale','UPDATE')
              AS mutation_locale_update,
            has_column_privilege('rise_pals_app','practice_attempts','mutation_expected_revision','UPDATE')
              AS mutation_expected_revision_update,
            has_table_privilege('rise_pals_app','learning_progress_events','UPDATE') AS event_update,
            has_table_privilege('rise_pals_app','learning_progress_events','DELETE') AS event_delete`,
  );
  assert.deepEqual(privileges.rows[0], {
    lesson_delete: false,
    practice_update: false,
    practice_delete: false,
    mutation_intent_update: false,
    mutation_locale_update: false,
    mutation_expected_revision_update: false,
    event_update: false,
    event_delete: false,
  });
}

let migrationResult = { migrationFiles: [], statementCount: 0 };

try {
  migrationResult = await applyMigration();
  await finalizeDisposableIdentityResolverBootstrap();
  await verifyIdentityProvisioningBoundary();
  await verifyConstraintsAndLifecycle();
  await verifyConcurrentPublicationGuards();
  await verifyRowLevelSecurity();
  await verifySerializedConsentReceipts();
  await verifyPersistedAssessmentContract();
  await verifyPersistedLessonContract();
  console.log(
    `PostgreSQL integration PASS (${migrationResult.statementCount} statements across ${migrationResult.migrationFiles.length} migrations, 20 tables, atomic Clerk provisioning, profile controls, persisted assessment revision/idempotency/submission controls, immutable reproducible derived runs with tie/priority/re-score evidence, persisted lesson-practice schema controls, and complete cross-user forced-RLS evidence).`,
  );
} finally {
  await Promise.allSettled([ownerPool.end(), applicationPool.end(), disposableBootstrapPool.end()]);
}
