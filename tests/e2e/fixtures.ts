import {
  expect,
  test as base,
  type BrowserContext,
  type Page,
  type Request,
} from "@playwright/test";

const allowedOrigin = "http://127.0.0.1:3104";

export const test = base.extend<{ context: BrowserContext }>({
  context: async ({ context }, run) => {
    const blockedOrigins = new Set<string>();

    await context.route("**/*", async (route) => {
      const url = new URL(route.request().url());
      if (url.origin !== allowedOrigin) {
        blockedOrigins.add(url.origin);
        await route.abort("blockedbyclient");
        return;
      }
      await route.continue();
    });

    await run(context);
    expect(
      [...blockedOrigins],
      "standard E2E must make only loopback application requests",
    ).toEqual([]);
  },
});

export { expect };
export type { Page, Request };
