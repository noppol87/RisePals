import "server-only";
import type { Pool, PoolClient } from "pg";
import { parseTrustedUserId } from "@/lib/db/config";

export async function withUserDatabaseTransaction<T>(
  pool: Pool,
  trustedUserId: string,
  operation: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const userId = parseTrustedUserId(trustedUserId);
  const client = await pool.connect();

  try {
    await client.query("BEGIN");
    await client.query("SELECT set_config('app.current_user_id', $1, true)", [userId]);
    const result = await operation(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}
