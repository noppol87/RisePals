import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page, type Request } from "./fixtures";
import { sourceVerificationMission } from "../../src/modules/lesson/source-verification/mission-v2";

const path = "/lessons/source-verification-practice";
const cases = sourceVerificationMission.cases;
type Locale = "th" | "en";
const label = (locale: Locale, th: string, en: string) => (locale === "th" ? th : en);
async function begin(page: Page, locale: Locale = "en") {
  await page
    .getByRole("button", { name: label(locale, "เริ่มเช็กสรุปนี้", "Check this summary") })
    .click();
}
async function answer(
  page: Page,
  caseIndex: number,
  locale: Locale = "en",
  firstOnly = false,
  scan = false,
) {
  for (const [index, question] of cases[caseIndex]!.questions.entries()) {
    if (scan) await checkAccess(page);
    const option = firstOnly ? question.options[0]! : question.options.find((o) => o.correct)!;
    await page.getByRole("radio", { name: option.label[locale] }).check();
    if (caseIndex === 0) {
      await page
        .getByRole("button", { name: label(locale, "เช็กคำตอบ", "Check my choice") })
        .click();
      await expect(page.getByRole("status")).toContainText(option.reason[locale]);
    } else await expect(page.getByRole("status")).toHaveCount(0);
    if (index === 2)
      await expect(page.locator(".mission-live-note")).toContainText(option.label[locale]);
    await page
      .getByRole("button", {
        name:
          index === 3
            ? label(locale, "ดูสรุปของฉัน", "See my summary")
            : label(locale, "ไปต่อ", "Continue"),
      })
      .click();
  }
}
async function checkAccess(page: Page) {
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();
  const blocking = results.violations.filter(
    (v) => v.impact === "serious" || v.impact === "critical",
  );
  expect(blocking).toEqual([]);
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= document.documentElement.clientWidth,
    ),
  ).toBe(true);
}
for (const locale of ["th", "en"] as const) {
  test(`${locale} mission-first entry, coached artifact and independent case work with accessible steps`, async ({
    page,
  }) => {
    await page.goto(`/${locale}`);
    await page.locator(".landing-hero .narrative-cta").click();
    await expect(page).toHaveURL(`/${locale}${path}`);
    expect((await page.locator("main").innerText()).length).toBeLessThan(900);
    await checkAccess(page);
    await begin(page, locale);
    await expect(page.locator("#mission-question")).toBeFocused();
    await expect(page.locator(".mission-facts")).toBeVisible();
    await expect(page.locator('[data-missing="true"] .mission-fact-bar')).toHaveCount(0);
    await answer(page, 0, locale, false, true);
    await expect(
      page.getByRole("heading", {
        name: label(locale, "คุณแก้สรุปนี้ได้แล้ว", "You fixed this summary"),
      }),
    ).toBeFocused();
    await expect(page.locator(".mission-before-after")).toBeVisible();
    await checkAccess(page);
    await page
      .getByRole("button", { name: label(locale, "ลองอีกสถานการณ์", "Try a new situation") })
      .click();
    await begin(page, locale);
    await answer(page, 1, locale, false, true);
    await expect(
      page.getByRole("heading", {
        name: label(locale, "คุณแก้สรุปนี้ได้แล้ว", "You fixed this summary"),
      }),
    ).toBeFocused();
    await checkAccess(page);
    await expect(
      page.getByRole("link", { name: label(locale, "กลับไปดูทักษะอื่น", "Explore other skills") }),
    ).toHaveAttribute("href", `/${locale}#skill-framework`);
  });
}

test("coaching validates, blocks an incorrect choice, and preserves Back selections", async ({
  page,
}) => {
  await page.goto(`/en${path}`);
  await page.keyboard.press("Tab");
  await expect(page.getByRole("link", { name: "Skip to main content" })).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("main")).toBeFocused();
  await begin(page);
  await page.getByRole("button", { name: "Check my choice" }).click();
  await expect(page.locator("#mission-error")).toBeFocused();
  await page.getByRole("radio").first().check();
  await page.getByRole("button", { name: "Check my choice" }).click();
  await expect(page.getByRole("status")).toContainText("Take another look");
  await expect(page.getByRole("button", { name: "Continue" })).toHaveCount(0);
  await page.getByRole("radio").nth(2).focus();
  await page.keyboard.press("Space");
  await page.getByRole("button", { name: "Check my choice" }).click();
  await page.getByRole("button", { name: "Continue" }).click();
  await page.getByRole("button", { name: "Back", exact: true }).click();
  await expect(page.getByRole("radio").nth(2)).toBeChecked();
  await page.locator(".mission-source-details summary").click();
  await expect(page.locator(".mission-source-details")).toContainText("40");
});

