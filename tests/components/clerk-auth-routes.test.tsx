import { render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/modules/identity/providers/clerk/client-boundary", () => ({
  ClerkSignInPanel: ({ locale, returnPath }: { locale: string; returnPath: string }) => (
    <div data-testid="route-sign-in" data-locale={locale} data-return-path={returnPath} />
  ),
  ClerkSignUpPanel: ({ locale, returnPath }: { locale: string; returnPath: string }) => (
    <div data-testid="route-sign-up" data-locale={locale} data-return-path={returnPath} />
  ),
}));

import SignInPage from "@/app/[locale]/sign-in/[[...sign-in]]/page";
import SignUpPage from "@/app/[locale]/sign-up/[[...sign-up]]/page";

const originalPublishableKey = process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY;
const originalSecretKey = process.env.CLERK_SECRET_KEY;

describe("localized Clerk route contracts", () => {
  beforeEach(() => {
    process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY = "pk_test_synthetic_public_value";
    process.env.CLERK_SECRET_KEY = "sk_test_synthetic_server_value";
  });

  afterEach(() => {
    if (originalPublishableKey === undefined) delete process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY;
    else process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY = originalPublishableKey;
    if (originalSecretKey === undefined) delete process.env.CLERK_SECRET_KEY;
    else process.env.CLERK_SECRET_KEY = originalSecretKey;
  });

  it("passes a validated same-locale fallback into the sign-in panel", async () => {
    render(
      await SignInPage({
        params: Promise.resolve({ locale: "th" }),
        searchParams: Promise.resolve({ returnTo: "/th/profile" }),
      }),
    );

    expect(screen.getByTestId("route-sign-in")).toHaveAttribute("data-locale", "th");
    expect(screen.getByTestId("route-sign-in")).toHaveAttribute("data-return-path", "/th/profile");
  });

  it("normalizes a cross-locale sign-up fallback before it reaches Clerk", async () => {
    render(
      await SignUpPage({
        params: Promise.resolve({ locale: "en" }),
        searchParams: Promise.resolve({ returnTo: "/th/profile" }),
      }),
    );

    expect(screen.getByTestId("route-sign-up")).toHaveAttribute("data-locale", "en");
    expect(screen.getByTestId("route-sign-up")).toHaveAttribute("data-return-path", "/en");
  });
});
