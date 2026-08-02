import type { Metadata } from "next";
import type { ReactNode } from "react";
import "@/app/globals.css";
import "@/lib/env/server";
import { defaultLocale } from "@/lib/i18n/config";

export const metadata: Metadata = {
  title: "Rise Pals",
  description: "Rise Pals application foundation",
};

type DefaultRootLayoutProps = Readonly<{
  children: ReactNode;
}>;

export default function DefaultRootLayout({ children }: DefaultRootLayoutProps) {
  return (
    <html lang={defaultLocale} data-scroll-behavior="smooth">
      <body>{children}</body>
    </html>
  );
}
