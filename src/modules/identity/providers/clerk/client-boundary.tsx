"use client";

import type { ReactNode } from "react";
import type { Locale } from "@/lib/i18n/config";
import {
  ClerkProvider,
  enUS,
  SignIn,
  SignOutButton,
  thTH,
} from "@/modules/identity/providers/clerk/client-runtime.mjs";

export function ClerkClientBoundary({
  children,
  locale,
  publishableKey,
}: Readonly<{ children: ReactNode; locale: Locale; publishableKey: string }>) {
  return (
    <ClerkProvider
      publishableKey={publishableKey}
      localization={locale === "th" ? thTH : enUS}
      signInUrl={`/${locale}/sign-in`}
      signUpUrl={`/${locale}/sign-in`}
      afterSignOutUrl={`/${locale}`}
    >
      {children}
    </ClerkProvider>
  );
}

export function ClerkSignInPanel({
  locale,
  returnPath,
}: Readonly<{ locale: Locale; returnPath: string }>) {
  return (
    <SignIn
      routing="path"
      path={`/${locale}/sign-in`}
      signUpUrl={`/${locale}/sign-in`}
      fallbackRedirectUrl={returnPath}
    />
  );
}

export function ClerkLogoutControl({ label, locale }: Readonly<{ label: string; locale: Locale }>) {
  return (
    <SignOutButton redirectUrl={`/${locale}`}>
      <button className="player-button player-button--quiet" type="button">
        {label}
      </button>
    </SignOutButton>
  );
}
