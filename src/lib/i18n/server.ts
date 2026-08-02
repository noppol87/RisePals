import "server-only";
import { catalogs, type AppCatalog } from "@/lib/i18n/catalogs";
import { intlLocales, isLocale, type Locale } from "@/lib/i18n/config";

export type ResolvedCatalog = Readonly<{
  locale: Locale;
  intlLocale: (typeof intlLocales)[Locale];
  catalog: AppCatalog;
}>;

export function getCatalogForSegment(segment: string): ResolvedCatalog | null {
  if (!isLocale(segment)) {
    return null;
  }

  return {
    locale: segment,
    intlLocale: intlLocales[segment],
    catalog: catalogs[segment],
  };
}
