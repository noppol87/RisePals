import { ASSESSMENT_ID, SCORING_MODEL_ID } from "@/modules/assessment/assessment";
import { FRAMEWORK_VERSION_ID } from "@/modules/assessment/framework";
import type { SyntheticRawResponseFixture } from "@/modules/assessment/types";

export const syntheticRawResponseFixtures = [
  {
    fixtureId: "synthetic-deliberate-review",
    assessmentId: ASSESSMENT_ID,
    frameworkVersionId: FRAMEWORK_VERSION_ID,
    scoringModelId: SCORING_MODEL_ID,
    responses: [
      {
        itemKey: "verify-ai-summary-source",
        optionId: "verify-ai-summary-source-check-claims",
      },
      {
        itemKey: "test-process-assumption",
        optionId: "test-process-assumption-define-evidence",
      },
      {
        itemKey: "map-downstream-impact",
        optionId: "map-downstream-impact-map-test",
      },
      {
        itemKey: "trace-recurring-bottleneck",
        optionId: "trace-recurring-bottleneck-trace-flow",
      },
      {
        itemKey: "own-shared-outcome",
        optionId: "own-shared-outcome-coordinate-fix",
      },
      {
        itemKey: "move-with-safe-urgency",
        optionId: "move-with-safe-urgency-small-step",
      },
    ],
  },
  {
    fixtureId: "synthetic-mixed-review",
    assessmentId: ASSESSMENT_ID,
    frameworkVersionId: FRAMEWORK_VERSION_ID,
    scoringModelId: SCORING_MODEL_ID,
    responses: [
      {
        itemKey: "verify-ai-summary-source",
        optionId: "verify-ai-summary-source-discard-all",
      },
      {
        itemKey: "test-process-assumption",
        optionId: "test-process-assumption-roll-out",
      },
      {
        itemKey: "map-downstream-impact",
        optionId: "map-downstream-impact-ask-separately",
      },
      {
        itemKey: "trace-recurring-bottleneck",
        optionId: "trace-recurring-bottleneck-trace-flow",
      },
      {
        itemKey: "own-shared-outcome",
        optionId: "own-shared-outcome-fix-own-copy",
      },
      {
        itemKey: "move-with-safe-urgency",
        optionId: "move-with-safe-urgency-wait-certainty",
      },
    ],
  },
] as const satisfies readonly SyntheticRawResponseFixture[];
