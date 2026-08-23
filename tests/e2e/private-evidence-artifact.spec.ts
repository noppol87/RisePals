import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "./fixtures";
import { evidenceCopy } from "@/modules/evidence/copy";

async function expectNoHorizontalOverflow(page: Page) {
  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
}

for (const locale of ["th", "en"] as const) {
  test(`${locale} private evidence routes fail closed without Clerk and remain loopback-only`, async ({
    page,
  }) => {
    const unexpectedOrigins = new Set<string>();
    const nonGetRequests: string[] = [];
    page.on("request", (request) => {
      const url = new URL(request.url());
      if (url.hostname !== "127.0.0.1") unexpectedOrigins.add(url.origin);
      if (request.method() !== "GET") nonGetRequests.push(request.url());
    });
    await page.goto(`/${locale}/evidence`);
    await expect(page.locator("html")).toHaveAttribute("lang", locale);
    await expect(page.getByRole("heading", { level: 1 })).toHaveText(
      evidenceCopy[locale].indexHeading,
    );
    await expect(page.getByText(evidenceCopy[locale].privateLabel)).toBeVisible();
    await expect(page.getByText(evidenceCopy[locale].noSharing)).toBeVisible();
    await expect(page.locator("form, input")).toHaveCount(0);
    await page.goto(`/${locale}/evidence/source-verification-note`);
    await expect(page.getByRole("heading", { level: 1 })).toHaveText(
      evidenceCopy[locale].unavailableHeading,
    );
    await expect(page.locator("form, input")).toHaveCount(0);
    await page.waitForLoadState("networkidle");
    expect([...unexpectedOrigins]).toEqual([]);
    expect(nonGetRequests).toEqual([]);
    expect(new URL(page.url()).search).toBe("");
    expect(new URL(page.url()).hash).toBe("");
  });

  test(`${locale} private evidence shell supports 320px, reduced motion and axe`, async ({
    page,
  }) => {
    await page.emulateMedia({ reducedMotion: "reduce" });
    await page.setViewportSize({ width: 320, height: 800 });
    await page.goto(`/${locale}/evidence`);
    await expectNoHorizontalOverflow(page);
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
      .analyze();
    expect(
      results.violations.filter(
        (violation) => violation.impact === "serious" || violation.impact === "critical",
      ),
    ).toEqual([]);
  });
}

test("private evidence language switches preserve only fixed same-locale routes", async ({
  page,
}) => {
  await page.goto("/th/evidence");
  await page.getByRole("link", { name: "English" }).click();
  await expect(page).toHaveURL(/\/en\/evidence$/u);
  await page.goto("/th/evidence/source-verification-note");
  await page.getByRole("link", { name: "English" }).click();
  await expect(page).toHaveURL(/\/en\/evidence\/source-verification-note$/u);
  expect(new URL(page.url()).search).toBe("");
  expect(new URL(page.url()).hash).toBe("");
});
