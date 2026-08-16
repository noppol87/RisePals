import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "./fixtures";

async function expectNoHorizontalOverflow(page: Page) {
  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
}

for (const locale of ["th", "en"] as const) {
  test(`${locale} persisted attempt is localized and fails closed without Clerk`, async ({
    page,
  }) => {
    const unexpectedOrigins = new Set<string>();
    page.on("request", (request) => {
      const url = new URL(request.url());
      if (url.hostname !== "127.0.0.1") unexpectedOrigins.add(url.origin);
    });
    await page.goto(`/${locale}/assessment/attempt`);
    await expect(page.locator("html")).toHaveAttribute("lang", locale);
    await expect(page.getByRole("heading", { level: 1 })).toContainText(
      locale === "th" ? "บันทึกการตอบ" : "Persist responses",
    );
    await expect(
      page.getByRole("heading", {
        level: 2,
        name:
          locale === "th"
            ? "ยังไม่พร้อมเริ่มการตอบแบบบันทึก"
            : "The persisted attempt is not available",
      }),
    ).toBeVisible();
    await expect(page.locator("form, input")).toHaveCount(0);
    await page.waitForLoadState("networkidle");
    expect([...unexpectedOrigins]).toEqual([]);
  });

  test(`${locale} persisted attempt reflows and has no blocking accessibility violations`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 320, height: 800 });
    await page.goto(`/${locale}/assessment/attempt`);
    await expectNoHorizontalOverflow(page);
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
      .analyze();
    expect(
      results.violations.filter(
        (violation) => violation.impact === "serious" || violation.impact === "critical",
      ),
    ).toEqual([]);
  });

  test(`${locale} persisted result fails closed without Clerk and leaks no result data`, async ({
    page,
  }) => {
    const unexpectedOrigins = new Set<string>();
    page.on("request", (request) => {
      const url = new URL(request.url());
      if (url.hostname !== "127.0.0.1") unexpectedOrigins.add(url.origin);
    });

    await page.goto(`/${locale}/assessment/result`);
    await expect(page).toHaveURL(new RegExp(`/${locale}/assessment/result$`));
    await expect(
      page.getByRole("heading", {
        level: 2,
        name:
          locale === "th" ? "ยังไม่มีเซสชันที่พร้อมสร้างผลลัพธ์" : "No submitted session is ready",
      }),
    ).toBeVisible();
    await expect(page.locator("body")).not.toContainText(
      /selectedOptionId|sessionId|scoringRunId|inputDigest|outputDigest/i,
    );
    await page.waitForLoadState("networkidle");
    expect([...unexpectedOrigins]).toEqual([]);
  });
}

test("temporary prototype links honestly without copying browser state", async ({ page }) => {
  await page.goto("/en/assessment");
  await page.evaluate(() => sessionStorage.setItem("turn-12-boundary-sentinel", "unchanged"));
  await page.getByRole("link", { name: /Open the persisted path/ }).click();
  await expect(page).toHaveURL(/\/en\/assessment\/attempt$/);
  await expect(page.getByText(/never copies temporary answers/)).toBeVisible();
  expect(await page.evaluate(() => sessionStorage.getItem("turn-12-boundary-sentinel"))).toBe(
    "unchanged",
  );
});

test("persisted attempt language switching preserves only the route", async ({ page }) => {
  await page.goto("/th/assessment/attempt");
  await page.getByRole("link", { name: "English" }).click();
  await expect(page).toHaveURL(/\/en\/assessment\/attempt$/);
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  expect(new URL(page.url()).search).toBe("");
  expect(new URL(page.url()).hash).toBe("");
});

test("persisted result language switching preserves only the protected result route", async ({
  page,
}) => {
  await page.goto("/th/assessment/result");
  await expect(page).toHaveURL(/\/th\/assessment\/result$/);
  await page.getByRole("link", { name: "English" }).click();
  await expect(page).toHaveURL(/\/en\/assessment\/result$/);
  expect(new URL(page.url()).search).toBe("");
  expect(new URL(page.url()).hash).toBe("");
});
