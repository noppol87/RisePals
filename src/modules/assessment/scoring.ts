import { assessmentDefinition, scoringModelDefinition } from "@/modules/assessment/assessment";
import { assessmentFramework } from "@/modules/assessment/framework";
import type {
  AssessmentDefinition,
  CoreSkillSignal,
  FrameworkDefinition,
  MultiplierObservation,
  ProvisionalScoringOutput,
  ScoringModelDefinition,
  SyntheticRawResponseFixture,
} from "@/modules/assessment/types";
import { validateAssessmentDomain } from "@/modules/assessment/validate";

export type AssessmentScoringContext = Readonly<{
  framework: FrameworkDefinition;
  assessment: AssessmentDefinition;
  scoringModel: ScoringModelDefinition;
}>;

export const defaultAssessmentScoringContext: AssessmentScoringContext = {
  framework: assessmentFramework,
  assessment: assessmentDefinition,
  scoringModel: scoringModelDefinition,
};

export function scoreAssessmentFixture(
  fixture: SyntheticRawResponseFixture,
  context: AssessmentScoringContext = defaultAssessmentScoringContext,
): ProvisionalScoringOutput {
  const { framework, assessment, scoringModel } = context;
  validateAssessmentDomain(framework, assessment, scoringModel);

  if (fixture.assessmentId !== assessment.id) {
    throw new Error("response fixture assessment compatibility failed.");
  }

  if (fixture.frameworkVersionId !== framework.id) {
    throw new Error("response fixture framework compatibility failed.");
  }

  if (fixture.scoringModelId !== scoringModel.id) {
    throw new Error("response fixture scoring-version compatibility failed.");
  }

  const itemsByKey = new Map(assessment.items.map((item) => [item.key, item]));
  const responsesByItem = new Map<string, (typeof fixture.responses)[number]>();

  for (const response of fixture.responses) {
    const item = itemsByKey.get(response.itemKey);
    if (!item) {
      throw new Error(`response contains unknown item key: ${response.itemKey}.`);
    }

    if (responsesByItem.has(response.itemKey)) {
      throw new Error(`response contains duplicate item key: ${response.itemKey}.`);
    }

    if (!item.options.some((option) => option.id === response.optionId)) {
      throw new Error(
        `response for ${response.itemKey} contains unknown option ID: ${response.optionId}.`,
      );
    }

    responsesByItem.set(response.itemKey, response);
  }

  const missingItemKeys = assessment.items
    .filter((item) => item.required && !responsesByItem.has(item.key))
    .map((item) => item.key);
  if (missingItemKeys.length > 0) {
    throw new Error(`response is missing required item keys: ${missingItemKeys.join(", ")}.`);
  }

  const scoredItems = assessment.items.map((item) => {
    const response = responsesByItem.get(item.key)!;
    const option = item.options.find((candidate) => candidate.id === response.optionId)!;
    return {
      itemKey: item.key,
      targetKind: item.rubric.targetKind,
      targetId: item.rubric.targetId,
      earnedPoints: option.rubricPoints,
      availablePoints: item.rubric.availablePoints,
    } as const;
  });

  const coreSkillSignals = framework.coreCompetencies.flatMap((competency) => {
    const evidence = scoredItems.filter(
      (item) => item.targetKind === "core" && item.targetId === competency.id,
    );
    if (evidence.length === 0) {
      return [];
    }

    const signal: CoreSkillSignal = {
      competencyId: competency.id,
      earnedPoints: evidence.reduce((total, item) => total + item.earnedPoints, 0),
      availablePoints: evidence.reduce((total, item) => total + item.availablePoints, 0),
      evidenceCount: evidence.length,
      supportingItemKeys: evidence.map((item) => item.itemKey),
    };
    assertPossibleSignal(signal.earnedPoints, signal.availablePoints, competency.id);
    return [signal];
  });

  const multiplierObservations = framework.multipliers.flatMap((multiplier) => {
    const evidence = scoredItems.filter(
      (item) => item.targetKind === "multiplier" && item.targetId === multiplier.id,
    );
    if (evidence.length === 0) {
      return [];
    }

    const observation: MultiplierObservation = {
      multiplierId: multiplier.id,
      earnedRubricPoints: evidence.reduce((total, item) => total + item.earnedPoints, 0),
      availableRubricPoints: evidence.reduce((total, item) => total + item.availablePoints, 0),
      evidenceCount: evidence.length,
      supportingItemKeys: evidence.map((item) => item.itemKey),
    };
    assertPossibleSignal(
      observation.earnedRubricPoints,
      observation.availableRubricPoints,
      multiplier.id,
    );
    return [observation];
  });

  const assessedCoreIds = new Set(coreSkillSignals.map((signal) => signal.competencyId));

  return {
    contract: "assessment-fixture-scoring",
    provisional: true,
    fixtureOnly: true,
    assessmentId: assessment.id,
    frameworkVersionId: framework.id,
    scoringModelId: scoringModel.id,
    coreSkillSignals,
    multiplierObservations,
    unassessedCoreCompetencyIds: framework.coreCompetencies
      .filter((competency) => !assessedCoreIds.has(competency.id))
      .map((competency) => competency.id),
  };
}

function assertPossibleSignal(earned: number, available: number, targetId: string): void {
  if (
    !Number.isInteger(earned) ||
    !Number.isInteger(available) ||
    available <= 0 ||
    earned < 0 ||
    earned > available
  ) {
    throw new Error(`calculated points for ${targetId} are impossible.`);
  }
}
