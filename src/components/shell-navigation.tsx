"use client";

import { usePathname } from "next/navigation";
import { LanguageSwitcher } from "@/components/language-switcher";
import { TextLink } from "@/components/primitives/text-link";
import type { ShellCatalog } from "@/lib/i18n/catalogs";
import { assessmentPath, localePath, type Locale } from "@/lib/i18n/config";

type ShellNavigationProps = Readonly<{
  currentLocale: Locale;
  messages: ShellCatalog;
}>;

export function ShellNavigation({ currentLocale, messages }: ShellNavigationProps) {
  const pathname = usePathname();
  const homePath = localePath(currentLocale);
  const onAssessmentRoute = pathname === assessmentPath(currentLocale);

  return (
    <>
      <nav className="primary-nav" aria-label={messages.navigationLabel}>
        <ul className="primary-nav__list">
          <li>
            <TextLink href={homePath} aria-current={pathname === homePath ? "page" : undefined}>
              {messages.homeLabel}
            </TextLink>
          </li>
        </ul>
      </nav>
      <LanguageSwitcher
        currentLocale={currentLocale}
        label={messages.languageSwitcherLabel}
        currentLanguageLabel={messages.currentLanguageLabel}
        languageNames={messages.languageNames}
        routeSuffix={onAssessmentRoute ? "/assessment" : ""}
      />
    </>
  );
}
