import { describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));
vi.mock("@/lib/db/server", () => ({ createApplicationPool: vi.fn() }));

import { withAuthorizedUserTransaction } from "@/modules/account/authorization";
import type { IdentityProvider, ProviderSession } from "@/modules/identity/contract";
import type { Pool, PoolClient } from "pg";

function provider(session: ProviderSession): IdentityProvider {
  return { readSession: vi.fn().mockResolvedValue(session) };
}

function database(status: string) {
  const query = vi.fn(async (statement: string) => {
    if (statement.includes("resolve_or_provision_clerk_identity")) {
      return {
        rows: [{ user_id: "10000000-0000-4000-8000-000000000001", status }],
        rowCount: 1,
      };
    }
    return { rows: [], rowCount: null };
  });
  const release = vi.fn();
  const client = { query, release } as unknown as PoolClient;
  const connect = vi.fn().mockResolvedValue(client);
  const pool = { connect } as unknown as Pool;
  return { client, connect, pool, query, release };
}

describe("server-only account authorization", () => {
  it.each(["absent", "invalid", "expired", "unavailable"] as const)(
    "fails closed for a %s session before touching PostgreSQL",
    async (state) => {
      const db = database("active");
      await expect(
        withAuthorizedUserTransaction(provider({ state }), vi.fn(), db.pool),
      ).resolves.toEqual({ state: "denied", reason: state });
      expect(db.connect).not.toHaveBeenCalled();
    },
  );

  it("rejects a browser-shaped subject before identity resolution", async () => {
    const db = database("active");
    const session = provider({
      state: "authenticated",
      provider: "clerk",
      providerSubject: "guessed-browser-id",
    });

    await expect(withAuthorizedUserTransaction(session, vi.fn(), db.pool)).resolves.toEqual({
      state: "denied",
      reason: "invalid",
    });
    expect(db.connect).not.toHaveBeenCalled();
  });

  it.each(["suspended", "deletion_pending", "deleted"] as const)(
    "fails closed and rolls back a %s internal account",
    async (status) => {
      const db = database(status);
      const operation = vi.fn();
      const result = await withAuthorizedUserTransaction(
        provider({
          state: "authenticated",
          provider: "clerk",
          providerSubject: "user_synthetic0001",
        }),
        operation,
        db.pool,
      );

      expect(result).toEqual({ state: "denied", reason: status });
      expect(operation).not.toHaveBeenCalled();
      expect(db.query).toHaveBeenCalledWith("ROLLBACK");
    },
  );

  it("runs an active operation inside the internal-user transaction without returning the subject", async () => {
    const db = database("active");
    const operation = vi.fn().mockResolvedValue({ profile: "client-safe" });
    const result = await withAuthorizedUserTransaction(
      provider({
        state: "authenticated",
        provider: "clerk",
        providerSubject: "user_synthetic0001",
      }),
      operation,
      db.pool,
    );

    expect(result).toEqual({ state: "authorized", value: { profile: "client-safe" } });
    expect(operation).toHaveBeenCalledWith(db.client, "10000000-0000-4000-8000-000000000001");
    expect(JSON.stringify(result)).not.toContain("user_synthetic");
    expect(db.query).toHaveBeenCalledWith("COMMIT");
    expect(db.release).toHaveBeenCalledOnce();
  });
});
