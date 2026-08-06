import "server-only";
import { auth } from "@/modules/identity/providers/clerk/server-runtime.mjs";
import type { IdentityProvider, ProviderSession } from "@/modules/identity/contract";
import { isValidatedClerkSession } from "@/modules/identity/contract";
import { parseClerkDevelopmentConfiguration } from "@/modules/identity/providers/clerk/config";

export class ClerkDevelopmentIdentityProvider implements IdentityProvider {
  async readSession(): Promise<ProviderSession> {
    const configuration = parseClerkDevelopmentConfiguration(process.env);

    if (configuration.state === "disabled") {
      return { state: "unavailable" };
    }

    try {
      const session = await auth();
      if (!session.isAuthenticated || !session.userId) {
        return { state: "absent" };
      }

      const authenticated = {
        state: "authenticated",
        provider: "clerk",
        providerSubject: session.userId,
      } as const;

      return isValidatedClerkSession(authenticated) ? authenticated : { state: "invalid" };
    } catch {
      return { state: "invalid" };
    }
  }
}

export function createClerkDevelopmentIdentityProvider(): IdentityProvider {
  return new ClerkDevelopmentIdentityProvider();
}
