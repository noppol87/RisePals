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
import {
  SOURCE_VERIFICATION_LESSON_KEY,
  SOURCE_VERIFICATION_LESSON_VERSION,
  SOURCE_VERIFICATION_LESSON_VERSION_ID,
} from "@/modules/lesson/source-verification/types";

export const SYNTHETIC_EXAMPLE_RESULT_CONTRACT_VERSION_ID = "synthetic-example-result-contract-v1";
export const VISIBLE_SYNTHETIC_EXAMPLE_FIXTURE_ID = "synthetic-mixed-review";

const fixtureKeys = [
  "assessmentId",
  "fixtureId",
  "frameworkVersionId",
  "responses",
  "scoringModelId",
] as const;
const responseKeys = ["itemKey", "optionId"] as const;

export function getVisibleSyntheticExampleFixture(): SyntheticFixtureInput {
  validateReviewedSyntheticFixtureRegistry(syntheticRawResponseFixtures);
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
  const reviewedFixture = resolveReviewedSyntheticFixture(fixture);
  const score = scoreAssessmentFixture(reviewedFixture);
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
    fixtureId: reviewedFixture.fixtureId,
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
      fixtureId: reviewedFixture.fixtureId,
      targetCompetencyId: nextPractice.targetCompetencyId,
      scoringModelVersionId: nextPractice.scoringModelVersionId,
      scoringModelVersion: nextPractice.scoringModelVersion,
      supportingItemKeys: [...nextPractice.supportingItemKeys],
      prototypeLesson: { ...nextPractice.prototypeLesson },
    },
  };
}

export function validateReviewedSyntheticFixtureRegistry(
  registry: readonly SyntheticFixtureInput[],
): void {
  if (registry.length === 0) {
    throw new Error("reviewed synthetic fixture registry must not be empty.");
  }

  const fixtureIds = new Set<string>();
  const contentSignatures = new Map<string, string>();

  for (const fixture of registry) {
    if (!hasExactKeys(fixture, fixtureKeys)) {
      throw new Error(
        `reviewed synthetic fixture ${fixture.fixtureId} must use the exact canonical fixture shape.`,
      );
    }

    if (fixtureIds.has(fixture.fixtureId)) {
      throw new Error(
        `reviewed synthetic fixture registry contains duplicate fixture ID: ${fixture.fixtureId}.`,
      );
    }
    fixtureIds.add(fixture.fixtureId);

    for (const response of fixture.responses) {
      if (!hasExactKeys(response, responseKeys)) {
        throw new Error(
          `reviewed synthetic fixture ${fixture.fixtureId} must use exact response item/option pairs.`,
        );
      }
    }

    const contentSignature = fixtureContentSignature(fixture);
    const existingFixtureId = contentSignatures.get(contentSignature);
    if (existingFixtureId) {
      throw new Error(
        `reviewed synthetic fixture registry contains ambiguous content for ${existingFixtureId} and ${fixture.fixtureId}.`,
      );
    }
    contentSignatures.set(contentSignature, fixture.fixtureId);
  }
}

function resolveReviewedSyntheticFixture(fixture: SyntheticFixtureInput): SyntheticFixtureInput {
  validateReviewedSyntheticFixtureRegistry(syntheticRawResponseFixtures);

  const reviewedFixture = syntheticRawResponseFixtures.find(
    (candidate) => candidate.fixtureId === fixture.fixtureId,
  );
  if (!reviewedFixture) {
    throw new Error(`synthetic fixture ${fixture.fixtureId} is not an approved reviewed fixture.`);
  }

  if (!hasExactKeys(fixture, fixtureKeys)) {
    throw new Error(
      `synthetic fixture ${fixture.fixtureId} must exactly match the reviewed canonical fixture shape.`,
    );
  }

  if (
    fixture.assessmentId !== reviewedFixture.assessmentId ||
    fixture.frameworkVersionId !== reviewedFixture.frameworkVersionId ||
    fixture.scoringModelId !== reviewedFixture.scoringModelId
  ) {
    throw new Error(
      `synthetic fixture ${fixture.fixtureId} compatibility metadata must exactly match the reviewed fixture.`,
    );
  }

  if (!hasExactResponses(fixture, reviewedFixture)) {
    throw new Error(
      `synthetic fixture ${fixture.fixtureId} response item/option pairs must exactly match the reviewed fixture.`,
    );
  }

  return reviewedFixture;
}

function hasExactResponses(
  fixture: SyntheticFixtureInput,
  reviewedFixture: SyntheticFixtureInput,
): boolean {
  return (
    fixture.responses.length === reviewedFixture.responses.length &&
    fixture.responses.every((response, index) => {
      const reviewedResponse = reviewedFixture.responses[index];
      return (
        reviewedResponse !== undefined &&
        hasExactKeys(response, responseKeys) &&
        response.itemKey === reviewedResponse.itemKey &&
        response.optionId === reviewedResponse.optionId
      );
    })
  );
}

function fixtureContentSignature(fixture: SyntheticFixtureInput): string {
  return JSON.stringify([
    fixture.assessmentId,
    fixture.frameworkVersionId,
    fixture.scoringModelId,
    fixture.responses.map((response) => [response.itemKey, response.optionId]),
  ]);
}

function hasExactKeys(value: object, expectedKeys: readonly string[]): boolean {
  const actualKeys = Object.keys(value).sort();
  const sortedExpectedKeys = [...expectedKeys].sort();
  return (
    actualKeys.length === sortedExpectedKeys.length &&
    actualKeys.every((key, index) => key === sortedExpectedKeys[index])
  );
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

  if (
    nextPractice.prototypeLesson.lessonKey !== SOURCE_VERIFICATION_LESSON_KEY ||
    nextPractice.prototypeLesson.lessonVersionId !== SOURCE_VERIFICATION_LESSON_VERSION_ID ||
    nextPractice.prototypeLesson.version !== SOURCE_VERIFICATION_LESSON_VERSION ||
    nextPractice.prototypeLesson.status !== "prototype" ||
    nextPractice.prototypeLesson.availability !== "prototype-available"
  ) {
    throw new Error("next-practice lesson reference must match the exact available prototype.");
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
