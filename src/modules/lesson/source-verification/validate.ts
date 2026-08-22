import { FRAMEWORK_VERSION_ID } from "@/modules/assessment/framework";
import {
  LESSON_CONTENT_CONTRACT_VERSION_ID,
  SOURCE_VERIFICATION_LESSON_KEY,
  SOURCE_VERIFICATION_LESSON_VERSION,
  SOURCE_VERIFICATION_LESSON_VERSION_ID,
  SOURCE_VERIFICATION_PRACTICE_ID,
  SOURCE_VERIFICATION_PROOF_ID,
  SOURCE_VERIFICATION_RUBRIC_VERSION_ID,
  sourceVerificationCriterionIds,
  sourceVerificationProofFieldIds,
  type SourceVerificationLessonDefinition,
} from "@/modules/lesson/source-verification/types";

const expectedOptionLinks = [
  ["trace-claim-to-source-map", "evidence-traceability", true],
  ["trace-trust-ai-link-list", "evidence-traceability", false],
  ["trace-remove-source-notes", "evidence-traceability", false],
  ["fit-narrow-to-supported-teams", "claim-source-fit", true],
  ["fit-keep-all-team-claim", "claim-source-fit", false],
  ["fit-convert-to-broad-average", "claim-source-fit", false],
  ["safe-hold-and-resolve-gaps", "safe-next-action", true],
  ["safe-publish-with-small-note", "safe-next-action", false],
  ["safe-ask-ai-for-confidence", "safe-next-action", false],
] as const;

const expectedRubricLinks = [
  ["rubric-evidence-traceability", "evidence-traceability"],
  ["rubric-claim-source-fit", "claim-source-fit"],
  ["rubric-safe-next-action", "safe-next-action"],
] as const;

const localizedTopKeys = [
  "actions",
  "concepts",
  "feedback",
  "hero",
  "locale",
  "metadata",
  "overview",
  "practice",
  "proof",
  "reflection",
  "rubric",
  "scenario",
] as const;

export function validateSourceVerificationLessonDefinition(
  input: unknown,
): asserts input is SourceVerificationLessonDefinition {
  const definition = requireRecord(input, "lesson definition");
  requireExactKeys(
    definition,
    ["content", "contractVersionId", "lesson", "practice", "proof", "rubric", "xpRule"],
    "lesson definition",
  );

  requireEqual(
    definition.contractVersionId,
    LESSON_CONTENT_CONTRACT_VERSION_ID,
    "lesson contract version",
  );
  validateLessonIdentity(requireRecord(definition.lesson, "lesson identity"));
  validatePractice(requireRecord(definition.practice, "practice definition"));
  validateRubric(requireRecord(definition.rubric, "rubric definition"));
  validateProof(requireRecord(definition.proof, "proof definition"));
  validateXpRule(requireRecord(definition.xpRule, "XP rule"));

  const content = requireRecord(definition.content, "localized lesson content");
  requireExactKeys(content, ["en", "th"], "localized lesson content");
  const thai = validateLocalizedContent(content.th, "th");
  const english = validateLocalizedContent(content.en, "en");

  if (structureSignature(thai) !== structureSignature(english)) {
    throw new Error("Thai and English lesson content must have complete structural parity.");
  }
}

function validateLessonIdentity(lesson: Record<string, unknown>): void {
  requireExactKeys(
    lesson,
    [
      "estimatedActiveMinutes",
      "frameworkVersionId",
      "key",
      "locales",
      "practiceId",
      "primaryRoiPillar",
      "proofId",
      "provenance",
      "rubricVersionId",
      "status",
      "targetCompetencyId",
      "targetWorkingStage",
      "validationStatus",
      "version",
      "versionId",
    ],
    "lesson identity",
  );
  requireEqual(lesson.key, SOURCE_VERIFICATION_LESSON_KEY, "lesson key");
  requireEqual(lesson.versionId, SOURCE_VERIFICATION_LESSON_VERSION_ID, "lesson version ID");
  requireEqual(lesson.version, SOURCE_VERIFICATION_LESSON_VERSION, "lesson version");
  requireEqual(lesson.status, "published", "lesson status");
  requireEqual(lesson.validationStatus, "prototype-unvalidated", "lesson validation status");
  requireEqual(lesson.frameworkVersionId, FRAMEWORK_VERSION_ID, "framework version ID");
  requireEqual(lesson.targetCompetencyId, "critical-thinking-fact-checking", "target competency");
  requireEqual(lesson.targetWorkingStage, "Practicing", "target working stage");
  requireEqual(lesson.primaryRoiPillar, "Intelligent Risk & Governance", "primary R.O.I. pillar");
  requireEqual(lesson.estimatedActiveMinutes, 8, "estimated active minutes");
  requireEqual(lesson.provenance, "git-reviewed-content-publication-pipeline", "lesson provenance");
  requireSequence(lesson.locales, ["th", "en"], "lesson locales");
  requireEqual(lesson.practiceId, SOURCE_VERIFICATION_PRACTICE_ID, "lesson practice link");
  requireEqual(lesson.rubricVersionId, SOURCE_VERIFICATION_RUBRIC_VERSION_ID, "lesson rubric link");
  requireEqual(lesson.proofId, SOURCE_VERIFICATION_PROOF_ID, "lesson proof link");
}

