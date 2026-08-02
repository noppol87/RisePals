import { describe, expect, it } from "vitest";
import { assessmentDefinition } from "@/modules/assessment/assessment";
import { expectedExplanationFixtures } from "@/modules/assessment/fixtures/expected-explanations";
import { expectedScoringFixtures } from "@/modules/assessment/fixtures/expected-scores";
import { syntheticRawResponseFixtures } from "@/modules/assessment/fixtures/raw-responses";
import { assessmentLocales } from "@/modules/assessment/types";

const stableIdentifierPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

describe("assessment fixture inventory", () => {
  it("contains exactly six stable bilingual scenario-choice items in the authorized distribution", () => {
    expect(assessmentDefinition.items).toHaveLength(6);
    expect(
      assessmentDefinition.items.filter(
        (item) => item.rubric.targetId === "critical-thinking-fact-checking",
      ),
    ).toHaveLength(2);
    expect(
      assessmentDefinition.items.filter((item) => item.rubric.targetId === "systematic-thinking"),
    ).toHaveLength(2);
    expect(
      assessmentDefinition.items.filter((item) => item.rubric.targetId === "ownership-thinking"),
    ).toHaveLength(1);
    expect(
      assessmentDefinition.items.filter((item) => item.rubric.targetId === "sense-of-urgency"),
    ).toHaveLength(1);

    for (const item of assessmentDefinition.items) {
      expect(item.type).toBe("scenario-choice");
      expect(item.required).toBe(true);
      expect(item.key).toMatch(stableIdentifierPattern);
      expect(Object.keys(item.prompt).sort()).toEqual([...assessmentLocales].sort());
      expect(item.options).toHaveLength(3);

      for (const locale of assessmentLocales) {
        expect(item.prompt[locale].trim()).not.toBe("");
      }

      for (const option of item.options) {
        expect(option.id).toMatch(stableIdentifierPattern);
        expect(Object.keys(option.label).sort()).toEqual([...assessmentLocales].sort());
        for (const locale of assessmentLocales) {
          expect(option.label[locale].trim()).not.toBe("");
        }
      }
    }
  });

  it("keeps synthetic raw responses separate from expected score and explanation fixtures", () => {
    expect(syntheticRawResponseFixtures).toHaveLength(2);
    expect(expectedScoringFixtures).toHaveLength(2);
    expect(expectedExplanationFixtures).toHaveLength(2);
    expect(syntheticRawResponseFixtures.map((fixture) => fixture.fixtureId)).toEqual(
      expectedScoringFixtures.map((fixture) => fixture.fixtureId),
    );
    expect(syntheticRawResponseFixtures.map((fixture) => fixture.fixtureId)).toEqual(
      expectedExplanationFixtures.map((fixture) => fixture.fixtureId),
    );
  });

  it("uses unique synthetic identifiers and only item/option references in raw responses", () => {
    const fixtureIds = syntheticRawResponseFixtures.map((fixture) => fixture.fixtureId);
    expect(new Set(fixtureIds).size).toBe(fixtureIds.length);

    const itemsByKey = new Map(assessmentDefinition.items.map((item) => [item.key, item]));
    for (const fixture of syntheticRawResponseFixtures) {
      expect(fixture.fixtureId).toMatch(/^synthetic-/);
      expect(Object.keys(fixture).sort()).toEqual([
        "assessmentId",
        "fixtureId",
        "frameworkVersionId",
        "responses",
        "scoringModelId",
      ]);
      expect(fixture.responses).toHaveLength(6);
      expect(new Set(fixture.responses.map((response) => response.itemKey)).size).toBe(6);

      for (const response of fixture.responses) {
        expect(Object.keys(response).sort()).toEqual(["itemKey", "optionId"]);
        const item = itemsByKey.get(response.itemKey);
        expect(item).toBeDefined();
        expect(item!.options.some((option) => option.id === response.optionId)).toBe(true);
      }
    }
  });
});
