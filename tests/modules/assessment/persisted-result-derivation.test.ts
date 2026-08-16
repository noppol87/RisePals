import { describe, expect, it } from "vitest";
import { assessmentDefinition, scoringModelDefinition } from "@/modules/assessment/assessment";
import { syntheticRawResponseFixtures } from "@/modules/assessment/fixtures/raw-responses";
import { assessmentFramework } from "@/modules/assessment/framework";
import {
  derivePersistedSyntheticResult,
  normalizeBasisPoints,
} from "@/modules/assessment/persisted-result/derive";
import {
  RESULT_PRIORITY_POLICY_CANONICAL_JSON,
  RESULT_PRIORITY_POLICY_DIGEST,
  RESULT_PRIORITY_POLICY_ID,
  sha256Hex,
} from "@/modules/assessment/persisted-result/policy";
import type { PersistedResultDerivationInput } from "@/modules/assessment/persisted-result/types";

const contentDigest = "a".repeat(64);

function inputFromResponses(
  responses: readonly Readonly<{ itemKey: string; optionId: string }>[],
): PersistedResultDerivationInput {
  const responseByKey = new Map(responses.map((response) => [response.itemKey, response]));
  return {
    assessment: {
      contentId: assessmentDefinition.id,
      key: assessmentDefinition.assessmentKey,
      version: assessmentDefinition.version,
      contentDigest,
    },
    framework: {
      contentId: assessmentFramework.id,
      key: assessmentFramework.frameworkKey,
      version: assessmentFramework.version,
      contentDigest,
    },
    scoringModel: {
      contentId: scoringModelDefinition.id,
      key: scoringModelDefinition.scoringKey,
      version: scoringModelDefinition.version,
      contentDigest,
    },
    responses: assessmentDefinition.items.map((item) => ({
      itemKey: item.key,
      displayOrder: item.displayOrder,
      revision: item.displayOrder,
      selectedOptionId: responseByKey.get(item.key)!.optionId,
    })),
  };
}

const mixedInput = inputFromResponses(syntheticRawResponseFixtures[1]!.responses);
const deliberateInput = inputFromResponses(syntheticRawResponseFixtures[0]!.responses);

