import { spawnSync } from "node:child_process";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { randomBytes } from "node:crypto";
import { createServer } from "node:net";

// Isolated cluster only: never connects to an existing local or hosted database.
const root = await mkdtemp(join(tmpdir(), "risepals-postgres-"));
const bin = process.env.RISE_PALS_POSTGRES_BIN;
if (!bin) throw new Error("Set RISE_PALS_POSTGRES_BIN to an installed PostgreSQL bin directory.");
const data = join(root, "data");
const password = randomBytes(24).toString("hex");
const appPassword = randomBytes(24).toString("hex");
const ownerPassword = randomBytes(24).toString("hex");
const environment = { ...process.env, PGPASSWORD: password };
function run(file, args, input, env = environment) {
  const result = spawnSync(file, args, { env, input, encoding: "utf8", maxBuffer: 8_000_000 });
  if (result.status !== 0) throw new Error(`${file.split("/").pop()} failed: ${result.stderr}`);
  return result.stdout;
}
const listener = createServer();
await new Promise((resolve) => listener.listen(0, "127.0.0.1", resolve));
const port = listener.address().port;
await new Promise((resolve) => listener.close(resolve));
let started = false;
try {
  await writeFile(join(root, "password"), password, { mode: 0o600 });
  run(join(bin, "initdb"), [
    "-D",
    data,
    "-U",
    "postgres",
    "--auth-local=trust",
    "--auth-host=scram-sha-256",
    `--pwfile=${join(root, "password")}`,
    "--encoding=UTF8",
    "--locale=C",
  ]);
  run(join(bin, "pg_ctl"), [
    "-D",
    data,
    "-l",
    join(root, "server.log"),
    "-o",
    `-h 127.0.0.1 -p ${port} -c ssl=off`,
    "-w",
    "start",
  ]);
  started = true;
  if (process.argv.includes("--provision")) {
    console.log(
      run(process.execPath, ["scripts/db/provision-integration.mjs"], undefined, {
        ...environment,
        SUPABASE_DB_ADMIN_URL: `postgresql://postgres:${password}@127.0.0.1:${port}/postgres?sslmode=disable`,
        RISE_PALS_APP_DB_PASSWORD: appPassword,
      }),
    );
  } else {
    run(
      join(bin, "psql"),
      [
        "-h",
        "127.0.0.1",
        "-p",
        String(port),
        "-U",
        "postgres",
        "-d",
        "postgres",
        "-v",
        "ON_ERROR_STOP=1",
      ],
      `
CREATE ROLE rise_pals_owner LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS PASSWORD '${ownerPassword}';
CREATE ROLE rise_pals_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS PASSWORD '${appPassword}';
CREATE ROLE rise_pals_identity_resolver NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
CREATE ROLE rise_pals_privacy_operator NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
GRANT rise_pals_identity_resolver TO rise_pals_owner WITH ADMIN OPTION;
GRANT rise_pals_privacy_operator TO rise_pals_owner WITH ADMIN OPTION;
CREATE DATABASE rise_pals_test OWNER rise_pals_owner;
REVOKE CONNECT ON DATABASE rise_pals_test FROM PUBLIC;
GRANT CONNECT ON DATABASE rise_pals_test TO rise_pals_owner, rise_pals_app;
`,
    );
    const env = {
      ...environment,
      DATABASE_URL: `postgresql://rise_pals_app:${appPassword}@127.0.0.1:${port}/rise_pals_test?sslmode=disable`,
      DATABASE_MIGRATION_URL: `postgresql://rise_pals_owner:${ownerPassword}@127.0.0.1:${port}/rise_pals_test?sslmode=disable`,
      RISE_PALS_DISPOSABLE_BOOTSTRAP_URL: `postgresql://postgres:${password}@127.0.0.1:${port}/rise_pals_test?sslmode=disable`,
    };
    console.log(run(join(bin, "postgres"), ["--version"]).trim());
    console.log(run(process.execPath, ["scripts/db/integration.mjs"], undefined, env));
    console.log(run(process.execPath, ["scripts/db/supabase-integration.mjs"], undefined, env));
  }
} finally {
  if (started) run(join(bin, "pg_ctl"), ["-D", data, "-m", "fast", "-w", "stop"]);
  await rm(root, { recursive: true, force: true });
  console.log("Disposable PostgreSQL cluster stopped and removed.");
}
