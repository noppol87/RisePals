import assert from "node:assert/strict";
import pg from "pg";
import { provisionSupabase } from "./provision-supabase.mjs";

const url = new URL(process.env.SUPABASE_DB_ADMIN_URL);
assert.equal(url.hostname, "127.0.0.1", "Disposable provisioning test is loopback-only");
const admin = new pg.Pool({ connectionString: url.href });
try {
  await admin.query("CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN");
  const first = await provisionSupabase(process.env);
  assert.equal(first.tables, 26);
  assert.equal(
    (
      await admin.query(
        "SELECT count(*)::integer AS count FROM assessment_versions WHERE status='published'",
      )
    ).rows[0].count,
    1,
  );
  assert.equal(
    (await admin.query("SELECT count(*)::integer AS count FROM user_accounts")).rows[0].count,
    0,
  );
  const rules = await admin.query(
    "SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r' AND NOT c.relrowsecurity",
  );
  assert.equal(rules.rowCount, 0, "all application tables have RLS enabled");
  const owner = await admin.query(
    "SELECT pg_has_role('rise_pals_owner','rise_pals_identity_resolver','MEMBER') AS member",
  );
  assert.equal(owner.rows[0].member, false);
  for (const role of ["anon", "authenticated"]) {
    const result = await admin.query(
      "SELECT has_table_privilege($1,'user_accounts','SELECT') AS allowed",
      [role],
    );
    assert.equal(result.rows[0].allowed, false);
  }
  await assert.rejects(() => provisionSupabase(process.env), /empty dedicated project/);
  assert.equal(
    (await admin.query("SELECT count(*)::integer AS count FROM assessment_versions")).rows[0].count,
    1,
  );
  const appUrl = new URL(url);
  appUrl.username = "rise_pals_app";
  appUrl.password = process.env.RISE_PALS_APP_DB_PASSWORD;
  const app = new pg.Pool({ connectionString: appUrl.href });
  try {
    const c = await app.connect();
    try {
      await c.query("BEGIN");
      const account = await c.query(
        "SELECT * FROM rise_pals_private.resolve_or_provision_supabase_identity('supabase','70000000-0000-4000-8000-000000000001')",
      );
      assert.equal(account.rows[0].status, "active");
      assert.equal(
        (await c.query("SELECT count(*)::integer AS count FROM assessment_versions")).rows[0].count,
        1,
      );
      await c.query("ROLLBACK");
    } finally {
      c.release();
    }
  } finally {
    await app.end();
  }
  console.log(
    "Fresh project provisioning PASS: 26 RLS tables, versioned migrations, synthetic definitions, isolated runtime role, no Data API grants, and safe refusal to overwrite.",
  );
} finally {
  await admin.end();
}
