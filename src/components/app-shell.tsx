import type { ReactNode } from "react";
import { PageContainer } from "@/components/primitives/page-container";
import { ShellNavigation } from "@/components/shell-navigation";
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
          <ShellNavigation currentLocale={locale} messages={messages} />
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
