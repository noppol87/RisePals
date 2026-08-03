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
