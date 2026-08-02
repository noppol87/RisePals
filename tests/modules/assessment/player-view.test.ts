import { describe, expect, it } from "vitest";
import { assessmentDefinition, SCORING_MODEL_ID } from "@/modules/assessment/assessment";
import { syntheticRawResponseFixtures } from "@/modules/assessment/fixtures/raw-responses";
import { createAssessmentPlayerView } from "@/modules/assessment/player/view";

describe("assessment player presentation view", () => {
  it("preserves exact localized prompts and option labels in display order", () => {
    for (const locale of ["th", "en"] as const) {
      const view = createAssessmentPlayerView(locale);

      expect(view.items).toHaveLength(6);
      expect(view.items.map((item) => item.key)).toEqual(
        assessmentDefinition.items.map((item) => item.key),
      );
      for (const [index, item] of view.items.entries()) {
        const definition = assessmentDefinition.items[index]!;
        expect(item.prompt).toBe(definition.prompt[locale]);
        expect(item.options.map((option) => option.label)).toEqual(
          definition.options.map((option) => option.label[locale]),
        );
      }
    }
  });

  it("contains only compatibility, prompt, order, item, and option presentation fields", () => {
    const view = createAssessmentPlayerView("en");
    expect(Object.keys(view).sort()).toEqual([
      "assessmentId",
      "assessmentVersion",
      "assessmentVersionId",
      "items",
    ]);
    for (const item of view.items) {
      expect(Object.keys(item).sort()).toEqual(["displayOrder", "key", "options", "prompt"]);
      for (const option of item.options) {
        expect(Object.keys(option).sort()).toEqual(["id", "label"]);
      }
    }

    const serialized = JSON.stringify(view);
    for (const forbidden of [
      "rubricPoints",
      "targetId",
      "targetKind",
      "weightBasisPoints",
      SCORING_MODEL_ID,
      "scoringModel",
      "explanationCode",
      syntheticRawResponseFixtures[0]!.fixtureId,
    ]) {
      expect(serialized).not.toContain(forbidden);
    }
  });
});
