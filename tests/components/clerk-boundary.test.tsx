import { render, screen } from "@testing-library/react";
import type { ReactNode } from "react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/modules/identity/providers/clerk/client-runtime.mjs", () => ({
  ClerkProvider: ({
    children,
    signInUrl,
    signUpUrl,
    afterSignOutUrl,
  }: {
    children: ReactNode;
    signInUrl: string;
    signUpUrl: string;
    afterSignOutUrl: string;
  }) => (
    <div
      data-testid="clerk-provider"
      data-sign-in-url={signInUrl}
      data-sign-up-url={signUpUrl}
      data-after-sign-out-url={afterSignOutUrl}
    >
      {children}
    </div>
  ),
  SignIn: ({
    routing,
    path,
    signUpUrl,
    fallbackRedirectUrl,
  }: {
    routing: string;
    path: string;
    signUpUrl: string;
    fallbackRedirectUrl: string;
  }) => (
    <div
      data-testid="sign-in"
      data-routing={routing}
      data-path={path}
      data-sign-up-url={signUpUrl}
      data-return-path={fallbackRedirectUrl}
    />
  ),
  SignUp: ({
    routing,
    path,
    signInUrl,
    fallbackRedirectUrl,
  }: {
    routing: string;
    path: string;
    signInUrl: string;
    fallbackRedirectUrl: string;
  }) => (
    <div
      data-testid="sign-up"
      data-routing={routing}
      data-path={path}
      data-sign-in-url={signInUrl}
      data-return-path={fallbackRedirectUrl}
    />
  ),
  SignOutButton: ({ children, redirectUrl }: { children: ReactNode; redirectUrl: string }) => (
    <div data-testid="sign-out" data-return-path={redirectUrl}>
      {children}
    </div>
  ),
  enUS: {},
  thTH: {},
}));

import {
  ClerkClientBoundary,
  ClerkLogoutControl,
  ClerkSignInPanel,
  ClerkSignUpPanel,
} from "@/modules/identity/providers/clerk/client-boundary";

describe("Clerk client integration boundary", () => {
  it("configures deterministic same-locale sign-in and sign-up routes", () => {
    render(
      <ClerkClientBoundary locale="th" publishableKey="pk_test_synthetic">
        <p>child</p>
      </ClerkClientBoundary>,
    );
    expect(screen.getByTestId("clerk-provider")).toHaveAttribute("data-sign-in-url", "/th/sign-in");
    expect(screen.getByTestId("clerk-provider")).toHaveAttribute("data-sign-up-url", "/th/sign-up");
    expect(screen.getByTestId("clerk-provider")).toHaveAttribute("data-after-sign-out-url", "/th");
  });

  it("keeps the validated locale return path and dedicated sign-up URL on sign-in", () => {
    render(<ClerkSignInPanel locale="th" returnPath="/th/profile" />);
    expect(screen.getByTestId("sign-in")).toHaveAttribute("data-return-path", "/th/profile");
    expect(screen.getByTestId("sign-in")).toHaveAttribute("data-routing", "path");
    expect(screen.getByTestId("sign-in")).toHaveAttribute("data-path", "/th/sign-in");
    expect(screen.getByTestId("sign-in")).toHaveAttribute("data-sign-up-url", "/th/sign-up");
  });

  it("keeps the validated locale return path and dedicated sign-in URL on sign-up", () => {
    render(<ClerkSignUpPanel locale="en" returnPath="/en/onboarding" />);
    expect(screen.getByTestId("sign-up")).toHaveAttribute("data-return-path", "/en/onboarding");
    expect(screen.getByTestId("sign-up")).toHaveAttribute("data-routing", "path");
    expect(screen.getByTestId("sign-up")).toHaveAttribute("data-path", "/en/sign-up");
    expect(screen.getByTestId("sign-up")).toHaveAttribute("data-sign-in-url", "/en/sign-in");
  });

  it("delegates logout to Clerk and returns to the locale root", () => {
    render(<ClerkLogoutControl label="ออกจากระบบ" locale="th" />);
    expect(screen.getByRole("button", { name: "ออกจากระบบ" })).toBeVisible();
    expect(screen.getByTestId("sign-out")).toHaveAttribute("data-return-path", "/th");
  });
});
