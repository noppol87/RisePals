import type { ReactNode } from "react";
import { LanguageSwitcher } from "@/components/language-switcher";
import { PageContainer } from "@/components/primitives/page-container";
import { Stack } from "@/components/primitives/stack";
import { TextLink } from "@/components/primitives/text-link";
import { localePath, type Locale } from "@/lib/i18n/config";
import type { ShellCatalog } from "@/lib/i18n/catalogs";

type AppShellProps = Readonly<{
  children: ReactNode;
  locale: Locale;
  messages: ShellCatalog;
}>;

export function AppShell({ children, locale, messages }: AppShellProps) {
  const homePath = localePath(locale);

  return (
    <>
      <a className="skip-link" href="#main-content">
        {messages.skipToContent}
      </a>
      <header className="site-header">
        <PageContainer className="shell-header">
          <TextLink className="wordmark" href={homePath}>
            {messages.brandName}
          </TextLink>
          <nav className="primary-nav" aria-label={messages.navigationLabel}>
            <ul className="primary-nav__list">
              <li>
                <TextLink href={homePath} aria-current="page">
                  {messages.homeLabel}
                </TextLink>
              </li>
            </ul>
          </nav>
          <LanguageSwitcher
            currentLocale={locale}
            label={messages.languageSwitcherLabel}
            currentLanguageLabel={messages.currentLanguageLabel}
            languageNames={messages.languageNames}
          />
        </PageContainer>
      </header>
      <main id="main-content" className="main-region" tabIndex={-1}>
        <PageContainer>
          <Stack>{children}</Stack>
        </PageContainer>
      </main>
    </>
  );
}