function validatePractice(practice: Record<string, unknown>): void {
  requireExactKeys(
    practice,
    ["criterionIds", "id", "options", "rubricVersionId", "version"],
    "practice definition",
  );
  requireEqual(practice.id, SOURCE_VERIFICATION_PRACTICE_ID, "practice ID");
  requireEqual(practice.version, "1.0.0", "practice version");
  requireEqual(
    practice.rubricVersionId,
    SOURCE_VERIFICATION_RUBRIC_VERSION_ID,
    "practice rubric link",
  );
  requireSequence(practice.criterionIds, sourceVerificationCriterionIds, "practice criteria");

  const options = requireArray(practice.options, "practice options");
  if (options.length !== expectedOptionLinks.length) {
    throw new Error("practice options must match the exact canonical option registry.");
  }
  options.forEach((optionValue, index) => {
    const option = requireRecord(optionValue, `practice option ${index + 1}`);
    requireExactKeys(
      option,
      ["criterionId", "id", "meetsCriterion"],
      `practice option ${index + 1}`,
    );
    const expected = expectedOptionLinks[index]!;
    requireEqual(option.id, expected[0], `practice option ${index + 1} ID`);
    requireEqual(option.criterionId, expected[1], `practice option ${index + 1} criterion link`);
    requireEqual(option.meetsCriterion, expected[2], `practice option ${index + 1} result`);
  });

  for (const criterionId of sourceVerificationCriterionIds) {
    const criterionOptions = options
      .map((option) => requireRecord(option, "practice option"))
      .filter((option) => option.criterionId === criterionId);
    if (
      criterionOptions.length !== 3 ||
      criterionOptions.filter((option) => option.meetsCriterion === true).length !== 1
    ) {
      throw new Error(`criterion ${criterionId} must have three options and one met choice.`);
    }
  }
}

function validateRubric(rubric: Record<string, unknown>): void {
  requireExactKeys(
    rubric,
    ["criteria", "demonstratedRequires", "practiceId", "version", "versionId"],
    "rubric definition",
  );
  requireEqual(rubric.versionId, SOURCE_VERIFICATION_RUBRIC_VERSION_ID, "rubric version ID");
  requireEqual(rubric.version, "1.0.0", "rubric version");
  requireEqual(rubric.practiceId, SOURCE_VERIFICATION_PRACTICE_ID, "rubric practice link");
  requireEqual(rubric.demonstratedRequires, "all-criteria-met", "demonstrated rule");

  const criteria = requireArray(rubric.criteria, "rubric criteria");
  if (criteria.length !== expectedRubricLinks.length) {
    throw new Error("rubric must contain the exact three canonical criteria.");
  }
  criteria.forEach((criterionValue, index) => {
    const criterion = requireRecord(criterionValue, `rubric criterion ${index + 1}`);
    requireExactKeys(criterion, ["id", "practiceCriterionId"], `rubric criterion ${index + 1}`);
    const expected = expectedRubricLinks[index]!;
    requireEqual(criterion.id, expected[0], `rubric criterion ${index + 1} ID`);
    requireEqual(
      criterion.practiceCriterionId,
      expected[1],
      `rubric criterion ${index + 1} practice link`,
    );
  });
}

function validateProof(proof: Record<string, unknown>): void {
  requireExactKeys(
    proof,
    ["artifactType", "capturesInput", "fieldIds", "id", "status", "version"],
    "proof definition",
  );
  requireEqual(proof.id, SOURCE_VERIFICATION_PROOF_ID, "proof ID");
  requireEqual(proof.version, "1.0.0", "proof version");
  requireEqual(proof.status, "placeholder", "proof status");
  requireEqual(proof.artifactType, "source-verification-note", "proof artifact type");
  requireSequence(proof.fieldIds, sourceVerificationProofFieldIds, "proof fields");
  requireEqual(proof.capturesInput, false, "proof input boundary");
}

