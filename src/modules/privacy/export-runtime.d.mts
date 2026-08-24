export interface AlphaExportQueryClient {
  query(sql: string, values: readonly unknown[]): Promise<{ rows: Record<string, unknown>[] }>;
}

export const alphaExportContractVersion: "rise-pals-alpha-export-v1@1.0.0";
export const alphaExportMaximumRowsPerSection: 500;
export const alphaExportQueryPlan: readonly Readonly<{
  key: string;
  one: boolean;
  sql: string;
}>[];

export function loadAlphaOwnerExportSource(
  client: AlphaExportQueryClient,
  ownerId: string,
): Promise<Record<string, Record<string, unknown>[]>>;
export function createCanonicalAlphaExport(
  source: Record<string, Record<string, unknown>[]>,
): Record<string, unknown>;
export function serializeCanonicalAlphaExport(exportDocument: Record<string, unknown>): string;
export function createAlphaOwnerExport(
  client: AlphaExportQueryClient,
  ownerId: string,
): Promise<{
  contractVersion: "rise-pals-alpha-export-v1@1.0.0";
  document: Record<string, unknown>;
  bytes: string;
  sha256: string;
}>;
