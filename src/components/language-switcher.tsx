import { TextLink } from "@/components/primitives/text-link";
import { localePath, locales, type Locale } from "@/lib/i18n/config";

type LanguageSwitcherProps = Readonly<{
  currentLocale: Locale;
  label: string;
  currentLanguageLabel: string;
  languageNames: Readonly<Record<Locale, string>>;
  routeSuffix:
    | ""
    | "/assessment"
    | "/assessment/example-result"
    | "/lessons/source-verification-practice"
    | "/profile"
    | "/onboarding"
    | "/sign-in";
}>;

export function LanguageSwitcher({
  currentLocale,
  label,
  currentLanguageLabel,
  languageNames,
  routeSuffix,
}: LanguageSwitcherProps) {
  return (
    <nav className="language-switcher" aria-label={label}>
      <p className="language-switcher__current">
        <span>{currentLanguageLabel}: </span>
        <span lang={currentLocale}>{languageNames[currentLocale]}</span>
      </p>
      <ul className="language-switcher__list">
        {locales.map((locale) => (
          <li key={locale}>
            <TextLink
              className="language-switcher__link"
              href={`${localePath(locale)}${routeSuffix}`}
              hrefLang={locale}
              lang={locale}
              aria-current={locale === currentLocale ? "page" : undefined}
            >
              {languageNames[locale]}
            </TextLink>
          </li>
        ))}
      </ul>
    </nav>
  );
}
