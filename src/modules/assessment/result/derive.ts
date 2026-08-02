import { assessmentDefinition, scoringModelDefinition } from "@/modules/assessment/assessment";
import { syntheticRawResponseFixtures } from "@/modules/assessment/fixtures/raw-responses";
import { exampleNextPracticeDefinition } from "@/modules/assessment/result/next-practice";
import type {
  ExampleMultiplierObservation,
  ExampleNextPracticeDefinition,
  SyntheticExampleResult,
  SyntheticFixtureInput,
} from "@/modules/assessment/result/types";
import { scoreAssessmentFixture } from "@/modules/assessment/scoring";

export const SYNTHETIC_EXAMPLE_RESULT_CONTRACT_VERSION_ID = "synthetic-example-result-contract-v1";
export const VISIBLE_SYNTHETIC_EXAMPLE_FIXTURE_ID = "synthetic-mixed-review";

export function getVisibleSyntheticExampleFixture(): SyntheticFixtureInput {
  const fixture = syntheticRawResponseFixtures.find(
    (candidate) => candidate.fixtureId === VISIBLE_SYNTHETIC_EXAMPLE_FIXTURE_ID,
  );

  if (!fixture) {
    throw new Error("visible synthetic example fixture is unavailable.");
  }

  return fixture;
}

export function deriveSyntheticExampleResult(
  fixture: SyntheticFixtureInput,
  nextPractice: ExampleNextPracticeDefinition = exampleNextPracticeDefinition,
): SyntheticExampleResult {
  const score = scoreAssessmentFixture(fixture);
  validateExampleNextPractice(nextPractice, score);

  const multiplierObservations = score.multiplierObservations.map((observation) => {
    if (observation.evidenceCount !== 1 || observation.supportingItemKeys.length !== 1) {
      throw new Error(
        `example multiplier ${observation.multiplierId} must remain a one-scenario observation.`,
      );
    }

    return {
      multiplierId: observation.multiplierId,
      evidenceCount: 1,
      supportingItemKeys: [observation.supportingItemKeys[0]!],
    } as const satisfies ExampleMultiplierObservation;
  });

  return {
    contract: "synthetic-example-result",
    contractVersionId: SYNTHETIC_EXAMPLE_RESULT_CONTRACT_VERSION_ID,
    exampleOnly: true,
    source: "reviewed-synthetic-fixture",
    fixtureId: fixture.fixtureId,
    assessmentVersionId: score.assessmentId,
    frameworkVersionId: score.frameworkVersionId,
    scoringModelVersionId: score.scoringModelId,
    coreSignals: score.coreSkillSignals.map((signal) => ({
      competencyId: signal.competencyId,
      earnedPoints: signal.earnedPoints,
      availablePoints: signal.availablePoints,
      evidenceCount: signal.evidenceCount,
      supportingItemKeys: [...signal.supportingItemKeys],
    })),
    unassessedCoreCompetencyIds: [...score.unassessedCoreCompetencyIds],
    multiplierObservations,
    exampleNextPractice: {
      definitionId: nextPractice.id,
      definitionVersion: nextPractice.version,
      exampleOnly: true,
      fixtureId: fixture.fixtureId,
      targetCompetencyId: nextPractice.targetCompetencyId,
      scoringModelVersionId: nextPractice.scoringModelVersionId,
      scoringModelVersion: nextPractice.scoringModelVersion,
      supportingItemKeys: [...nextPractice.supportingItemKeys],
      plannedLesson: { ...nextPractice.plannedLesson },
    },
  };
}

function validateExampleNextPractice(
  nextPractice: ExampleNextPracticeDefinition,
  score: ReturnType<typeof scoreAssessmentFixture>,
): void {
  if (!nextPractice.exampleOnly) {
    throw new Error("next practice must be explicitly example-only.");
  }

  if (
    nextPractice.scoringModelVersionId !== score.scoringModelId ||
    nextPractice.scoringModelVersion !== scoringModelDefinition.version
  ) {
    throw new Error("next-practice scoring-model compatibility failed.");
  }

  if (nextPractice.plannedLesson.availability !== "planned-unavailable") {
    throw new Error("next-practice lesson reference must remain planned and unavailable.");
  }

  const targetSignal = score.coreSkillSignals.find(
    (signal) => signal.competencyId === nextPractice.targetCompetencyId,
  );
  if (!targetSignal) {
    throw new Error("next-practice target must be covered by the synthetic fixture.");
  }

  if (
    nextPractice.supportingItemKeys.length === 0 ||
    nextPractice.supportingItemKeys.some(
      (itemKey) => !targetSignal.supportingItemKeys.includes(itemKey),
    )
  ) {
    throw new Error("next-practice item trace must belong to the target core signal.");
  }

  const assessmentItems = new Map<string, (typeof assessmentDefinition.items)[number]>(
    assessmentDefinition.items.map((item) => [item.key, item]),
  );
  for (const itemKey of nextPractice.supportingItemKeys) {
    const item = assessmentItems.get(itemKey);
    if (
      !item ||
      item.rubric.targetKind !== "core" ||
      item.rubric.targetId !== nextPractice.targetCompetencyId
    ) {
      throw new Error("next-practice item trace is incompatible with the assessment definition.");
    }
  }
}
