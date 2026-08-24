import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

const criticalPaths = [
  "sign-in",
  "assessment",
  "assessment/attempt",
  "assessment/example-result",
  "learning",
  "lessons/source-verification-practice",
  "evidence",
  "profile",
] as const;

for (const locale of ["th", "en"] as const) {
  test(`@alpha-hardening ${locale} critical alpha surfaces remain accessible and private`, async ({
    page,
  }, testInfo) => {
    const unexpectedOrigins = new Set<string>();
    const consolePayloads: string[] = [];
    page.on("request", (request) => {
      const url = new URL(request.url());
      if (url.hostname !== "127.0.0.1") unexpectedOrigins.add(url.origin);
    });
    page.on("console", (message) => consolePayloads.push(message.text()));
    if (testInfo.project.name === "chromium-reduced-motion") {
      await page.emulateMedia({ reducedMotion: "reduce" });
    }

    for (const path of criticalPaths) {
      await page.goto(`/${locale}/${path}`);
      await expect(page.locator("html")).toHaveAttribute("lang", locale);
      await expect(page.locator("h1")).toHaveCount(1);

      const dimensions = await page.evaluate(() => ({
        clientWidth: document.documentElement.clientWidth,
        scrollWidth: document.documentElement.scrollWidth,
        reducedMotion: matchMedia("(prefers-reduced-motion: reduce)").matches,
      }));
      expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
      if (testInfo.project.name === "chromium-mobile-320") {
        expect(dimensions.clientWidth).toBe(320);
      }
      if (testInfo.project.name === "chromium-reduced-motion") {
        expect(dimensions.reducedMotion).toBe(true);
      }

      await page.keyboard.press("Tab");
      const focus = await page.evaluate(() => ({
        tag: document.activeElement?.tagName,
        visible: Boolean(document.activeElement?.getClientRects().length),
      }));
      expect(focus.tag).not.toBe("BODY");
      expect(focus.visible).toBe(true);
    }

    for (const path of ["sign-in", "assessment/attempt", "learning", "evidence"] as const) {
      await page.goto(`/${locale}/${path}`);
      const accessibility = await new AxeBuilder({ page }).analyze();
      expect(
        accessibility.violations.filter(({ impact }) =>
          ["serious", "critical"].includes(impact ?? ""),
        ),
      ).toEqual([]);
    }

    const browserState = await page.evaluate(() => ({
      cookies: document.cookie,
      local: Object.keys(localStorage),
      session: Object.keys(sessionStorage),
    }));
    expect(browserState).toEqual({ cookies: "", local: [], session: [] });
    expect(unexpectedOrigins).toEqual(new Set());
    expect(consolePayloads.join("\n")).not.toMatch(
      /selectedOptionId|providerSubject|clientMutationId|DATABASE_URL|CLERK_SECRET_KEY/u,
    );
  });
}
