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
  test(`${locale} sign-in explains the synthetic Clerk boundary without keys`, async ({ page }) => {
    const unexpectedOrigins = new Set<string>();
    page.on("request", (request) => {
      const url = new URL(request.url());
      if (url.hostname !== "127.0.0.1") unexpectedOrigins.add(url.origin);
    });

    await page.goto(`/${locale}/sign-in?returnTo=/${locale}/profile`);
    await expect(page.locator("html")).toHaveAttribute("lang", locale);
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    await expect(
      page.getByText(locale === "th" ? /ข้อมูลบุคคลจริง/ : /Real personal data/),
    ).toBeVisible();
    await expect(page.getByText(locale === "th" ? /สหรัฐอเมริกา/ : /United States/)).toBeVisible();
    await expect(page.getByRole("heading", { level: 2 })).toContainText(
      locale === "th" ? "ยังไม่ได้เชื่อมต่อ" : "not connected",
    );
    await page.waitForLoadState("networkidle");
    expect([...unexpectedOrigins]).toEqual([]);
  });

  test(`${locale} sign-up route is localized, bounded and unavailable without keys`, async ({
    page,
  }) => {
    const unexpectedOrigins = new Set<string>();
    page.on("request", (request) => {
      const url = new URL(request.url());
      if (url.hostname !== "127.0.0.1") unexpectedOrigins.add(url.origin);
    });

    await page.goto(`/${locale}/sign-up?returnTo=/${locale}/onboarding`);
    await expect(page.locator("html")).toHaveAttribute("lang", locale);
    await expect(page.getByRole("heading", { level: 1 })).toContainText(
      locale === "th" ? "สร้างบัญชีอัลฟา" : "Create an alpha account",
    );
    await expect(
      page.getByText(locale === "th" ? /ข้อมูลบุคคลจริง/ : /Real personal data/),
    ).toBeVisible();
    await expect(page.getByRole("heading", { level: 2 })).toContainText(
      locale === "th" ? "ยังไม่ได้เชื่อมต่อ" : "not connected",
    );
    await page.waitForLoadState("networkidle");
    expect([...unexpectedOrigins]).toEqual([]);
  });

  test(`${locale} protected profile fails closed before database access when Clerk is unavailable`, async ({
    page,
  }) => {
    await page.goto(`/${locale}/profile`);
    await expect(page.getByRole("heading", { level: 1 })).toContainText(
      locale === "th" ? "ยังไม่ได้เชื่อมต่อ" : "not connected",
    );
    await expect(page.locator("form, input, select, textarea")).toHaveCount(0);
  });

  test(`${locale} auth/profile routes reflow and have no blocking accessibility violations`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 320, height: 800 });
    await page.goto(`/${locale}/sign-in`);
    await expectNoHorizontalOverflow(page);

    const signInResults = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
      .analyze();
    expect(
      signInResults.violations.filter(
        (violation) => violation.impact === "serious" || violation.impact === "critical",
      ),
    ).toEqual([]);

    await page.goto(`/${locale}/sign-up`);
    await expectNoHorizontalOverflow(page);

    const signUpResults = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
      .analyze();
    expect(
      signUpResults.violations.filter(
        (violation) => violation.impact === "serious" || violation.impact === "critical",
      ),
    ).toEqual([]);
  });
}

test("auth route language switching preserves the bounded route without copying return data", async ({
  page,
}) => {
  await page.goto("/th/sign-in?returnTo=/th/profile");
  await page.getByRole("link", { name: "English" }).click();
  await expect(page).toHaveURL(/\/en\/sign-in$/);
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
});

test("sign-up language switching preserves the dedicated route without copying return data", async ({
  page,
}) => {
  await page.goto("/en/sign-up?returnTo=/en/onboarding");
  await page.getByRole("link", { name: "ไทย" }).click();
  await expect(page).toHaveURL(/\/th\/sign-up$/);
  await expect(page.locator("html")).toHaveAttribute("lang", "th");
});
