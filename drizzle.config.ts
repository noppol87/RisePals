import { defineConfig } from "drizzle-kit";
import { parseDatabaseEnvironment } from "./src/lib/db/config";

const hasDatabaseConfiguration = Boolean(
  process.env.DATABASE_URL || process.env.DATABASE_MIGRATION_URL,
);
const databaseEnvironment = hasDatabaseConfiguration ? parseDatabaseEnvironment(process.env) : null;

export default defineConfig({
  dialect: "postgresql",
  schema: "./src/lib/db/schema.ts",
  out: "./drizzle",
  strict: true,
  verbose: true,
  ...(databaseEnvironment ? { dbCredentials: { url: databaseEnvironment.migrationUrl } } : {}),
});
