import type { CoreCompetencyId, MultiplierId } from "@/modules/assessment/types";

type ExpectedPointSignal = Readonly<{
  id: CoreCompetencyId | MultiplierId;
  earned: number;
  available: number;
  evidenceCount: number;
  supportingItemKeys: readonly string[];
}>;

export type ExpectedScoringFixture = Readonly<{
  fixtureId: string;
  coreSignals: readonly ExpectedPointSignal[];
  multiplierObservations: readonly ExpectedPointSignal[];
  unassessedCoreCompetencyIds: readonly CoreCompetencyId[];
}>;

const unassessedCoreCompetencyIds = [
  "growth-mindset",
  "emotional-intelligence",
  "resilience-adaptability",
  "curiosity",
  "ethical-judgement-governance",
  "strategic-storytelling-framing",
] as const satisfies readonly CoreCompetencyId[];

export const expectedScoringFixtures = [
  {
    fixtureId: "synthetic-deliberate-review",
    coreSignals: [
      {
        id: "critical-thinking-fact-checking",
        earned: 4,
        available: 4,
        evidenceCount: 2,
        supportingItemKeys: ["verify-ai-summary-source", "test-process-assumption"],
      },
      {
        id: "systematic-thinking",
        earned: 4,
        available: 4,
        evidenceCount: 2,
        supportingItemKeys: ["map-downstream-impact", "trace-recurring-bottleneck"],
      },
    ],
    multiplierObservations: [
      {
        id: "ownership-thinking",
        earned: 2,
        available: 2,
        evidenceCount: 1,
        supportingItemKeys: ["own-shared-outcome"],
      },
      {
        id: "sense-of-urgency",
        earned: 2,
        available: 2,
        evidenceCount: 1,
        supportingItemKeys: ["move-with-safe-urgency"],
      },
    ],
    unassessedCoreCompetencyIds,
  },
  {
    fixtureId: "synthetic-mixed-review",
    coreSignals: [
      {
        id: "critical-thinking-fact-checking",
        earned: 1,
        available: 4,
        evidenceCount: 2,
        supportingItemKeys: ["verify-ai-summary-source", "test-process-assumption"],
      },
      {
        id: "systematic-thinking",
        earned: 3,
        available: 4,
        evidenceCount: 2,
        supportingItemKeys: ["map-downstream-impact", "trace-recurring-bottleneck"],
      },
    ],
    multiplierObservations: [
      {
        id: "ownership-thinking",
        earned: 1,
        available: 2,
        evidenceCount: 1,
        supportingItemKeys: ["own-shared-outcome"],
      },
      {
        id: "sense-of-urgency",
        earned: 1,
        available: 2,
        evidenceCount: 1,
        supportingItemKeys: ["move-with-safe-urgency"],
      },
    ],
    unassessedCoreCompetencyIds,
  },
] as const satisfies readonly ExpectedScoringFixture[];
