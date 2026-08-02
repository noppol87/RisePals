import type {
  CoreCompetencyId,
  MultiplierId,
  SyntheticRawResponseFixture,
} from "@/modules/assessment/types";

export type ExampleCoreSignal = Readonly<{
  competencyId: CoreCompetencyId;
  earnedPoints: number;
  availablePoints: number;
  evidenceCount: number;
  supportingItemKeys: readonly string[];
}>;

export type ExampleMultiplierObservation = Readonly<{
  multiplierId: MultiplierId;
  evidenceCount: 1;
  supportingItemKeys: readonly [string];
}>;

export type PlannedLessonVersionReference = Readonly<{
  lessonVersionId: string;
  availability: "planned-unavailable";
}>;

export type ExampleNextPracticeDefinition = Readonly<{
  id: string;
  version: string;
  exampleOnly: true;
  targetCompetencyId: CoreCompetencyId;
  scoringModelVersionId: string;
  scoringModelVersion: string;
  supportingItemKeys: readonly string[];
  plannedLesson: PlannedLessonVersionReference;
}>;

export type ExampleNextPracticeTrace = Readonly<{
  definitionId: string;
  definitionVersion: string;
  exampleOnly: true;
  fixtureId: string;
  targetCompetencyId: CoreCompetencyId;
  scoringModelVersionId: string;
  scoringModelVersion: string;
  supportingItemKeys: readonly string[];
  plannedLesson: PlannedLessonVersionReference;
}>;

export type SyntheticExampleResult = Readonly<{
  contract: "synthetic-example-result";
  contractVersionId: string;
  exampleOnly: true;
  source: "reviewed-synthetic-fixture";
  fixtureId: string;
  assessmentVersionId: string;
  frameworkVersionId: string;
  scoringModelVersionId: string;
  coreSignals: readonly ExampleCoreSignal[];
  unassessedCoreCompetencyIds: readonly CoreCompetencyId[];
  multiplierObservations: readonly ExampleMultiplierObservation[];
  exampleNextPractice: ExampleNextPracticeTrace;
}>;

export type SyntheticFixtureInput = SyntheticRawResponseFixture;
