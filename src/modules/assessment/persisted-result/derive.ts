import { assessmentDefinition, scoringModelDefinition } from "@/modules/assessment/assessment";
import { assessmentFramework } from "@/modules/assessment/framework";
import {
  RESULT_PRIORITY_POLICY_DIGEST,
  RESULT_PRIORITY_POLICY_KEY,
  RESULT_PRIORITY_POLICY_VERSION,
  assertResultPriorityPolicyIntegrity,
  sha256Hex,
} from "@/modules/assessment/persisted-result/policy";
import type {
  PersistedCoreScore,
  PersistedPriorityRecommendation,
  PersistedResultDerivation,
  PersistedResultDerivationInput,
  PersistedResultExplanation,
  PersistedResultSemanticOutput,
} from "@/modules/assessment/persisted-result/types";
import { scoreAssessmentFixture } from "@/modules/assessment/scoring";
import type { CoreCompetencyId, LimitationCode } from "@/modules/assessment/types";

const digestPattern = /^[0-9a-f]{64}$/;
const allRunLimitations = [
  "not-validated-assessment",
  "partial-core-slice",
  "cannot-predict-job-loss",
  "cannot-predict-job-performance",
  "cannot-determine-employability",
  "cannot-determine-hiring-eligibility",
] as const satisfies readonly LimitationCode[];

export function derivePersistedSyntheticResult(
  input: PersistedResultDerivationInput,
): PersistedResultDerivation {
  assertResultPriorityPolicyIntegrity();
  validateContentIdentities(input);

  const canonicalResponses = canonicalizeResponses(input.responses);
  const score = scoreAssessmentFixture({
    fixtureId: "persisted-submitted-session",
    assessmentId: input.assessment.contentId,
    frameworkVersionId: input.framework.contentId,
    scoringModelId: input.scoringModel.contentId,
    responses: canonicalResponses.map(({ itemKey, selectedOptionId }) => ({
      itemKey,
      optionId: selectedOptionId,
    })),
  });

  const coreScores = score.coreSkillSignals.map((signal): PersistedCoreScore => ({
    competencyId: signal.competencyId,
    earnedPoints: signal.earnedPoints,
    availablePoints: signal.availablePoints,
    evidenceCount: signal.evidenceCount,
    normalizedBasisPoints: normalizeBasisPoints(signal.earnedPoints, signal.availablePoints),
    supportingItemKeys: [...signal.supportingItemKeys],
  }));
  validateCompleteExpectedEvidence(coreScores);

  const priorityRecommendation = selectPriority(coreScores);
  const explanations = buildExplanations(
    coreScores,
    score.multiplierObservations,
    priorityRecommendation,
  );

  const semanticOutput: PersistedResultSemanticOutput = {
    contract: "persisted-synthetic-result",
    contractVersion: "1.0.0",
    syntheticAlphaOnly: true,
    assessmentContentId: input.assessment.contentId,
    frameworkContentId: input.framework.contentId,
    scoringModelContentId: input.scoringModel.contentId,
    resultPolicyKey: RESULT_PRIORITY_POLICY_KEY,
    resultPolicyVersion: RESULT_PRIORITY_POLICY_VERSION,
    resultPolicyDigest: RESULT_PRIORITY_POLICY_DIGEST,
    coreScores,
    unassessedCoreCompetencyIds: [...score.unassessedCoreCompetencyIds],
    multiplierObservations: score.multiplierObservations.map((observation) => ({
      multiplierId: observation.multiplierId,
      earnedRubricPoints: observation.earnedRubricPoints,
      availableRubricPoints: observation.availableRubricPoints,
      evidenceCount: observation.evidenceCount,
      supportingItemKeys: [...observation.supportingItemKeys],
    })),
    explanations,
    priorityRecommendation,
  };

  const canonicalInput = canonicalizeInput(input, canonicalResponses);
  const canonicalOutput = canonicalizeOutput(semanticOutput);

  return {
    inputDigest: sha256Hex(canonicalInput),
    outputDigest: sha256Hex(canonicalOutput),
    canonicalInput,
    canonicalOutput,
    semanticOutput,
  };
}

export function normalizeBasisPoints(earned: number, available: number): number {
  if (!Number.isInteger(earned) || !Number.isInteger(available) || available <= 0) {
    throw new Error("Persisted result points are invalid.");
  }
  if (earned < 0 || earned > available) {
    throw new Error("Persisted result points are impossible.");
  }
  return Math.floor((earned * 10_000) / available);
}

function validateContentIdentities(input: PersistedResultDerivationInput): void {
  const expected = [
    [
      input.assessment,
      assessmentDefinition.id,
      assessmentDefinition.assessmentKey,
      assessmentDefinition.version,
    ],
    [
      input.framework,
      assessmentFramework.id,
      assessmentFramework.frameworkKey,
      assessmentFramework.version,
    ],
    [
      input.scoringModel,
      scoringModelDefinition.id,
      scoringModelDefinition.scoringKey,
      scoringModelDefinition.version,
    ],
  ] as const;

  for (const [identity, contentId, key, version] of expected) {
    if (
      identity.contentId !== contentId ||
      identity.key !== key ||
      identity.version !== version ||
      !digestPattern.test(identity.contentDigest)
    ) {
      throw new Error("Persisted result content compatibility failed.");
    }
  }
}

