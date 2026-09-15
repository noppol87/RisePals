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
    const ethics = explorer.getByRole("button", { name: "Ethical Judgement & Governance" });
    await ethics.focus();
    await page.keyboard.press("Enter");
    await expect(ethics).toHaveAttribute("aria-pressed", "true");
    await expect(explorer.locator('[aria-pressed="true"]')).toHaveCount(1);
    await expect(page.locator("#skill-explorer-detail")).toContainText(
      "Ethical Judgement & Governance",
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
      explorer.getByRole("button", { name: "Critical Thinking & Fact-Checking" }),
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
