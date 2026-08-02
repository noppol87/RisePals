import type {
  ExplanationCode,
  LimitationCode,
  ScoreExplanationRecord,
} from "@/modules/assessment/types";

type ExpectedExplanationFixture = Readonly<{
  fixtureId: string;
  records: readonly ScoreExplanationRecord[];
}>;

const runLimitations = [
  "not-validated-assessment",
  "partial-core-slice",
  "cannot-predict-job-loss",
  "cannot-predict-job-performance",
  "cannot-determine-employability",
  "cannot-determine-hiring-eligibility",
] as const satisfies readonly LimitationCode[];

const expectedRecords = [
  {
    id: "explanation-assessment-workplace-scenarios-fixture-v1",
    explanationCode: "fixture-slice-observation",
    target: { kind: "assessment", id: "assessment-workplace-scenarios-fixture-v1" },
    supportingItemKeys: [
      "verify-ai-summary-source",
      "test-process-assumption",
      "map-downstream-impact",
      "trace-recurring-bottleneck",
      "own-shared-outcome",
      "move-with-safe-urgency",
    ],
    limitationCodes: runLimitations,
  },
  {
    id: "explanation-critical-thinking-fact-checking",
    explanationCode: "core-signal-observation",
    target: { kind: "core", id: "critical-thinking-fact-checking" },
    supportingItemKeys: ["verify-ai-summary-source", "test-process-assumption"],
    limitationCodes: ["not-validated-assessment", "partial-core-slice"],
  },
  {
    id: "explanation-systematic-thinking",
    explanationCode: "core-signal-observation",
    target: { kind: "core", id: "systematic-thinking" },
    supportingItemKeys: ["map-downstream-impact", "trace-recurring-bottleneck"],
    limitationCodes: ["not-validated-assessment", "partial-core-slice"],
  },
  {
    id: "explanation-ownership-thinking",
    explanationCode: "multiplier-single-scenario-observation",
    target: { kind: "multiplier", id: "ownership-thinking" },
    supportingItemKeys: ["own-shared-outcome"],
    limitationCodes: ["not-validated-assessment", "single-scenario-not-behavior-pattern"],
  },
  {
    id: "explanation-sense-of-urgency",
    explanationCode: "multiplier-single-scenario-observation",
    target: { kind: "multiplier", id: "sense-of-urgency" },
    supportingItemKeys: ["move-with-safe-urgency"],
    limitationCodes: ["not-validated-assessment", "single-scenario-not-behavior-pattern"],
  },
] as const satisfies readonly ScoreExplanationRecord[];

const expectedExplanationCodes = [
  "fixture-slice-observation",
  "core-signal-observation",
  "multiplier-single-scenario-observation",
] as const satisfies readonly ExplanationCode[];

export const expectedExplanationFixtures = [
  { fixtureId: "synthetic-deliberate-review", records: expectedRecords },
  { fixtureId: "synthetic-mixed-review", records: expectedRecords },
] as const satisfies readonly ExpectedExplanationFixture[];

export { expectedExplanationCodes };
