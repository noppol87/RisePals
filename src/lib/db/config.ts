export type ApplicationDatabaseEnvironment = Readonly<{
  applicationUrl: string;
}>;

export type DatabaseEnvironment = ApplicationDatabaseEnvironment &
  Readonly<{
    migrationUrl: string;
  }>;

type EnvironmentRecord = Readonly<Record<string, string | undefined>>;

const DATABASE_URL_REMEDIATION =
  "DATABASE_URL and DATABASE_MIGRATION_URL must be distinct PostgreSQL URLs with separate credentials, an explicit database, and an approved sslmode.";
const TRUSTED_USER_ID_REMEDIATION = "The trusted application user ID must be a non-nil UUID.";
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const NIL_UUID = "00000000-0000-0000-0000-000000000000";
const LOOPBACK_HOSTS = new Set(["127.0.0.1", "::1", "localhost"]);
const ALLOWED_SSL_MODES = new Set(["disable", "require", "verify-full"]);

type ParsedDatabaseUrl = Readonly<{
  decodedUsername: string;
  url: URL;
}>;

function decodeUrlComponent(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    throw new Error(DATABASE_URL_REMEDIATION);
  }
}

function parseDatabaseUrl(
  name: "DATABASE_URL" | "DATABASE_MIGRATION_URL",
  raw: string,
): ParsedDatabaseUrl {
  let url: URL;

  try {
    url = new URL(raw);
  } catch {
    throw new Error(DATABASE_URL_REMEDIATION);
  }

  const databaseSegments = url.pathname.split("/").filter(Boolean);
  const decodedUsername = decodeUrlComponent(url.username);
  const decodedPassword = decodeUrlComponent(url.password);
  databaseSegments.forEach(decodeUrlComponent);
  const queryKeys = [...url.searchParams.keys()];
  const sslMode = url.searchParams.get("sslmode");
  const isLoopback = LOOPBACK_HOSTS.has(url.hostname.toLowerCase());
  const hasSafeProtocol = url.protocol === "postgresql:" || url.protocol === "postgres:";
  const hasCredentials = decodedUsername.length > 0 && decodedPassword.length > 0;
  const hasOnlySslMode = queryKeys.length === 1 && queryKeys[0] === "sslmode";
  const hasAllowedSslMode = sslMode !== null && ALLOWED_SSL_MODES.has(sslMode);
  const hasSafeTransport = isLoopback ? sslMode === "disable" : sslMode !== "disable";

  if (
    !hasSafeProtocol ||
    !hasCredentials ||
    url.hostname.length === 0 ||
    databaseSegments.length !== 1 ||
    url.hash !== "" ||
    !hasOnlySslMode ||
    !hasAllowedSslMode ||
    !hasSafeTransport
  ) {
    throw new Error(DATABASE_URL_REMEDIATION);
  }

  if (name === "DATABASE_URL" && /(?:owner|migrat|admin|postgres)/i.test(decodedUsername)) {
    throw new Error(DATABASE_URL_REMEDIATION);
  }

  return { decodedUsername, url };
}

export function parseApplicationDatabaseEnvironment(
  environment: EnvironmentRecord,
): ApplicationDatabaseEnvironment {
  const rawApplicationUrl = environment.DATABASE_URL?.trim();

  if (!rawApplicationUrl) {
    throw new Error(DATABASE_URL_REMEDIATION);
  }

  const application = parseDatabaseUrl("DATABASE_URL", rawApplicationUrl);

  return { applicationUrl: application.url.href };
}

export function parseDatabaseEnvironment(environment: EnvironmentRecord): DatabaseEnvironment {
  const rawMigrationUrl = environment.DATABASE_MIGRATION_URL?.trim();

  if (!rawMigrationUrl) {
    throw new Error(DATABASE_URL_REMEDIATION);
  }

  const { applicationUrl } = parseApplicationDatabaseEnvironment(environment);
  const application = parseDatabaseUrl("DATABASE_URL", applicationUrl);
  const migration = parseDatabaseUrl("DATABASE_MIGRATION_URL", rawMigrationUrl);

  if (
    application.url.href === migration.url.href ||
    application.decodedUsername === migration.decodedUsername
  ) {
    throw new Error(DATABASE_URL_REMEDIATION);
  }

  return {
    applicationUrl: application.url.href,
    migrationUrl: migration.url.href,
  };
}

export function parseTrustedUserId(value: string): string {
  const candidate = value.trim().toLowerCase();

  if (!UUID_PATTERN.test(candidate) || candidate === NIL_UUID) {
    throw new Error(TRUSTED_USER_ID_REMEDIATION);
  }

  return candidate;
}

export const databaseConfigurationMessages = {
  databaseUrl: DATABASE_URL_REMEDIATION,
  trustedUserId: TRUSTED_USER_ID_REMEDIATION,
} as const;
