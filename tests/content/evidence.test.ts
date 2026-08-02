import { describe, expect, it } from "vitest";
import { localizedEvidenceFields } from "@/lib/evidence/model";
import { evidenceRecords, getPublishedEvidence } from "@/lib/evidence/records";
import { validateEvidenceRecords } from "@/lib/evidence/validate";
import { locales } from "@/lib/i18n/config";

type MutableObject = Record<string, unknown>;

function mutableRecords(): MutableObject[] {
  return structuredClone(evidenceRecords) as unknown as MutableObject[];
}

function nestedObject(parent: MutableObject, key: string): MutableObject {
  return parent[key] as MutableObject;
}

function localizedContent(records: MutableObject[], index: number, locale: string): MutableObject {
  return nestedObject(nestedObject(records[index]!, "localized"), locale);
}

const validationOptions = { publicationDate: "2026-08-02" } as const;

describe("evidence contract", () => {
  it("accepts exactly the two reviewed records and resolves complete localized content", () => {
    const validated = validateEvidenceRecords(evidenceRecords, validationOptions);

    expect(validated).toHaveLength(2);
    expect(getPublishedEvidence("th", validationOptions.publicationDate)).toHaveLength(2);
    expect(getPublishedEvidence("en", validationOptions.publicationDate)).toHaveLength(2);

    for (const locale of locales) {
      for (const record of getPublishedEvidence(locale, validationOptions.publicationDate)) {
        expect(Object.keys(record.content).sort()).toEqual([...localizedEvidenceFields].sort());
        expect(Object.values(record.content).every((value) => value.trim().length > 0)).toBe(true);
      }
    }
  });

  it("rejects a missing required field", () => {
    const records = mutableRecords();
    delete records[0]!.dateLastVerified;

    expect(() => validateEvidenceRecords(records, validationOptions)).toThrow(
      "evidence[0].dateLastVerified is required.",
    );
  });

  it("rejects unsupported or incomplete locale coverage", () => {
    const records = mutableRecords();
    const localized = nestedObject(records[0]!, "localized");
    localized.fr = structuredClone(localized.en);

    expect(() => validateEvidenceRecords(records, validationOptions)).toThrow(
      "evidence[0].localized must cover exactly these locales: en, th.",
    );
  });

  it("rejects blank localized values", () => {
    const records = mutableRecords();
    localizedContent(records, 0, "th").claim = "   ";

    expect(() => validateEvidenceRecords(records, validationOptions)).toThrow(
      "evidence[0].localized.th.claim must be a non-blank string.",
    );
  });

  it.each(["http://example.com/report", "not-a-url"])(
    "rejects a non-HTTPS or malformed source URL: %s",
    (url) => {
      const records = mutableRecords();
      nestedObject(records[0]!, "source").url = url;

      expect(() => validateEvidenceRecords(records, validationOptions)).toThrow(
        "evidence[0].source.url must be a valid absolute HTTPS URL.",
      );
    },
  );

  it.each(["2026/08/02", "2026-02-30"])("rejects an invalid ISO date: %s", (date) => {
    const records = mutableRecords();
    records[0]!.dateLastVerified = date;

    expect(() => validateEvidenceRecords(records, validationOptions)).toThrow(
      "evidence[0].dateLastVerified must use a valid YYYY-MM-DD date.",
    );
  });

  it("rejects a review date that is not later than verification", () => {
    const records = mutableRecords();
    records[0]!.reviewDate = records[0]!.dateLastVerified;

    expect(() => validateEvidenceRecords(records, validationOptions)).toThrow(
      "evidence[0].reviewDate must be later than dateLastVerified.",
    );
  });

  it("rejects evidence that is past its review date at publication time", () => {
    expect(() =>
      validateEvidenceRecords(evidenceRecords, { publicationDate: "2027-02-03" }),
    ).toThrow("evidence[0] is past its review date and must not be published.");
  });

  it("rejects raw HTML in evidence content", () => {
    const records = mutableRecords();
    localizedContent(records, 0, "en").claim = "<strong>Unsupported markup</strong>";

    expect(() => validateEvidenceRecords(records, validationOptions)).toThrow(
      "evidence[0].localized.en.claim must not contain raw HTML.",
    );
  });

  it("rejects duplicate evidence IDs", () => {
    const records = mutableRecords();
    records[1]!.id = records[0]!.id;

    expect(() => validateEvidenceRecords(records, validationOptions)).toThrow(
      "evidence contains duplicate ID: ilo-nask-genai-exposure-2025.",
    );
  });
});
