import { canonicalCoreWeightBasisPoints } from "@/modules/assessment/framework";
import {
  assessmentLocales,
  type AssessmentDefinition,
  type FrameworkDefinition,
  type LocalizedText,
  type ScoringModelDefinition,
} from "@/modules/assessment/types";

const stableIdentifierPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const rawHtmlPattern = /<\/?[a-z][^>]*>/i;

function requireStableIdentifier(value: string, path: string): void {
  if (!stableIdentifierPattern.test(value)) {
    throw new Error(`${path} must be a stable lowercase kebab-case identifier.`);
  }
}

function validateLocalizedText(value: LocalizedText, path: string): void {
  const localeKeys = Object.keys(value).sort();
  const expectedLocaleKeys = [...assessmentLocales].sort();

  if (
    localeKeys.length !== expectedLocaleKeys.length ||
    localeKeys.some((locale, index) => locale !== expectedLocaleKeys[index])
  ) {
    throw new Error(`${path} must cover exactly these locales: en, th.`);
  }

  for (const locale of assessmentLocales) {
    const text = value[locale];
    if (typeof text !== "string" || text.trim().length === 0) {
      throw new Error(`${path}.${locale} must be a non-blank string.`);
    }

    if (rawHtmlPattern.test(text)) {
      throw new Error(`${path}.${locale} must not contain raw HTML.`);
    }
  }
}

function requireUnique(values: readonly string[], path: string): void {
  if (new Set(values).size !== values.length) {
    throw new Error(`${path} must contain unique values.`);
  }
}

export function validateFrameworkDefinition(framework: FrameworkDefinition): void {
  requireStableIdentifier(framework.id, "framework.id");
  requireStableIdentifier(framework.frameworkKey, "framework.frameworkKey");

  if (framework.coreCompetencies.length !== 8) {
    throw new Error("framework must contain exactly eight core competencies.");
  }

  if (framework.multipliers.length !== 2) {
    throw new Error("framework must contain exactly two multipliers.");
  }

  const allIds = [
    ...framework.coreCompetencies.map((competency) => competency.id),
    ...framework.multipliers.map((multiplier) => multiplier.id),
  ];
  requireUnique(allIds, "framework member IDs");
  requireUnique(
    framework.coreCompetencies.map((competency) => String(competency.displayOrder)),
    "core competency display orders",
  );
  requireUnique(
    framework.multipliers.map((multiplier) => String(multiplier.displayOrder)),
    "multiplier display orders",
  );

  let totalWeight = 0;
  for (const competency of framework.coreCompetencies) {
    requireStableIdentifier(competency.id, `framework.core.${competency.id}.id`);
    if (competency.kind !== "core") {
      throw new Error(`framework.core.${competency.id}.kind must be core.`);
    }
    validateLocalizedText(competency.name, `framework.core.${competency.id}.name`);

    if (!Number.isInteger(competency.weightBasisPoints) || competency.weightBasisPoints <= 0) {
      throw new Error(
        `framework.core.${competency.id}.weightBasisPoints must be a positive integer.`,
      );
    }

    if (competency.weightBasisPoints !== canonicalCoreWeightBasisPoints[competency.id]) {
      throw new Error(
        `framework.core.${competency.id}.weightBasisPoints must match the canonical framework weight.`,
      );
    }

    totalWeight += competency.weightBasisPoints;
  }

  if (totalWeight !== 10_000) {
    throw new Error("framework core competency weights must total 10000 basis points.");
  }

  for (const multiplier of framework.multipliers) {
    requireStableIdentifier(multiplier.id, `framework.multiplier.${multiplier.id}.id`);
    if (multiplier.kind !== "multiplier") {
      throw new Error(`framework.multiplier.${multiplier.id}.kind must be multiplier.`);
    }
    validateLocalizedText(multiplier.name, `framework.multiplier.${multiplier.id}.name`);

    if (Reflect.has(multiplier, "weightBasisPoints")) {
      throw new Error(`framework.multiplier.${multiplier.id} must not define a core weight.`);
    }
  }
}

export function validateScoringModelDefinition(
  scoringModel: ScoringModelDefinition,
  assessment: AssessmentDefinition,
  framework: FrameworkDefinition,
): void {
  requireStableIdentifier(scoringModel.id, "scoringModel.id");
  requireStableIdentifier(scoringModel.scoringKey, "scoringModel.scoringKey");

  if (scoringModel.method !== "deterministic-integer-rubric") {
    throw new Error("scoringModel.method must be deterministic-integer-rubric.");
  }

  if (scoringModel.assessmentId !== assessment.id) {
    throw new Error("scoringModel assessment compatibility failed.");
  }

  if (
    scoringModel.frameworkVersionId !== framework.id ||
    assessment.frameworkVersionId !== framework.id
  ) {
    throw new Error("scoringModel framework compatibility failed.");
  }

  const { minimum, maximum, step } = scoringModel.pointScale;
  if (
    !Number.isInteger(minimum) ||
    !Number.isInteger(maximum) ||
    !Number.isInteger(step) ||
    minimum !== 0 ||
    maximum <= minimum ||
    step <= 0
  ) {
    throw new Error("scoringModel.pointScale must define a possible non-negative integer scale.");
  }
}

