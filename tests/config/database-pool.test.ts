import { beforeEach, describe, expect, it, vi } from "vitest";

const poolConstructor = vi.hoisted(() =>
  vi.fn(function MockPool(options: unknown) {
    return { options };
  }),
);

vi.mock("server-only", () => ({}));
vi.mock("pg", () => ({ Pool: poolConstructor }));

import { createApplicationPool } from "@/lib/db/server";

const applicationUrl =
  "postgresql://rise_pals_app:synthetic-app-password@127.0.0.1:5432/rise_pals_test?sslmode=disable";

describe("application database pool", () => {
  beforeEach(() => {
    poolConstructor.mockClear();
  });

  it("works without a migration credential and never reads one", () => {
    const environment = new Proxy(
      { DATABASE_URL: applicationUrl },
      {
        get(target, property, receiver) {
          if (property === "DATABASE_MIGRATION_URL") {
            throw new Error("application pool read the migration credential");
          }

          return Reflect.get(target, property, receiver);
        },
      },
    ) as unknown as NodeJS.ProcessEnv;

    createApplicationPool(environment);

    expect(poolConstructor).toHaveBeenCalledOnce();
    expect(poolConstructor).toHaveBeenCalledWith({
      application_name: "rise-pals-app",
      connectionString: applicationUrl,
      max: 10,
      query_timeout: 12_000,
      statement_timeout: 10_000,
    });
  });
});
