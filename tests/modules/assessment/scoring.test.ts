import { describe, expect, it } from "vitest";
import { assessmentDefinition, scoringModelDefinition } from "@/modules/assessment/assessment";
import { expectedScoringFixtures } from "@/modules/assessment/fixtures/expected-scores";
import { syntheticRawResponseFixtures } from "@/modules/assessment/fixtures/raw-responses";
import { assessmentFramework } from "@/modules/assessment/framework";
import {
  defaultAssessmentScoringContext,
  scoreAssessmentFixture,
  type AssessmentScoringContext,
} from "@/modules/assessment/scoring";
import type { SyntheticRawResponseFixture } from "@/modules/assessment/types";

type MutableObject = Record<string, unknown>;

function mutableFixture(index = 0): MutableObject {
  return structuredClone(syntheticRawResponseFixtures[index]) as unknown as MutableObject;
}

function responseObjects(fixture: MutableObject): MutableObject[] {
  return fixture.responses as MutableObject[];
}

function mutableContext(): MutableObject {
  return structuredClone(defaultAssessmentScoringContext) as unknown as MutableObject;
}

function scoreMutableFixture(fixture: MutableObject, context = defaultAssessmentScoringContext) {
  return scoreAssessmentFixture(fixture as unknown as SyntheticRawResponseFixture, context);
}

