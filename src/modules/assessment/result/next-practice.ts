import { SCORING_MODEL_ID, scoringModelDefinition } from "@/modules/assessment/assessment";
import type { ExampleNextPracticeDefinition } from "@/modules/assessment/result/types";
import {
  SOURCE_VERIFICATION_LESSON_KEY,
  SOURCE_VERIFICATION_LESSON_VERSION,
  SOURCE_VERIFICATION_LESSON_VERSION_ID,
} from "@/modules/lesson/source-verification/types";

export const exampleNextPracticeDefinition = {
  id: "example-practice-source-verification-v1",
  version: "1.0.0",
  exampleOnly: true,
  targetCompetencyId: "critical-thinking-fact-checking",
  scoringModelVersionId: SCORING_MODEL_ID,
  scoringModelVersion: scoringModelDefinition.version,
  supportingItemKeys: ["verify-ai-summary-source", "test-process-assumption"],
  prototypeLesson: {
    lessonKey: SOURCE_VERIFICATION_LESSON_KEY,
    lessonVersionId: SOURCE_VERIFICATION_LESSON_VERSION_ID,
    version: SOURCE_VERIFICATION_LESSON_VERSION,
    status: "prototype",
    availability: "prototype-available",
  },
} as const satisfies ExampleNextPracticeDefinition;
