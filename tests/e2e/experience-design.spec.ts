import { expect, test } from "./fixtures";

for (const locale of ["th", "en"] as const) {
  test(`${locale} skill exploration works by keyboard without creating a score or saved identity`, async ({
    page,
  }) => {
    await page.goto(`/${locale}`);
    const explorer = page.locator(".skill-explorer");
    const before = await page.evaluate(() => ({
      local: { ...localStorage },
      session: { ...sessionStorage },
      cookie: document.cookie,
    }));
    const ethics = explorer.getByRole("button", {
      name: locale === "th" ? "ใช้ข้อมูลอย่างรับผิดชอบ" : "Act responsibly",
    });
    await ethics.focus();
    await page.keyboard.press("Enter");
    await expect(ethics).toHaveAttribute("aria-pressed", "true");
    await expect(explorer.locator('[aria-pressed="true"]')).toHaveCount(1);
    await expect(page.locator("#skill-explorer-detail")).toContainText(
      locale === "th" ? "ใช้ข้อมูลอย่างรับผิดชอบ" : "Act responsibly",
    );
    await expect(page.locator("[data-score], [data-result], input, form")).toHaveCount(0);
    expect(
      await page.evaluate(() => ({
        local: { ...localStorage },
        session: { ...sessionStorage },
        cookie: document.cookie,
      })),
    ).toEqual(before);
    await page.reload();
    await expect(
      explorer.getByRole("button", { name: locale === "th" ? "คิดก่อนเชื่อ" : "Think critically" }),
    ).toHaveAttribute("aria-pressed", "true");
  });

  test(`${locale} practice entry and lesson shortcuts reach working content`, async ({ page }) => {
    await page.goto(`/${locale}`);
    await page.locator(".mission-link").click();
    await expect(page).toHaveURL(new RegExp(`/${locale}/lessons/source-verification-practice$`));
    const shortcut = page.locator('.lesson-quick-nav a[href="#lesson-practice-heading"]');
    await shortcut.click();
    const heading = page.locator("#lesson-practice-heading");
    await expect(heading).toBeInViewport();
    const headingBox = await heading.boundingBox();
    const headerBox = await page.locator(".site-header").boundingBox();
    expect(headingBox?.y ?? 0).toBeGreaterThanOrEqual((headerBox?.height ?? 0) - 1);
  });
}

test("the mobile skill map keeps all eight touch targets inside the viewport", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.goto("/th");
  const targets = page.locator(".skill-orbit__node");
  await expect(targets).toHaveCount(8);
  for (const target of await targets.all()) {
    const box = await target.boundingBox();
    expect(box?.width).toBeGreaterThanOrEqual(44);
    expect(box?.height).toBeGreaterThanOrEqual(44);
    expect(box?.x).toBeGreaterThanOrEqual(0);
    expect((box?.x ?? 0) + (box?.width ?? 0)).toBeLessThanOrEqual(320);
  }
});

for (const locale of ["th", "en"] as const) {
  test(`${locale} keeps the first visit concise and expands references by keyboard`, async ({
    page,
  }) => {
    await page.goto(`/${locale}`);
    const text = await page.locator("main").innerText();
    expect(text.length).toBeLessThan(1400);
    if (locale === "th") {
      // Proper names and AI are intentional; everyday UI labels must be Thai.
      expect(text.replaceAll("AI", "")).not.toMatch(/[A-Za-z]{2,}/);
    }
    const disclosure = page.locator("#why-now details");
    await expect(disclosure).not.toHaveAttribute("open", "");
    const summary = disclosure.locator("summary");
    await summary.focus();
    await page.keyboard.press("Enter");
    await expect(disclosure).toHaveAttribute("open", "");
    await expect(disclosure.getByRole("article")).toHaveCount(2);
    await expect(disclosure.getByRole("link")).toHaveCount(2);
    await page.keyboard.press("Space");
    await expect(disclosure).not.toHaveAttribute("open", "");
    await expect(summary).toBeFocused();
  });
}

test("references stay readable without JavaScript and reflow on a small screen", async ({
  browser,
}) => {
  const context = await browser.newContext({
    javaScriptEnabled: false,
    viewport: { width: 320, height: 800 },
  });
  const page = await context.newPage();
  await page.goto("http://127.0.0.1:3104/th");
  for (const selector of ["#skill-framework", "#why-now"]) {
    const section = page.locator(selector);
    await section.locator("summary").click();
    await expect(section.locator("details")).toHaveAttribute("open", "");
  }
  await expect(page.locator("#why-now").getByRole("article")).toHaveCount(2);
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(320);
  await context.close();
});
