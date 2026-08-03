export { sourceVerificationLessonDefinition } from "@/modules/lesson/source-verification/definition";
export { evaluateSourceVerificationPractice } from "@/modules/lesson/source-verification/evaluate";
export {
  createInitialSourceVerificationPracticeState,
  getSourceVerificationPracticeOutcome,
  resetSourceVerificationPractice,
  retrySourceVerificationPractice,
  selectSourceVerificationOption,
  submitSourceVerificationPractice,
} from "@/modules/lesson/source-verification/state";
export {
  LESSON_CONTENT_CONTRACT_VERSION_ID,
  SOURCE_VERIFICATION_EVALUATION_CONTRACT_VERSION_ID,
  SOURCE_VERIFICATION_LESSON_KEY,
  SOURCE_VERIFICATION_LESSON_VERSION,
  SOURCE_VERIFICATION_LESSON_VERSION_ID,
  SOURCE_VERIFICATION_PRACTICE_ID,
  SOURCE_VERIFICATION_PROOF_ID,
  SOURCE_VERIFICATION_RUBRIC_VERSION_ID,
  sourceVerificationCriterionIds,
  sourceVerificationProofFieldIds,
} from "@/modules/lesson/source-verification/types";
export { validateSourceVerificationLessonDefinition } from "@/modules/lesson/source-verification/validate";
export { createSourceVerificationLessonView } from "@/modules/lesson/source-verification/view";
export type {
  SourceVerificationLessonDefinition,
  SourceVerificationLessonView,
  SourceVerificationPracticeEvaluation,
  SourceVerificationPracticeSelection,
} from "@/modules/lesson/source-verification/types";
export type { SourceVerificationPracticeState } from "@/modules/lesson/source-verification/state";
