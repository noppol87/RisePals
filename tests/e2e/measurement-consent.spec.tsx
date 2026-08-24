import AxeBuilder from "@axe-core/playwright";
import { createMeasurementConsentView } from "@/modules/consent/measurement-view";
import { expect, test, type Page } from "./fixtures";

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

async function renderConsent(page: Page, locale: "th" | "en") {
  const view = createMeasurementConsentView(locale, "not-set");
  const paragraphs = [
    view.summary,
    view.fields,
    view.exclusions,
    view.independence,
    view.withdrawal,
  ]
    .map((paragraph) => `<p>${escapeHtml(paragraph)}</p>`)
    .join("");
  const actions = view.actions
    .map(
      (action) =>
        `<button name="decision" value="${action.decision}">${escapeHtml(action.label)}</button>`,
    )
    .join("");
  const markup = `<section aria-labelledby="measurement-consent-heading"><h2 id="measurement-consent-heading">${escapeHtml(view.heading)}</h2>${paragraphs}<p aria-live="polite"><strong>${escapeHtml(view.statusLabel)}:</strong> ${escapeHtml(view.status)}</p><form action="#"><input type="hidden" name="preferredLocale" value="${locale}">${actions}</form></section>`;
  await page.setContent(
    `<!doctype html><html lang="${locale}"><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHtml(view.heading)}</title><style>*,*::before,*::after{box-sizing:border-box}body{margin:0;padding:1rem;font-family:system-ui}.profile-panel{max-width:48rem}.profile-actions{display:flex;flex-wrap:wrap;gap:.75rem}button{min-height:44px;padding:.6rem 1rem}</style></head><body>${markup}</body></html>`,
  );
}

for (const locale of ["th", "en"] as const) {
  test(`${locale} optional measurement consent is explicit, accessible and narrow`, async ({
    page,
  }) => {
    const requests: string[] = [];
    page.on("request", (request) => requests.push(request.url()));
    await page.setViewportSize({ width: 320, height: 800 });
    await page.emulateMedia({ reducedMotion: "reduce" });
    await renderConsent(page, locale);

    await expect(page.locator("html")).toHaveAttribute("lang", locale);
    await expect(page.getByRole("heading", { level: 2 })).toContainText(
      locale === "th" ? "แบบไม่บังคับ" : "Optional measurement",
    );
    await expect(
      page.getByText(locale === "th" ? /ไม่ปิดกั้นการประเมิน/ : /does not block assessment/),
    ).toBeVisible();
    const grant = page.getByRole("button", {
      name: locale === "th" ? "ยินยอมแบบไม่บังคับ" : "Grant optional consent",
    });
    const decline = page.getByRole("button", { name: locale === "th" ? "ปฏิเสธ" : "Decline" });
    await grant.focus();
    await expect(grant).toBeFocused();
    await page.keyboard.press("Tab");
    await expect(decline).toBeFocused();

    const dimensions = await page.evaluate(() => ({
      clientWidth: document.documentElement.clientWidth,
      scrollWidth: document.documentElement.scrollWidth,
      reducedMotion: matchMedia("(prefers-reduced-motion: reduce)").matches,
    }));
    expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
    expect(dimensions.reducedMotion).toBe(true);
    const accessibility = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
      .analyze();
    expect(
      accessibility.violations.filter(
        (violation) => violation.impact === "serious" || violation.impact === "critical",
      ),
    ).toEqual([]);
    expect(requests).toEqual([]);
    const html = await page.locator("body").innerHTML();
    for (const prohibited of [
      "measurement_subject_id",
      "consent_record_id",
      "correlation_id",
      "mutation_digest",
    ]) {
      expect(html).not.toContain(prohibited);
    }
  });
}
