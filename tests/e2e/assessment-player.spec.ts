import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page, type Request } from "./fixtures";

const storageKey = "rise-pals:assessment-player:v1";

async function startEnglishPlayer(page: Page) {
  await page.goto("/en/assessment");
  const start = page.getByRole("button", { name: "Start the six-scenario prototype" });
  await expect(start).toBeEnabled();
  await start.focus();
  await page.keyboard.press("Enter");
  await expect(page.getByRole("heading", { name: "Scenario 1" })).toBeFocused();
}

async function chooseFirstResponseByKeyboard(page: Page) {
  const firstRadio = page.getByRole("radio").first();
  await firstRadio.focus();
  await page.keyboard.press("Space");
  await expect(firstRadio).toBeChecked();
}

async function continueByKeyboard(page: Page, finalStep = false) {
  const button = page.getByRole("button", {
    name: finalStep ? "Finish prototype" : "Continue",
  });
  await button.focus();
  await page.keyboard.press("Enter");
}

async function expectNoHorizontalOverflow(page: Page) {
  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
}

test("missing-answer validation is announced and focuses the inline error", async ({ page }) => {
  await startEnglishPlayer(page);
  await page.getByRole("button", { name: "Continue" }).click();

  const error = page.locator("#assessment-answer-error");
  await expect(error).toHaveText("Choose one response before continuing.");
  await expect(error).toBeFocused();
  await expect(page.getByRole("group")).toHaveAttribute("aria-invalid", "true");
});

test("keyboard flow completes six steps without producing a result", async ({ page }) => {
  await startEnglishPlayer(page);

  for (let step = 1; step <= 6; step += 1) {
    await expect(page.getByText(`Scenario ${step} of 6`, { exact: true })).toBeVisible();
    await chooseFirstResponseByKeyboard(page);
    await continueByKeyboard(page, step === 6);
  }

  await expect(
    page.getByRole("heading", { name: "You completed the synthetic scenarios" }),
  ).toBeFocused();
  await expect(page.getByText("Answered 6 of 6 scenarios")).toBeVisible();
  await expect(page.getByText(/calculates and displays no score/)).toBeVisible();
  await expect(page.locator("output, [data-score], [data-result]")).toHaveCount(0);
  await expect(page.getByText(/your score|your proficiency|recommended next step/i)).toHaveCount(0);
  const exampleLink = page.getByRole("link", {
    name: "View a synthetic example result (your choices are not used)",
  });
  await expect(exampleLink).toHaveAttribute("href", "/en/assessment/example-result");
  await expect(page.getByText(/does not read, score, or use the choices/)).toBeVisible();
});

test("Back preserves answers and refresh resumes the same session step", async ({ page }) => {
  await startEnglishPlayer(page);
  const firstChoice = page.getByRole("radio").nth(1);
  await firstChoice.check();
  await page.getByRole("button", { name: "Continue" }).click();
  await page.getByRole("radio").nth(2).check();
  await expect(page.getByText("Answered 2 of 6 scenarios")).toBeVisible();

  await page.getByRole("button", { name: "Back" }).click();
  await expect(page.getByRole("heading", { name: "Scenario 1" })).toBeFocused();
  await expect(page.getByRole("radio").nth(1)).toBeChecked();

  await page.getByRole("button", { name: "Continue" }).click();
  await page.reload();
  await expect(page.getByRole("heading", { name: "Scenario 2" })).toBeVisible();
  await expect(page.getByRole("radio").nth(2)).toBeChecked();
  await expect(
    page.getByText("The step and selections saved temporarily in this tab were restored."),
  ).toBeVisible();
});

test("locale switch preserves the assessment route and temporary progress", async ({ page }) => {
  await startEnglishPlayer(page);
  await page.getByRole("radio").first().check();
  await page.getByRole("button", { name: "Continue" }).click();

  await page.getByRole("link", { name: "ไทย" }).click();
  await expect(page).toHaveURL(/\/th\/assessment$/);
  await expect(page.getByText("สถานการณ์ 2 จาก 6", { exact: true })).toBeVisible();
  await expect(page.getByText("ตอบแล้ว 1 จาก 6 สถานการณ์", { exact: true })).toBeVisible();

  await page.getByRole("link", { name: "English" }).click();
  await expect(page).toHaveURL(/\/en\/assessment$/);
  await expect(page.getByText("Scenario 2 of 6", { exact: true })).toBeVisible();
});

