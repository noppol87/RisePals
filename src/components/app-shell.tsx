import type { ReactNode } from "react";
import { PageContainer } from "@/components/primitives/page-container";
import { ShellNavigation } from "@/components/shell-navigation";
import { Stack } from "@/components/primitives/stack";
import { TextLink } from "@/components/primitives/text-link";
import { BrandMark, ArrowIcon } from "@/components/brand-mark";
import { ExperienceMotion } from "@/components/experience-motion";
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
      <ExperienceMotion />
      <a className="skip-link" href="#main-content">
        {messages.skipToContent}
      </a>
      <header className="site-header">
        <PageContainer className="shell-header">
          <TextLink className="wordmark" href={homePath} aria-label={messages.brandName}>
            <BrandMark />
            <span aria-hidden="true">
              rise<span className="wordmark__light">pals</span>
              <span className="wordmark__period">.</span>
            </span>
          </TextLink>
          <ShellNavigation currentLocale={locale} messages={messages} />
        </PageContainer>
      </header>
      <main id="main-content" className="main-region" tabIndex={-1}>
        <PageContainer>
          <Stack>{children}</Stack>
        </PageContainer>
      </main>
      <footer className="site-footer">
        <PageContainer>
          <div className="footer-main">
            <div>
              <div className="footer-wordmark">
                <BrandMark />
                <span>risepals.</span>
              </div>
              <p>{locale === "th" ? "ค่อย ๆ เก่งขึ้นไปด้วยกัน" : "Grow at your own pace."}</p>
            </div>
            <a href={`${homePath}#skill-framework`} className="footer-explore">
              {locale === "th" ? "รู้จักทักษะ 8+2" : "Explore the 8+2 skills"}
              <ArrowIcon diagonal />
            </a>
          </div>
          <div className="footer-bottom">
            <span>© 2026 Rise Pals</span>
            <span>
              {locale === "th" ? "เริ่มเล็ก ๆ ไปได้อีกไกล" : "Small steps. Keep growing."}
            </span>
            <span>{locale === "th" ? "ต้นแบบเพื่อการเรียนรู้" : "A learning prototype"}</span>
          </div>
        </PageContainer>
      </footer>
    </>
  );
}
