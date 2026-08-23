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
  test(`${locale} protected learning routes fail closed without Clerk and remain loopback-only`, async ({
    page,
  }) => {
    const unexpectedOrigins = new Set<string>();
    page.on("request", (request) => {
      const url = new URL(request.url());
      if (url.hostname !== "127.0.0.1") unexpectedOrigins.add(url.origin);
    });
    await page.goto(`/${locale}/learning`);
    await expect(page.locator("html")).toHaveAttribute("lang", locale);
    await expect(page.getByRole("heading", { level: 1 })).toContainText(
      locale === "th" ? "ความคืบหน้าการเรียนรู้" : "Learning progress",
    );
    await expect(page.locator("form, input")).toHaveCount(0);
    await page.goto(`/${locale}/lessons/source-verification-practice/attempt`);
    await expect(page.getByRole("heading", { level: 1 })).toContainText(
      locale === "th" ? "ยังเปิดพื้นที่เรียนรู้ไม่ได้" : "The learning area is unavailable",
    );
    await expect(page.locator("form, input")).toHaveCount(0);
    await page.waitForLoadState("networkidle");
    expect([...unexpectedOrigins]).toEqual([]);
  });

  test(`${locale} protected learning shell reflows and has no blocking axe violations`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 320, height: 800 });
    await page.goto(`/${locale}/learning`);
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
}

test("protected learning language switches preserve only the fixed route", async ({ page }) => {
  await page.goto("/th/learning");
  await page.getByRole("link", { name: "English" }).click();
  await expect(page).toHaveURL(/\/en\/learning$/);
  await page.goto("/th/lessons/source-verification-practice/attempt");
  await page.getByRole("link", { name: "English" }).click();
  await expect(page).toHaveURL(/\/en\/lessons\/source-verification-practice\/attempt$/);
  expect(new URL(page.url()).search).toBe("");
  expect(new URL(page.url()).hash).toBe("");
});

test("public lesson remains static, memory-only and separate from persisted routes", async ({
  page,
}) => {
  const postRequests: string[] = [];
  page.on("request", (request) => {
    if (request.method() !== "GET") postRequests.push(request.url());
  });
  await page.goto("/en/lessons/source-verification-practice");
  await expect(page.getByRole("radio")).toHaveCount(9);
  await page.getByRole("radio").first().check();
  await page.reload();
  await expect(page.getByRole("radio").first()).not.toBeChecked();
  expect(postRequests).toEqual([]);
});
