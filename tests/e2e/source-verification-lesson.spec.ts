import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page, type Request } from "./fixtures";

const lessonPath = "/lessons/source-verification-practice";
const selectedOptionId = "trace-claim-to-source-map";

async function expectNoHorizontalOverflow(page: Page) {
  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
}

async function enterPractice(page: Page) {
  await page.locator(".guided-steps button").nth(2).click();
}
async function answerAll(page: Page, correct = true) {
  await enterPractice(page);
  for (let index = 0; index < 3; index++) {
    await page
      .getByRole("radio")
      .nth(correct ? 0 : 1)
      .check();
    if (index < 2) await page.getByRole("button", { name: "Next question" }).click();
  }
}

for (const locale of ["th", "en"] as const) {
  test(`${locale} starts with a clear action, then visual evidence and one question`, async ({
    page,
  }) => {
    await page.goto(`/${locale}${lessonPath}`);
    await expect(page.locator("html")).toHaveAttribute("lang", locale);
    expect((await page.locator("main").innerText()).length).toBeLessThan(900);
    await expect(page.getByRole("radio")).toHaveCount(0);
    const start = page.getByRole("button", {
      name: locale === "th" ? "เริ่มเช็กสรุปนี้" : "Check this summary",
    });
    await start.focus();
    await page.keyboard.press("Enter");
    await expect(page.locator("#lesson-source-pack-heading")).toBeFocused();
    await expect(page.locator(".guided-sources .team-chart")).toHaveCount(3);
    await expect(page.locator(".guided-sources").getByText("30%", { exact: true })).toBeVisible();
    await expect(page.locator(".guided-sources").getByText("8%", { exact: true })).toBeVisible();
    await expect(
      page
        .locator(".guided-sources")
        .getByText(locale === "th" ? "ยังไม่รู้" : "Unknown", { exact: true }),
    ).toBeVisible();
    await expect(
      page.locator('.guided-sources [data-missing="true"] .team-chart__bar'),
    ).toHaveCount(0);
    await page
      .locator(".guided-sources .lesson-source-original")
      .first()
      .locator("summary")
      .click();
    await expect(
      page
        .locator(".guided-sources .lesson-source-original")
        .first()
        .getByText(locale === "th" ? /12 รายการ/ : /12/),
    ).toBeVisible();
    await page
      .getByRole("button", { name: locale === "th" ? "ลองตอบจากที่เห็น" : "Try a question" })
      .click();
    await expect(page.locator("#lesson-practice-heading")).toBeFocused();
    await expect(page.getByRole("radio")).toHaveCount(3);
    await page.locator(".guided-recall > summary").click();
    await expect(page.locator(".guided-recall .team-comparison")).toBeVisible();
    await expect(page.locator('input[type="file"],textarea,input[type="text"]')).toHaveCount(0);
    const extras = page.locator(".guided-extras");
    await extras.locator(":scope > summary").click();
    for (const summary of await extras.locator("details > summary").all()) await summary.click();
    await expect(page.getByText("lesson-source-verification-practice-v1")).toBeVisible();
    await expect(page.getByText("published", { exact: true })).toBeVisible();
    await expect(page.getByText("prototype-unvalidated", { exact: true })).toBeVisible();
    await expect(page.locator(".lesson-proof")).toContainText(
      locale === "th"
        ? "ยังพิมพ์ข้อความ อัปโหลด หรือบันทึกไฟล์ไม่ได้"
        : "No text entry, uploads or saved files.",
    );
  });
}

test("the result-to-lesson link is locale matched and explicitly non-personalized", async ({
  page,
}) => {
  await page.goto("/en/assessment/example-result");
  await expect(
    page.getByText("An example lesson, not a recommendation based on your choices."),
  ).toBeVisible();
  await page.getByRole("link", { name: "Try this lesson" }).click();
  await expect(page).toHaveURL(`/en${lessonPath}`);

  await page.getByRole("link", { name: "ไทย" }).click();
  await expect(page).toHaveURL(`/th${lessonPath}`);
  await expect(page.locator("html")).toHaveAttribute("lang", "th");
});

test("guided questions validate, preserve Back selections, and never accumulate XP", async ({
  page,
}) => {
  await page.goto(`/en${lessonPath}`);
  await page.keyboard.press("Tab");
  await expect(page.getByRole("link", { name: "Skip to main content" })).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("main")).toBeFocused();
  await enterPractice(page);
  await page.getByRole("button", { name: "Next question" }).click();
  await expect(page.locator("#lesson-practice-error")).toBeFocused();
  await expect(page.locator("#lesson-practice-error")).toContainText("Choose an answer first.");
  await page.getByRole("radio").nth(0).check();
  await page.getByRole("button", { name: "Next question" }).click();
  await page.getByRole("button", { name: "Back", exact: true }).click();
  await expect(page.getByRole("radio").nth(0)).toBeChecked();
  for (let i = 0; i < 3; i++) {
    await page
      .getByRole("radio")
      .nth(i === 1 ? 1 : 0)
      .check();
    if (i < 2) await page.getByRole("button", { name: "Next question" }).click();
  }
  await page.getByRole("button", { name: "See how you did" }).click();
  await expect(
    page.getByRole("heading", { name: "Review at least one criterion before using the summary" }),
  ).toBeFocused();
  await expect(page.getByText("XP rule preview: 0 XP")).toBeVisible();
  await page.getByRole("button", { name: "Try again" }).click();
  await expect(page.locator("#lesson-practice-heading")).toBeFocused();
  await answerAll(page);
  await page.getByRole("button", { name: "See how you did" }).click();
  await expect(
    page.getByRole("heading", { name: "All three criteria are met in this synthetic practice" }),
  ).toBeFocused();
  await expect(page.getByText("XP rule preview: 20 XP")).toBeVisible();
  await expect(page.getByText(/not saved.*never accumulates/i)).toBeVisible();
  await page.getByRole("button", { name: "Try again" }).click();
  await answerAll(page);
  await page.getByRole("button", { name: "See how you did" }).click();
  await expect(page.getByText("XP rule preview: 20 XP")).toBeVisible();
  await expect(page.getByText(/40 XP/)).toHaveCount(0);
  await page.getByRole("button", { name: "Clear answers" }).click();
  for (let i = 0; i < 3; i++) {
    await expect(page.getByRole("radio").nth(0)).not.toBeChecked();
    if (i < 2) {
      await page.getByRole("radio").nth(1).check();
      await page.getByRole("button", { name: "Next question" }).click();
    }
  }
});

