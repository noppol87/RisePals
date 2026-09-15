export const identityProviders = ["clerk", "supabase"] as const;

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

const SUPABASE_SUBJECT_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
export function isValidatedSupabaseSession(
  session: ProviderSession,
): session is Extract<ProviderSession, { state: "authenticated" }> {
  return (
    session.state === "authenticated" &&
    session.provider === "supabase" &&
    SUPABASE_SUBJECT_PATTERN.test(session.providerSubject)
  );
}
export function isValidatedProviderSession(
  session: ProviderSession,
): session is Extract<ProviderSession, { state: "authenticated" }> {
  return isValidatedSupabaseSession(session) || isValidatedClerkSession(session);
}
