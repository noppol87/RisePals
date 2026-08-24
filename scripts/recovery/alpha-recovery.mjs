import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { mkdir, readFile, realpath, rm, writeFile } from "node:fs/promises";
import { basename, dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";

import pg from "pg";

import { createAlphaOwnerExport } from "../../src/modules/privacy/export-runtime.mjs";
import {
  createDeterministicSyntheticIdentityErasureAdapter,
  runAlphaOwnerErasure,
} from "../../src/modules/privacy/erasure-runtime.mjs";

const { Pool } = pg;
const migrationUrl = process.env.DATABASE_MIGRATION_URL;
const applicationUrl = process.env.DATABASE_URL;
const bootstrapUrl = process.env.RISE_PALS_DISPOSABLE_BOOTSTRAP_URL;
const postgresBin = process.env.RISE_PALS_POSTGRES_BIN;
const recoveryRoot = process.env.RISE_PALS_ALPHA_RECOVERY_ROOT;
const recoveryBase = resolve(tmpdir(), "risepals-alpha-recovery");
const recoveryOwner = "20000000-0000-4000-8000-000000000004";
const preservedOwner = "20000000-0000-4000-8000-000000000005";
const deletionRequest = "60000000-0000-4000-8000-000000000001";
const upgradeDatabase = "rise_pals_upgrade_rehearsal";
const restoredDatabase = "rise_pals_restore_rehearsal";
const invalidDatabase = "rise_pals_invalid_restore_rehearsal";
const databaseNames = [upgradeDatabase, restoredDatabase, invalidDatabase];

if (!migrationUrl || !applicationUrl || !bootstrapUrl || !postgresBin || !recoveryRoot) {
  throw new Error("Recovery rehearsal requires bounded disposable database configuration.");
}

const resolvedRecoveryRoot = resolve(recoveryRoot);
const canonicalRecoveryBase = await realpath(recoveryBase);
const canonicalRecoveryParent = await realpath(dirname(resolvedRecoveryRoot));
if (
  canonicalRecoveryParent.toLowerCase() !== canonicalRecoveryBase.toLowerCase() ||
  !/^[0-9a-f]{32}$/i.test(basename(resolvedRecoveryRoot))
) {
  throw new Error("Recovery rehearsal refused an unverified temporary path.");
}

const migrationDirectory = resolve("drizzle");
const journal = JSON.parse(await readFile(join(migrationDirectory, "meta/_journal.json"), "utf8"));
const migrationFiles = journal.entries.map((entry) => `${entry.tag}.sql`);
assert.equal(migrationFiles.length, 8, "recovery rehearsal requires exactly eight migrations");

function databaseUrl(source, database) {
  const result = new URL(source);
  result.pathname = `/${database}`;
  return result.toString();
}

function postgresEnvironment(source, database) {
  const url = new URL(source);
  return {
    ...process.env,
    PGHOST: url.hostname,
    PGPORT: url.port,
    PGUSER: decodeURIComponent(url.username),
    PGPASSWORD: decodeURIComponent(url.password),
    PGDATABASE: database,
  };
}

function runPostgresTool(executable, args, environment, expectedSuccess = true) {
  const result = spawnSync(join(postgresBin, executable), args, {
    env: environment,
    encoding: "utf8",
    windowsHide: true,
  });
  if (expectedSuccess) {
    assert.equal(result.status, 0, `${executable} completed successfully`);
  } else {
    assert.notEqual(result.status, 0, `${executable} rejected an invalid recovery artifact`);
  }
  return result.status;
}

async function applyMigrations(pool, startInclusive, endExclusive) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(`CREATE SCHEMA IF NOT EXISTS drizzle`);
    await client.query(
      `CREATE TABLE IF NOT EXISTS drizzle.__drizzle_migrations (
         id serial PRIMARY KEY,
         hash text NOT NULL,
         created_at bigint NOT NULL
       )`,
    );
    for (let index = startInclusive; index < endExclusive; index += 1) {
      const fileName = migrationFiles[index];
      const raw = await readFile(join(migrationDirectory, fileName), "utf8");
      const statements = raw
        .split("--> statement-breakpoint")
        .map((statement) => statement.trim())
        .filter(Boolean);
      for (const statement of statements) {
        await client.query(statement);
      }
      await client.query(
        `INSERT INTO drizzle.__drizzle_migrations (hash, created_at) VALUES ($1, $2)`,
        [createHash("sha256").update(raw, "utf8").digest("hex"), journal.entries[index].when],
      );
    }
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function inventory(pool) {
  const result = await pool.query(
    `SELECT
       (SELECT count(*)::integer FROM information_schema.tables
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE') AS tables,
       (SELECT count(*)::integer FROM drizzle.__drizzle_migrations) AS migrations,
       (SELECT count(*)::integer FROM pg_class
        WHERE relnamespace = 'public'::regnamespace AND relrowsecurity AND relforcerowsecurity)
         AS forced_rls,
       (SELECT count(*)::integer FROM pg_class relation
        JOIN pg_roles owner ON owner.oid = relation.relowner
        WHERE relation.relkind = 'r' AND relation.relnamespace = 'public'::regnamespace
          AND owner.rolname = 'rise_pals_privacy_operator') AS privacy_owned_tables,
       (SELECT count(*)::integer FROM pg_proc function
        JOIN pg_namespace namespace ON namespace.oid = function.pronamespace
        JOIN pg_roles owner ON owner.oid = function.proowner
        WHERE namespace.nspname = 'rise_pals_private'
          AND owner.rolname = 'rise_pals_privacy_operator'
          AND function.proname IN ('request_owner_erasure', 'erase_owner_private_data'))
         AS privacy_functions,
       (SELECT count(*)::integer FROM pg_constraint
        WHERE conrelid = 'public.user_accounts'::regclass
          AND conname IN ('user_accounts_deletion_request_id_unique',
                          'user_accounts_deletion_request_state_check'))
         AS deletion_constraints,
       (SELECT (NOT rolcanlogin AND NOT rolinherit AND NOT rolbypassrls
                       AND NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole)
        FROM pg_roles WHERE rolname = 'rise_pals_privacy_operator') AS privacy_role_locked,
       (SELECT count(*)::integer FROM user_accounts) AS accounts,
       (SELECT string_agg(content_digest, ',' ORDER BY content_digest)
        FROM framework_versions) AS framework_digests,
       (SELECT string_agg(content_digest, ',' ORDER BY content_digest)
        FROM assessment_versions) AS assessment_digests,
       (SELECT string_agg(content_digest, ',' ORDER BY content_digest)
        FROM scoring_model_versions) AS scoring_digests,
       (SELECT string_agg(result_policy_digest, ',' ORDER BY result_policy_digest)
        FROM scoring_runs) AS result_policy_digests`,
  );
  return result.rows[0];
}

async function ownerPrivateCount(pool, ownerId) {
  const result = await pool.query(
    `SELECT
       (SELECT count(*) FROM external_identities WHERE user_id = $1) +
       (SELECT count(*) FROM consent_records WHERE user_id = $1) +
       (SELECT count(*) FROM user_profiles WHERE user_id = $1) +
       (SELECT count(*) FROM assessment_sessions WHERE user_id = $1) +
       (SELECT count(*) FROM scoring_runs WHERE user_id = $1) +
       (SELECT count(*) FROM competency_scores WHERE user_id = $1) +
       (SELECT count(*) FROM multiplier_observations WHERE user_id = $1) +
       (SELECT count(*) FROM score_explanations WHERE user_id = $1) +
       (SELECT count(*) FROM priority_recommendations WHERE user_id = $1) +
       (SELECT count(*) FROM lesson_attempts WHERE user_id = $1) +
       (SELECT count(*) FROM practice_attempts WHERE user_id = $1) +
       (SELECT count(*) FROM learning_progress_events WHERE user_id = $1) +
       (SELECT count(*) FROM evidence_artifacts WHERE user_id = $1) +
       (SELECT count(*) FROM evidence_artifact_revisions WHERE user_id = $1) +
       (SELECT count(*) FROM evidence_competency_links WHERE user_id = $1) +
       (SELECT count(*) FROM measurement_subjects WHERE user_id = $1)
       AS count`,
    [ownerId],
  );
  return Number(result.rows[0].count);
}

async function exportOwner(pool, ownerId) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT set_config('app.current_user_id', $1, true)", [ownerId]);
    const result = await createAlphaOwnerExport(client, ownerId);
    await client.query("ROLLBACK");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

function createPrivacyClient(pool, ownerId) {
  return {
    async query(sql, values) {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        await client.query("SET LOCAL ROLE rise_pals_privacy_operator");
        await client.query("SELECT set_config('app.current_user_id', $1, true)", [ownerId]);
        const result = await client.query(sql, values);
        await client.query("COMMIT");
        return result;
      } catch (error) {
        await client.query("ROLLBACK");
        throw error;
      } finally {
        client.release();
      }
    },
  };
}