function validateXpRule(xpRule: Record<string, unknown>): void {
  requireExactKeys(
    xpRule,
    [
      "accumulation",
      "demonstratedPreviewXp",
      "incompletePreviewXp",
      "persisted",
      "versionId",
      "viewingPreviewXp",
    ],
    "XP rule",
  );
  requireEqual(xpRule.versionId, "source-verification-xp-preview-v1", "XP rule version");
  requireEqual(xpRule.viewingPreviewXp, 0, "viewing XP");
  requireEqual(xpRule.incompletePreviewXp, 0, "incomplete XP");
  requireEqual(xpRule.demonstratedPreviewXp, 20, "demonstrated XP");
  requireEqual(xpRule.accumulation, "replace-not-add", "XP accumulation rule");
  requireEqual(xpRule.persisted, false, "XP persistence rule");
}

function validateLocalizedContent(value: unknown, locale: "th" | "en"): Record<string, unknown> {
  const content = requireRecord(value, `${locale} lesson content`);
  requireExactKeys(content, localizedTopKeys, `${locale} lesson content`);
  requireEqual(content.locale, locale, `${locale} content locale`);

  validateSimpleSection(content.metadata, ["description", "title"], `${locale} metadata`);
  validateSimpleSection(
    content.hero,
    ["boundary", "eyebrow", "heading", "introduction", "prototypeLabel"],
    `${locale} hero`,
  );
  validateSimpleSection(
    content.overview,
    ["heading", "roiLabel", "stageLabel", "targetLabel", "timeLabel", "timeValue"],
    `${locale} overview`,
  );
  validateScenario(content.scenario, locale);
  validateConcepts(content.concepts, locale);
  validateLocalizedPractice(content.practice, locale);
  validateLocalizedRubric(content.rubric, locale);
  validateSimpleSection(
    content.feedback,
    [
      "demonstratedAnnouncement",
      "demonstratedHeading",
      "demonstratedSummary",
      "evaluateLabel",
      "heading",
      "incompleteError",
      "metLabel",
      "notMetLabel",
      "partialAnnouncement",
      "partialHeading",
      "partialSummary",
      "previewXpTemplate",
      "resetLabel",
      "retryLabel",
      "unsavedXpBoundary",
    ],
    `${locale} feedback`,
  );
  validateLocalizedProof(content.proof, locale);
  validateSimpleSection(
    content.reflection,
    ["boundary", "heading", "prompt"],
    `${locale} reflection`,
  );
  validateSimpleSection(content.actions, ["backToExampleLabel", "homeLabel"], `${locale} actions`);

  validateStringTree(content, `${locale} content`);
  return content;
}

function validateScenario(value: unknown, locale: string): void {
  const scenario = requireRecord(value, `${locale} scenario`);
  requireExactKeys(
    scenario,
    [
      "aiSummary",
      "aiSummaryLabel",
      "document",
      "documentLabel",
      "heading",
      "introduction",
      "organization",
      "organizationLabel",
      "sourceHeading",
      "sourceRecords",
      "syntheticLabel",
    ],
    `${locale} scenario`,
  );
  const records = requireArray(scenario.sourceRecords, `${locale} source records`);
  requireIdSequence(records, ["pilot-table", "scope-note", "risk-log"], `${locale} source records`);
  records.forEach((record, index) =>
    requireExactKeys(
      requireRecord(record, `${locale} source record`),
      ["detail", "id", "label"],
      `${locale} source record ${index + 1}`,
    ),
  );
}

function validateConcepts(value: unknown, locale: string): void {
  const concepts = requireRecord(value, `${locale} concepts`);
  requireExactKeys(concepts, ["heading", "introduction", "items"], `${locale} concepts`);
  const items = requireArray(concepts.items, `${locale} concepts`);
  requireIdSequence(items, sourceVerificationCriterionIds, `${locale} concepts`);
  items.forEach((item, index) =>
    requireExactKeys(
      requireRecord(item, `${locale} concept`),
      ["body", "heading", "id"],
      `${locale} concept ${index + 1}`,
    ),
  );
}

