import { notFound } from "next/navigation";
import { Stack } from "@/components/primitives/stack";
import { isLocale } from "@/lib/i18n/config";
import { ClerkSignUpPanel } from "@/modules/identity/providers/clerk/client-boundary";
import { parseClerkDevelopmentConfiguration } from "@/modules/identity/providers/clerk/config";
import { safeLocaleReturnPath } from "@/modules/identity/redirects";
import { profileCopy } from "@/modules/profile/copy";

export const dynamic = "force-dynamic";

export default async function SignUpPage({
  params,
  searchParams,
}: Readonly<{
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ returnTo?: string }>;
}>) {
  const [{ locale: localeSegment }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(localeSegment)) {
    notFound();
  }

  const copy = profileCopy[localeSegment];
  const configuration = parseClerkDevelopmentConfiguration(process.env);
  const returnPath = safeLocaleReturnPath(query.returnTo, localeSegment);

  return (
    <Stack className="profile-flow">
      <section className="surface-card profile-panel">
        <p className="eyebrow">{copy.eyebrow}</p>
        <h1>{copy.signUpHeading}</h1>
        <p>{copy.signUpIntroduction}</p>
        <p>{copy.syntheticBoundary}</p>
        <p className="boundary-note">{copy.localizationFallback}</p>
      </section>
      {configuration.state === "enabled" ? (
        <section className="auth-provider-panel" aria-label={copy.signUpHeading}>
          <ClerkSignUpPanel locale={localeSegment} returnPath={returnPath} />
        </section>
      ) : (
        <section className="surface-card profile-panel">
          <h2>{copy.unavailableHeading}</h2>
          <p>{copy.unavailableBody}</p>
        </section>
      )}
    </Stack>
  );
}
