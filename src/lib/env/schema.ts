export type ServerEnvironment = Readonly<{
  appBaseUrl: URL | null;
}>;

type EnvironmentRecord = Readonly<Record<string, string | undefined>>;

const APP_BASE_URL_REMEDIATION =
  "APP_BASE_URL must be an http:// or https:// origin with no credentials, path, query, or fragment.";

export function parseServerEnvironment(environment: EnvironmentRecord): ServerEnvironment {
  const rawAppBaseUrl = environment.APP_BASE_URL?.trim();

  if (!rawAppBaseUrl) {
    return { appBaseUrl: null };
  }

  let appBaseUrl: URL;

  try {
    appBaseUrl = new URL(rawAppBaseUrl);
  } catch {
    throw new Error(APP_BASE_URL_REMEDIATION);
  }

  const hasAllowedProtocol = appBaseUrl.protocol === "http:" || appBaseUrl.protocol === "https:";
  const hasCredentials = appBaseUrl.username !== "" || appBaseUrl.password !== "";
  const hasNonRootPath = appBaseUrl.pathname !== "/";
  const hasQuery = rawAppBaseUrl.includes("?");
  const hasFragment = rawAppBaseUrl.includes("#");

  if (!hasAllowedProtocol || hasCredentials || hasNonRootPath || hasQuery || hasFragment) {
    throw new Error(APP_BASE_URL_REMEDIATION);
  }

  return { appBaseUrl: new URL(appBaseUrl.origin) };
}
