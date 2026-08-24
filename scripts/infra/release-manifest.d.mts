export const releaseManifestSchema: string;

export type ReleaseManifestInput = Readonly<{
  root: string;
  sourceCommit: string;
  releaseId: string;
  nodeVersion: string;
  npmVersion: string;
  nextVersion: string;
  configurationTemplateVersion: string;
}>;

export type ReleaseManifest = Readonly<{
  schemaVersion: string;
  sourceCommit: string;
  releaseId: string;
  runtime: Readonly<{ node: string; npm: string; next: string }>;
  configurationTemplateVersion: string;
  inventoryDigest: string;
  files: readonly Readonly<{ path: string; length: number; sha256: string }>[];
}>;

export function createReleaseManifest(input: ReleaseManifestInput): Promise<ReleaseManifest>;
export function writeReleaseManifest(input: ReleaseManifestInput): Promise<ReleaseManifest>;
