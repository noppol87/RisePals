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

async function answerAll(page: Page, correct = true) {
  for (const group of await page.getByRole("group").all()) {
    const radios = group.getByRole("radio");
    await radios.nth(correct ? 0 : 1).check();
  }
}

for (const locale of ["th", "en"] as const) {
  test(`${locale} renders the full versioned lesson, transparent rubric and proof placeholder`, async ({
    page,
  }) => {
    await page.goto(`/${locale}${lessonPath}`);

    await expect(page.locator("html")).toHaveAttribute("lang", locale);
    await expect(page.getByText("lesson-source-verification-practice-v1")).toBeVisible();
    await expect(page.getByText("1.0.0")).toBeVisible();
    await expect(page.getByText("published", { exact: true })).toBeVisible();
    await expect(page.getByText("prototype-unvalidated", { exact: true })).toBeVisible();
    await expect(page.getByText("Practicing")).toBeVisible();
    await expect(page.getByText("Intelligent Risk & Governance")).toBeVisible();
    await expect(page.getByText("Bright River Operations")).toBeVisible();
    await expect(page.getByRole("group")).toHaveCount(3);
    await expect(page.getByRole("radio")).toHaveCount(9);
    await expect(page.locator('input[type="file"], textarea, input[type="text"]')).toHaveCount(0);
    await expect(page.getByText(/20 XP/)).toHaveCount(1);
    await expect(page.locator(".lesson-feedback")).toHaveCount(0);
    await expect(page.locator(".lesson-proof")).toContainText(
      locale === "th"
        ? "ไม่มีช่องข้อความ การอัปโหลด การสร้างไฟล์ หรือการจัดเก็บหลักฐาน"
        : "no text field, upload, artifact creation, or storage",
    );
  });
}

test("the result-to-lesson link is locale matched and explicitly non-personalized", async ({
  page,
}) => {
  await page.goto("/en/assessment/example-result");
  await expect(
    page.getByText(
      "The result above remains a fixed synthetic example. This lesson is a prototype, and the link is not a personalized recommendation.",
    ),
  ).toBeVisible();
  await page.getByRole("link", { name: "Open the source-verification lesson prototype" }).click();
  await expect(page).toHaveURL(`/en${lessonPath}`);

  await page.getByRole("link", { name: "ไทย" }).click();
  await expect(page).toHaveURL(`/th${lessonPath}`);
  await expect(page.locator("html")).toHaveAttribute("lang", "th");
});

test("keyboard flow focuses incomplete and criterion feedback, then retry and reset do not accumulate XP", async ({
  page,
}) => {
  await page.goto(`/en${lessonPath}`);
  await page.keyboard.press("Tab");
  await expect(page.getByRole("link", { name: "Skip to main content" })).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("main")).toBeFocused();

  await page.getByRole("button", { name: "Review rubric feedback" }).click();
  const error = page.locator("#lesson-practice-error");
  await expect(error).toBeFocused();
  await expect(error).toContainText("Choose one response for all three criteria");

  const groups = page.getByRole("group");
  await groups.nth(0).getByRole("radio").nth(0).check();
  await groups.nth(1).getByRole("radio").nth(1).check();
  await groups.nth(2).getByRole("radio").nth(0).check();
  await page.getByRole("button", { name: "Review rubric feedback" }).click();
  await expect(
    page.getByRole("heading", { name: "Review at least one criterion before using the summary" }),
  ).toBeFocused();
  await expect(page.getByText("XP rule preview: 0 XP")).toBeVisible();

  await page.getByRole("button", { name: "Revise choices and try again" }).click();
  await expect(
    page.getByRole("heading", { name: "Choose the safest verification response" }),
  ).toBeFocused();
  await answerAll(page);
  await page.getByRole("button", { name: "Review rubric feedback" }).click();
  await expect(
    page.getByRole("heading", { name: "All three criteria are met in this synthetic practice" }),
  ).toBeFocused();
  await expect(page.getByText("XP rule preview: 20 XP")).toBeVisible();
  await expect(page.getByText(/not saved.*never accumulates/i)).toBeVisible();

  await page.getByRole("button", { name: "Revise choices and try again" }).click();
  await page.getByRole("button", { name: "Review rubric feedback" }).click();
  await expect(page.getByText("XP rule preview: 20 XP")).toBeVisible();
  await expect(page.getByText(/40 XP/)).toHaveCount(0);

  await page.getByRole("button", { name: "Clear choices on this page" }).click();
  await expect(page.getByRole("radio").first()).not.toBeChecked();
  await expect(page.locator(".lesson-feedback")).toHaveCount(0);
});

test("refresh discards every in-memory practice choice and feedback state", async ({ page }) => {
  await page.goto(`/en${lessonPath}`);
  await answerAll(page);
  await page.getByRole("button", { name: "Review rubric feedback" }).click();
  await expect(page.getByText("XP rule preview: 20 XP")).toBeVisible();

  await page.reload();
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
  await page.getByRole("button", { name: "Review rubric feedback" }).click();
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
    await expect(page.getByRole("radio")).toHaveCount(9);
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
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
      .analyze();
    const blocking = results.violations.filter(
      (violation) => violation.impact === "serious" || violation.impact === "critical",
    );
    expect(blocking, JSON.stringify(blocking, null, 2)).toEqual([]);
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
