import { describe, expect, it } from "vitest";
import {
  databaseConfigurationMessages,
  parseApplicationDatabaseEnvironment,
  parseDatabaseEnvironment,
  parseTrustedUserId,
} from "@/lib/db/config";

const validEnvironment = {
  DATABASE_URL:
    "postgresql://rise_pals_app:synthetic-app-password@127.0.0.1:5432/rise_pals_test?sslmode=disable",
  DATABASE_MIGRATION_URL:
    "postgresql://rise_pals_migrator:synthetic-migration-password@127.0.0.1:5432/rise_pals_test?sslmode=disable",
} as const;

describe("database environment", () => {
  it("parses the application URL without requiring or reading migration credentials", () => {
    const environment = new Proxy(
      { DATABASE_URL: validEnvironment.DATABASE_URL },
      {
        get(target, property, receiver) {
          if (property === "DATABASE_MIGRATION_URL") {
            throw new Error("application configuration read the migration credential");
          }

          return Reflect.get(target, property, receiver);
        },
      },
    );

    expect(parseApplicationDatabaseEnvironment(environment)).toEqual({
      applicationUrl: validEnvironment.DATABASE_URL,
    });
  });

  it("accepts separate loopback application and migration roles", () => {
    expect(parseDatabaseEnvironment(validEnvironment)).toEqual({
      applicationUrl: validEnvironment.DATABASE_URL,
      migrationUrl: validEnvironment.DATABASE_MIGRATION_URL,
    });
  });

  it.each([
    [
      "missing application URL",
      { DATABASE_MIGRATION_URL: validEnvironment.DATABASE_MIGRATION_URL },
    ],
    ["missing migration URL", { DATABASE_URL: validEnvironment.DATABASE_URL }],
    [
      "non-PostgreSQL protocol",
      {
        ...validEnvironment,
        DATABASE_URL: "https://rise_pals_app:password@db.test/rise_pals?sslmode=require",
      },
    ],
    [
      "missing credentials",
      { ...validEnvironment, DATABASE_URL: "postgresql://127.0.0.1/rise_pals?sslmode=disable" },
    ],
    [
      "unsafe remote plaintext",
      {
        ...validEnvironment,
        DATABASE_URL: "postgresql://rise_pals_app:password@db.example/rise_pals?sslmode=disable",
      },
    ],
    [
      "unexpected query option",
      {
        ...validEnvironment,
        DATABASE_URL: `${validEnvironment.DATABASE_URL}&application_name=unsafe`,
      },
    ],
    [
      "privileged application username",
      {
        ...validEnvironment,
        DATABASE_URL: "postgresql://postgres:password@127.0.0.1/rise_pals?sslmode=disable",
      },
    ],
    [
      "percent-encoded postgres application username",
      {
        ...validEnvironment,
        DATABASE_URL: "postgresql://post%67res:password@127.0.0.1/rise_pals?sslmode=disable",
      },
    ],
    [
      "percent-encoded owner application username",
      {
        ...validEnvironment,
        DATABASE_URL: "postgresql://rise_pals_%6Fwner:password@127.0.0.1/rise_pals?sslmode=disable",
      },
    ],
    [
      "percent-encoded admin application username",
      {
        ...validEnvironment,
        DATABASE_URL: "postgresql://rise_pals_%61dmin:password@127.0.0.1/rise_pals?sslmode=disable",
      },
    ],
    [
      "percent-encoded migration-like application username",
      {
        ...validEnvironment,
        DATABASE_URL:
          "postgresql://rise_pals_mig%72ator:password@127.0.0.1/rise_pals?sslmode=disable",
      },
    ],
    [
      "same application and migration role",
      { ...validEnvironment, DATABASE_MIGRATION_URL: validEnvironment.DATABASE_URL },
    ],
    [
      "differently encoded forms of the same role",
      {
        ...validEnvironment,
        DATABASE_MIGRATION_URL:
          "postgresql://rise_pals_%61pp:other-password@127.0.0.1:5432/rise_pals_test?sslmode=disable",
      },
    ],
    [
      "malformed percent encoding",
      {
        ...validEnvironment,
        DATABASE_URL: "postgresql://rise_pals_%ZZ:password@127.0.0.1/rise_pals?sslmode=disable",
      },
    ],
  ])("rejects %s without reflecting the secret value", (_description, environment) => {
    expect(() => parseDatabaseEnvironment(environment)).toThrow(
      databaseConfigurationMessages.databaseUrl,
    );
    expect(databaseConfigurationMessages.databaseUrl).not.toContain("password");
  });

  it("accepts encrypted remote PostgreSQL URLs", () => {
    const parsed = parseDatabaseEnvironment({
      DATABASE_URL:
        "postgresql://rise_pals_app:synthetic-app-password@db.example/rise_pals?sslmode=verify-full",
      DATABASE_MIGRATION_URL:
        "postgresql://rise_pals_migrator:synthetic-migration-password@db.example/rise_pals?sslmode=verify-full",
    });
    expect(parsed.applicationUrl).toContain("sslmode=verify-full");
  });
});

describe("trusted database user context", () => {
  it("normalizes a valid non-nil UUID", () => {
    expect(parseTrustedUserId(" AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA ")).toBe(
      "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    );
  });

  it.each(["", "not-a-uuid", "00000000-0000-0000-0000-000000000000"])(
    "rejects unsafe trusted user ID %j",
    (value) => {
      expect(() => parseTrustedUserId(value)).toThrow(databaseConfigurationMessages.trustedUserId);
    },
  );
});