describe("persisted result policy and pure derivation", () => {
  it("pins the exact canonical policy identity and SHA-256 digest", () => {
    expect(RESULT_PRIORITY_POLICY_ID).toBe("persisted-synthetic-priority-v1@1.0.0");
    expect(sha256Hex(RESULT_PRIORITY_POLICY_CANONICAL_JSON)).toBe(RESULT_PRIORITY_POLICY_DIGEST);
    expect(RESULT_PRIORITY_POLICY_CANONICAL_JSON).not.toContain("weight");
    expect(RESULT_PRIORITY_POLICY_CANONICAL_JSON).not.toContain('multiplier":true');
  });

  it("derives exact assessed-core signals, separate multipliers, six unassessed cores and a unique Critical Thinking priority", () => {
    const result = derivePersistedSyntheticResult(mixedInput);

    expect(result.inputDigest).toBe(
      "90f07f138f6908d54f4a3269864a58b025ff58c53dd661ac709f3b0af0cce58e",
    );
    expect(result.outputDigest).toBe(
      "af3e33759afda1765ddd7a7d22d42e3e1b0d82c5df855c0c043b244a581d8c3c",
    );

    expect(result.semanticOutput.coreScores).toEqual([
      {
        competencyId: "critical-thinking-fact-checking",
        earnedPoints: 1,
        availablePoints: 4,
        evidenceCount: 2,
        normalizedBasisPoints: 2500,
        supportingItemKeys: ["verify-ai-summary-source", "test-process-assumption"],
      },
      {
        competencyId: "systematic-thinking",
        earnedPoints: 3,
        availablePoints: 4,
        evidenceCount: 2,
        normalizedBasisPoints: 7500,
        supportingItemKeys: ["map-downstream-impact", "trace-recurring-bottleneck"],
      },
    ]);
    expect(result.semanticOutput.unassessedCoreCompetencyIds).toHaveLength(6);
    expect(result.semanticOutput.multiplierObservations).toHaveLength(2);
    expect(result.semanticOutput.priorityRecommendation).toMatchObject({
      competencyId: "critical-thinking-fact-checking",
      rank: 1,
      reasonCode: "unique-lowest-assessed-core-signal",
      nextAction: {
        kind: "prototype-lesson",
        lessonVersionId: "lesson-source-verification-practice-v1",
        lessonVersion: "1.0.0",
      },
    });
    expect(result.semanticOutput.explanations).toHaveLength(6);
  });

  it("selects Systematic Thinking only when its exact ratio is uniquely lower", () => {
    const responses = deliberateInput.responses.map((response) => {
      if (response.itemKey === "map-downstream-impact") {
        return { ...response, selectedOptionId: "map-downstream-impact-change-local" };
      }
      if (response.itemKey === "trace-recurring-bottleneck") {
        return { ...response, selectedOptionId: "trace-recurring-bottleneck-add-status" };
      }
      return response;
    });
    const result = derivePersistedSyntheticResult({ ...deliberateInput, responses });

    expect(result.semanticOutput.priorityRecommendation).toMatchObject({
      competencyId: "systematic-thinking",
      nextAction: { kind: "practice-unavailable" },
    });
  });

  it("persists no recommendation and emits no-distinct-priority on an exact tie", () => {
    const result = derivePersistedSyntheticResult(deliberateInput);

    expect(result.semanticOutput.priorityRecommendation).toBeNull();
    expect(result.semanticOutput.explanations.at(-1)).toMatchObject({
      explanationCode: "no-distinct-priority",
      target: { kind: "priority", id: "none" },
      supportingItemKeys: [],
    });
  });

  it("is response-order independent and excludes locale, UUIDs and timestamps from canonical semantics", () => {
    const ordered = derivePersistedSyntheticResult(mixedInput);
    const reversed = derivePersistedSyntheticResult({
      ...mixedInput,
      responses: [...mixedInput.responses].reverse(),
    });

    expect(reversed).toEqual(ordered);
    expect(ordered.canonicalInput).not.toMatch(/locale|userId|sessionId|timestamp|createdAt/i);
    expect(ordered.canonicalOutput).not.toMatch(/locale|uuid|timestamp|createdAt/i);
  });

  it("keeps multiplier changes out of core scores and priority selection", () => {
    const baseline = derivePersistedSyntheticResult(mixedInput);
    const changedMultipliers = mixedInput.responses.map((response) => {
      if (response.itemKey === "own-shared-outcome") {
        return { ...response, selectedOptionId: "own-shared-outcome-coordinate-fix" };
      }
      if (response.itemKey === "move-with-safe-urgency") {
        return { ...response, selectedOptionId: "move-with-safe-urgency-rush-all" };
      }
      return response;
    });
    const changed = derivePersistedSyntheticResult({
      ...mixedInput,
      responses: changedMultipliers,
    });

    expect(changed.semanticOutput.coreScores).toEqual(baseline.semanticOutput.coreScores);
    expect(changed.semanticOutput.priorityRecommendation).toEqual(
      baseline.semanticOutput.priorityRecommendation,
    );
  });

  it("uses deterministic floor integer arithmetic for basis-point metadata", () => {
    expect(normalizeBasisPoints(1, 3)).toBe(3333);
    expect(normalizeBasisPoints(2, 3)).toBe(6666);
    expect(() => normalizeBasisPoints(4, 3)).toThrow("impossible");
  });

  it.each([
    [
      "unknown option",
      () => ({
        ...mixedInput,
        responses: mixedInput.responses.map((response, index) =>
          index === 0 ? { ...response, selectedOptionId: "unknown-option" } : response,
        ),
      }),
    ],
    ["missing response", () => ({ ...mixedInput, responses: mixedInput.responses.slice(1) })],
    [
      "duplicate response",
      () => ({
        ...mixedInput,
        responses: [...mixedInput.responses.slice(0, -1), mixedInput.responses[0]!],
      }),
    ],
    [
      "wrong version",
      () => ({
        ...mixedInput,
        scoringModel: { ...mixedInput.scoringModel, version: "9.9.9" },
      }),
    ],
    [
      "altered definition digest",
      () => ({
        ...mixedInput,
        assessment: { ...mixedInput.assessment, contentDigest: "not-a-digest" },
      }),
    ],
    [
      "impossible revision",
      () => ({
        ...mixedInput,
        responses: mixedInput.responses.map((response, index) =>
          index === 0 ? { ...response, revision: 0 } : response,
        ),
      }),
    ],
  ])("rejects %s before emitting a result", (_label, mutate) => {
    expect(() => derivePersistedSyntheticResult(mutate())).toThrow();
  });

  it("exposes no forbidden overall, proficiency, confidence or employment field", () => {
    const keys = collectKeys(derivePersistedSyntheticResult(mixedInput).semanticOutput);
    expect(keys.join(" ")).not.toMatch(
      /overall|weighted|proficiency|confidence|employability|hiring|salary|eligibility|readiness|risk|personality/i,
    );
  });
});

function collectKeys(value: unknown): string[] {
  if (Array.isArray(value)) return value.flatMap(collectKeys);
  if (!value || typeof value !== "object") return [];
  return Object.entries(value).flatMap(([key, nested]) => [key, ...collectKeys(nested)]);
}
