export const alphaErasureContractVersion = "rise-pals-alpha-erasure-v1@1.0.0";

const canonicalUuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function requireOpaqueUuid(value, label) {
  if (typeof value !== "string" || !canonicalUuidPattern.test(value)) {
    throw new Error(`${label} must be a canonical opaque UUID.`);
  }
}

function validateDatabaseResult(value, expectedStates) {
  if (
    !value ||
    value.contractVersion !== alphaErasureContractVersion ||
    !expectedStates.includes(value.state) ||
    typeof value.replayed !== "boolean"
  ) {
    throw new Error("Privacy maintenance returned an invalid erasure contract result.");
  }
  return value;
}

export async function runAlphaOwnerErasure({ client, ownerId, requestId, providerAdapter }) {
  requireOpaqueUuid(ownerId, "Owner ID");
  requireOpaqueUuid(requestId, "Deletion request ID");
  if (!client || typeof client.query !== "function") {
    throw new Error("A privacy-operator database client is required.");
  }
  if (!providerAdapter || typeof providerAdapter.revokeAndDeleteSyntheticIdentity !== "function") {
    throw new Error("A bounded identity-provider erasure adapter is required.");
  }

  const pendingResult = await client.query(
    `SELECT rise_pals_private.request_owner_erasure($1::uuid, $2::uuid) AS result`,
    [ownerId, requestId],
  );
  const pending = validateDatabaseResult(pendingResult.rows[0]?.result, [
    "deletion_pending",
    "deleted",
  ]);

  if (pending.state === "deleted") {
    return Object.freeze({
      contractVersion: alphaErasureContractVersion,
      state: "deleted",
      replayed: true,
      deletedRows: 0,
      provider: "already-complete",
    });
  }

  const providerResult = await providerAdapter.revokeAndDeleteSyntheticIdentity({
    ownerId,
    requestId,
  });
  if (!providerResult || providerResult.state !== "deleted") {
    throw new Error("Synthetic identity-provider erasure did not complete.");
  }

  const eraseResult = await client.query(
    `SELECT rise_pals_private.erase_owner_private_data($1::uuid, $2::uuid) AS result`,
    [ownerId, requestId],
  );
  const erased = validateDatabaseResult(eraseResult.rows[0]?.result, ["deleted"]);
  if (!Number.isInteger(erased.deletedRows) || erased.deletedRows < 0) {
    throw new Error("Privacy maintenance returned an invalid deleted-row count.");
  }

  return Object.freeze({
    contractVersion: alphaErasureContractVersion,
    state: "deleted",
    replayed: pending.replayed && erased.replayed,
    deletedRows: erased.deletedRows,
    provider: providerResult.replayed ? "replayed" : "deleted",
  });
}

export function createDeterministicSyntheticIdentityErasureAdapter() {
  const completedRequests = new Set();
  let mutationCount = 0;

  return Object.freeze({
    async revokeAndDeleteSyntheticIdentity({ ownerId, requestId }) {
      requireOpaqueUuid(ownerId, "Owner ID");
      requireOpaqueUuid(requestId, "Deletion request ID");
      const key = `${ownerId}:${requestId}`;
      const replayed = completedRequests.has(key);
      if (!replayed) {
        completedRequests.add(key);
        mutationCount += 1;
      }
      return Object.freeze({ state: "deleted", replayed });
    },
    getMutationCount() {
      return mutationCount;
    },
  });
}
