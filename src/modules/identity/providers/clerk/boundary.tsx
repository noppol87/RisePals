import type { ReactNode } from "react";
import type { Locale } from "@/lib/i18n/config";
import { ClerkClientBoundary } from "@/modules/identity/providers/clerk/client-boundary";
import { parseClerkDevelopmentConfiguration } from "@/modules/identity/providers/clerk/config";

export function ClerkDevelopmentBoundary({
  children,
  locale,
}: Readonly<{ children: ReactNode; locale: Locale }>) {
  const configuration = parseClerkDevelopmentConfiguration(process.env);

  if (configuration.state === "disabled") {
    return children;
  }

  return (
    <ClerkClientBoundary locale={locale} publishableKey={configuration.publishableKey}>
      {children}
    </ClerkClientBoundary>
  );
}