test("refresh discards every in-memory practice choice and feedback state", async ({ page }) => {
  await page.goto(`/en${lessonPath}`);
  await answerAll(page);
  await page.getByRole("button", { name: "See how you did" }).click();
  await expect(page.getByText("XP rule preview: 20 XP")).toBeVisible();

  await page.reload();
  await expect(page.getByRole("radio")).toHaveCount(0);
  await enterPractice(page);
  await expect(page.getByRole("radio").first()).not.toBeChecked();
  await expect(page.locator(".lesson-feedback")).toHaveCount(0);
});

test("lesson practice never uses storage, cookies, logs, URLs or network requests for choices", async ({
  context,
  page,
}) => {
  const requests: Request[] = [];
  const consoleMessages: string[] = [];
  page.on("request", (request) => requests.push(request));
  page.on("console", (message) => consoleMessages.push(message.text()));
  await page.addInitScript(() => {
    const operations: string[] = [];
    Object.defineProperty(window, "__risePalsStorageOperations", { value: operations });
    const originalGetItem = Storage.prototype.getItem;
    const originalSetItem = Storage.prototype.setItem;
    const originalRemoveItem = Storage.prototype.removeItem;
    const originalClear = Storage.prototype.clear;
    Storage.prototype.getItem = function (key: string) {
      operations.push(`getItem:${key}`);
      return originalGetItem.call(this, key);
    };
    Storage.prototype.setItem = function (key: string, value: string) {
      operations.push(`setItem:${key}`);
      return originalSetItem.call(this, key, value);
    };
    Storage.prototype.removeItem = function (key: string) {
      operations.push(`removeItem:${key}`);
      return originalRemoveItem.call(this, key);
    };
    Storage.prototype.clear = function () {
      operations.push("clear");
      return originalClear.call(this);
    };
  });

  await page.goto(`/en${lessonPath}`);
  await answerAll(page);
  await page.getByRole("button", { name: "See how you did" }).click();
  await page.waitForLoadState("networkidle");

  const operations = await page.evaluate(
    () =>
      (window as typeof window & { __risePalsStorageOperations: string[] })
        .__risePalsStorageOperations,
  );
  expect(
    operations.filter((operation) => !operation.startsWith("setItem:__next_debug_channel:")),
  ).toEqual([]);
  expect(new URL(page.url()).search).toBe("");
  expect(consoleMessages.join("\n")).not.toContain(selectedOptionId);
  for (const request of requests) {
    expect(new URL(request.url()).hostname).toBe("127.0.0.1");
    expect(request.postData()).toBeNull();
    expect(request.url()).not.toContain(selectedOptionId);
  }
  for (const cookie of await context.cookies()) {
    expect(`${cookie.name}=${cookie.value}`).not.toContain(selectedOptionId);
  }
});

for (const reducedMotion of ["no-preference", "reduce"] as const) {
  test(`${reducedMotion} motion and 320px reflow preserve the lesson and controls`, async ({
    page,
  }) => {
    await page.emulateMedia({ reducedMotion });
    await page.setViewportSize({ width: 320, height: 800 });
    await page.goto(`/th${lessonPath}`);

    await expectNoHorizontalOverflow(page);
    await page.getByRole("button", { name: "เริ่มเช็กสรุปนี้" }).click();
    await expectNoHorizontalOverflow(page);
    await page.getByRole("button", { name: "ลองตอบจากที่เห็น" }).click();
    await expectNoHorizontalOverflow(page);
    await expect(page.getByRole("radio")).toHaveCount(3);
    for (const control of await page.locator("main").getByRole("button").all()) {
      const box = await control.boundingBox();
      expect(box?.height).toBeGreaterThanOrEqual(44);
      expect(box?.x).toBeGreaterThanOrEqual(0);
      expect((box?.x ?? 0) + (box?.width ?? 0)).toBeLessThanOrEqual(320);
    }
    if (reducedMotion === "reduce") {
      expect(await page.evaluate(() => document.getAnimations().length)).toBe(0);
    }
  });
}

for (const locale of ["th", "en"] as const) {
  test(`${locale} lesson has no serious or critical axe violations`, async ({ page }) => {
    await page.goto(`/${locale}${lessonPath}`);
    for (let stage = 0; stage < 3; stage++) {
      await page.locator(".guided-steps button").nth(stage).click();
      const results = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
        .analyze();
      const blocking = results.violations.filter(
        (violation) => violation.impact === "serious" || violation.impact === "critical",
      );
      expect(blocking, JSON.stringify(blocking, null, 2)).toEqual([]);
    }
  });
}

test("lesson metadata blocks indexing and unsupported locale fails", async ({ page }) => {
  await page.goto(`/en${lessonPath}`);
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute(
    "content",
    /noindex.*noarchive|noarchive.*noindex/,
  );

  const response = await page.goto(`/fr${lessonPath}`);
  expect(response?.status()).toBe(404);
});