describe("deterministic assessment scoring", () => {
  it("matches every explicit expected scoring fixture", () => {
    for (const [index, fixture] of syntheticRawResponseFixtures.entries()) {
      const expected = expectedScoringFixtures[index]!;
      const result = scoreAssessmentFixture(fixture);

      expect(expected.fixtureId).toBe(fixture.fixtureId);
      expect(result.contract).toBe("assessment-fixture-scoring");
      expect(result.provisional).toBe(true);
      expect(result.fixtureOnly).toBe(true);
      expect(result.coreSkillSignals).toHaveLength(2);
      expect(result.multiplierObservations).toHaveLength(2);

      for (const [signalIndex, signal] of result.coreSkillSignals.entries()) {
        const expectedSignal = expected.coreSignals[signalIndex]!;
        expect(signal.competencyId).toBe(expectedSignal.id);
        expect(signal.earnedPoints).toBe(expectedSignal.earned);
        expect(signal.availablePoints).toBe(expectedSignal.available);
        expect(signal.evidenceCount).toBe(expectedSignal.evidenceCount);
        expect(signal.supportingItemKeys).toEqual(expectedSignal.supportingItemKeys);
      }

      for (const [observationIndex, observation] of result.multiplierObservations.entries()) {
        const expectedObservation = expected.multiplierObservations[observationIndex]!;
        expect(observation.multiplierId).toBe(expectedObservation.id);
        expect(observation.earnedRubricPoints).toBe(expectedObservation.earned);
        expect(observation.availableRubricPoints).toBe(expectedObservation.available);
        expect(observation.evidenceCount).toBe(expectedObservation.evidenceCount);
        expect(observation.supportingItemKeys).toEqual(expectedObservation.supportingItemKeys);
      }

      expect(result.unassessedCoreCompetencyIds).toEqual(expected.unassessedCoreCompetencyIds);
    }
  });

  it("is response-order independent and does not mutate inputs or domain definitions", () => {
    const fixture = structuredClone(syntheticRawResponseFixtures[1]);
    const fixtureBefore = structuredClone(fixture);
    const contextBefore = structuredClone(defaultAssessmentScoringContext);
    const reversedFixture = {
      ...fixture,
      responses: [...fixture.responses].reverse(),
    };

    expect(scoreAssessmentFixture(reversedFixture)).toEqual(scoreAssessmentFixture(fixture));
    expect(fixture).toEqual(fixtureBefore);
    expect(defaultAssessmentScoringContext).toEqual(contextBefore);
  });

  it.each([
    ["assessmentId", "different-assessment", "response fixture assessment compatibility failed."],
    [
      "frameworkVersionId",
      "different-framework",
      "response fixture framework compatibility failed.",
    ],
    [
      "scoringModelId",
      "different-scoring",
      "response fixture scoring-version compatibility failed.",
    ],
  ])("rejects incompatible %s", (field, value, message) => {
    const fixture = mutableFixture();
    fixture[field] = value;

    expect(() => scoreMutableFixture(fixture)).toThrow(message);
  });

  it("rejects a scoring model bound to another assessment", () => {
    const context = mutableContext();
    (context.scoringModel as MutableObject).assessmentId = "different-assessment";

    expect(() =>
      scoreAssessmentFixture(
        syntheticRawResponseFixtures[0],
        context as unknown as AssessmentScoringContext,
      ),
    ).toThrow("scoringModel assessment compatibility failed.");
  });

  it("rejects an assessment bound to another framework version", () => {
    const context = mutableContext();
    (context.assessment as MutableObject).frameworkVersionId = "different-framework";

    expect(() =>
      scoreAssessmentFixture(
        syntheticRawResponseFixtures[0],
        context as unknown as AssessmentScoringContext,
      ),
    ).toThrow("scoringModel framework compatibility failed.");
  });

  it("rejects an impossible scoring-model point scale", () => {
    const context = mutableContext();
    const pointScale = (context.scoringModel as MutableObject).pointScale as MutableObject;
    pointScale.maximum = 2.5;

    expect(() =>
      scoreAssessmentFixture(
        syntheticRawResponseFixtures[0],
        context as unknown as AssessmentScoringContext,
      ),
    ).toThrow("scoringModel.pointScale must define a possible non-negative integer scale.");
  });

  it("rejects a missing required response", () => {
    const fixture = mutableFixture();
    responseObjects(fixture).pop();

    expect(() => scoreMutableFixture(fixture)).toThrow(
      "response is missing required item keys: move-with-safe-urgency.",
    );
  });

  it("rejects a duplicate item response", () => {
    const fixture = mutableFixture();
    const responses = responseObjects(fixture);
    responses[5] = structuredClone(responses[0]!);

    expect(() => scoreMutableFixture(fixture)).toThrow(
      "response contains duplicate item key: verify-ai-summary-source.",
    );
  });

  it("rejects an unknown item key", () => {
    const fixture = mutableFixture();
    responseObjects(fixture)[0]!.itemKey = "unknown-synthetic-item";

    expect(() => scoreMutableFixture(fixture)).toThrow(
      "response contains unknown item key: unknown-synthetic-item.",
    );
  });

  it("rejects an unknown option ID", () => {
    const fixture = mutableFixture();
    responseObjects(fixture)[0]!.optionId = "unknown-synthetic-option";

    expect(() => scoreMutableFixture(fixture)).toThrow(
      "response for verify-ai-summary-source contains unknown option ID: unknown-synthetic-option.",
    );
  });

  it("rejects an invalid rubric configuration", () => {
    const context = mutableContext();
    const assessment = context.assessment as MutableObject;
    const items = assessment.items as MutableObject[];
    const rubric = items[0]!.rubric as MutableObject;
    rubric.availablePoints = 3;

    expect(() =>
      scoreAssessmentFixture(
        syntheticRawResponseFixtures[0],
        context as unknown as AssessmentScoringContext,
      ),
    ).toThrow(
      "assessment.item.verify-ai-summary-source.rubric.availablePoints must equal the scoring scale maximum.",
    );
  });

  it("rejects an unknown item target kind even when the target is a known multiplier", () => {
    const context = mutableContext();
    const assessment = context.assessment as MutableObject;
    const items = assessment.items as MutableObject[];
    const rubric = items[4]!.rubric as MutableObject;
    rubric.targetKind = "unknown-kind";

    expect(() =>
      scoreAssessmentFixture(
        syntheticRawResponseFixtures[0],
        context as unknown as AssessmentScoringContext,
      ),
    ).toThrow("assessment.item.own-shared-outcome.rubric.targetKind must be core or multiplier.");
  });

  it("retains wrong-kind target rejection for a known multiplier ID labeled as core", () => {
    const context = mutableContext();
    const assessment = context.assessment as MutableObject;
    const items = assessment.items as MutableObject[];
    const rubric = items[4]!.rubric as MutableObject;
    rubric.targetKind = "core";

    expect(() =>
      scoreAssessmentFixture(
        syntheticRawResponseFixtures[0],
        context as unknown as AssessmentScoringContext,
      ),
    ).toThrow("assessment.item.own-shared-outcome.rubric target is unknown or has the wrong kind.");
  });

  it("rejects impossible option point values", () => {
    const context = mutableContext();
    const assessment = context.assessment as MutableObject;
    const items = assessment.items as MutableObject[];
    const options = items[0]!.options as MutableObject[];
    options[0]!.rubricPoints = 2.5;

    expect(() =>
      scoreAssessmentFixture(
        syntheticRawResponseFixtures[0],
        context as unknown as AssessmentScoringContext,
      ),
    ).toThrow(
      "assessment.item.verify-ai-summary-source.option.verify-ai-summary-source-use-draft.rubricPoints is impossible for the scoring scale.",
    );
  });

  it("never multiplies or aggregates multiplier observations into core signals", () => {
    const baseline = structuredClone(syntheticRawResponseFixtures[0]);
    const changedMultipliers = {
      ...baseline,
      responses: baseline.responses.map((response) => {
        if (response.itemKey === "own-shared-outcome") {
          return { ...response, optionId: "own-shared-outcome-complete-task" };
        }
        if (response.itemKey === "move-with-safe-urgency") {
          return { ...response, optionId: "move-with-safe-urgency-rush-all" };
        }
        return response;
      }),
    };

    const baselineResult = scoreAssessmentFixture(baseline);
    const changedResult = scoreAssessmentFixture(changedMultipliers);
    expect(changedResult.coreSkillSignals).toEqual(baselineResult.coreSkillSignals);
    expect(changedResult.multiplierObservations).not.toEqual(baselineResult.multiplierObservations);
  });

  it("emits no overall score, confidence, proficiency, recommendation or hiring field", () => {
    const result = scoreAssessmentFixture(syntheticRawResponseFixtures[0]);
    const serialized = JSON.stringify(result);

    expect(Object.keys(result).sort()).toEqual([
      "assessmentId",
      "contract",
      "coreSkillSignals",
      "fixtureOnly",
      "frameworkVersionId",
      "multiplierObservations",
      "provisional",
      "scoringModelId",
      "unassessedCoreCompetencyIds",
    ]);
    for (const forbidden of [
      "overallScore",
      "confidence",
      "proficiencyStage",
      "priorityGap",
      "lessonRecommendation",
      "employmentImplication",
      "employability",
      "hiringEligibility",
      "multiplicativeFactor",
    ]) {
      expect(serialized).not.toContain(forbidden);
    }
  });

  it("keeps accepted domain identities compatible", () => {
    expect(assessmentDefinition.frameworkVersionId).toBe(assessmentFramework.id);
    expect(scoringModelDefinition.assessmentId).toBe(assessmentDefinition.id);
    expect(scoringModelDefinition.frameworkVersionId).toBe(assessmentFramework.id);
  });
});
