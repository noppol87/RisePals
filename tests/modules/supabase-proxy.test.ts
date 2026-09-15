import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const mock = vi.hoisted(() => ({ create: vi.fn(), getUser: vi.fn() }));
vi.mock("@supabase/ssr", () => ({ createServerClient: mock.create }));
vi.mock("@/modules/identity/providers/supabase/config", () => ({
  parseSupabaseConfiguration: () => ({
    state: "enabled",
    url: "https://synthetic.supabase.co",
    publishableKey: "sb_publishable_synthetic",
  }),
}));
import { refreshSupabaseSession } from "@/modules/identity/providers/supabase/proxy";

beforeEach(() => {
  vi.resetAllMocks();
});
describe("Supabase session refresh", () => {
  it("carries refreshed cookies into the request and non-cacheable response", async () => {
    mock.create.mockImplementation((_url, _key, options) => {
      mock.getUser.mockImplementation(async () => {
        options.cookies.setAll(
          [
            {
              name: "sb-test-auth-token",
              value: "synthetic-refreshed",
              options: { httpOnly: true, sameSite: "lax", path: "/", secure: true },
            },
          ],
          { "Cache-Control": "private, no-store", Pragma: "no-cache" },
        );
        return { data: { user: null }, error: null };
      });
      return { auth: { getUser: mock.getUser } };
    });
    const request = new NextRequest("https://risepals.example/th/profile");
    const response = await refreshSupabaseSession(request);
    expect(request.cookies.get("sb-test-auth-token")?.value).toBe("synthetic-refreshed");
    expect(response.cookies.get("sb-test-auth-token")).toMatchObject({
      value: "synthetic-refreshed",
      httpOnly: true,
      secure: true,
    });
    expect(response.headers.get("Cache-Control")).toBe("private, no-store");
    expect(response.headers.get("Pragma")).toBe("no-cache");
  });
  it("does not expose provider exceptions or cache authenticated routes during outages", async () => {
    mock.getUser.mockRejectedValue(new Error("private provider details"));
    mock.create.mockReturnValue({ auth: { getUser: mock.getUser } });
    const response = await refreshSupabaseSession(
      new NextRequest("https://risepals.example/en/profile"),
    );
    expect(response.headers.get("Cache-Control")).toBe("private, no-store");
    expect(await response.text()).not.toContain("private provider details");
  });
});
