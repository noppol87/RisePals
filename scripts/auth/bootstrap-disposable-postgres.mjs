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
  assert.equal(tables.rowCount, 10, "the smoke database must contain exactly ten tables");

  for (const { table_name: tableName } of tables.rows) {
    assert.match(tableName, /^[a-z][a-z0-9_]*$/, "table inventory must be identifier-safe");
    const result = await bootstrapPool.query(`SELECT count(*)::integer AS count FROM ${tableName}`);
    assert.equal(result.rows[0].count, 0, `${tableName} must start empty`);
  }

  console.log(
    `Disposable smoke database PASS (${statementCount} statements across ${migrationFiles.length} migrations; ${tables.rowCount} empty tables).`,
  );
} finally {
  await Promise.allSettled([ownerPool.end(), bootstrapPool.end()]);
}
