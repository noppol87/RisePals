import { evaluateSourceVerificationPractice } from "@/modules/lesson/source-verification/evaluate";
import type {
  SourceVerificationCriterionId,
  SourceVerificationLessonView,
  SourceVerificationPracticeEvaluation,
  SourceVerificationPracticeSelection,
} from "@/modules/lesson/source-verification/types";

export type SourceVerificationPracticeState = Readonly<{
  phase: "practice" | "feedback";
  selections: readonly SourceVerificationPracticeSelection[];
  evaluation: SourceVerificationPracticeEvaluation | null;
}>;

export type SourceVerificationSubmitResult =
  | Readonly<{ ok: true; state: SourceVerificationPracticeState }>
  | Readonly<{ ok: false; reason: "incomplete"; state: SourceVerificationPracticeState }>;

export function createInitialSourceVerificationPracticeState(): SourceVerificationPracticeState {
  return {
    phase: "practice",
    selections: [],
    evaluation: null,
  };
}

export function selectSourceVerificationOption(
  state: SourceVerificationPracticeState,
  view: SourceVerificationLessonView,
  criterionId: SourceVerificationCriterionId,
  optionId: string,
): SourceVerificationPracticeState {
  const criterion = view.practice.criteria.find((candidate) => candidate.id === criterionId);
  if (!criterion || !criterion.options.some((option) => option.id === optionId)) {
    throw new Error(`unknown practice option: ${criterionId}/${optionId}.`);
  }

  return {
    phase: "practice",
    selections: [
      ...state.selections.filter((selection) => selection.criterionId !== criterionId),
      { criterionId, optionId },
    ].sort(
      (left, right) =>
        view.practice.criteria.findIndex(
          (criterionValue) => criterionValue.id === left.criterionId,
        ) -
        view.practice.criteria.findIndex(
          (criterionValue) => criterionValue.id === right.criterionId,
        ),
    ),
    evaluation: null,
  };
}

export function submitSourceVerificationPractice(
  state: SourceVerificationPracticeState,
  view: SourceVerificationLessonView,
): SourceVerificationSubmitResult {
  const result = evaluateSourceVerificationPractice(view, state.selections);
  if (!result.ok) {
    return { ok: false, reason: "incomplete", state };
  }

  return {
    ok: true,
    state: {
      phase: "feedback",
      selections: [...state.selections],
      evaluation: result.evaluation,
    },
  };
}

export function retrySourceVerificationPractice(
  state: SourceVerificationPracticeState,
): SourceVerificationPracticeState {
  return {
    phase: "practice",
    selections: [...state.selections],
    evaluation: null,
  };
}

export function resetSourceVerificationPractice(): SourceVerificationPracticeState {
  return createInitialSourceVerificationPracticeState();
}

export function getSourceVerificationPracticeOutcome(
  state: SourceVerificationPracticeState,
): Readonly<{ demonstrated: boolean; previewXp: 0 | 20 }> {
  return {
    demonstrated: state.evaluation?.demonstrated ?? false,
    previewXp: state.evaluation?.previewXp ?? 0,
  };
}
