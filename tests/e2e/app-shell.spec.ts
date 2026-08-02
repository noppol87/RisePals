import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

async function expectNoHorizontalOverflow(page: Page) {
  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));

  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
}

test("the root route resolves to the Thai default", async ({ page }) => {
  await page.goto("/");

  await expect(page).toHaveURL(/\/th$/);
  await expect(page.locator("html")).toHaveAttribute("lang", "th");
  await expect(page.getByRole("heading", { level: 1 })).toContainText("พื้นฐานประสบการณ์");
});

test("Thai and English routes use complete localized shell content", async ({ page }) => {
  await page.goto("/th");
  await expect(page.locator("html")).toHaveAttribute("lang", "th");
  await expect(page.getByRole("navigation", { name: "การนำทางหลัก" })).toBeVisible();
  await expect(page.getByRole("link", { name: "ไทย" })).toHaveAttribute("aria-current", "page");

  await page.getByRole("link", { name: "English" }).click();
  await expect(page).toHaveURL(/\/en$/);
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Rise Pals experience foundation",
  );
  await expect(page.getByRole("link", { name: "English" })).toHaveAttribute("aria-current", "page");
});

test("unsupported locale segments return not found", async ({ page }) => {
  const response = await page.goto("/fr");

  expect(response?.status()).toBe(404);
});

test("the skip link is first, visibly focused, and moves focus to main", async ({ page }) => {
  await page.goto("/th");
  await page.keyboard.press("Tab");

  const skipLink = page.getByRole("link", { name: "ข้ามไปยังเนื้อหาหลัก" });
  await expect(skipLink).toBeFocused();
  await expect
    .poll(async () => skipLink.evaluate((element) => getComputedStyle(element).outlineStyle))
    .not.toBe("none");

  await page.keyboard.press("Enter");
  await expect(page.getByRole("main")).toBeFocused();
});

test("the 320px and 400%-equivalent reflow view has no horizontal overflow", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.goto("/th");

  await expectNoHorizontalOverflow(page);
  await expect(page.getByRole("banner")).toBeVisible();
  await expect(page.getByRole("main")).toBeVisible();

  for (const link of await page.getByRole("banner").getByRole("link").all()) {
    const box = await link.boundingBox();
    expect(box?.height).toBeGreaterThanOrEqual(44);
    expect(box?.x).toBeGreaterThanOrEqual(0);
    expect((box?.x ?? 0) + (box?.width ?? 0)).toBeLessThanOrEqual(320);
  }
});

test("the representative desktop shell preserves reading and navigation order", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.goto("/en");

  await expectNoHorizontalOverflow(page);
  const wordmarkBox = await page
    .getByRole("banner")
    .getByRole("link", { name: "Rise Pals" })
    .boundingBox();
  const languageBox = await page.getByRole("navigation", { name: "Choose language" }).boundingBox();
  expect(Math.abs((wordmarkBox?.y ?? 0) - (languageBox?.y ?? 0))).toBeLessThan(32);
});

test("reduced motion removes meaningful animation and transition duration", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/th");

  const transitionDurationSeconds = await page
    .getByRole("link", { name: "English" })
    .evaluate((element) =>
      getComputedStyle(element)
        .transitionDuration.split(",")
        .map((duration) => Number.parseFloat(duration)),
    );
  expect(transitionDurationSeconds.every((duration) => duration <= 0.00001)).toBe(true);
  expect(await page.evaluate(() => document.getAnimations().length)).toBe(0);
});

for (const locale of ["th", "en"] as const) {
  test(`${locale} shell has no serious or critical automated accessibility violations`, async ({
    page,
  }) => {
    await page.goto(`/${locale}`);
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
      .analyze();
    const blockingViolations = results.violations.filter(
      (violation) => violation.impact === "serious" || violation.impact === "critical",
    );

    expect(blockingViolations, JSON.stringify(blockingViolations, null, 2)).toEqual([]);
  });
}