function validateLocalizedPractice(value: unknown, locale: string): void {
  const practice = requireRecord(value, `${locale} practice`);
  requireExactKeys(
    practice,
    ["criteria", "eyebrow", "heading", "instruction", "introduction"],
    `${locale} practice`,
  );
  const criteria = requireArray(practice.criteria, `${locale} practice criteria`);
  requireIdSequence(criteria, sourceVerificationCriterionIds, `${locale} practice criteria`);
  criteria.forEach((criterionValue, criterionIndex) => {
    const criterion = requireRecord(criterionValue, `${locale} practice criterion`);
    requireExactKeys(
      criterion,
      ["id", "label", "options", "prompt"],
      `${locale} practice criterion ${criterionIndex + 1}`,
    );
    const criterionId = sourceVerificationCriterionIds[criterionIndex]!;
    const expectedOptionIds = expectedOptionLinks
      .filter((option) => option[1] === criterionId)
      .map((option) => option[0]);
    const options = requireArray(criterion.options, `${locale} criterion options`);
    requireIdSequence(options, expectedOptionIds, `${locale} ${criterionId} options`);
    options.forEach((option, optionIndex) =>
      requireExactKeys(
        requireRecord(option, `${locale} option`),
        ["id", "label"],
        `${locale} option ${optionIndex + 1}`,
      ),
    );
  });
}

function validateLocalizedRubric(value: unknown, locale: string): void {
  const rubric = requireRecord(value, `${locale} rubric`);
  requireExactKeys(
    rubric,
    ["criteria", "demonstratedRule", "heading", "introduction"],
    `${locale} rubric`,
  );
  const criteria = requireArray(rubric.criteria, `${locale} rubric criteria`);
  requireIdSequence(criteria, sourceVerificationCriterionIds, `${locale} rubric criteria`);
  criteria.forEach((criterion, index) =>
    requireExactKeys(
      requireRecord(criterion, `${locale} rubric criterion`),
      ["id", "label", "metDescription", "notMetDescription"],
      `${locale} rubric criterion ${index + 1}`,
    ),
  );
}

function validateLocalizedProof(value: unknown, locale: string): void {
  const proof = requireRecord(value, `${locale} proof`);
  requireExactKeys(
    proof,
    [
      "boundary",
      "eyebrow",
      "fields",
      "fieldsHeading",
      "heading",
      "introduction",
      "placeholderLabel",
    ],
    `${locale} proof`,
  );
  const fields = requireArray(proof.fields, `${locale} proof fields`);
  requireIdSequence(fields, sourceVerificationProofFieldIds, `${locale} proof fields`);
  fields.forEach((field, index) =>
    requireExactKeys(
      requireRecord(field, `${locale} proof field`),
      ["id", "label"],
      `${locale} proof field ${index + 1}`,
    ),
  );
}

function validateSimpleSection(value: unknown, keys: readonly string[], label: string): void {
  requireExactKeys(requireRecord(value, label), keys, label);
}

function validateStringTree(value: unknown, label: string): void {
  if (typeof value === "string") {
    if (value.trim().length === 0 || /<[^>]+>/.test(value)) {
      throw new Error(`${label} contains empty or raw-HTML copy.`);
    }
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((child) => validateStringTree(child, label));
    return;
  }
  if (value !== null && typeof value === "object") {
    Object.values(value).forEach((child) => validateStringTree(child, label));
    return;
  }
  throw new Error(`${label} contains non-string copy.`);
}

function structureSignature(value: unknown): string {
  if (typeof value === "string") {
    return "string";
  }
  if (Array.isArray(value)) {
    return `[${value.map(structureSignature).join(",")}]`;
  }
  if (value !== null && typeof value === "object") {
    return `{${Object.entries(value)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, child]) => `${key}:${structureSignature(child)}`)
      .join(",")}}`;
  }
  return typeof value;
}

function requireRecord(value: unknown, label: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function requireArray(value: unknown, label: string): unknown[] {
  if (!Array.isArray(value)) {
    throw new Error(`${label} must be an array.`);
  }
  return value;
}

function requireExactKeys(
  value: Record<string, unknown>,
  expectedKeys: readonly string[],
  label: string,
): void {
  const actual = Object.keys(value).sort();
  const expected = [...expectedKeys].sort();
  if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
    throw new Error(`${label} must use the exact contract shape.`);
  }
}

function requireEqual(actual: unknown, expected: unknown, label: string): void {
  if (actual !== expected) {
    throw new Error(`${label} must equal ${String(expected)}.`);
  }
}

function requireSequence(value: unknown, expected: readonly unknown[], label: string): void {
  const actual = requireArray(value, label);
  if (actual.length !== expected.length || actual.some((item, index) => item !== expected[index])) {
    throw new Error(`${label} must match the exact canonical order.`);
  }
}

function requireIdSequence(
  values: readonly unknown[],
  expectedIds: readonly string[],
  label: string,
): void {
  const actualIds = values.map((value) => requireRecord(value, label).id);
  requireSequence(actualIds, expectedIds, label);
}