const adminPool = new Pool({ connectionString: databaseUrl(bootstrapUrl, "postgres"), max: 1 });
const originalPool = new Pool({ connectionString: bootstrapUrl, max: 2 });
let upgradePool;
let restoredAdminPool;
let restoredAppPool;
let invalidPool;
const dumpPath = join(resolvedRecoveryRoot, "synthetic-alpha.backup");
const exportOnePath = join(resolvedRecoveryRoot, "owner-export-one.json");
const exportTwoPath = join(resolvedRecoveryRoot, "owner-export-two.json");
const invalidDumpPath = join(resolvedRecoveryRoot, "invalid.backup");

try {
  await mkdir(resolvedRecoveryRoot, { recursive: false });
  for (const database of databaseNames) {
    await adminPool.query(`DROP DATABASE IF EXISTS ${database} WITH (FORCE)`);
  }

  await adminPool.query(`CREATE DATABASE ${upgradeDatabase} OWNER rise_pals_owner`);
  await adminPool.query(`GRANT rise_pals_identity_resolver TO rise_pals_owner WITH ADMIN OPTION`);
  await adminPool.query(`GRANT rise_pals_privacy_operator TO rise_pals_owner WITH ADMIN OPTION`);
  upgradePool = new Pool({
    connectionString: databaseUrl(migrationUrl, upgradeDatabase),
    max: 1,
  });
  await applyMigrations(upgradePool, 0, 7);
  const sevenInventory = await inventory(upgradePool);
  assert.equal(sevenInventory.tables, 26, "accepted seven-migration state has 26 public tables");
  assert.equal(sevenInventory.migrations, 7, "accepted state records seven migrations");
  await applyMigrations(upgradePool, 7, 8);
  const upgradedInventory = await inventory(upgradePool);
  assert.equal(upgradedInventory.tables, 26, "seven-to-eight upgrade preserves 26 public tables");
  assert.equal(upgradedInventory.migrations, 8, "seven-to-eight upgrade records migration eight");
  await upgradePool.end();
  upgradePool = undefined;
  await adminPool.query(`REVOKE rise_pals_identity_resolver FROM rise_pals_owner`);
  await adminPool.query(`REVOKE rise_pals_privacy_operator FROM rise_pals_owner`);

  const originalInventory = await inventory(originalPool);
  assert.equal(originalInventory.tables, 26);
  assert.equal(originalInventory.migrations, 8);
  assert.equal(originalInventory.forced_rls, 20);
  assert.equal(originalInventory.privacy_owned_tables, 0);
  assert.equal(originalInventory.privacy_functions, 2);
  assert.equal(originalInventory.deletion_constraints, 2);
  assert.equal(originalInventory.privacy_role_locked, true);

  runPostgresTool(
    "pg_dump.exe",
    ["--format=custom", "--file", dumpPath],
    postgresEnvironment(bootstrapUrl, "rise_pals_test"),
  );
  await adminPool.query(`CREATE DATABASE ${restoredDatabase} OWNER rise_pals_owner`);
  runPostgresTool(
    "pg_restore.exe",
    ["--exit-on-error", "--dbname", restoredDatabase, dumpPath],
    postgresEnvironment(bootstrapUrl, restoredDatabase),
  );

  restoredAdminPool = new Pool({
    connectionString: databaseUrl(bootstrapUrl, restoredDatabase),
    max: 2,
  });
  restoredAppPool = new Pool({
    connectionString: databaseUrl(applicationUrl, restoredDatabase),
    max: 1,
  });
  const restoredInventory = await inventory(restoredAdminPool);
  assert.deepEqual(
    restoredInventory,
    originalInventory,
    "restored schema and digest inventory matches",
  );

  const firstExport = await exportOwner(restoredAppPool, recoveryOwner);
  const secondExport = await exportOwner(restoredAppPool, recoveryOwner);
  assert.equal(firstExport.bytes, secondExport.bytes, "restored export is byte-identical");
  assert.equal(firstExport.sha256, secondExport.sha256, "restored export digest is stable");
  await writeFile(exportOnePath, firstExport.bytes, { encoding: "utf8", flag: "wx" });
  await writeFile(exportTwoPath, secondExport.bytes, { encoding: "utf8", flag: "wx" });

  const preservedCountBefore = await ownerPrivateCount(restoredAdminPool, preservedOwner);
  const erasedCountBefore = await ownerPrivateCount(restoredAdminPool, recoveryOwner);
  assert.ok(erasedCountBefore > 0, "recovery owner has private rows before erasure");
  const providerAdapter = createDeterministicSyntheticIdentityErasureAdapter();
  const privacyClient = createPrivacyClient(restoredAdminPool, recoveryOwner);
  const erased = await runAlphaOwnerErasure({
    client: privacyClient,
    ownerId: recoveryOwner,
    requestId: deletionRequest,
    providerAdapter,
  });
  assert.equal(erased.state, "deleted");
  assert.ok(erased.deletedRows > 0);
  assert.equal(await ownerPrivateCount(restoredAdminPool, recoveryOwner), 0);
  const replay = await runAlphaOwnerErasure({
    client: privacyClient,
    ownerId: recoveryOwner,
    requestId: deletionRequest,
    providerAdapter,
  });
  assert.deepEqual(replay, {
    contractVersion: "rise-pals-alpha-erasure-v1@1.0.0",
    state: "deleted",
    replayed: true,
    deletedRows: 0,
    provider: "already-complete",
  });
  assert.equal(providerAdapter.getMutationCount(), 1, "fake provider erasure mutates once");
  assert.equal(
    await ownerPrivateCount(restoredAdminPool, preservedOwner),
    preservedCountBefore,
    "another owner is unchanged after restored-database erasure",
  );
  const postErasureInventory = await inventory(restoredAdminPool);
  assert.equal(postErasureInventory.framework_digests, originalInventory.framework_digests);
  assert.equal(postErasureInventory.assessment_digests, originalInventory.assessment_digests);
  assert.equal(postErasureInventory.scoring_digests, originalInventory.scoring_digests);

  await writeFile(invalidDumpPath, "not-a-postgresql-backup\n", {
    encoding: "utf8",
    flag: "wx",
  });
  await adminPool.query(`CREATE DATABASE ${invalidDatabase} OWNER rise_pals_owner`);
  runPostgresTool(
    "pg_restore.exe",
    ["--exit-on-error", "--dbname", invalidDatabase, invalidDumpPath],
    postgresEnvironment(bootstrapUrl, invalidDatabase),
    false,
  );

  console.log(
    `Alpha recovery PASS (fresh 8 migrations, seven-to-eight upgrade, 26 tables, 20 forced-RLS tables, byte-identical owner export, backup/restore inventory match, idempotent restored-database erasure, invalid restore rejected).`,
  );
} finally {
  await Promise.allSettled([
    upgradePool?.end(),
    restoredAppPool?.end(),
    restoredAdminPool?.end(),
    invalidPool?.end(),
    originalPool.end(),
  ]);
  for (const database of databaseNames) {
    await adminPool.query(`DROP DATABASE IF EXISTS ${database} WITH (FORCE)`);
  }
  const leftovers = await adminPool.query(
    `SELECT count(*)::integer AS count FROM pg_database WHERE datname = ANY($1::text[])`,
    [databaseNames],
  );
  assert.equal(leftovers.rows[0].count, 0, "recovery rehearsal leaves no child database");
  await adminPool.end();
  await rm(resolvedRecoveryRoot, { recursive: true, force: true });
}
