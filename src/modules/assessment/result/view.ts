import {
  deriveExplanationRecords,
  explanationCopy,
  limitationCopy,
} from "@/modules/assessment/explanations";
import { assessmentFramework } from "@/modules/assessment/framework";
import {
  deriveSyntheticExampleResult,
  getVisibleSyntheticExampleFixture,
} from "@/modules/assessment/result/derive";
import type {
  SyntheticExampleResult,
  SyntheticFixtureInput,
} from "@/modules/assessment/result/types";
import { scoreAssessmentFixture } from "@/modules/assessment/scoring";
import type {
  AssessmentLocale,
  CoreCompetencyId,
  ExplanationTarget,
  LimitationCode,
  MultiplierId,
} from "@/modules/assessment/types";

type LocalizedExplanationView = Readonly<{
  id: string;
  target: ExplanationTarget;
  heading: string;
  body: string;
  supportingItemKeys: readonly string[];
}>;

export type SyntheticExampleResultView = Readonly<{
  result: SyntheticExampleResult;
  overviewExplanation: LocalizedExplanationView;
  coreSignals: readonly (SyntheticExampleResult["coreSignals"][number] &
    Readonly<{ name: string; explanation: LocalizedExplanationView }>)[];
  unassessedCoreCompetencies: readonly Readonly<{
    competencyId: CoreCompetencyId;
    name: string;
  }>[];
  multiplierObservations: readonly (SyntheticExampleResult["multiplierObservations"][number] &
    Readonly<{ name: string; explanation: LocalizedExplanationView }>)[];
  exampleNextPractice: SyntheticExampleResult["exampleNextPractice"] &
    Readonly<{ targetCompetencyName: string }>;
  limitations: readonly Readonly<{ code: LimitationCode; body: string }>[];
}>;

const completeResultLimitationCodes = [
  "not-validated-assessment",
  "partial-core-slice",
  "single-scenario-not-behavior-pattern",
  "cannot-predict-job-loss",
  "cannot-predict-job-performance",
  "cannot-determine-employability",
  "cannot-determine-hiring-eligibility",
] as const satisfies readonly LimitationCode[];

export function createSyntheticExampleResultView(
  locale: AssessmentLocale,
  fixture: SyntheticFixtureInput = getVisibleSyntheticExampleFixture(),
): SyntheticExampleResultView {
  const result = deriveSyntheticExampleResult(fixture);
  const explanations = deriveExplanationRecords(scoreAssessmentFixture(fixture)).map((record) => ({
    id: record.id,
    target: record.target,
    heading: explanationCopy[record.explanationCode].heading[locale],
    body: explanationCopy[record.explanationCode].body[locale],
    supportingItemKeys: [...record.supportingItemKeys],
  }));

  const overviewExplanation = explanations.find(
    (explanation) => explanation.target.kind === "assessment",
  );
  if (!overviewExplanation) {
    throw new Error("synthetic example result requires an assessment explanation.");
  }

  const coreNames = new Map(
    assessmentFramework.coreCompetencies.map((competency) => [
      competency.id,
      competency.name[locale],
    ]),
  );
  const multiplierNames = new Map(
    assessmentFramework.multipliers.map((multiplier) => [multiplier.id, multiplier.name[locale]]),
  );

  return {
    result,
    overviewExplanation,
    coreSignals: result.coreSignals.map((signal) => ({
      ...signal,
      name: requireCoreName(coreNames, signal.competencyId),
      explanation: requireExplanation(explanations, "core", signal.competencyId),
    })),
    unassessedCoreCompetencies: result.unassessedCoreCompetencyIds.map((competencyId) => ({
      competencyId,
      name: requireCoreName(coreNames, competencyId),
    })),
    multiplierObservations: result.multiplierObservations.map((observation) => ({
      ...observation,
      name: requireMultiplierName(multiplierNames, observation.multiplierId),
      explanation: requireExplanation(explanations, "multiplier", observation.multiplierId),
    })),
    exampleNextPractice: {
      ...result.exampleNextPractice,
      targetCompetencyName: requireCoreName(
        coreNames,
        result.exampleNextPractice.targetCompetencyId,
      ),
    },
    limitations: completeResultLimitationCodes.map((code) => ({
      code,
      body: limitationCopy[code].body[locale],
    })),
  };
}

function requireCoreName(
  names: ReadonlyMap<CoreCompetencyId, string>,
  competencyId: CoreCompetencyId,
): string {
  const name = names.get(competencyId);
  if (!name) {
    throw new Error(`missing localized core name: ${competencyId}.`);
  }
  return name;
}

function requireMultiplierName(
  names: ReadonlyMap<MultiplierId, string>,
  multiplierId: MultiplierId,
): string {
  const name = names.get(multiplierId);
  if (!name) {
    throw new Error(`missing localized multiplier name: ${multiplierId}.`);
  }
  return name;
}

function requireExplanation(
  explanations: readonly LocalizedExplanationView[],
  kind: "core" | "multiplier",
  id: CoreCompetencyId | MultiplierId,
): LocalizedExplanationView {
  const explanation = explanations.find(
    (candidate) => candidate.target.kind === kind && candidate.target.id === id,
  );
  if (!explanation) {
    throw new Error(`missing localized ${kind} explanation: ${id}.`);
  }
  return explanation;
}
