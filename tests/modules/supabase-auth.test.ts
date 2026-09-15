import { beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({
  client: vi.fn(),
  getUser: vi.fn(),
  send: vi.fn(),
  verify: vi.fn(),
  signOut: vi.fn(),
  redirect: vi.fn(),
}));
vi.mock("server-only", () => ({}));
vi.mock("@/modules/identity/providers/supabase/client", () => ({
  createSupabaseServerClient: mocks.client,
}));
vi.mock("next/navigation", () => ({ redirect: mocks.redirect }));
import { SupabaseIdentityProvider } from "@/modules/identity/providers/supabase/server";
import { parseSupabaseConfiguration } from "@/modules/identity/providers/supabase/config";
import { submitEmailCode, signOut } from "@/modules/identity/providers/supabase/actions";

const id = "70000000-0000-4000-8000-000000000001";
const user = { id, email_confirmed_at: "2026-09-15T00:00:00Z", is_anonymous: false };
function form(intent: string, email = "synthetic@example.invalid", token = "123456") {
  const data = new FormData();
  data.set("intent", intent);
  data.set("email", email);
  data.set("token", token);
  return data;
}
beforeEach(() => {
  vi.resetAllMocks();
  mocks.client.mockResolvedValue({
    auth: {
      getUser: mocks.getUser,
      signInWithOtp: mocks.send,
      verifyOtp: mocks.verify,
      signOut: mocks.signOut,
    },
  });
  mocks.redirect.mockImplementation((path) => {
    throw new Error(`redirect:${path}`);
  });
});
describe("Supabase authentication", () => {
  it("does not contact auth when unconfigured", async () => {
    mocks.client.mockResolvedValue(null);
    expect(await new SupabaseIdentityProvider().readSession()).toEqual({ state: "unavailable" });
    expect(mocks.getUser).not.toHaveBeenCalled();
  });
  it("uses the server-verified identity without returning email or metadata", async () => {
    mocks.getUser.mockResolvedValue({
      data: { user: { ...user, email: "private@example.invalid", user_metadata: { admin: true } } },
      error: null,
    });
    expect(await new SupabaseIdentityProvider().readSession()).toEqual({
      state: "authenticated",
      provider: "supabase",
      providerSubject: id,
    });
  });
  it.each([
    { user: null },
    { user: { ...user, is_anonymous: true } },
    { user: { ...user, email_confirmed_at: null } },
    { user: { ...user, id: "guessed" } },
  ])("rejects invalid identity $user", async (data) => {
    mocks.getUser.mockResolvedValue({ data, error: null });
    expect((await new SupabaseIdentityProvider().readSession()).state).not.toBe("authenticated");
  });
  it("denies a forged session rejected by the auth server", async () => {
    mocks.getUser.mockResolvedValue({ data: { user }, error: new Error("invalid token") });
    expect((await new SupabaseIdentityProvider().readSession()).state).toBe("absent");
  });
  it.each(["sign-in", "sign-up"])(
    "only creates users in %s when explicitly signing up",
    async (mode) => {
      mocks.send.mockResolvedValue({ error: null });
      const result = await submitEmailCode(
        "th",
        mode,
        "/th/profile",
        { step: "email", status: "idle" },
        form("send"),
      );
      expect(result).toEqual({ step: "verify", status: "sent" });
      expect(mocks.send).toHaveBeenCalledWith({
        email: "synthetic@example.invalid",
        options: { shouldCreateUser: mode === "sign-up" },
      });
    },
  );
  it("does not reveal unknown accounts or raw provider errors", async () => {
    mocks.send.mockResolvedValue({ error: new Error("user not found: private@example.invalid") });
    expect(
      await submitEmailCode(
        "en",
        "sign-in",
        "/en",
        { step: "email", status: "idle" },
        form("send"),
      ),
    ).toEqual({ step: "verify", status: "sent" });
  });
  it("rejects malformed email and token without provider requests", async () => {
    await submitEmailCode(
      "en",
      "sign-in",
      "/en",
      { step: "email", status: "idle" },
      form("send", "bad"),
    );
    await submitEmailCode(
      "en",
      "sign-in",
      "/en",
      { step: "email", status: "idle" },
      form("verify", "synthetic@example.invalid", "invalid"),
    );
    expect(mocks.client).not.toHaveBeenCalled();
  });
  it("redirects only after verified OTP and rejects an external return URL", async () => {
    mocks.verify.mockResolvedValue({
      data: { user, session: { access_token: "private" } },
      error: null,
    });
    await expect(
      submitEmailCode(
        "th",
        "sign-in",
        "https://attacker.invalid",
        { step: "verify", status: "sent" },
        form("verify"),
      ),
    ).rejects.toThrow("redirect:/th");
    expect(mocks.verify).toHaveBeenCalledWith({
      email: "synthetic@example.invalid",
      token: "123456",
      type: "email",
    });
  });
  it("does not redirect after an expired code", async () => {
    mocks.verify.mockResolvedValue({
      data: { user: null, session: null },
      error: { message: "expired" },
    });
    expect(
      await submitEmailCode(
        "en",
        "sign-in",
        "/en/profile",
        { step: "verify", status: "sent" },
        form("verify"),
      ),
    ).toEqual({ step: "verify", status: "error" });
    expect(mocks.redirect).not.toHaveBeenCalled();
  });
  it("reports logout failure and redirects only after successful sign-out", async () => {
    mocks.signOut.mockResolvedValueOnce({ error: new Error("private") });
    expect(await signOut("en", true)).toBe(false);
    expect(mocks.redirect).not.toHaveBeenCalled();
    mocks.signOut.mockResolvedValueOnce({ error: null });
    await expect(signOut("en", false)).rejects.toThrow("redirect:/en");
  });
});
describe("Supabase configuration", () => {
  it("keeps preview contexts disconnected from configured live credentials unless explicitly enabled", () => {
    const env = {
      CONTEXT: "deploy-preview",
      SUPABASE_URL: "https://project.supabase.co",
      SUPABASE_PUBLISHABLE_KEY: "sb_publishable_synthetic",
    };
    expect(parseSupabaseConfiguration(env)).toEqual({ state: "disabled" });
    expect(parseSupabaseConfiguration({ ...env, RISE_PALS_ALLOW_PREVIEW_AUTH: "true" }).state).toBe(
      "enabled",
    );
  });
  it("allows an unconfigured demo and explicit secret-free tests", () => {
    expect(parseSupabaseConfiguration({})).toEqual({ state: "disabled" });
    expect(
      parseSupabaseConfiguration({
        RISE_PALS_SECRET_FREE_STANDARD_GATE: "true",
        SUPABASE_URL: "broken",
      }),
    ).toEqual({ state: "disabled" });
  });
  it.each([
    "http://remote.invalid",
    "https://user:password@project.supabase.co",
    "https://project.supabase.co/path",
  ])("rejects unsafe URL %s", (url) => {
    expect(() =>
      parseSupabaseConfiguration({
        SUPABASE_URL: url,
        SUPABASE_PUBLISHABLE_KEY: "sb_publishable_synthetic",
      }),
    ).toThrow();
  });
  it("rejects secret keys without echoing them", () => {
    expect(() =>
      parseSupabaseConfiguration({
        SUPABASE_URL: "https://project.supabase.co",
        SUPABASE_PUBLISHABLE_KEY: "sb_secret_private",
      }),
    ).toThrow("Supabase authentication requires a valid project URL and publishable key.");
  });
});
