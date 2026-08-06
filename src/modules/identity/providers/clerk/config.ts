export type ClerkDevelopmentConfiguration =
  | Readonly<{ state: "disabled" }>
  | Readonly<{
      state: "enabled";
      publishableKey: string;
      secretKey: string;
    }>;

type EnvironmentRecord = Readonly<Record<string, string | undefined>>;

const CLERK_CONFIGURATION_ERROR =
  "Clerk alpha authentication requires one complete Development key pair; production keys are prohibited.";

export function parseClerkDevelopmentConfiguration(
  environment: EnvironmentRecord,
): ClerkDevelopmentConfiguration {
  const publishableKey = environment.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY?.trim();
  const secretKey = environment.CLERK_SECRET_KEY?.trim();

  if (!publishableKey && !secretKey) {
    return { state: "disabled" };
  }

  if (
    !publishableKey ||
    !secretKey ||
    !publishableKey.startsWith("pk_test_") ||
    !secretKey.startsWith("sk_test_")
  ) {
    throw new Error(CLERK_CONFIGURATION_ERROR);
  }

  return { state: "enabled", publishableKey, secretKey };
}
