import { expect, test } from "@playwright/test";

test.describe("non-sensitive infrastructure health boundary", () => {
  test("exposes only fixed liveness in the standard secret-free application", async ({
    request,
  }) => {
    const response = await request.get("/health/live");
    expect(response.status()).toBe(200);
    expect(await response.json()).toEqual({ status: "ok" });
    expect(response.headers()["cache-control"]).toBe("no-store");
  });

  test("fails readiness closed outside the explicit rehearsal", async ({ request }) => {
    const response = await request.get("/health/ready");
    expect(response.status()).toBe(503);
    expect(await response.json()).toEqual({ status: "unavailable" });
  });

  test("keeps the streaming probe absent outside the explicit rehearsal", async ({ request }) => {
    const response = await request.get("/health/stream");
    expect(response.status()).toBe(404);
    expect(await response.text()).toBe("Not Found");
  });
});
