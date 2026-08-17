import type { CoreCompetencyId, LimitationCode, MultiplierId } from "@/modules/assessment/types";

export type PersistedResultContentIdentity = Readonly<{
  contentId: string;
  key: string;
  version: string;
  contentDigest: string;
}>;

export type PersistedResultResponseInput = Readonly<{
  itemKey: string;
  displayOrder: number;
  revision: number;
  selectedOptionId: string;
}>;

export type PersistedResultDerivationInput = Readonly<{
  assessment: PersistedResultContentIdentity;
  framework: PersistedResultContentIdentity;
  scoringModel: PersistedResultContentIdentity;
  responses: readonly PersistedResultResponseInput[];
}>;

export type PersistedCoreScore = Readonly<{
  competencyId: CoreCompetencyId;
  earnedPoints: number;
  availablePoints: number;
  evidenceCount: number;
  normalizedBasisPoints: number;
  supportingItemKeys: readonly string[];
}>;

export type PersistedMultiplierObservation = Readonly<{
  multiplierId: MultiplierId;
  earnedRubricPoints: number;
  availableRubricPoints: number;
  evidenceCount: number;
  supportingItemKeys: readonly string[];
}>;

export type PersistedResultExplanationCode =
  | "synthetic-partial-result-limitation"
  | "assessed-core-raw-signal"
  | "single-scenario-multiplier-observation"
  | "unique-lowest-assessed-core-signal"
  | "no-distinct-priority";

export type PersistedResultExplanationTarget =
  | Readonly<{ kind: "run"; id: "result" }>
  | Readonly<{ kind: "core"; id: CoreCompetencyId }>
  | Readonly<{ kind: "multiplier"; id: MultiplierId }>
  | Readonly<{ kind: "priority"; id: CoreCompetencyId | "none" }>;

export type PersistedResultExplanation = Readonly<{
  explanationCode: PersistedResultExplanationCode;
  target: PersistedResultExplanationTarget;
  supportingItemKeys: readonly string[];
  limitationCodes: readonly LimitationCode[];
  messageParams: Readonly<{ schemaVersion: "persisted-result-explanation-params-v1" }>;
}>;

export type PersistedPriorityRecommendation = Readonly<{
  competencyId: CoreCompetencyId;
  rank: 1;
  reasonCode: "unique-lowest-assessed-core-signal";
  supportingItemKeys: readonly string[];
  nextAction:
    | Readonly<{
        kind: "prototype-lesson";
        lessonVersionId: "lesson-source-verification-practice-v1";
        lessonVersion: "1.0.0";
      }>
    | Readonly<{ kind: "practice-unavailable" }>;
}>;

export type PersistedResultSemanticOutput = Readonly<{
  contract: "persisted-synthetic-result";
  contractVersion: "1.0.0";
  syntheticAlphaOnly: true;
  assessmentContentId: string;
  frameworkContentId: string;
  scoringModelContentId: string;
  resultPolicyKey: string;
  resultPolicyVersion: string;
  resultPolicyDigest: string;
  coreScores: readonly PersistedCoreScore[];
  unassessedCoreCompetencyIds: readonly CoreCompetencyId[];
  multiplierObservations: readonly PersistedMultiplierObservation[];
  explanations: readonly PersistedResultExplanation[];
  priorityRecommendation: PersistedPriorityRecommendation | null;
}>;

export type PersistedResultDerivation = Readonly<{
  inputDigest: string;
  outputDigest: string;
  canonicalInput: string;
  canonicalOutput: string;
  semanticOutput: PersistedResultSemanticOutput;
}>;
