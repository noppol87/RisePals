import { readdir, readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { pathToFileURL } from "node:url";
import pg from "pg";
import { seedSyntheticPublishedDefinition } from "./seed-synthetic.mjs";

// One-time initialization of a dedicated, empty project. Existing projects are
// deliberately refused. No DROP, overwrite, or implicit schema repair is performed.
export async function provisionSupabase(environment) {
  const url = environment.SUPABASE_DB_ADMIN_URL;
  const password = environment.RISE_PALS_APP_DB_PASSWORD;
  if (!url || !password || password.length < 32)
    throw new Error(
      "Provisioning needs an admin database URL and an application password of at least 32 characters.",
    );
  const connection = new URL(url);
  if (
    !["postgres:", "postgresql:"].includes(connection.protocol) ||
    !connection.username ||
    !connection.password ||
    (!["localhost", "127.0.0.1", "[::1]"].includes(connection.hostname) &&
      !["require", "verify-full"].includes(connection.searchParams.get("sslmode")))
  ) {
    throw new Error("Use an authenticated PostgreSQL connection with TLS outside loopback.");
  }
  const pool = new pg.Pool({ connectionString: url, max: 1 });
  let client;
  try {
    client = await pool.connect();
    await client.query("BEGIN");
    await client.query("SELECT pg_advisory_xact_lock(829317026)");
    const existing = await client.query(
      "SELECT tablename FROM pg_tables WHERE schemaname='public'",
    );
    const roles = await client.query("SELECT rolname FROM pg_roles WHERE rolname=ANY($1)", [
      [
        "rise_pals_owner",
        "rise_pals_app",
        "rise_pals_identity_resolver",
        "rise_pals_privacy_operator",
      ],
    ]);
    if (existing.rowCount || roles.rowCount)
      throw new Error(
        "Provisioning requires an empty dedicated project without existing Rise Pals roles.",
      );
    const current = (await client.query("SELECT current_user AS name")).rows[0].name;
    await client.query(
      `CREATE ROLE rise_pals_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS`,
    );
    await client.query(
      `CREATE ROLE rise_pals_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS PASSWORD ${pg.escapeLiteral(password)}`,
    );
    await client.query(
      "CREATE ROLE rise_pals_identity_resolver NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS",
    );
    await client.query(
      "CREATE ROLE rise_pals_privacy_operator NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS",
    );
    await client.query(
      `GRANT rise_pals_owner TO ${pg.escapeIdentifier(current)} WITH ADMIN OPTION`,
    );
    await client.query("GRANT rise_pals_identity_resolver TO rise_pals_owner WITH ADMIN OPTION");
    await client.query("GRANT rise_pals_privacy_operator TO rise_pals_owner WITH ADMIN OPTION");
    await client.query("GRANT USAGE, CREATE ON SCHEMA public TO rise_pals_owner");
    const database = (await client.query("SELECT current_database() AS name")).rows[0].name;
    await client.query(
      `GRANT CONNECT, CREATE ON DATABASE ${pg.escapeIdentifier(database)} TO rise_pals_owner`,
    );
    await client.query(
      `GRANT CONNECT ON DATABASE ${pg.escapeIdentifier(database)} TO rise_pals_app`,
    );
    await client.query("SET LOCAL ROLE rise_pals_owner");
    await client.query("CREATE SCHEMA drizzle");
    await client.query(
      "CREATE TABLE drizzle.__drizzle_migrations (id serial PRIMARY KEY, hash text NOT NULL, created_at bigint NOT NULL)",
    );
    const journal = JSON.parse(await readFile("drizzle/meta/_journal.json", "utf8"));
    for (const entry of journal.entries) {
      const sql = await readFile(`drizzle/${entry.tag}.sql`, "utf8");
      await client.query(sql);
      await client.query(
        "INSERT INTO drizzle.__drizzle_migrations(hash,created_at) VALUES ($1,$2)",
        [createHash("sha256").update(sql).digest("hex"), entry.when],
      );
    }
    await client.query(
      "CREATE TABLE drizzle.supabase_migrations (filename text PRIMARY KEY, sha256 text NOT NULL)",
    );
    for (const file of (await readdir("supabase/migrations"))
      .filter((name) => name.endsWith(".sql"))
      .sort()) {
      const sql = await readFile(`supabase/migrations/${file}`, "utf8");
      await client.query(sql);
      await client.query("INSERT INTO drizzle.supabase_migrations VALUES ($1,$2)", [
        file,
        createHash("sha256").update(sql).digest("hex"),
      ]);
    }
    await seedSyntheticPublishedDefinition(client);
    await client.query("RESET ROLE");
    await client.query("REVOKE rise_pals_identity_resolver FROM rise_pals_owner");
    await client.query("REVOKE rise_pals_privacy_operator FROM rise_pals_owner");
    await client.query(`REVOKE rise_pals_owner FROM ${pg.escapeIdentifier(current)}`);
    await client.query(
      `REVOKE CREATE ON DATABASE ${pg.escapeIdentifier(database)} FROM rise_pals_owner`,
    );
    const tables = await client.query(
      "SELECT count(*)::integer AS count FROM pg_tables WHERE schemaname='public'",
    );
    if (tables.rows[0].count !== 26) throw new Error("Unexpected application table count.");
    await client.query("COMMIT");
    return {
      tables: 26,
      baselineMigrations: journal.entries.length,
      seeded: "synthetic assessment only",
    };
  } catch (error) {
    if (client) await client.query("ROLLBACK");
    throw error;
  } finally {
    client?.release();
    await pool.end();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (!process.argv.includes("--apply")) {
    console.log(
      "Plan only: initialize an empty dedicated project with restricted roles, 26 tables, immutable baseline + Supabase migration, and reviewed synthetic assessment definitions. Pass --apply with server-side environment credentials to execute.",
    );
  } else {
    try {
      console.log(await provisionSupabase(process.env));
    } catch {
      console.error(
        "Provisioning failed and rolled back. Verify an empty dedicated project, role-creation rights, and TLS connection. No credentials were printed.",
      );
      process.exitCode = 1;
    }
  }
}
