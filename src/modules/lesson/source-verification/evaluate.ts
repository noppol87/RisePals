import {
  SOURCE_VERIFICATION_EVALUATION_CONTRACT_VERSION_ID,
  sourceVerificationCriterionIds,
  type SourceVerificationLessonView,
  type SourceVerificationPracticeEvaluation,
  type SourceVerificationPracticeSelection,
} from "@/modules/lesson/source-verification/types";

export type SourceVerificationEvaluationResult =
  | Readonly<{
      ok: true;
      evaluation: SourceVerificationPracticeEvaluation;
    }>
  | Readonly<{
      ok: false;
      reason: "incomplete";
      missingCriterionIds: readonly string[];
    }>;

export function evaluateSourceVerificationPractice(
  view: SourceVerificationLessonView,
  selections: readonly SourceVerificationPracticeSelection[],
): SourceVerificationEvaluationResult {
  const selectionMap = new Map<string, SourceVerificationPracticeSelection>();

  for (const selection of selections) {
    if (selectionMap.has(selection.criterionId)) {
      throw new Error(`duplicate practice selection: ${selection.criterionId}.`);
    }
    const criterion = view.practice.criteria.find(
      (candidate) => candidate.id === selection.criterionId,
    );
    if (!criterion || !criterion.options.some((option) => option.id === selection.optionId)) {
      throw new Error(
        `unknown practice selection: ${selection.criterionId}/${selection.optionId}.`,
      );
    }
    selectionMap.set(selection.criterionId, selection);
  }

  const missingCriterionIds = sourceVerificationCriterionIds.filter(
    (criterionId) => !selectionMap.has(criterionId),
  );
  if (missingCriterionIds.length > 0) {
    return { ok: false, reason: "incomplete", missingCriterionIds };
  }

  const criterionResults = view.practice.criteria.map((criterion) => {
    const selection = selectionMap.get(criterion.id)!;
    const option = criterion.options.find((candidate) => candidate.id === selection.optionId)!;
    return {
      criterionId: criterion.id,
      selectedOptionId: option.id,
      status: option.meetsCriterion ? "met" : "not-met",
    } as const;
  });
  const demonstrated = criterionResults.every((result) => result.status === "met");

  return {
    ok: true,
    evaluation: {
      contractVersionId: SOURCE_VERIFICATION_EVALUATION_CONTRACT_VERSION_ID,
      practiceId: view.practice.id,
      rubricVersionId: view.practice.rubricVersionId,
      criterionResults,
      demonstrated,
      previewXp: demonstrated ? view.xpRule.demonstratedPreviewXp : view.xpRule.incompletePreviewXp,
      xpSaved: false,
    },
  };
}
