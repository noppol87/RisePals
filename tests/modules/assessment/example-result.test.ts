import { describe, expect, it } from "vitest";
import { syntheticRawResponseFixtures } from "@/modules/assessment/fixtures/raw-responses";
import {
  SYNTHETIC_EXAMPLE_RESULT_CONTRACT_VERSION_ID,
  VISIBLE_SYNTHETIC_EXAMPLE_FIXTURE_ID,
  deriveSyntheticExampleResult,
  getVisibleSyntheticExampleFixture,
  validateReviewedSyntheticFixtureRegistry,
} from "@/modules/assessment/result/derive";
import { exampleNextPracticeDefinition } from "@/modules/assessment/result/next-practice";
import type { ExampleNextPracticeDefinition } from "@/modules/assessment/result/types";
import type { SyntheticRawResponseFixture } from "@/modules/assessment/types";

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

  it("rejects an unknown fixture ID even when every response and compatibility field is valid", () => {
    const fixture = {
      ...structuredClone(getVisibleSyntheticExampleFixture()),
      fixtureId: "synthetic-unreviewed-copy",
    };

    expect(() => deriveSyntheticExampleResult(fixture)).toThrow(
      "synthetic fixture synthetic-unreviewed-copy is not an approved reviewed fixture.",
    );
  });

  it("rejects a known fixture ID when one valid response is altered", () => {
    const canonicalFixture = getVisibleSyntheticExampleFixture();
    const fixture: SyntheticRawResponseFixture = {
      ...canonicalFixture,
      responses: canonicalFixture.responses.map((response, index) =>
        index === 0
          ? { ...response, optionId: "verify-ai-summary-source-check-claims" }
          : { ...response },
      ),
    };

    expect(() => deriveSyntheticExampleResult(fixture)).toThrow(
      "synthetic fixture synthetic-mixed-review response item/option pairs must exactly match the reviewed fixture.",
    );
  });

  it.each([
    ["assessmentId", "assessment-unreviewed-v1"],
    ["frameworkVersionId", "framework-unreviewed-v1"],
    ["scoringModelId", "scoring-unreviewed-v1"],
  ] as const)(
    "rejects a known fixture ID with altered %s compatibility metadata",
    (field, value) => {
      const fixture: SyntheticRawResponseFixture = {
        ...structuredClone(getVisibleSyntheticExampleFixture()),
        [field]: value,
      };

      expect(() => deriveSyntheticExampleResult(fixture)).toThrow(
        "synthetic fixture synthetic-mixed-review compatibility metadata must exactly match the reviewed fixture.",
      );
    },
  );

  it("rejects duplicate canonical fixture IDs before resolving reviewed provenance", () => {
    const fixture = structuredClone(getVisibleSyntheticExampleFixture());
    const duplicateRegistry = [fixture, structuredClone(fixture)];

    expect(() => validateReviewedSyntheticFixtureRegistry(duplicateRegistry)).toThrow(
      "reviewed synthetic fixture registry contains duplicate fixture ID: synthetic-mixed-review.",
    );
  });

  it("rejects ambiguous canonical fixture content under different identities", () => {
    const fixture = structuredClone(getVisibleSyntheticExampleFixture());
    const ambiguousCopy = {
      ...structuredClone(fixture),
      fixtureId: "synthetic-ambiguous-copy",
    } as SyntheticRawResponseFixture;

    expect(() => validateReviewedSyntheticFixtureRegistry([fixture, ambiguousCopy])).toThrow(
      "reviewed synthetic fixture registry contains ambiguous content for synthetic-mixed-review and synthetic-ambiguous-copy.",
    );
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

  it("emits the exact example-practice trace and available prototype lesson reference", () => {
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
      prototypeLesson: {
        lessonKey: "source-verification-practice",
        lessonVersionId: "lesson-source-verification-practice-v1",
        version: "1.0.0",
        status: "prototype",
        availability: "prototype-available",
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

  it("rejects incompatible practice traces and non-canonical lesson references", () => {
    const incompatibleModel = {
      ...exampleNextPracticeDefinition,
      scoringModelVersionId: "unknown-scoring-model-v1",
    } as unknown as ExampleNextPracticeDefinition;
    const incompatibleLesson = {
      ...exampleNextPracticeDefinition,
      prototypeLesson: {
        ...exampleNextPracticeDefinition.prototypeLesson,
        lessonVersionId: "lesson-source-verification-practice-v2",
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
      deriveSyntheticExampleResult(getVisibleSyntheticExampleFixture(), incompatibleLesson),
    ).toThrow("next-practice lesson reference must match the exact available prototype.");
    expect(() =>
      deriveSyntheticExampleResult(getVisibleSyntheticExampleFixture(), unrelatedItem),
    ).toThrow("next-practice item trace must belong to the target core signal.");
  });
});
