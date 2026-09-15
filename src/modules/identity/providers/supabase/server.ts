import "server-only";
import type { IdentityProvider, ProviderSession } from "../../contract";
import { isValidatedSupabaseSession } from "../../contract";
import { createSupabaseServerClient } from "./client";

export class SupabaseIdentityProvider implements IdentityProvider {
  async readSession(): Promise<ProviderSession> {
    try {
      const client = await createSupabaseServerClient();
      if (!client) return { state: "unavailable" };
      const { data, error } = await client.auth.getUser();
      if (error || !data.user) return { state: "absent" };
      if (data.user.is_anonymous || !data.user.email_confirmed_at) return { state: "invalid" };
      const session = {
        state: "authenticated",
        provider: "supabase",
        providerSubject: data.user.id,
      } as const;
      return isValidatedSupabaseSession(session) ? session : { state: "invalid" };
    } catch {
      return { state: "unavailable" };
    }
  }
}
export function createIdentityProvider(): IdentityProvider {
  return new SupabaseIdentityProvider();
}
