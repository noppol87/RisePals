import { localePath, type Locale } from "@/lib/i18n/config";

const SAFE_PATH_PATTERN = /^\/(th|en)(?:\/[a-z0-9-]+)*\/?$/;

export function safeLocaleReturnPath(value: unknown, fallbackLocale: Locale): string {
  if (typeof value !== "string" || value.length > 160 || !SAFE_PATH_PATTERN.test(value)) {
    return localePath(fallbackLocale);
  }

  return value.split("/")[1] === fallbackLocale ? value : localePath(fallbackLocale);
}
