import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const authMock = vi.hoisted(() => vi.fn());

vi.mock("server-only", () => ({}));
vi.mock("@/modules/identity/providers/clerk/server-runtime.mjs", () => ({ auth: authMock }));

import { isValidatedClerkSession } from "@/modules/identity/contract";
import { parseClerkDevelopmentConfiguration } from "@/modules/identity/providers/clerk/config";
import { ClerkDevelopmentIdentityProvider } from "@/modules/identity/providers/clerk/server";

const originalPublishableKey = process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY;
const originalSecretKey = process.env.CLERK_SECRET_KEY;

function setDevelopmentKeys() {
  process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY = "pk_test_synthetic_public_value";
  process.env.CLERK_SECRET_KEY = "sk_test_synthetic_server_value";
}

describe("Clerk Development provider boundary", () => {
  beforeEach(() => {
    authMock.mockReset();
    delete process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY;
    delete process.env.CLERK_SECRET_KEY;
  });

  afterEach(() => {
    if (originalPublishableKey === undefined) delete process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY;
    else process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY = originalPublishableKey;
    if (originalSecretKey === undefined) delete process.env.CLERK_SECRET_KEY;
    else process.env.CLERK_SECRET_KEY = originalSecretKey;
  });

  it("stays disabled when the ignored Development key pair is absent", async () => {
    expect(parseClerkDevelopmentConfiguration({})).toEqual({ state: "disabled" });
    await expect(new ClerkDevelopmentIdentityProvider().readSession()).resolves.toEqual({
      state: "unavailable",
    });
    expect(authMock).not.toHaveBeenCalled();
  });

  it.each([
    { environment: { NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: "pk_test_only" } },
    { environment: { CLERK_SECRET_KEY: "sk_test_only" } },
    {
      environment: {
        NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: "pk_live_prohibited",
        CLERK_SECRET_KEY: ["sk", "live", "prohibited"].join("_"),
      },
    },
  ])("rejects $environment without echoing credential values", ({ environment }) => {
    expect(() => parseClerkDevelopmentConfiguration(environment)).toThrow(
      "Clerk alpha authentication requires one complete Development key pair",
    );
    try {
      parseClerkDevelopmentConfiguration(environment);
    } catch (error) {
      expect(String(error)).not.toContain(Object.values(environment)[0]);
    }
  });

  it("maps an authenticated Clerk subject and no other provider data", async () => {
    setDevelopmentKeys();
    authMock.mockResolvedValue({ isAuthenticated: true, userId: "user_synthetic0001" });

    await expect(new ClerkDevelopmentIdentityProvider().readSession()).resolves.toEqual({
      state: "authenticated",
      provider: "clerk",
      providerSubject: "user_synthetic0001",
    });
  });

  it("fails closed for absent and invalid provider sessions", async () => {
    setDevelopmentKeys();
    authMock.mockResolvedValueOnce({ isAuthenticated: false, userId: null });
    await expect(new ClerkDevelopmentIdentityProvider().readSession()).resolves.toEqual({
      state: "absent",
    });

    authMock.mockRejectedValueOnce(new Error("synthetic expired or invalid session"));
    await expect(new ClerkDevelopmentIdentityProvider().readSession()).resolves.toEqual({
      state: "invalid",
    });

    expect(
      isValidatedClerkSession({
        state: "authenticated",
        provider: "clerk",
        providerSubject: "browser-supplied",
      }),
    ).toBe(false);
  });
});
