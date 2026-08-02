import { describe, expect, it } from "vitest";
import { syntheticRawResponseFixtures } from "@/modules/assessment/fixtures/raw-responses";
import {
  SYNTHETIC_EXAMPLE_RESULT_CONTRACT_VERSION_ID,
  VISIBLE_SYNTHETIC_EXAMPLE_FIXTURE_ID,
  deriveSyntheticExampleResult,
  getVisibleSyntheticExampleFixture,
} from "@/modules/assessment/result/derive";
import { exampleNextPracticeDefinition } from "@/modules/assessment/result/next-practice";
import type { ExampleNextPracticeDefinition } from "@/modules/assessment/result/types";

describe("synthetic example-result contract", () => {
  it("derives both reviewed fixtures deterministically without mutating fixture inputs", () => {
    for (const fixture of syntheticRawResponseFixtures) {
      const before = structuredClone(fixture);
      const first = deriveSyntheticExampleResult(fixture);
      const second = deriveSyntheticExampleResult(fixture);

      expect(first).toEqual(second);
      expect(fixture).toEqual(before);
      expect(first.fixtureId).toBe(fixture.fixtureId);
      expect(first.contractVersionId).toBe(SYNTHETIC_EXAMPLE_RESULT_CONTRACT_VERSION_ID);
      expect(first.coreSignals).toHaveLength(2);
      expect(first.unassessedCoreCompetencyIds).toHaveLength(6);
      expect(first.multiplierObservations).toHaveLength(2);
    }
  });

  it("fixes the visible example to the reviewed mixed-response fixture and exact raw signals", () => {
    const fixture = getVisibleSyntheticExampleFixture();
    const result = deriveSyntheticExampleResult(fixture);

    expect(fixture.fixtureId).toBe(VISIBLE_SYNTHETIC_EXAMPLE_FIXTURE_ID);
    expect(result.fixtureId).toBe("synthetic-mixed-review");
    expect(result.coreSignals).toEqual([
      {
        competencyId: "critical-thinking-fact-checking",
        earnedPoints: 1,
        availablePoints: 4,
        evidenceCount: 2,
        supportingItemKeys: ["verify-ai-summary-source", "test-process-assumption"],
      },
      {
        competencyId: "systematic-thinking",
        earnedPoints: 3,
        availablePoints: 4,
        evidenceCount: 2,
        supportingItemKeys: ["map-downstream-impact", "trace-recurring-bottleneck"],
      },
    ]);
    expect(result.unassessedCoreCompetencyIds).toEqual([
      "growth-mindset",
      "emotional-intelligence",
      "resilience-adaptability",
      "curiosity",
      "ethical-judgement-governance",
      "strategic-storytelling-framing",
    ]);
  });

  it("keeps Ownership Thinking and Sense of Urgency as separate one-scenario observations", () => {
    const result = deriveSyntheticExampleResult(getVisibleSyntheticExampleFixture());

    expect(result.multiplierObservations).toEqual([
      {
        multiplierId: "ownership-thinking",
        evidenceCount: 1,
        supportingItemKeys: ["own-shared-outcome"],
      },
      {
        multiplierId: "sense-of-urgency",
        evidenceCount: 1,
        supportingItemKeys: ["move-with-safe-urgency"],
      },
    ]);
    for (const observation of result.multiplierObservations) {
      expect(observation).not.toHaveProperty("earnedRubricPoints");
      expect(observation).not.toHaveProperty("availableRubricPoints");
      expect(observation).not.toHaveProperty("multiplicativeFactor");
    }
  });

  it("emits the exact example-practice trace and a planned unavailable lesson reference", () => {
    const result = deriveSyntheticExampleResult(getVisibleSyntheticExampleFixture());

    expect(result.exampleNextPractice).toEqual({
      definitionId: "example-practice-source-verification-v1",
      definitionVersion: "1.0.0",
      exampleOnly: true,
      fixtureId: "synthetic-mixed-review",
      targetCompetencyId: "critical-thinking-fact-checking",
      scoringModelVersionId: "scoring-integer-rubric-fixture-v1",
      scoringModelVersion: "1.0.0",
      supportingItemKeys: ["verify-ai-summary-source", "test-process-assumption"],
      plannedLesson: {
        lessonVersionId: "lesson-source-verification-practice-planned-v1",
        availability: "planned-unavailable",
      },
    });
  });

  it("contains no aggregate, proficiency, confidence, employment, readiness, risk or personality fields", () => {
    for (const fixture of syntheticRawResponseFixtures) {
      const result = deriveSyntheticExampleResult(fixture);
      const serialized = JSON.stringify(result);

      expect(Object.keys(result).sort()).toEqual(
        [
          "assessmentVersionId",
          "contract",
          "contractVersionId",
          "coreSignals",
          "exampleNextPractice",
          "exampleOnly",
          "fixtureId",
          "frameworkVersionId",
          "multiplierObservations",
          "scoringModelVersionId",
          "source",
          "unassessedCoreCompetencyIds",
        ].sort(),
      );
      for (const forbiddenField of [
        "overallScore",
        "weightedAggregate",
        "percentageProficiency",
        "proficiencyStage",
        "awareLeadingStage",
        "confidencePercentage",
        "priorityGap",
        "personalizedRecommendation",
        "jobLoss",
        "jobPerformance",
        "employability",
        "hiringEligibility",
        "workReadiness",
        "riskLevel",
        "personalityType",
        "coreWeightBasisPoints",
      ]) {
        expect(serialized).not.toContain(forbiddenField);
      }
    }
  });

  it("rejects incompatible practice traces and available-lesson claims", () => {
    const incompatibleModel = {
      ...exampleNextPracticeDefinition,
      scoringModelVersionId: "unknown-scoring-model-v1",
    } as unknown as ExampleNextPracticeDefinition;
    const availableLesson = {
      ...exampleNextPracticeDefinition,
      plannedLesson: {
        ...exampleNextPracticeDefinition.plannedLesson,
        availability: "available",
      },
    } as unknown as ExampleNextPracticeDefinition;
    const unrelatedItem = {
      ...exampleNextPracticeDefinition,
      supportingItemKeys: ["map-downstream-impact"],
    } as unknown as ExampleNextPracticeDefinition;

    expect(() =>
      deriveSyntheticExampleResult(getVisibleSyntheticExampleFixture(), incompatibleModel),
    ).toThrow("next-practice scoring-model compatibility failed.");
    expect(() =>
      deriveSyntheticExampleResult(getVisibleSyntheticExampleFixture(), availableLesson),
    ).toThrow("next-practice lesson reference must remain planned and unavailable.");
    expect(() =>
      deriveSyntheticExampleResult(getVisibleSyntheticExampleFixture(), unrelatedItem),
    ).toThrow("next-practice item trace must belong to the target core signal.");
  });
});
