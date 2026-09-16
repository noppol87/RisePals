import { expect, test } from "./fixtures";

for (const locale of ["th", "en"] as const) {
  test(`${locale} first visit finds a starting path by keyboard without creating a score or saved identity`, async ({
    page,
  }) => {
    await page.goto(`/${locale}`);
    const journey = page.locator(".first-visit");
    const before = await page.evaluate(() => ({
      local: { ...localStorage },
      session: { ...sessionStorage },
      cookie: document.cookie,
    }));
    const goal = journey.getByRole("button", {
      name: locale === "th" ? /อยากรับมือวิธีทำงานใหม่/ : /Handle new tools/,
    });
    await goal.focus();
    await page.keyboard.press("Enter");
    const situation = journey.getByRole("button", {
      name: locale === "th" ? /ข้อมูลจาก AI เชื่อได้แค่ไหน/ : /AI answer is reliable/,
    });
    await situation.focus();
    await page.keyboard.press("Enter");
    await expect(
      journey.getByRole("heading", {
        name:
          locale === "th" ? "คิดก่อนเชื่อและใช้ข้อมูลให้ชัวร์" : "Check the evidence before acting",
      }),
    ).toBeVisible();
    await expect(journey.getByRole("link")).toHaveAttribute(
      "href",
      `/${locale}/lessons/source-verification-practice`,
    );
    await expect(
      page.locator("[data-score], [data-result], input, textarea, select, form"),
    ).toHaveCount(0);
    expect(
      await page.evaluate(() => ({
        local: { ...localStorage },
        session: { ...sessionStorage },
        cookie: document.cookie,
      })),
    ).toEqual(before);
    await page.reload();
    await expect(journey.getByRole("heading", { level: 1 })).toContainText(
      locale === "th" ? "อยากให้การทำงานดีขึ้น" : "What would you like to improve",
    );
  });

  test(`${locale} practice entry and lesson shortcuts reach working content`, async ({ page }) => {
    await page.goto(`/${locale}`);
    await page
      .getByRole("button", {
        name: locale === "th" ? /อยากรับมือวิธีทำงานใหม่/ : /Handle new tools/,
      })
      .click();
    await page
      .getByRole("button", {
        name: locale === "th" ? /ข้อมูลจาก AI เชื่อได้แค่ไหน/ : /AI answer is reliable/,
      })
      .click();
    await page
      .getByRole("link", { name: locale === "th" ? /เริ่มภารกิจแรก/ : /Start your first mission/ })
      .click();
    await expect(page).toHaveURL(new RegExp(`/${locale}/lessons/source-verification-practice$`));
    const shortcut = page.getByRole("button", {
      name: locale === "th" ? "ลองหาจุดที่ต้องเช็ก" : "Find what needs checking",
    });
    await shortcut.click();
    const heading = page.locator("#mission-question");
    await expect(heading).toBeFocused();
    await expect(heading).toBeInViewport();
    const headerBox = await page.locator(".site-header").boundingBox();
    await expect
      .poll(async () => (await heading.boundingBox())?.y ?? 0)
      .toBeGreaterThanOrEqual((headerBox?.height ?? 0) - 1);
  });
}

test("the mobile first-visit choices stay usable inside the viewport", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.goto("/th");
  const targets = page.locator(".first-visit__choices button");
  await expect(targets).toHaveCount(4);
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
