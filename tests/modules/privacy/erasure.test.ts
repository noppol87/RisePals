import { describe, expect, it, vi } from "vitest";

import {
  alphaErasureContractVersion,
  createDeterministicSyntheticIdentityErasureAdapter,
  runAlphaOwnerErasure,
} from "@/modules/privacy/erasure-runtime.mjs";

const ownerId = "40000000-0000-4000-8000-000000000001";
const requestId = "40000000-0000-4000-8000-000000000002";

describe("synthetic-alpha owner erasure orchestration", () => {
  it("runs pending, fake-provider and database completion in order", async () => {
    const calls: string[] = [];
    const client = {
      async query(sql: string) {
        calls.push(sql);
        return {
          rows: [
            {
              result: sql.includes("request_owner_erasure")
                ? {
                    contractVersion: alphaErasureContractVersion,
                    state: "deletion_pending",
                    replayed: false,
                  }
                : {
                    contractVersion: alphaErasureContractVersion,
                    state: "deleted",
                    replayed: false,
                    deletedRows: 23,
                  },
            },
          ],
        };
      },
    };
    const providerAdapter = createDeterministicSyntheticIdentityErasureAdapter();

    const result = await runAlphaOwnerErasure({ client, ownerId, requestId, providerAdapter });

    expect(result).toEqual({
      contractVersion: alphaErasureContractVersion,
      state: "deleted",
      replayed: false,
      deletedRows: 23,
      provider: "deleted",
    });
    expect(calls[0]).toContain("request_owner_erasure");
    expect(calls[1]).toContain("erase_owner_private_data");
    expect(providerAdapter.getMutationCount()).toBe(1);
  });

  it("makes an already-complete exact replay mutation-free", async () => {
    const providerAdapter = {
      revokeAndDeleteSyntheticIdentity: vi.fn(),
    };
    const client = {
      async query() {
        return {
          rows: [
            {
              result: {
                contractVersion: alphaErasureContractVersion,
                state: "deleted",
                replayed: true,
              },
            },
          ],
        };
      },
    };

    await expect(
      runAlphaOwnerErasure({ client, ownerId, requestId, providerAdapter }),
    ).resolves.toMatchObject({ state: "deleted", replayed: true, deletedRows: 0 });
    expect(providerAdapter.revokeAndDeleteSyntheticIdentity).not.toHaveBeenCalled();
  });

  it("keeps the fake provider idempotent and rejects malformed inputs", async () => {
    const adapter = createDeterministicSyntheticIdentityErasureAdapter();
    await adapter.revokeAndDeleteSyntheticIdentity({ ownerId, requestId });
    await expect(adapter.revokeAndDeleteSyntheticIdentity({ ownerId, requestId })).resolves.toEqual(
      { state: "deleted", replayed: true },
    );
    expect(adapter.getMutationCount()).toBe(1);

    await expect(
      runAlphaOwnerErasure({
        client: { query: vi.fn() },
        ownerId: "not-a-uuid",
        requestId,
        providerAdapter: adapter,
      }),
    ).rejects.toThrow("canonical opaque UUID");
  });

  it("propagates database conflicts without calling the provider", async () => {
    const providerAdapter = { revokeAndDeleteSyntheticIdentity: vi.fn() };
    const conflict = Object.assign(new Error("controlled conflict"), { code: "23505" });
    const client = { query: vi.fn().mockRejectedValue(conflict) };

    await expect(
      runAlphaOwnerErasure({ client, ownerId, requestId, providerAdapter }),
    ).rejects.toMatchObject({ code: "23505" });
    expect(providerAdapter.revokeAndDeleteSyntheticIdentity).not.toHaveBeenCalled();
  });
});
