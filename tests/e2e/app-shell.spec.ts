import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "./fixtures";

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
  await expect(page.getByRole("heading", { level: 1 })).toContainText(
    "อยากให้การทำงานดีขึ้นตรงไหน",
  );
});

test("Thai and English routes use complete intentional narrative content", async ({ page }) => {
  await page.goto("/th");
  await expect(page.locator("html")).toHaveAttribute("lang", "th");
  await expect(page.getByRole("navigation", { name: "การนำทางหลัก" })).toBeVisible();
  await expect(page.getByRole("link", { name: "ไทย" })).toHaveAttribute("aria-current", "page");
  await expect(page.getByRole("heading", { level: 1 })).toContainText("อยากให้การทำงานดีขึ้น");

  await page.getByRole("link", { name: "English" }).click();
  await expect(page).toHaveURL(/\/en$/);
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page.getByRole("heading", { level: 1 })).toContainText(
    "What would you like to improve",
  );
  await expect(page.getByRole("link", { name: "English" })).toHaveAttribute("aria-current", "page");
});

test("both evidence items expose attribution, limitations, and exact source destinations", async ({
  page,
}) => {
  await page.goto("/en");

  await page.locator("#why-now summary").click();
  await expect(page.getByRole("article")).toHaveCount(2);
  await expect(page.getByText(/about one in four workers/)).toBeVisible();
  await expect(page.getByText(/39% of workers’ core skills/)).toBeVisible();
  await expect(page.getByText(/not a Thailand-specific figure/)).toBeVisible();
  await expect(page.getByText(/not a certainty or individual prediction/)).toBeVisible();

  const sources = page.getByRole("link", { name: "Read the source" });
  await expect(sources).toHaveCount(2);
  await expect(sources.nth(0)).toHaveAttribute(
    "href",
    "https://www.ilo.org/publications/generative-ai-and-jobs-refined-global-index-occupational-exposure",
  );
  await expect(sources.nth(1)).toHaveAttribute(
    "href",
    "https://www.weforum.org/publications/the-future-of-jobs-report-2025/in-full/3-skills-outlook/",
  );
  await expect(page).toHaveURL(/\/en$/);
});

test("the first-visit journey opens locale-matched practice without collecting data on landing", async ({
  page,
}) => {
  await page.goto("/th");

  await page.getByRole("button", { name: /อยากรับมือวิธีทำงานใหม่/ }).click();
  await page.getByRole("button", { name: /ข้อมูลจาก AI เชื่อได้แค่ไหน/ }).click();
  const cta = page.getByRole("link", { name: /เริ่มภารกิจแรก/ });
  await expect(cta).toHaveAttribute("href", "/th/lessons/source-verification-practice");
  await expect(page.getByText(/ยังไม่บันทึกผล/)).toBeVisible();
  await expect(page.locator("input, textarea, select, form")).toHaveCount(0);

  await cta.click();
  await expect(page).toHaveURL(/\/th\/lessons\/source-verification-practice$/);
  await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
});

test("the page exposes the complete product loop and the 8+2 distinction", async ({ page }) => {
  await page.goto("/en");

  const loop = page.getByRole("list", { name: "The Rise Pals development loop" });
  await expect(loop.getByRole("listitem")).toHaveCount(6);
  for (const step of [
    "Explore",
    "Focus",
    "Learn",
    "Practise",
    "Show your work",
    "Find opportunities",
  ]) {
    await expect(loop.getByRole("heading", { name: step })).toBeVisible();
  }

  await page.locator("#skill-framework summary").click();
  await expect(page.getByRole("heading", { name: "8 core skills" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "2 habits that help" })).toBeVisible();
  await expect(page.getByText(/not a ninth and tenth skill/)).toBeVisible();
  await expect(
    page.locator("#skill-framework").getByText(/not your assessment result/),
  ).toBeVisible();
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

  await page.keyboard.press("Tab");
  await expect(page.getByRole("button", { name: /อยากให้งานราบรื่นขึ้น/ })).toBeFocused();
});

test("the 320px and 400%-equivalent reflow view has no horizontal overflow", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.goto("/th");

  await expectNoHorizontalOverflow(page);
  await expect(page.getByRole("banner")).toBeVisible();
  await expect(page.getByRole("main")).toBeVisible();
  await page.locator("#why-now summary").click();
  await expect(page.getByRole("article")).toHaveCount(2);

  for (const link of await page.getByRole("link").all()) {
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
  await page.locator("#why-now summary").click();
  await expect(page.getByRole("article")).toHaveCount(2);
  const wordmarkBox = await page
    .getByRole("banner")
    .getByRole("link", { name: "Rise Pals" })
    .boundingBox();
  const languageBox = await page.getByRole("navigation", { name: "Choose language" }).boundingBox();
  expect(Math.abs((wordmarkBox?.y ?? 0) - (languageBox?.y ?? 0))).toBeLessThan(32);
});

for (const locale of ["th", "en"] as const) {
  test(`${locale} initial page load makes no unexpected third-party request`, async ({ page }) => {
    const unexpectedOrigins = new Set<string>();
    page.on("request", (request) => {
      const url = new URL(request.url());
      if (url.hostname !== "127.0.0.1") {
        unexpectedOrigins.add(url.origin);
      }
    });

    await page.goto(`/${locale}`);
    await page.waitForLoadState("networkidle");

    expect([...unexpectedOrigins]).toEqual([]);
  });
}

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