function canonicalizeResponses(
  responses: PersistedResultDerivationInput["responses"],
): PersistedResultDerivationInput["responses"] {
  if (responses.length !== assessmentDefinition.items.length) {
    throw new Error("Persisted result requires one active response for every accepted item.");
  }

  const responseByKey = new Map<string, (typeof responses)[number]>();
  for (const response of responses) {
    if (
      typeof response.itemKey !== "string" ||
      typeof response.selectedOptionId !== "string" ||
      !Number.isInteger(response.displayOrder) ||
      !Number.isInteger(response.revision) ||
      response.revision < 1 ||
      responseByKey.has(response.itemKey)
    ) {
      throw new Error("Persisted result response provenance is invalid.");
    }
    responseByKey.set(response.itemKey, response);
  }

  return [...assessmentDefinition.items]
    .sort((left, right) => left.displayOrder - right.displayOrder)
    .map((item) => {
      const response = responseByKey.get(item.key);
      if (!response || response.displayOrder !== item.displayOrder) {
        throw new Error("Persisted result response order metadata is incompatible.");
      }
      return { ...response };
    });
}

function validateCompleteExpectedEvidence(coreScores: readonly PersistedCoreScore[]): void {
  const expectedCoreEvidence = new Map<CoreCompetencyId, number>([
    ["critical-thinking-fact-checking", 2],
    ["systematic-thinking", 2],
  ]);
  if (coreScores.length !== expectedCoreEvidence.size) {
    throw new Error("Persisted result assessed-core coverage is invalid.");
  }
  for (const score of coreScores) {
    if (score.evidenceCount !== expectedCoreEvidence.get(score.competencyId)) {
      throw new Error("Persisted result core evidence is incomplete.");
    }
  }
}

function selectPriority(
  coreScores: readonly PersistedCoreScore[],
): PersistedPriorityRecommendation | null {
  const [first, second] = coreScores;
  if (!first || !second || coreScores.length !== 2) {
    throw new Error("Persisted result priority requires the exact assessed core set.");
  }

  const comparison =
    first.earnedPoints * second.availablePoints - second.earnedPoints * first.availablePoints;
  if (comparison === 0) return null;
  const lowest = comparison < 0 ? first : second;

  return {
    competencyId: lowest.competencyId,
    rank: 1,
    reasonCode: "unique-lowest-assessed-core-signal",
    supportingItemKeys: [...lowest.supportingItemKeys],
    nextAction:
      lowest.competencyId === "critical-thinking-fact-checking"
        ? {
            kind: "prototype-lesson",
            lessonVersionId: "lesson-source-verification-practice-v1",
            lessonVersion: "1.0.0",
          }
        : { kind: "practice-unavailable" },
  };
}

function buildExplanations(
  coreScores: PersistedResultSemanticOutput["coreScores"],
  multipliers: PersistedResultSemanticOutput["multiplierObservations"],
  priority: PersistedPriorityRecommendation | null,
): readonly PersistedResultExplanation[] {
  const params = { schemaVersion: "persisted-result-explanation-params-v1" } as const;
  const allItemKeys = [
    ...coreScores.flatMap((score) => score.supportingItemKeys),
    ...multipliers.flatMap((observation) => observation.supportingItemKeys),
  ];

  return [
    {
      explanationCode: "synthetic-partial-result-limitation",
      target: { kind: "run", id: "result" },
      supportingItemKeys: allItemKeys,
      limitationCodes: allRunLimitations,
      messageParams: params,
    },
    ...coreScores.map((score): PersistedResultExplanation => ({
      explanationCode: "assessed-core-raw-signal",
      target: { kind: "core", id: score.competencyId },
      supportingItemKeys: [...score.supportingItemKeys],
      limitationCodes: ["not-validated-assessment", "partial-core-slice"],
      messageParams: params,
    })),
    ...multipliers.map((observation): PersistedResultExplanation => ({
      explanationCode: "single-scenario-multiplier-observation",
      target: { kind: "multiplier", id: observation.multiplierId },
      supportingItemKeys: [...observation.supportingItemKeys],
      limitationCodes: ["not-validated-assessment", "single-scenario-not-behavior-pattern"],
      messageParams: params,
    })),
    {
      explanationCode: priority ? "unique-lowest-assessed-core-signal" : "no-distinct-priority",
      target: priority
        ? { kind: "priority", id: priority.competencyId }
        : { kind: "priority", id: "none" },
      supportingItemKeys: priority ? [...priority.supportingItemKeys] : [],
      limitationCodes: ["not-validated-assessment", "partial-core-slice"],
      messageParams: params,
    },
  ];
}

function canonicalizeInput(
  input: PersistedResultDerivationInput,
  responses: PersistedResultDerivationInput["responses"],
): string {
  return JSON.stringify({
    schemaVersion: "persisted-scoring-input-v1",
    assessment: canonicalContentIdentity(input.assessment),
    framework: canonicalContentIdentity(input.framework),
    scoringModel: canonicalContentIdentity(input.scoringModel),
    resultPolicy: {
      key: RESULT_PRIORITY_POLICY_KEY,
      version: RESULT_PRIORITY_POLICY_VERSION,
      digest: RESULT_PRIORITY_POLICY_DIGEST,
    },
    responses: responses.map((response) => ({
      itemKey: response.itemKey,
      revision: response.revision,
      selectedOptionId: response.selectedOptionId,
    })),
  });
}

function canonicalContentIdentity(identity: PersistedResultDerivationInput["assessment"]) {
  return {
    contentId: identity.contentId,
    key: identity.key,
    version: identity.version,
    contentDigest: identity.contentDigest,
  };
}

function canonicalizeOutput(output: PersistedResultSemanticOutput): string {
  return JSON.stringify(output);
}
