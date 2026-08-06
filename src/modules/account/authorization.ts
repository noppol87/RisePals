import "server-only";
import type { Pool, PoolClient } from "pg";
import { createApplicationPool } from "@/lib/db/server";
import type { IdentityProvider, ProviderSession } from "@/modules/identity/contract";
import { isValidatedClerkSession } from "@/modules/identity/contract";

export type AccountStatus = "active" | "suspended" | "deletion_pending" | "deleted";
export type AuthorizationFailureReason =
  "absent" | "invalid" | "expired" | "unavailable" | "suspended" | "deletion_pending" | "deleted";

export type AuthorizedTransactionResult<T> =
  | Readonly<{ state: "authorized"; value: T }>
  | Readonly<{ state: "denied"; reason: AuthorizationFailureReason }>;

type ResolvedAccount = Readonly<{ userId: string; status: AccountStatus }>;

let applicationPool: Pool | null = null;

function getApplicationPool(): Pool {
  applicationPool ??= createApplicationPool();
  return applicationPool;
}

function deniedSession(session: ProviderSession): AuthorizedTransactionResult<never> {
  return {
    state: "denied",
    reason: session.state === "authenticated" ? "invalid" : session.state,
  };
}

function parseResolvedAccount(row: unknown): ResolvedAccount {
  if (!row || typeof row !== "object") {
    throw new Error("Identity resolution returned no internal account.");
  }

  const candidate = row as Readonly<Record<string, unknown>>;
  const validStatuses: readonly AccountStatus[] = [
    "active",
    "suspended",
    "deletion_pending",
    "deleted",
  ];

  if (
    typeof candidate.user_id !== "string" ||
    typeof candidate.status !== "string" ||
    !validStatuses.includes(candidate.status as AccountStatus)
  ) {
    throw new Error("Identity resolution returned an invalid internal account.");
  }

  return { userId: candidate.user_id, status: candidate.status as AccountStatus };
}

export async function withAuthorizedUserTransaction<T>(
  identityProvider: IdentityProvider,
  operation: (client: PoolClient, internalUserId: string) => Promise<T>,
  pool?: Pool,
): Promise<AuthorizedTransactionResult<T>> {
  const session = await identityProvider.readSession();

  if (!isValidatedClerkSession(session)) {
    return deniedSession(session);
  }

  const client = await (pool ?? getApplicationPool()).connect();

  try {
    await client.query("BEGIN");
    await client.query(`SELECT pg_advisory_xact_lock(hashtextextended('clerk:' || $1, 0))`, [
      session.providerSubject,
    ]);
    const resolution = await client.query(
      `SELECT user_id, status
       FROM rise_pals_private.resolve_or_provision_clerk_identity('clerk', $1)`,
      [session.providerSubject],
    );
    const account = parseResolvedAccount(resolution.rows[0]);

    if (account.status !== "active") {
      await client.query("ROLLBACK");
      return { state: "denied", reason: account.status };
    }

    await client.query("SELECT set_config('app.current_user_id', $1, true)", [account.userId]);
    const value = await operation(client, account.userId);
    await client.query("COMMIT");
    return { state: "authorized", value };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}
