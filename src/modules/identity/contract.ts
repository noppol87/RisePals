export const identityProviders = ["clerk"] as const;

export type IdentityProviderName = (typeof identityProviders)[number];

export type ProviderSession =
  | Readonly<{
      state: "authenticated";
      provider: IdentityProviderName;
      providerSubject: string;
    }>
  | Readonly<{
      state: "absent" | "invalid" | "expired" | "unavailable";
    }>;

export interface IdentityProvider {
  readSession(): Promise<ProviderSession>;
}

const CLERK_SUBJECT_PATTERN = /^user_[A-Za-z0-9]{8,128}$/;

export function isValidatedClerkSession(
  session: ProviderSession,
): session is Extract<ProviderSession, { state: "authenticated" }> {
  return (
    session.state === "authenticated" &&
    session.provider === "clerk" &&
    CLERK_SUBJECT_PATTERN.test(session.providerSubject)
  );
}
