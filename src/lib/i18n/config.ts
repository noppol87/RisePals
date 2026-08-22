export const locales = ["th", "en"] as const;

export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = "th";

export const intlLocales = {
  th: "th-TH",
  en: "en",
} as const satisfies Record<Locale, string>;

export function isLocale(value: string): value is Locale {
  return locales.some((locale) => locale === value);
}

export function localePath(locale: Locale): `/${Locale}` {
  return `/${locale}`;
}

export function assessmentPath(locale: Locale): `/${Locale}/assessment` {
  return `/${locale}/assessment`;
}

export function persistedAssessmentPath(locale: Locale): `/${Locale}/assessment/attempt` {
  return `/${locale}/assessment/attempt`;
}

export function persistedAssessmentResultPath(locale: Locale): `/${Locale}/assessment/result` {
  return `/${locale}/assessment/result`;
}

export function assessmentExampleResultPath(
  locale: Locale,
): `/${Locale}/assessment/example-result` {
  return `/${locale}/assessment/example-result`;
}

export function sourceVerificationLessonPath(
  locale: Locale,
): `/${Locale}/lessons/source-verification-practice` {
  return `/${locale}/lessons/source-verification-practice`;
}

export function learningPath(locale: Locale): `/${Locale}/learning` {
  return `/${locale}/learning`;
}

export function persistedLessonAttemptPath(
  locale: Locale,
): `/${Locale}/lessons/source-verification-practice/attempt` {
  return `/${locale}/lessons/source-verification-practice/attempt`;
}

export function profilePath(locale: Locale): `/${Locale}/profile` {
  return `/${locale}/profile`;
}

export function onboardingPath(locale: Locale): `/${Locale}/onboarding` {
  return `/${locale}/onboarding`;
}

export function signInPath(locale: Locale): `/${Locale}/sign-in` {
  return `/${locale}/sign-in`;
}

export function signUpPath(locale: Locale): `/${Locale}/sign-up` {
  return `/${locale}/sign-up`;
}
