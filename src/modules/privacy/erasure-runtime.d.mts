export interface AlphaErasureQueryClient {
  query(
    sql: string,
    values: readonly unknown[],
  ): Promise<{ rows: { result?: Record<string, unknown> }[] }>;
}

export interface SyntheticIdentityErasureAdapter {
  revokeAndDeleteSyntheticIdentity(input: {
    ownerId: string;
    requestId: string;
  }): Promise<{ state: "deleted"; replayed: boolean }>;
}

export const alphaErasureContractVersion: "rise-pals-alpha-erasure-v1@1.0.0";
export function runAlphaOwnerErasure(input: {
  client: AlphaErasureQueryClient;
  ownerId: string;
  requestId: string;
  providerAdapter: SyntheticIdentityErasureAdapter;
}): Promise<
  Readonly<{
    contractVersion: "rise-pals-alpha-erasure-v1@1.0.0";
    state: "deleted";
    replayed: boolean;
    deletedRows: number;
    provider: "already-complete" | "replayed" | "deleted";
  }>
>;
export function createDeterministicSyntheticIdentityErasureAdapter(): Readonly<
  SyntheticIdentityErasureAdapter & { getMutationCount(): number }
>;
