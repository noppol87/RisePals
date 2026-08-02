import type { Metadata } from "next";
import type { ReactNode } from "react";
import "@/app/globals.css";
import "@/lib/env/server";

export const metadata: Metadata = {
  title: "Rise Pals",
  description: "Rise Pals application foundation",
};

type RootLayoutProps = Readonly<{
  children: ReactNode;
}>;

export default function RootLayout({ children }: RootLayoutProps) {
  return (
    <html lang="th">
      <body>{children}</body>
    </html>
  );
}
