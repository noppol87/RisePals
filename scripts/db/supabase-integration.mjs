import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import pg from "pg";

const admin = new pg.Pool({
  connectionString: process.env.RISE_PALS_DISPOSABLE_BOOTSTRAP_URL,
  max: 1,
});
const owner = new pg.Pool({ connectionString: process.env.DATABASE_MIGRATION_URL, max: 1 });
const app = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 8 });
const subject = "70000000-0000-4000-8000-000000000001";
async function resolve(subject, provider = "supabase") {
  const client = await app.connect();
  try {
    await client.query("BEGIN");
    // Acquire the lock before the resolver statement to refresh the READ COMMITTED snapshot.
    await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1 || ':' || $2, 0))", [
      provider,
      subject,
    ]);
    const result = await client.query(
      "SELECT * FROM rise_pals_private.resolve_or_provision_supabase_identity($1,$2)",
      [provider, subject],
    );
    await client.query("COMMIT");
    return result.rows[0];
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}
try {
  await admin.query("GRANT rise_pals_identity_resolver TO rise_pals_owner WITH ADMIN OPTION");
  const client = await owner.connect();
  try {
    await client.query("BEGIN");
    for (const file of (await readdir("supabase/migrations"))
      .filter((name) => name.endsWith(".sql"))
      .sort()) {
      await client.query(await readFile(`supabase/migrations/${file}`, "utf8"));
    }
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
  await admin.query("REVOKE rise_pals_identity_resolver FROM rise_pals_owner");
  const results = await Promise.all(Array.from({ length: 8 }, () => resolve(subject)));
  assert.equal(new Set(results.map((row) => row.user_id)).size, 1);
  assert.equal(results[0].status, "active");
  const userId = results[0].user_id;
  const other = await resolve("70000000-0000-4000-8000-000000000002");
  assert.notEqual(other.user_id, userId);
  for (const bad of [
    null,
    "",
    "user_synthetic0001",
    "00000000-0000-0000-0000-000000000000",
    subject.toUpperCase().replace("700", "ZZZ"),
  ]) {
    await assert.rejects(() => resolve(bad), { code: "22023" });
  }
  await assert.rejects(() => resolve(subject, null), { code: "22023" });
  await assert.rejects(() => resolve(subject, "clerk"), { code: "22023" });
  const noContext = await app.query("SELECT * FROM user_accounts");
  assert.equal(noContext.rowCount, 0);
  const client2 = await app.connect();
  try {
    await client2.query("BEGIN");
    await client2.query("SELECT set_config('app.current_user_id', $1, true)", [userId]);
    assert.equal(
      (await client2.query("SELECT * FROM user_accounts WHERE id=$1", [other.user_id])).rowCount,
      0,
    );
    assert.equal(
      (await client2.query("SELECT * FROM user_accounts WHERE id=$1", [userId])).rowCount,
      1,
    );
    await client2.query("ROLLBACK");
  } finally {
    client2.release();
  }
  for (const status of ["suspended", "deletion_pending", "deleted"]) {
    const operator = await admin.connect();
    try {
      await operator.query("BEGIN");
      await operator.query("SET LOCAL ROLE rise_pals_privacy_operator");
      await operator.query("SELECT set_config('app.current_user_id', $1, true)", [userId]);
      await operator.query(
        `UPDATE user_accounts SET status=$1::text::account_status,
        deletion_request_id=CASE WHEN $1 IN ('deleted','deletion_pending') THEN '80000000-0000-4000-8000-000000000001'::uuid ELSE NULL END,
        deletion_requested_at=CASE WHEN $1 IN ('deleted','deletion_pending') THEN now() ELSE NULL END,
        deleted_at=CASE WHEN $1='deleted' THEN now() ELSE NULL END
        WHERE id=$2`,
        [status, userId],
      );
      await operator.query("COMMIT");
    } catch (error) {
      await operator.query("ROLLBACK");
      throw error;
    } finally {
      operator.release();
    }
    assert.equal((await resolve(subject)).status, status);
  }
  for (const role of ["anon", "authenticated"]) {
    const grants = await admin.query(
      "SELECT has_table_privilege($1,'public.external_identities','SELECT') AS allowed, has_schema_privilege($1,'rise_pals_private','USAGE') AS private",
      [role],
    );
    assert.deepEqual(grants.rows[0], { allowed: false, private: false });
  }
  const privileges = await admin.query(
    "SELECT rolcanlogin, rolbypassrls FROM pg_roles WHERE rolname='rise_pals_identity_resolver'",
  );
  assert.deepEqual(privileges.rows[0], { rolcanlogin: false, rolbypassrls: false });
  assert.equal(
    (
      await admin.query(
        "SELECT pg_has_role('rise_pals_owner','rise_pals_identity_resolver','MEMBER') AS member",
      )
    ).rows[0].member,
    false,
  );
  console.log(
    "Supabase identity migration PASS: concurrency, invalid subjects, isolated owners, account lifecycle, Data API denial and resolver privilege separation.",
  );
} finally {
  await Promise.all([admin.end(), owner.end(), app.end()]);
}
