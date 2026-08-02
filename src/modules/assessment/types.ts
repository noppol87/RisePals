export const assessmentLocales = ["th", "en"] as const;

export type AssessmentLocale = (typeof assessmentLocales)[number];
export type LocalizedText = Readonly<Record<AssessmentLocale, string>>;

export type CoreCompetencyId =
  | "critical-thinking-fact-checking"
  | "systematic-thinking"
  | "growth-mindset"
  | "emotional-intelligence"
  | "resilience-adaptability"
  | "curiosity"
  | "ethical-judgement-governance"
  | "strategic-storytelling-framing";

export type MultiplierId = "ownership-thinking" | "sense-of-urgency";
export type FrameworkMemberId = CoreCompetencyId | MultiplierId;

export type CoreCompetencyDefinition = Readonly<{
  id: CoreCompetencyId;
  kind: "core";
  weightBasisPoints: number;
  displayOrder: number;
  name: LocalizedText;
}>;

export type MultiplierDefinition = Readonly<{
  id: MultiplierId;
  kind: "multiplier";
  displayOrder: number;
  name: LocalizedText;
}>;

export type FrameworkDefinition = Readonly<{
  id: string;
  frameworkKey: string;
  version: string;
  coreCompetencies: readonly CoreCompetencyDefinition[];
  multipliers: readonly MultiplierDefinition[];
}>;

export type AssessmentOption = Readonly<{
  id: string;
  label: LocalizedText;
  rubricPoints: number;
}>;

export type AssessmentItem = Readonly<{
  key: string;
  type: "scenario-choice";
  required: true;
  displayOrder: number;
  prompt: LocalizedText;
  options: readonly AssessmentOption[];
  rubric: Readonly<{
    targetKind: "core" | "multiplier";
    targetId: FrameworkMemberId;
    availablePoints: number;
  }>;
}>;

export type AssessmentDefinition = Readonly<{
  id: string;
  assessmentKey: string;
  version: string;
  frameworkVersionId: string;
  items: readonly AssessmentItem[];
}>;

export type ScoringModelDefinition = Readonly<{
  id: string;
  scoringKey: string;
  version: string;
  assessmentId: string;
  frameworkVersionId: string;
  method: "deterministic-integer-rubric";
  pointScale: Readonly<{
    minimum: number;
    maximum: number;
    step: number;
  }>;
}>;

export type RawAssessmentResponse = Readonly<{
  itemKey: string;
  optionId: string;
}>;

export type SyntheticRawResponseFixture = Readonly<{
  fixtureId: string;
  assessmentId: string;
  frameworkVersionId: string;
  scoringModelId: string;
  responses: readonly RawAssessmentResponse[];
}>;

export type CoreSkillSignal = Readonly<{
  competencyId: CoreCompetencyId;
  earnedPoints: number;
  availablePoints: number;
  evidenceCount: number;
  supportingItemKeys: readonly string[];
}>;

export type MultiplierObservation = Readonly<{
  multiplierId: MultiplierId;
  earnedRubricPoints: number;
  availableRubricPoints: number;
  evidenceCount: number;
  supportingItemKeys: readonly string[];
}>;

export type ProvisionalScoringOutput = Readonly<{
  contract: "assessment-fixture-scoring";
  provisional: true;
  fixtureOnly: true;
  assessmentId: string;
  frameworkVersionId: string;
  scoringModelId: string;
  coreSkillSignals: readonly CoreSkillSignal[];
  multiplierObservations: readonly MultiplierObservation[];
  unassessedCoreCompetencyIds: readonly CoreCompetencyId[];
}>;

export type ExplanationCode =
  | "fixture-slice-observation"
  | "core-signal-observation"
  | "multiplier-single-scenario-observation";

export type LimitationCode =
  | "not-validated-assessment"
  | "partial-core-slice"
  | "single-scenario-not-behavior-pattern"
  | "cannot-predict-job-loss"
  | "cannot-predict-job-performance"
  | "cannot-determine-employability"
  | "cannot-determine-hiring-eligibility";

export type ExplanationTarget =
  | Readonly<{ kind: "assessment"; id: string }>
  | Readonly<{ kind: "core"; id: CoreCompetencyId }>
  | Readonly<{ kind: "multiplier"; id: MultiplierId }>;

export type ScoreExplanationRecord = Readonly<{
  id: string;
  explanationCode: ExplanationCode;
  target: ExplanationTarget;
  supportingItemKeys: readonly string[];
  limitationCodes: readonly LimitationCode[];
}>;

export type ExplanationCopy = Readonly<{
  heading: LocalizedText;
  body: LocalizedText;
}>;

export type LimitationCopy = Readonly<{
  body: LocalizedText;
}>;
