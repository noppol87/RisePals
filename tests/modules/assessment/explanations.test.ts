import { describe, expect, it } from "vitest";
import {
  deriveExplanationRecords,
  explanationCopy,
  limitationCopy,
} from "@/modules/assessment/explanations";
import {
  expectedExplanationCodes,
  expectedExplanationFixtures,
} from "@/modules/assessment/fixtures/expected-explanations";
import { syntheticRawResponseFixtures } from "@/modules/assessment/fixtures/raw-responses";
import { scoreAssessmentFixture } from "@/modules/assessment/scoring";
import { assessmentLocales } from "@/modules/assessment/types";

const rawHtmlPattern = /<\/?[a-z][^>]*>/i;

describe("assessment explanation contract", () => {
  it("matches the independent expected records with exact traces and limitation codes", () => {
    for (const [index, fixture] of syntheticRawResponseFixtures.entries()) {
      const actual = deriveExplanationRecords(scoreAssessmentFixture(fixture));
      const expected = expectedExplanationFixtures[index]!;

      expect(expected.fixtureId).toBe(fixture.fixtureId);
      expect(actual).toEqual(expected.records);
      expect(actual).toHaveLength(5);
    }
  });

  it("keeps explanation and limitation copy complete, bilingual and free of raw HTML", () => {
    expect(Object.keys(explanationCopy).sort()).toEqual([...expectedExplanationCodes].sort());

    for (const copy of Object.values(explanationCopy)) {
      expect(Object.keys(copy.heading).sort()).toEqual([...assessmentLocales].sort());
      expect(Object.keys(copy.body).sort()).toEqual([...assessmentLocales].sort());
      for (const locale of assessmentLocales) {
        expect(copy.heading[locale].trim()).not.toBe("");
        expect(copy.body[locale].trim()).not.toBe("");
        expect(copy.heading[locale]).not.toMatch(rawHtmlPattern);
        expect(copy.body[locale]).not.toMatch(rawHtmlPattern);
      }
    }

    expect(Object.keys(limitationCopy).sort()).toEqual(
      [
        "not-validated-assessment",
        "partial-core-slice",
        "single-scenario-not-behavior-pattern",
        "cannot-predict-job-loss",
        "cannot-predict-job-performance",
        "cannot-determine-employability",
        "cannot-determine-hiring-eligibility",
      ].sort(),
    );

    for (const copy of Object.values(limitationCopy)) {
      expect(Object.keys(copy.body).sort()).toEqual([...assessmentLocales].sort());
      for (const locale of assessmentLocales) {
        expect(copy.body[locale].trim()).not.toBe("");
        expect(copy.body[locale]).not.toMatch(rawHtmlPattern);
      }
    }
  });

  it("states every required non-prediction and one-scenario multiplier limitation", () => {
    const runRecord = expectedExplanationFixtures[0]!.records[0]!;
    expect(runRecord.limitationCodes).toEqual([
      "not-validated-assessment",
      "partial-core-slice",
      "cannot-predict-job-loss",
      "cannot-predict-job-performance",
      "cannot-determine-employability",
      "cannot-determine-hiring-eligibility",
    ]);

    const multiplierRecords = expectedExplanationFixtures[0]!.records.filter(
      (record) => record.target.kind === "multiplier",
    );
    expect(multiplierRecords).toHaveLength(2);
    for (const record of multiplierRecords) {
      expect(record.supportingItemKeys).toHaveLength(1);
      expect(record.limitationCodes).toContain("single-scenario-not-behavior-pattern");
      expect(record).not.toHaveProperty("multiplicativeFactor");
    }
  });

  it("keeps calculated score records free of explanation copy and codes", () => {
    const score = scoreAssessmentFixture(syntheticRawResponseFixtures[0]);
    expect(score).not.toHaveProperty("explanations");
    expect(score).not.toHaveProperty("explanationCode");
    expect(JSON.stringify(score)).not.toContain("limitationCodes");
  });
});
