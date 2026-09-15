import type { Metadata } from "next";
import { notFound } from "next/navigation";
import type { ReactNode } from "react";
import "@/app/globals.css";
import { AppShell } from "@/components/app-shell";
import "@/lib/env/server";
import { locales } from "@/lib/i18n/config";
import { getCatalogForSegment } from "@/lib/i18n/server";

export const metadata: Metadata = {
  title: "Rise Pals",
  description: "A Thai-first public narrative for building skills and evidence for changing work.",
};

export const dynamicParams = false;

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

type LocaleLayoutProps = Readonly<{
  children: ReactNode;
  params: Promise<{ locale: string }>;
}>;

export default async function LocaleLayout({ children, params }: LocaleLayoutProps) {
  const { locale: localeSegment } = await params;
  const resolved = getCatalogForSegment(localeSegment);

  if (resolved === null) {
    notFound();
  }

  return (
    <html lang={resolved.locale} data-scroll-behavior="smooth">
      <body>
        <AppShell locale={resolved.locale} messages={resolved.catalog.shell}>
          {children}
        </AppShell>
      </body>
    </html>
  );
}
