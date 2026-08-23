import type { Locale } from "@/lib/i18n/config";
import { isLocale } from "@/lib/i18n/config";
import {
  getSourceVerificationPublicationDigest,
  sourceVerificationLessonDefinition,
} from "@/modules/lesson/publication/registry";
import { createSourceVerificationLessonView } from "@/modules/lesson/source-verification/view";
import {
  sourceVerificationCriterionIds,
  type SourceVerificationCriterionId,
  type SourceVerificationPracticeSelection,
} from "@/modules/lesson/source-verification/types";

export const PERSISTED_LESSON_RESPONSE_SCHEMA_VERSION =
  "source-verification-practice-response-v1" as const;
export const LEARNING_PROGRESS_EVENT_SCHEMA_VERSION = "learning-progress-event-v1" as const;

export type ClientSafePracticeView = Readonly<{
  heading: string;
  introduction: string;
  instruction: string;
  criteria: readonly Readonly<{
    id: SourceVerificationCriterionId;
    label: string;
    prompt: string;
    options: readonly Readonly<{ id: string; label: string }>[];
  }>[];
}>;

export type PersistedPracticeSelection = SourceVerificationPracticeSelection;

export type PersistedLessonMutationInput = Readonly<{
  locale: Locale;
  intent: "save" | "evaluate" | "retry";
  selections?: readonly PersistedPracticeSelection[];
  expectedRevision: number;
  clientMutationId: string;
}>;

export function parsePersistedLessonStartInput(value: unknown): Readonly<{
  locale: Locale;
  clientMutationId: string;
}> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Lesson start input is invalid.");
  }
  const input = value as Readonly<Record<string, unknown>>;
  if (
    typeof input.locale !== "string" ||
    !isLocale(input.locale) ||
    !isUuid(input.clientMutationId) ||
    JSON.stringify(Object.keys(input).sort()) !== JSON.stringify(["clientMutationId", "locale"])
  ) {
    throw new Error("Lesson start input is invalid.");
  }
  return { locale: input.locale, clientMutationId: input.clientMutationId };
}

export function getPersistedLessonMetadata() {
  const definition = sourceVerificationLessonDefinition;
  return {
    lessonKey: definition.lesson.key,
    lessonVersionId: definition.lesson.versionId,
    lessonVersion: definition.lesson.version,
    lessonDigest: getSourceVerificationPublicationDigest(),
    practiceId: definition.practice.id,
    practiceVersion: definition.practice.version,
    rubricVersionId: definition.rubric.versionId,
    rubricVersion: definition.rubric.version,
    evaluationContractVersionId: "source-verification-evaluation-v1" as const,
  };
}

export function createClientSafePracticeView(locale: Locale): ClientSafePracticeView {
  const view = createSourceVerificationLessonView(locale, sourceVerificationLessonDefinition);
  return {
    heading: view.practice.heading,
    introduction: view.practice.introduction,
    instruction: view.practice.instruction,
    criteria: view.practice.criteria.map((criterion) => ({
      id: criterion.id,
      label: criterion.label,
      prompt: criterion.prompt,
      options: criterion.options.map(({ id, label }) => ({ id, label })),
    })),
  };
}

function isUuid(value: unknown): value is string {
  return (
    typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(value)
  );
}

export function parsePersistedPracticeSelections(
  value: unknown,
  allowPartial: boolean,
): readonly PersistedPracticeSelection[] {
  if (!Array.isArray(value)) throw new Error("Practice selections must be an array.");
  const view = createSourceVerificationLessonView("en", sourceVerificationLessonDefinition);
  if (value.length > view.practice.criteria.length)
    throw new Error("Too many practice selections.");
  const seen = new Set<string>();
  let previousRank = -1;
  const selections = value.map((candidate) => {
    if (!candidate || typeof candidate !== "object" || Array.isArray(candidate)) {
      throw new Error("Practice selection is invalid.");
    }
    const record = candidate as Readonly<Record<string, unknown>>;
    if (
      JSON.stringify(Object.keys(record).sort()) !== JSON.stringify(["criterionId", "optionId"])
    ) {
      throw new Error("Practice selection has unsupported fields.");
    }
    const criterion = view.practice.criteria.find((entry) => entry.id === record.criterionId);
    const rank = criterion ? view.practice.criteria.indexOf(criterion) : -1;
    if (
      !criterion ||
      rank <= previousRank ||
      typeof record.optionId !== "string" ||
      !criterion.options.some((option) => option.id === record.optionId) ||
      seen.has(criterion.id)
    ) {
      throw new Error("Practice selection is unknown, duplicated or out of canonical order.");
    }
    previousRank = rank;
    seen.add(criterion.id);
    return { criterionId: criterion.id, optionId: record.optionId };
  });
  if (!allowPartial && selections.length !== sourceVerificationCriterionIds.length) {
    throw new Error("All practice criteria are required before evaluation.");
  }
  return selections;
}

export function parsePersistedLessonMutationInput(value: unknown): PersistedLessonMutationInput {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Lesson mutation input is invalid.");
  }
  const input = value as Readonly<Record<string, unknown>>;
  if (
    typeof input.locale !== "string" ||
    !isLocale(input.locale) ||
    (input.intent !== "save" && input.intent !== "evaluate" && input.intent !== "retry") ||
    !Number.isInteger(input.expectedRevision) ||
    (input.expectedRevision as number) < 0 ||
    !isUuid(input.clientMutationId)
  ) {
    throw new Error("Lesson mutation input is invalid.");
  }
  const allowedKeys =
    input.intent === "save" || input.intent === "evaluate"
      ? ["clientMutationId", "expectedRevision", "intent", "locale", "selections"]
      : ["clientMutationId", "expectedRevision", "intent", "locale"];
  if (JSON.stringify(Object.keys(input).sort()) !== JSON.stringify(allowedKeys)) {
    throw new Error("Lesson mutation input has unsupported fields.");
  }
  return {
    locale: input.locale as Locale,
    intent: input.intent,
    expectedRevision: input.expectedRevision as number,
    clientMutationId: input.clientMutationId,
    ...(input.intent === "save" || input.intent === "evaluate"
      ? {
          selections: parsePersistedPracticeSelections(input.selections, input.intent === "save"),
        }
      : {}),
  };
}
