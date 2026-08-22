export const CONTENT_SOURCE_SCHEMA_VERSION: string;
export const PUBLICATION_MANIFEST_SCHEMA_VERSION: string;
export const PUBLISHED_REGISTRY_SCHEMA_VERSION: string;
export const PUBLISHED_LESSON_IDENTITY: string;

export type CompiledContent = Readonly<{
  aggregateDigest: string;
  lessonCount: number;
  manifest: Readonly<Record<string, unknown>>;
  manifestBytes: string;
  registry: Readonly<Record<string, unknown>>;
  registryBytes: string;
}>;

export function compileContent(
  options?: Readonly<{ contentRoot?: string }>,
): Promise<CompiledContent>;
export function validatePublishedContent(
  options?: Readonly<{ contentRoot?: string }>,
): Promise<CompiledContent>;
export function publishContent(
  options?: Readonly<{ contentRoot?: string }>,
): Promise<CompiledContent>;
export function parseTrustedMdx(
  source: string,
  label?: string,
): readonly Readonly<Record<string, unknown>>[];
