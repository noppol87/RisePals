import { describe, expect, it } from "vitest";
import { assessmentDefinition } from "@/modules/assessment/assessment";
import {
  createPersistedAssessmentView,
  getSyntheticPublishedDefinition,
  parseSavePersistedResponseInput,
} from "@/modules/assessment/persistence/contract";
import { persistedAssessmentCopy } from "@/modules/assessment/persistence/copy";

const validInput = {
  locale: "en",
  itemKey: "verify-ai-summary-source",
  selectedOptionId: "verify-ai-summary-source-check-claims",
  expectedRevision: 0,
  clientMutationId: "10000000-0000-4000-8000-000000000001",
} as const;

function collectObjectKeys(value: unknown): string[] {
  if (!value || typeof value !== "object") return [];
  if (Array.isArray(value)) return value.flatMap(collectObjectKeys);
  return Object.entries(value).flatMap(([key, nested]) => [key, ...collectObjectKeys(nested)]);
}

describe("persisted synthetic assessment contract", () => {
  it("pins the exact accepted assessment/item/option registry without exposing rubric data", () => {
    const registry = getSyntheticPublishedDefinition();
    const view = createPersistedAssessmentView("en");

    expect(registry.assessmentKey).toBe(assessmentDefinition.assessmentKey);
    expect(registry.assessmentVersion).toBe(assessmentDefinition.version);
    expect(view.items).toHaveLength(6);
    expect(view.items.map((item) => item.key)).toEqual(registry.items.map((item) => item.key));
    for (const [index, item] of view.items.entries()) {
      expect(item.options.map((option) => option.id)).toEqual(registry.items[index]!.optionIds);
    }
    expect(collectObjectKeys(view)).not.toEqual(
      expect.arrayContaining([
        "rubric",
        "rubricPoints",
        "weightBasisPoints",
        "score",
        "result",
        "recommendation",
        "competency",
        "targetKind",
        "targetKey",
      ]),
    );
  });

  it("accepts only the exact client mutation shape and accepted item/option pairs", () => {
    expect(parseSavePersistedResponseInput(validInput)).toEqual(validInput);
    expect(() =>
      parseSavePersistedResponseInput({ ...validInput, selectedOptionId: "unknown-option" }),
    ).toThrow("outside the accepted fixture");
    expect(() =>
      parseSavePersistedResponseInput({ ...validInput, itemKey: "unknown-item" }),
    ).toThrow("outside the accepted fixture");
    expect(() => parseSavePersistedResponseInput({ ...validInput, expectedRevision: -1 })).toThrow(
      "invalid",
    );
    expect(() =>
      parseSavePersistedResponseInput({ ...validInput, clientMutationId: "not-a-uuid" }),
    ).toThrow("invalid");
  });

  it.each(["sessionId", "userId", "assessmentVersionId", "freeText", "score"])(
    "rejects an unsupported browser field named %s",
    (field) => {
      expect(() =>
        parseSavePersistedResponseInput({ ...validInput, [field]: "unexpected" }),
      ).toThrow("unsupported fields");
    },
  );

  it("keeps Thai and English persistence/consent/limitations copy equivalent and explicit", () => {
    expect(Object.keys(persistedAssessmentCopy.th)).toEqual(
      Object.keys(persistedAssessmentCopy.en),
    );
    expect(persistedAssessmentCopy.th.boundaries).toHaveLength(4);
    expect(persistedAssessmentCopy.en.boundaries).toHaveLength(4);
    expect(persistedAssessmentCopy.th.introduction).toContain("ไม่คัดลอก");
    expect(persistedAssessmentCopy.en.introduction).toContain("never copies");
    expect(persistedAssessmentCopy.th.completionBoundary).toContain("ไม่มีคะแนน");
    expect(persistedAssessmentCopy.en.completionBoundary).toContain("no score");
  });
});
