import { assessmentDefinition, scoringModelDefinition } from "@/modules/assessment/assessment";
import { assessmentFramework } from "@/modules/assessment/framework";
import type { AssessmentLocale } from "@/modules/assessment/types";
import publishedDefinition from "./synthetic-published-definition.json";

export const PERSISTED_RESPONSE_SCHEMA_VERSION = "assessment-response-v1" as const;
export const PUBLISHED_OPTION_SCHEMA_VERSION = "assessment-response-options-v1" as const;

export type PersistedAssessmentOption = Readonly<{ id: string; label: string }>;
export type PersistedAssessmentItem = Readonly<{
  key: string;
  displayOrder: number;
  prompt: string;
  options: readonly PersistedAssessmentOption[];
}>;
export type PersistedAssessmentView = Readonly<{
  assessmentKey: string;
  assessmentVersion: string;
  items: readonly PersistedAssessmentItem[];
}>;

export type SavePersistedResponseInput = Readonly<{
  locale: AssessmentLocale;
  itemKey: string;
  selectedOptionId: string;
  expectedRevision: number;
  clientMutationId: string;
}>;

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const exactInputKeys = [
  "clientMutationId",
  "expectedRevision",
  "itemKey",
  "locale",
  "selectedOptionId",
] as const;

function assertPublishedDefinitionRegistry(): void {
  if (
    publishedDefinition.schemaVersion !== "persisted-assessment-definition-v1" ||
    publishedDefinition.assessmentKey !== assessmentDefinition.assessmentKey ||
    publishedDefinition.assessmentVersion !== assessmentDefinition.version ||
    publishedDefinition.frameworkKey !== assessmentFramework.frameworkKey ||
    publishedDefinition.frameworkVersion !== assessmentFramework.version ||
    publishedDefinition.scoringModelKey !== scoringModelDefinition.scoringKey ||
    publishedDefinition.scoringModelVersion !== scoringModelDefinition.version ||
    publishedDefinition.items.length !== assessmentDefinition.items.length
  ) {
    throw new Error(
      "Persisted assessment publication metadata does not match the accepted fixture.",
    );
  }

  const acceptedItems = [...assessmentDefinition.items].sort(
    (left, right) => left.displayOrder - right.displayOrder,
  );
  for (const [index, item] of acceptedItems.entries()) {
    const registered = publishedDefinition.items[index];
    if (
      registered?.key !== item.key ||
      registered.displayOrder !== item.displayOrder ||
      registered.targetKind !== item.rubric.targetKind ||
      registered.targetKey !== item.rubric.targetId ||
      JSON.stringify(registered.optionIds) !==
        JSON.stringify(item.options.map((option) => option.id))
    ) {
      throw new Error("Persisted assessment items do not match the accepted fixture registry.");
    }
  }
}

export function createPersistedAssessmentView(locale: AssessmentLocale): PersistedAssessmentView {
  assertPublishedDefinitionRegistry();

  return {
    assessmentKey: assessmentDefinition.assessmentKey,
    assessmentVersion: assessmentDefinition.version,
    items: [...assessmentDefinition.items]
      .sort((left, right) => left.displayOrder - right.displayOrder)
      .map((item) => ({
        key: item.key,
        displayOrder: item.displayOrder,
        prompt: item.prompt[locale],
        options: item.options.map((option) => ({ id: option.id, label: option.label[locale] })),
      })),
  };
}

export function parseSavePersistedResponseInput(raw: unknown): SavePersistedResponseInput {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new Error("Persisted assessment response input is invalid.");
  }

  const candidate = raw as Readonly<Record<string, unknown>>;
  if (JSON.stringify(Object.keys(candidate).sort()) !== JSON.stringify(exactInputKeys)) {
    throw new Error("Persisted assessment response input contains unsupported fields.");
  }

  if (candidate.locale !== "th" && candidate.locale !== "en") {
    throw new Error("Persisted assessment locale is invalid.");
  }
  if (
    typeof candidate.itemKey !== "string" ||
    typeof candidate.selectedOptionId !== "string" ||
    !Number.isInteger(candidate.expectedRevision) ||
    (candidate.expectedRevision as number) < 0 ||
    typeof candidate.clientMutationId !== "string" ||
    !uuidPattern.test(candidate.clientMutationId)
  ) {
    throw new Error("Persisted assessment response input is invalid.");
  }

  const view = createPersistedAssessmentView(candidate.locale);
  const item = view.items.find((entry) => entry.key === candidate.itemKey);
  if (!item || !item.options.some((option) => option.id === candidate.selectedOptionId)) {
    throw new Error("Persisted assessment response is outside the accepted fixture.");
  }

  return {
    locale: candidate.locale,
    itemKey: candidate.itemKey,
    selectedOptionId: candidate.selectedOptionId,
    expectedRevision: candidate.expectedRevision as number,
    clientMutationId: candidate.clientMutationId,
  };
}

export function getSyntheticPublishedDefinition() {
  assertPublishedDefinitionRegistry();
  return publishedDefinition;
}
