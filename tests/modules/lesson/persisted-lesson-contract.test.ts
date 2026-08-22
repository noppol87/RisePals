import { describe, expect, it, vi } from "vitest";
import {
  createClientSafePracticeView,
  getPersistedLessonMetadata,
  parsePersistedLessonMutationInput,
  parsePersistedPracticeSelections,
} from "@/modules/lesson/persistence/contract";

vi.mock("server-only", () => ({}));

const canonicalSelections = [
  { criterionId: "evidence-traceability", optionId: "trace-claim-to-source-map" },
  { criterionId: "claim-source-fit", optionId: "fit-narrow-to-supported-teams" },
  { criterionId: "safe-next-action", optionId: "safe-hold-and-resolve-gaps" },
] as const;

describe("persisted lesson client contract", () => {
  it("anchors persistence to the exact accepted publication and evaluation identities", () => {
    expect(getPersistedLessonMetadata()).toEqual({
      lessonKey: "source-verification-practice",
      lessonVersionId: "lesson-source-verification-practice-v1",
      lessonVersion: "1.0.0",
      lessonDigest: "51903ea9e6053a1102b4d60ad072c9a1dcde26a90d6a0ca7ae36cba8a6995e91",
      practiceId: "source-verification-decision-v1",
      practiceVersion: "1.0.0",
      rubricVersionId: "source-verification-rubric-v1",
      rubricVersion: "1.0.0",
      evaluationContractVersionId: "source-verification-evaluation-v1",
    });
  });

  it.each(["th", "en"] as const)(
    "exposes a complete %s practice view without evaluator internals",
    (locale) => {
      const view = createClientSafePracticeView(locale);
      expect(view.criteria).toHaveLength(3);
      expect(view.criteria.flatMap((criterion) => criterion.options)).toHaveLength(9);
      const serialized = JSON.stringify(view);
      expect(serialized).not.toContain("meetsCriterion");
      expect(serialized).not.toContain("lessonDigest");
      expect(serialized).not.toContain("source-verification-evaluation-v1");
      expect(serialized).not.toContain("demonstratedPreviewXp");
    },
  );

  it("accepts only canonical, ordered, unique selections", () => {
    expect(parsePersistedPracticeSelections(canonicalSelections, false)).toEqual(
      canonicalSelections,
    );
    expect(() => parsePersistedPracticeSelections(canonicalSelections.slice(0, 2), false)).toThrow(
      "All practice criteria are required",
    );
    expect(() =>
      parsePersistedPracticeSelections(
        [canonicalSelections[1], canonicalSelections[0], canonicalSelections[2]],
        false,
      ),
    ).toThrow("unknown, duplicated or out of canonical order");
    expect(() =>
      parsePersistedPracticeSelections(
        [{ criterionId: "evidence-traceability", optionId: "unknown-option" }],
        true,
      ),
    ).toThrow("unknown, duplicated or out of canonical order");
  });

  it("uses an exact mutation allowlist and requires a complete evaluation snapshot", () => {
    const mutationId = "80000000-0000-4000-8000-000000000001";
    expect(
      parsePersistedLessonMutationInput({
        locale: "en",
        intent: "save",
        selections: canonicalSelections,
        expectedRevision: 2,
        clientMutationId: mutationId,
      }),
    ).toMatchObject({ intent: "save", expectedRevision: 2 });
    expect(
      parsePersistedLessonMutationInput({
        locale: "th",
        intent: "evaluate",
        selections: canonicalSelections,
        expectedRevision: 3,
        clientMutationId: mutationId,
      }),
    ).toHaveProperty("selections", canonicalSelections);
    expect(() =>
      parsePersistedLessonMutationInput({
        locale: "th",
        intent: "evaluate",
        expectedRevision: 3,
        clientMutationId: mutationId,
      }),
    ).toThrow("unsupported fields");
  });
});