export function validateAssessmentDefinition(
  assessment: AssessmentDefinition,
  framework: FrameworkDefinition,
  scoringModel: ScoringModelDefinition,
): void {
  requireStableIdentifier(assessment.id, "assessment.id");
  requireStableIdentifier(assessment.assessmentKey, "assessment.assessmentKey");

  if (assessment.frameworkVersionId !== framework.id) {
    throw new Error("assessment framework compatibility failed.");
  }

  if (assessment.items.length !== 6) {
    throw new Error("assessment must contain exactly six scenario-choice items.");
  }

  requireUnique(
    assessment.items.map((item) => item.key),
    "assessment item keys",
  );
  requireUnique(
    assessment.items.map((item) => String(item.displayOrder)),
    "assessment item display orders",
  );

  const allOptionIds: string[] = [];
  const targetCounts = new Map<string, number>();
  const coreIds = new Set(framework.coreCompetencies.map((competency) => competency.id));
  const multiplierIds = new Set(framework.multipliers.map((multiplier) => multiplier.id));

  for (const item of assessment.items) {
    requireStableIdentifier(item.key, `assessment.item.${item.key}.key`);
    if (item.type !== "scenario-choice" || item.required !== true) {
      throw new Error(`assessment.item.${item.key} must be a required scenario-choice item.`);
    }

    validateLocalizedText(item.prompt, `assessment.item.${item.key}.prompt`);

    if (item.options.length < 2) {
      throw new Error(`assessment.item.${item.key} must define at least two options.`);
    }

    requireUnique(
      item.options.map((option) => option.id),
      `assessment.item.${item.key} option IDs`,
    );

    if (
      !Number.isInteger(item.rubric.availablePoints) ||
      item.rubric.availablePoints !== scoringModel.pointScale.maximum
    ) {
      throw new Error(
        `assessment.item.${item.key}.rubric.availablePoints must equal the scoring scale maximum.`,
      );
    }

    if (item.rubric.targetKind !== "core" && item.rubric.targetKind !== "multiplier") {
      throw new Error(`assessment.item.${item.key}.rubric.targetKind must be core or multiplier.`);
    }

    const targetExists =
      item.rubric.targetKind === "core"
        ? coreIds.has(item.rubric.targetId as never)
        : multiplierIds.has(item.rubric.targetId as never);
    if (!targetExists) {
      throw new Error(
        `assessment.item.${item.key}.rubric target is unknown or has the wrong kind.`,
      );
    }

    targetCounts.set(item.rubric.targetId, (targetCounts.get(item.rubric.targetId) ?? 0) + 1);

    for (const option of item.options) {
      requireStableIdentifier(option.id, `assessment.item.${item.key}.option.id`);
      validateLocalizedText(option.label, `assessment.item.${item.key}.option.${option.id}.label`);
      allOptionIds.push(option.id);

      const { minimum, maximum, step } = scoringModel.pointScale;
      if (
        !Number.isInteger(option.rubricPoints) ||
        option.rubricPoints < minimum ||
        option.rubricPoints > maximum ||
        (option.rubricPoints - minimum) % step !== 0
      ) {
        throw new Error(
          `assessment.item.${item.key}.option.${option.id}.rubricPoints is impossible for the scoring scale.`,
        );
      }
    }

    const itemPoints = new Set(item.options.map((option) => option.rubricPoints));
    if (
      !itemPoints.has(scoringModel.pointScale.minimum) ||
      !itemPoints.has(item.rubric.availablePoints)
    ) {
      throw new Error(`assessment.item.${item.key} rubric must include scale endpoints.`);
    }
  }

  requireUnique(allOptionIds, "assessment option IDs");

  const requiredDistribution = new Map<string, number>([
    ["critical-thinking-fact-checking", 2],
    ["systematic-thinking", 2],
    ["ownership-thinking", 1],
    ["sense-of-urgency", 1],
  ]);

  if (
    targetCounts.size !== requiredDistribution.size ||
    [...requiredDistribution].some(([targetId, count]) => targetCounts.get(targetId) !== count)
  ) {
    throw new Error("assessment item targets must match the authorized 2/2/1/1 slice.");
  }
}

export function validateAssessmentDomain(
  framework: FrameworkDefinition,
  assessment: AssessmentDefinition,
  scoringModel: ScoringModelDefinition,
): void {
  validateFrameworkDefinition(framework);
  validateScoringModelDefinition(scoringModel, assessment, framework);
  validateAssessmentDefinition(assessment, framework, scoringModel);
}
