import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page, type Request } from "@playwright/test";

const storageKey = "rise-pals:assessment-player:v1";
const selectedOptionId = "test-process-assumption-roll-out";

async function expectNoHorizontalOverflow(page: Page) {
  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
}

for (const locale of ["th", "en"] as const) {
  test(`${locale} renders the complete static synthetic example with text-equivalent signals`, async ({
    page,
  }) => {
    await page.goto(`/${locale}/assessment/example-result`);

    await expect(page.locator("html")).toHaveAttribute("lang", locale);
    await expect(page.getByRole("heading", { level: 1 })).toContainText(
      locale === "th" ? "แผนที่สัญญาณทักษะ" : "skill-signal map",
    );
    await expect(
      page.getByText(
        locale === "th"
          ? "ตัวอย่างเท่านั้น — ไม่ใช่ผลของคุณ"
          : "Example only — this is not your result",
      ),
    ).toBeVisible();
    await expect(page.getByText("synthetic-mixed-review").first()).toBeVisible();
    await expect(page.getByRole("figure")).toHaveCount(2);
    await expect(page.locator(".example-signal__segment")).toHaveCount(8);
    await expect(page.locator(".example-signal__segment--filled")).toHaveCount(4);
    await expect(page.locator(".example-signal__segments").first()).toHaveAttribute(
      "aria-hidden",
      "true",
    );
    await expect(
      page.getByText(
        locale === "th"
          ? "แต้มหลักฐานดิบ 1 จาก 4 แต้มที่เป็นไปได้ในชุดจำลองนี้"
          : "1 of 4 possible raw evidence points in this synthetic fixture",
      ),
    ).toBeVisible();

    const unassessedSection = page
      .getByRole("heading", {
        name:
          locale === "th"
            ? "ทักษะหลักอีก 6 ด้านที่ยังไม่มีหลักฐาน"
            : "6 core competencies with no evidence in this fixture",
      })
      .locator("xpath=../..");
    await expect(unassessedSection.getByRole("listitem")).toHaveCount(6);
    await expect(
      page.getByText(locale === "th" ? "การคิดแบบเจ้าของ" : "Ownership Thinking", {
        exact: true,
      }),
    ).toBeVisible();
    await expect(
      page.getByText(locale === "th" ? "การรับรู้และตอบสนองต่อความเร่งด่วน" : "Sense of Urgency", {
        exact: true,
      }),
    ).toBeVisible();
    await expect(page.getByText("lesson-source-verification-practice-v1")).toBeVisible();
    await expect(
      page.getByText(
        locale === "th"
          ? "ต้นแบบพร้อมให้ทดลอง — ยังไม่ใช่เนื้อหาที่เผยแพร่หรือผ่านการตรวจสอบผลการเรียนรู้"
          : "Prototype available — not published or externally validated learning content",
      ),
    ).toBeVisible();
    await expect(
      page.getByRole("link", {
        name:
          locale === "th"
            ? "เปิดบทเรียนต้นแบบการตรวจสอบแหล่งข้อมูล"
            : "Open the source-verification lesson prototype",
      }),
    ).toHaveAttribute("href", `/${locale}/lessons/source-verification-practice`);
    await expect(page.locator("output, [data-score], [data-result]")).toHaveCount(0);
  });
}

test("keyboard navigation reaches main content and locale switching preserves the example route", async ({
  page,
}) => {
  await page.goto("/th/assessment/example-result");
  await page.keyboard.press("Tab");
  const skipLink = page.getByRole("link", { name: "ข้ามไปยังเนื้อหาหลัก" });
  await expect(skipLink).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("main")).toBeFocused();

  const english = page.getByRole("link", { name: "English" });
  await english.focus();
  await page.keyboard.press("Enter");
  await expect(page).toHaveURL(/\/en\/assessment\/example-result$/);
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
});

for (const reducedMotion of ["no-preference", "reduce"] as const) {
  test(`${reducedMotion} motion and 320px reflow preserve the full example`, async ({ page }) => {
    await page.emulateMedia({ reducedMotion });
    await page.setViewportSize({ width: 320, height: 800 });
    await page.goto("/th/assessment/example-result");

    await expectNoHorizontalOverflow(page);
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    await expect(page.getByText("lesson-source-verification-practice-v1")).toBeVisible();
    for (const link of await page.locator("main").getByRole("link").all()) {
      const box = await link.boundingBox();
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
  test(`${locale} synthetic example has no serious or critical axe violations`, async ({
    page,
  }) => {
    await page.goto(`/${locale}/assessment/example-result`);
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
      .analyze();
    const blocking = results.violations.filter(
      (violation) => violation.impact === "serious" || violation.impact === "critical",
    );
    expect(blocking, JSON.stringify(blocking, null, 2)).toEqual([]);
  });
}

test("the result route never reads player storage or exposes answer data in browser boundaries", async ({
  context,
  page,
}) => {
  const requests: Request[] = [];
  const consoleMessages: string[] = [];
  page.on("request", (request) => requests.push(request));
  page.on("console", (message) => consoleMessages.push(message.text()));
  await page.addInitScript(
    ({ key, optionId }) => {
      sessionStorage.setItem(
        key,
        JSON.stringify({
          schemaVersion: 1,
          assessmentVersionId: "assessment-workplace-scenarios-fixture-v1",
          phase: "question",
          currentItemKey: "test-process-assumption",
          selections: [{ itemKey: "test-process-assumption", optionId }],
        }),
      );
      const originalGetItem = Storage.prototype.getItem;
      const reads: string[] = [];
      Object.defineProperty(window, "__risePalsStorageReads", { value: reads });
      Storage.prototype.getItem = function (storageKeyValue: string) {
        reads.push(storageKeyValue);
        return originalGetItem.call(this, storageKeyValue);
      };
    },
    { key: storageKey, optionId: selectedOptionId },
  );

  await page.goto("/en/assessment/example-result");
  await page.waitForLoadState("networkidle");

  const storageReads = await page.evaluate(
    () => (window as typeof window & { __risePalsStorageReads: string[] }).__risePalsStorageReads,
  );
  expect(storageReads).not.toContain(storageKey);
  expect(new URL(page.url()).search).toBe("");
  await expect(page.locator("body")).not.toContainText(selectedOptionId);
  expect(consoleMessages.join("\n")).not.toContain(selectedOptionId);
  for (const request of requests) {
    const url = new URL(request.url());
    expect(url.hostname).toBe("127.0.0.1");
    expect(request.postData()).toBeNull();
    expect(request.url()).not.toContain(selectedOptionId);
  }
  for (const cookie of await context.cookies()) {
    expect(`${cookie.name}=${cookie.value}`).not.toContain(selectedOptionId);
  }
});

test("example metadata blocks indexing and unsupported locale fails", async ({ page }) => {
  await page.goto("/en/assessment/example-result");
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute(
    "content",
    /noindex.*noarchive|noarchive.*noindex/,
  );

  const response = await page.goto("/fr/assessment/example-result");
  expect(response?.status()).toBe(404);
});
