"use client";

import { usePathname } from "next/navigation";
import { LanguageSwitcher } from "@/components/language-switcher";
import { TextLink } from "@/components/primitives/text-link";
import type { ShellCatalog } from "@/lib/i18n/catalogs";
import {
  assessmentExampleResultPath,
  assessmentPath,
  localePath,
  onboardingPath,
  profilePath,
  persistedAssessmentPath,
  persistedAssessmentResultPath,
  signInPath,
  signUpPath,
  sourceVerificationLessonPath,
  type Locale,
} from "@/lib/i18n/config";

type ShellNavigationProps = Readonly<{
  currentLocale: Locale;
  messages: ShellCatalog;
}>;

export function ShellNavigation({ currentLocale, messages }: ShellNavigationProps) {
  const pathname = usePathname();
  const homePath = localePath(currentLocale);
  const onAssessmentRoute = pathname === assessmentPath(currentLocale);
  const onPersistedAssessmentRoute = pathname === persistedAssessmentPath(currentLocale);
  const onPersistedAssessmentResultRoute =
    pathname === persistedAssessmentResultPath(currentLocale);
  const onExampleResultRoute = pathname === assessmentExampleResultPath(currentLocale);
  const onSourceVerificationLessonRoute = pathname === sourceVerificationLessonPath(currentLocale);
  const onProfileRoute = pathname === profilePath(currentLocale);
  const onOnboardingRoute = pathname === onboardingPath(currentLocale);
  const onSignInRoute = pathname.startsWith(signInPath(currentLocale));
  const onSignUpRoute = pathname.startsWith(signUpPath(currentLocale));

  return (
    <>
      <nav className="primary-nav" aria-label={messages.navigationLabel}>
        <ul className="primary-nav__list">
          <li>
            <TextLink href={homePath} aria-current={pathname === homePath ? "page" : undefined}>
              {messages.homeLabel}
            </TextLink>
          </li>
          <li>
            <TextLink
              href={profilePath(currentLocale)}
              prefetch={false}
              aria-current={onProfileRoute ? "page" : undefined}
            >
              {messages.profileLabel}
            </TextLink>
          </li>
        </ul>
      </nav>
      <LanguageSwitcher
        currentLocale={currentLocale}
        label={messages.languageSwitcherLabel}
        currentLanguageLabel={messages.currentLanguageLabel}
        languageNames={messages.languageNames}
        routeSuffix={
          onProfileRoute
            ? "/profile"
            : onOnboardingRoute
              ? "/onboarding"
              : onSignInRoute
                ? "/sign-in"
                : onSignUpRoute
                  ? "/sign-up"
                  : onSourceVerificationLessonRoute
                    ? "/lessons/source-verification-practice"
                    : onExampleResultRoute
                      ? "/assessment/example-result"
                      : onPersistedAssessmentResultRoute
                        ? "/assessment/result"
                        : onPersistedAssessmentRoute
                          ? "/assessment/attempt"
                          : onAssessmentRoute
                            ? "/assessment"
                            : ""
        }
      />
    </>
  );
}
