import { render, screen } from "@testing-library/react";
import type { ReactNode } from "react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/modules/identity/providers/clerk/client-runtime.mjs", () => ({
  ClerkProvider: ({ children }: { children: ReactNode }) => <div>{children}</div>,
  SignIn: ({ fallbackRedirectUrl }: { fallbackRedirectUrl: string }) => (
    <div data-testid="sign-in" data-return-path={fallbackRedirectUrl} />
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
  ClerkLogoutControl,
  ClerkSignInPanel,
} from "@/modules/identity/providers/clerk/client-boundary";

describe("Clerk client integration boundary", () => {
  it("keeps the validated locale return path on sign-in", () => {
    render(<ClerkSignInPanel locale="th" returnPath="/th/profile" />);
    expect(screen.getByTestId("sign-in")).toHaveAttribute("data-return-path", "/th/profile");
  });

  it("delegates logout to Clerk and returns to the locale root", () => {
    render(<ClerkLogoutControl label="ออกจากระบบ" locale="th" />);
    expect(screen.getByRole("button", { name: "ออกจากระบบ" })).toBeVisible();
    expect(screen.getByTestId("sign-out")).toHaveAttribute("data-return-path", "/th");
  });
});
