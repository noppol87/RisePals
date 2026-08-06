import { isLocale, localePath, type Locale } from "@/lib/i18n/config";

const SAFE_PATH_PATTERN = /^\/(th|en)(?:\/[a-z0-9-]+)*\/?$/;

export function safeLocaleReturnPath(value: unknown, fallbackLocale: Locale): string {
  if (typeof value !== "string" || value.length > 160 || !SAFE_PATH_PATTERN.test(value)) {
    return localePath(fallbackLocale);
  }

  const localeSegment = value.split("/")[1];
  return localeSegment && isLocale(localeSegment) ? value : localePath(fallbackLocale);
}
