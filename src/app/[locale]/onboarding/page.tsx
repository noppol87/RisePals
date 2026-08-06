import { notFound, redirect } from "next/navigation";
import { ProfileConsent } from "@/components/profile-consent";
import { isLocale } from "@/lib/i18n/config";
import { loadProfilePageState } from "@/modules/profile/dal";

export const dynamic = "force-dynamic";

export default async function OnboardingPage({
  params,
}: Readonly<{ params: Promise<{ locale: string }> }>) {
  const { locale: localeSegment } = await params;
  if (!isLocale(localeSegment)) {
    notFound();
  }

  const state = await loadProfilePageState();
  if (
    state.state === "denied" &&
    (state.reason === "absent" || state.reason === "invalid" || state.reason === "expired")
  ) {
    redirect(`/${localeSegment}/sign-in?returnTo=/${localeSegment}/onboarding`);
  }

  return <ProfileConsent locale={localeSegment} mode="onboarding" state={state} />;
}