test("same-position guessing fails the independent case, preserves the actual draft and resets cleanly", async ({
  page,
}) => {
  await page.goto(`/en${path}`);
  await begin(page);
  await answer(page, 0);
  await page.getByRole("button", { name: "Try a new situation" }).click();
  await begin(page);
  await answer(page, 1, "en", true);
  await expect(page.getByRole("heading", { name: "A few things need another look" })).toBeFocused();
  await expect(page.locator(".mission-after")).toContainText(
    cases[1]!.questions[3]!.options[0]!.label.en,
  );
  await expect(page.locator(".mission-after")).toHaveAttribute("data-correct", "false");
  await checkAccess(page);
  await page.getByRole("button", { name: "Try this case again" }).click();
  await begin(page);
  await expect(page.locator("input:checked")).toHaveCount(0);
  await page.reload();
  await expect(page.getByText("FIRST MISSION · WITH GUIDANCE")).toBeVisible();
  await begin(page);
  await expect(page.locator("input:checked")).toHaveCount(0);
});

test("practice choices never enter storage, cookies, URLs, logs or network payloads", async ({
  context,
  page,
}) => {
  const requests: Request[] = [];
  const logs: string[] = [];
  page.on("request", (r) => requests.push(r));
  page.on("console", (m) => logs.push(m.text()));
  await page.addInitScript(() => {
    const operations: string[] = [];
    Object.defineProperty(window, "__missionStorage", { value: operations });
    for (const key of ["getItem", "setItem", "removeItem", "clear"] as const) {
      const original = Storage.prototype[key];
      Object.defineProperty(Storage.prototype, key, {
        value: function (...args: string[]) {
          operations.push(`${key}:${args[0] ?? ""}`);
          return Reflect.apply(original, this, args);
        },
      });
    }
  });
  await page.goto(`/en${path}`);
  await begin(page);
  await answer(page, 0);
  await page.getByRole("button", { name: "Try a new situation" }).click();
  await begin(page);
  await answer(page, 1);
  await page.waitForLoadState("networkidle");
  const operations = await page.evaluate(
    () => (window as typeof window & { __missionStorage: string[] }).__missionStorage,
  );
  expect(operations.filter((s) => !s.startsWith("setItem:__next_debug_channel:"))).toEqual([]);
  expect(new URL(page.url()).search).toBe("");
  expect(new URL(page.url()).hash).toBe("");
  for (const request of requests) {
    expect(request.postData()).toBeNull();
    expect(request.url()).not.toContain("everyone-evening");
  }
  expect(logs.join(" ")).not.toContain("everyone-evening");
  expect(JSON.stringify(await context.cookies())).not.toContain("everyone-evening");
});

for (const reducedMotion of ["no-preference", "reduce"] as const) {
  test(`${reducedMotion} supports 320px touch targets and readable mobile results`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 320, height: 800 });
    await page.emulateMedia({ reducedMotion });
    await page.goto(`/th${path}`);
    const start = page.getByRole("button", { name: "เริ่มเช็กสรุปนี้" });
    await expect(start).toBeInViewport();
    await begin(page, "th");
    for (const [index, q] of cases[0]!.questions.entries()) {
      await checkAccess(page);
      for (const target of await page.locator(".mission-option, .mission-actions button").all()) {
        const box = await target.boundingBox();
        expect(box!.height).toBeGreaterThanOrEqual(44);
        expect(box!.x).toBeGreaterThanOrEqual(0);
        expect(box!.x + box!.width).toBeLessThanOrEqual(320);
      }
      await page.getByRole("radio", { name: q.options.find((o) => o.correct)!.label.th }).check();
      await page.getByRole("button", { name: "เช็กคำตอบ" }).click();
      await page.getByRole("button", { name: index === 3 ? "ดูสรุปของฉัน" : "ไปต่อ" }).click();
    }
    await checkAccess(page);
    if (reducedMotion === "reduce")
      expect(await page.evaluate(() => document.getAnimations().length)).toBe(0);
  });
}

test("example-result entry, locale switching and metadata preserve demo boundaries", async ({
  page,
}) => {
  await page.goto("/en/assessment/example-result");
  await page.getByRole("link", { name: "Try this lesson" }).click();
  await expect(page).toHaveURL(`/en${path}`);
  await page.getByRole("link", { name: "ไทย" }).click();
  await expect(page).toHaveURL(`/th${path}`);
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute(
    "content",
    /noindex.*noarchive|noarchive.*noindex/,
  );
  const response = await page.goto(`/fr${path}`);
  expect(response?.status()).toBe(404);
});
