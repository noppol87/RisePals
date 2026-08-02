export type ServerEnvironment = Readonly<{
  appBaseUrl: URL | null;
}>;

type EnvironmentRecord = Readonly<Record<string, string | undefined>>;

export function parseServerEnvironment(environment: EnvironmentRecord): ServerEnvironment {
  const rawAppBaseUrl = environment.APP_BASE_URL?.trim();

  if (!rawAppBaseUrl) {
    return { appBaseUrl: null };
  }

  try {
    return { appBaseUrl: new URL(rawAppBaseUrl) };
  } catch {
    throw new Error("APP_BASE_URL must be an absolute URL when provided.");
  }
}
