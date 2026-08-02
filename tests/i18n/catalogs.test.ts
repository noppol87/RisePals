import { describe, expect, it } from "vitest";
import { catalogs } from "@/lib/i18n/catalogs";
import {
  assessmentExampleResultPath,
  assessmentPath,
  defaultLocale,
  intlLocales,
  isLocale,
  locales,
  localePath,
} from "@/lib/i18n/config";

function messageKeys(value: unknown, prefix = ""): string[] {
  if (typeof value === "string") {
    return [prefix];
  }

  if (typeof value !== "object" || value === null) {
    return [];
  }

  return Object.entries(value).flatMap(([key, child]) =>
    messageKeys(child, prefix.length === 0 ? key : `${prefix}.${key}`),
  );
}

function messageValues(value: unknown): string[] {
  if (typeof value === "string") {
    return [value];
  }

  if (typeof value !== "object" || value === null) {
    return [];
  }

  return Object.values(value).flatMap(messageValues);
}

describe("locale configuration", () => {
  it("supports exactly the Thai default and prepared English locale", () => {
    expect(locales).toEqual(["th", "en"]);
    expect(defaultLocale).toBe("th");
    expect(isLocale("th")).toBe(true);
    expect(isLocale("en")).toBe(true);
    expect(isLocale("fr")).toBe(false);
    expect(localePath("th")).toBe("/th");
    expect(assessmentPath("th")).toBe("/th/assessment");
    expect(assessmentExampleResultPath("th")).toBe("/th/assessment/example-result");
  });

  it("uses canonical BCP 47-compatible identifiers prepared for Intl", () => {
    expect(Intl.getCanonicalLocales(locales)).toEqual(["th", "en"]);
    expect(Intl.getCanonicalLocales(Object.values(intlLocales))).toEqual(["th-TH", "en"]);
  });
});

describe("typed sample catalogs", () => {
  it("resolves the same complete message contract for Thai and English", () => {
    expect(messageKeys(catalogs.th).sort()).toEqual(messageKeys(catalogs.en).sort());
    expect(messageKeys(catalogs.th)).toContain("shell.skipToContent");
    expect(messageKeys(catalogs.th)).toContain("landing.hero.heading");
    expect(messageKeys(catalogs.th)).toContain("assessment.storageBody");
    expect(messageKeys(catalogs.th)).toContain("exampleResult.userChoicesBoundary");
    expect(messageKeys(catalogs.th)).toContain(
      "landing.framework.multiplierItems.senseOfUrgency.name",
    );
  });

  it("contains intentional text values without raw HTML", () => {
    for (const catalog of Object.values(catalogs)) {
      const values = messageValues(catalog);
      expect(values.every((value) => value.trim().length > 0)).toBe(true);
      expect(values.every((value) => !/<[^>]+>/.test(value))).toBe(true);
    }
  });

  it("keeps internal player terminology out of Thai user-facing copy", () => {
    expect(messageValues(catalogs.th).some((value) => /\bplayer\b/i.test(value))).toBe(false);
  });
});
