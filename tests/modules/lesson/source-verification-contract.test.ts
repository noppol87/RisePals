import { describe, expect, it } from "vitest";
import { FRAMEWORK_VERSION_ID } from "@/modules/assessment/framework";
import {
  SOURCE_VERIFICATION_LESSON_KEY,
  SOURCE_VERIFICATION_LESSON_VERSION,
  SOURCE_VERIFICATION_LESSON_VERSION_ID,
  SOURCE_VERIFICATION_PRACTICE_ID,
  SOURCE_VERIFICATION_PROOF_ID,
  SOURCE_VERIFICATION_RUBRIC_VERSION_ID,
  createSourceVerificationLessonView,
  sourceVerificationCriterionIds,
  sourceVerificationLessonDefinition,
  sourceVerificationProofFieldIds,
  validateSourceVerificationLessonDefinition,
} from "@/modules/lesson/source-verification";

function structuralKeys(value: unknown, prefix = ""): string[] {
  if (typeof value === "string") {
    return [prefix];
  }
  if (Array.isArray(value)) {
    return value.flatMap((child, index) => structuralKeys(child, `${prefix}[${index}]`));
  }
  if (value === null || typeof value !== "object") {
    return [prefix];
  }
  return Object.entries(value).flatMap(([key, child]) =>
    structuralKeys(child, prefix ? `${prefix}.${key}` : key),
  );
}

describe("source-verification lesson content contract", () => {
  it("validates the exact lesson, framework, practice, rubric, proof, stage and R.O.I. identities", () => {
    expect(() =>
      validateSourceVerificationLessonDefinition(sourceVerificationLessonDefinition),
    ).not.toThrow();
    expect(sourceVerificationLessonDefinition.lesson).toMatchObject({
      key: SOURCE_VERIFICATION_LESSON_KEY,
      versionId: SOURCE_VERIFICATION_LESSON_VERSION_ID,
      version: SOURCE_VERIFICATION_LESSON_VERSION,
      status: "prototype",
      frameworkVersionId: FRAMEWORK_VERSION_ID,
      targetCompetencyId: "critical-thinking-fact-checking",
      targetWorkingStage: "Practicing",
      primaryRoiPillar: "Intelligent Risk & Governance",
      practiceId: SOURCE_VERIFICATION_PRACTICE_ID,
      rubricVersionId: SOURCE_VERIFICATION_RUBRIC_VERSION_ID,
      proofId: SOURCE_VERIFICATION_PROOF_ID,
      provenance: "git-versioned-local-prototype",
    });
    expect(sourceVerificationLessonDefinition.practice.criterionIds).toEqual(
      sourceVerificationCriterionIds,
    );
    expect(sourceVerificationLessonDefinition.proof.fieldIds).toEqual(
      sourceVerificationProofFieldIds,
    );
  });

  it("keeps Thai and English content structurally complete and locale-specific", () => {
    const thai = sourceVerificationLessonDefinition.content.th;
    const english = sourceVerificationLessonDefinition.content.en;
    expect(
      structuralKeys(thai)
        .filter((key) => key !== "locale")
        .sort(),
    ).toEqual(
      structuralKeys(english)
        .filter((key) => key !== "locale")
        .sort(),
    );
    expect(thai.locale).toBe("th");
    expect(english.locale).toBe("en");
    expect(createSourceVerificationLessonView("th").lesson.locale).toBe("th");
    expect(createSourceVerificationLessonView("en").lesson.locale).toBe("en");
  });

  it("rejects malformed localized content and raw HTML", () => {
    const missingHeading = structuredClone(sourceVerificationLessonDefinition) as unknown as {
      content: { th: { hero: { heading?: string } } };
    };
    delete missingHeading.content.th.hero.heading;
    const rawHtml = {
      ...sourceVerificationLessonDefinition,
      content: {
        ...sourceVerificationLessonDefinition.content,
        en: {
          ...sourceVerificationLessonDefinition.content.en,
          hero: {
            ...sourceVerificationLessonDefinition.content.en.hero,
            heading: "<strong>Unreviewed HTML</strong>",
          },
        },
      },
    };

    expect(() => validateSourceVerificationLessonDefinition(missingHeading)).toThrow(
      "th hero must use the exact contract shape.",
    );
    expect(() => validateSourceVerificationLessonDefinition(rawHtml)).toThrow(
      "en content contains empty or raw-HTML copy.",
    );
  });

  it("rejects unknown lesson identities and altered rubric links", () => {
    const unknownLesson = {
      ...sourceVerificationLessonDefinition,
      lesson: { ...sourceVerificationLessonDefinition.lesson, key: "unknown-lesson" },
    };
    const alteredPracticeRubric = {
      ...sourceVerificationLessonDefinition,
      practice: {
        ...sourceVerificationLessonDefinition.practice,
        rubricVersionId: "unknown-rubric-v1",
      },
    };
    const alteredCriterionLink = {
      ...sourceVerificationLessonDefinition,
      rubric: {
        ...sourceVerificationLessonDefinition.rubric,
        criteria: sourceVerificationLessonDefinition.rubric.criteria.map((criterion, index) =>
          index === 0 ? { ...criterion, practiceCriterionId: "claim-source-fit" } : criterion,
        ),
      },
    };

    expect(() => validateSourceVerificationLessonDefinition(unknownLesson)).toThrow(
      "lesson key must equal source-verification-practice.",
    );
    expect(() => validateSourceVerificationLessonDefinition(alteredPracticeRubric)).toThrow(
      "practice rubric link must equal source-verification-rubric-v1.",
    );
    expect(() => validateSourceVerificationLessonDefinition(alteredCriterionLink)).toThrow(
      "rubric criterion 1 practice link must equal evidence-traceability.",
    );
  });

  it.each([
    ["viewingPreviewXp", 1, "viewing XP must equal 0."],
    ["incompletePreviewXp", 10, "incomplete XP must equal 0."],
    ["demonstratedPreviewXp", 40, "demonstrated XP must equal 20."],
    ["accumulation", "add", "XP accumulation rule must equal replace-not-add."],
    ["persisted", true, "XP persistence rule must equal false."],
  ] as const)("rejects invalid %s XP rules", (field, value, message) => {
    const invalid = {
      ...sourceVerificationLessonDefinition,
      xpRule: { ...sourceVerificationLessonDefinition.xpRule, [field]: value },
    };
    expect(() => validateSourceVerificationLessonDefinition(invalid)).toThrow(message);
  });

  it("contains only synthetic prototype provenance and no publication or reviewer claim", () => {
    const serialized = JSON.stringify(sourceVerificationLessonDefinition);
    expect(serialized).toContain("git-versioned-local-prototype");
    expect(serialized).toContain("Bright River Operations");
    for (const forbidden of [
      "publishedAt",
      "publishedBy",
      "authorId",
      "reviewerId",
      "externallyValidated",
      "learningEfficacy",
    ]) {
      expect(serialized).not.toContain(forbidden);
    }
  });
});
