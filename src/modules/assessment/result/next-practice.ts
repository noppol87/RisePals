import { SCORING_MODEL_ID, scoringModelDefinition } from "@/modules/assessment/assessment";
import type { ExampleNextPracticeDefinition } from "@/modules/assessment/result/types";

export const exampleNextPracticeDefinition = {
  id: "example-practice-source-verification-v1",
  version: "1.0.0",
  exampleOnly: true,
  targetCompetencyId: "critical-thinking-fact-checking",
  scoringModelVersionId: SCORING_MODEL_ID,
  scoringModelVersion: scoringModelDefinition.version,
  supportingItemKeys: ["verify-ai-summary-source", "test-process-assumption"],
  plannedLesson: {
    lessonVersionId: "lesson-source-verification-practice-planned-v1",
    availability: "planned-unavailable",
  },
} as const satisfies ExampleNextPracticeDefinition;
