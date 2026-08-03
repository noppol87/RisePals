import "server-only";
import { Pool } from "pg";
import { parseDatabaseEnvironment } from "@/lib/db/config";

export function createApplicationPool(environment: NodeJS.ProcessEnv = process.env): Pool {
  const { applicationUrl } = parseDatabaseEnvironment(environment);

  return new Pool({
    connectionString: applicationUrl,
    max: 10,
    statement_timeout: 10_000,
    query_timeout: 12_000,
    application_name: "rise-pals-app",
  });
}