test("clear removes session state and returns to the prototype intro", async ({ page }) => {
  await startEnglishPlayer(page);
  await page.getByRole("radio").first().check();
  await expect
    .poll(() => page.evaluate((key) => sessionStorage.getItem(key), storageKey))
    .not.toBeNull();

  await page.getByRole("button", { name: "Clear responses and return to the start" }).click();
  await expect(
    page.getByRole("heading", {
      name: "Try six synthetic workplace scenarios, one step at a time",
    }),
  ).toBeVisible();
  await expect
    .poll(() => page.evaluate((key) => sessionStorage.getItem(key), storageKey))
    .toBeNull();
  await expect(page.getByText("Temporary selections were cleared.")).toBeVisible();
});

for (const reducedMotion of ["no-preference", "reduce"] as const) {
  test(`${reducedMotion} motion completes a cross-step transition`, async ({ page }) => {
    await page.emulateMedia({ reducedMotion });
    await startEnglishPlayer(page);
    await page.getByRole("radio").first().check();
    await page.getByRole("button", { name: "Continue" }).click();
    await expect(page.getByRole("heading", { name: "Scenario 2" })).toBeFocused();

    if (reducedMotion === "reduce") {
      expect(await page.evaluate(() => document.getAnimations().length)).toBe(0);
    }
  });
}

test("player reflows at 320px and remains logically ordered on desktop", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await startEnglishPlayer(page);
  await expectNoHorizontalOverflow(page);

  for (const control of await page.locator("main").getByRole("button").all()) {
    const box = await control.boundingBox();
    expect(box?.height).toBeGreaterThanOrEqual(44);
    expect(box?.x).toBeGreaterThanOrEqual(0);
    expect((box?.x ?? 0) + (box?.width ?? 0)).toBeLessThanOrEqual(320);
  }
  for (const option of await page.locator(".assessment-option").all()) {
    const box = await option.boundingBox();
    expect(box?.height).toBeGreaterThanOrEqual(44);
    expect(box?.x).toBeGreaterThanOrEqual(0);
    expect((box?.x ?? 0) + (box?.width ?? 0)).toBeLessThanOrEqual(320);
  }

  await page.setViewportSize({ width: 1280, height: 900 });
  await page.reload();
  await expectNoHorizontalOverflow(page);
  await expect(page.locator("legend")).toBeVisible();
  await expect(page.getByRole("radio")).toHaveCount(3);
});

for (const locale of ["th", "en"] as const) {
  test(`${locale} assessment player has no serious or critical axe violations`, async ({
    page,
  }) => {
    await page.goto(`/${locale}/assessment`);
    const start = page
      .getByRole("button")
      .filter({ hasText: locale === "th" ? "เริ่มต้น" : "Start" });
    await expect(start).toBeEnabled();
    await start.click();

    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
      .analyze();
    const blocking = results.violations.filter(
      (violation) => violation.impact === "serious" || violation.impact === "critical",
    );
    expect(blocking, JSON.stringify(blocking, null, 2)).toEqual([]);
  });
}

test("answers stay out of URLs and requests and no third party is contacted", async ({ page }) => {
  const requests: Request[] = [];
  page.on("request", (request) => requests.push(request));

  await startEnglishPlayer(page);
  await page.getByRole("radio").nth(1).check();
  await page.getByRole("button", { name: "Continue" }).click();
  await page.waitForLoadState("networkidle");

  expect(new URL(page.url()).search).toBe("");
  for (const request of requests) {
    const url = new URL(request.url());
    expect(url.hostname).toBe("127.0.0.1");
    expect(request.postData()).toBeNull();
    expect(request.url()).not.toContain("option-");
  }
});

test("prototype metadata blocks indexing and unsupported locale fails", async ({ page }) => {
  await page.goto("/en/assessment");
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute(
    "content",
    /noindex.*noarchive|noarchive.*noindex/,
  );

  const response = await page.goto("/fr/assessment");
  expect(response?.status()).toBe(404);
});
