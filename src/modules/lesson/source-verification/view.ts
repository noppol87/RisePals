import { sourceVerificationLessonDefinition } from "@/modules/lesson/source-verification/definition";
import type {
  SourceVerificationCriterionId,
  SourceVerificationLessonDefinition,
  SourceVerificationLessonView,
} from "@/modules/lesson/source-verification/types";
import { validateSourceVerificationLessonDefinition } from "@/modules/lesson/source-verification/validate";
import type { Locale } from "@/lib/i18n/config";

export function createSourceVerificationLessonView(
  locale: Locale,
  definition: SourceVerificationLessonDefinition = sourceVerificationLessonDefinition,
): SourceVerificationLessonView {
  validateSourceVerificationLessonDefinition(definition);
  const content = definition.content[locale];

  return {
    contractVersionId: definition.contractVersionId,
    lesson: {
      ...definition.lesson,
      locales: [...definition.lesson.locales],
      locale,
    },
    metadata: { ...content.metadata },
    hero: { ...content.hero },
    overview: { ...content.overview },
    scenario: {
      ...content.scenario,
      sourceRecords: content.scenario.sourceRecords.map((record) => ({ ...record })),
    },
    concepts: {
      ...content.concepts,
      items: content.concepts.items.map((item) => ({ ...item })),
    },
    practice: {
      id: definition.practice.id,
      version: definition.practice.version,
      rubricVersionId: definition.practice.rubricVersionId,
      eyebrow: content.practice.eyebrow,
      heading: content.practice.heading,
      introduction: content.practice.introduction,
      instruction: content.practice.instruction,
      criteria: definition.practice.criterionIds.map((criterionId) => {
        const localizedCriterion = requireById(
          content.practice.criteria,
          criterionId,
          "localized practice criterion",
        );
        const localizedRubric = requireById(
          content.rubric.criteria,
          criterionId,
          "localized rubric criterion",
        );
        const optionDefinitions = definition.practice.options.filter(
          (option) => option.criterionId === criterionId,
        );

        return {
          id: criterionId,
          label: localizedCriterion.label,
          prompt: localizedCriterion.prompt,
          options: optionDefinitions.map((option) => ({
            id: option.id,
            label: requireById(localizedCriterion.options, option.id, "localized option").label,
            meetsCriterion: option.meetsCriterion,
          })),
          rubric: {
            label: localizedRubric.label,
            metDescription: localizedRubric.metDescription,
            notMetDescription: localizedRubric.notMetDescription,
          },
        };
      }),
    },
    rubric: {
      heading: content.rubric.heading,
      introduction: content.rubric.introduction,
      demonstratedRule: content.rubric.demonstratedRule,
    },
    feedback: { ...content.feedback },
    proof: {
      ...definition.proof,
      ...content.proof,
      fieldIds: [...definition.proof.fieldIds],
      fields: content.proof.fields.map((field) => ({ ...field })),
    },
    reflection: { ...content.reflection },
    actions: { ...content.actions },
    xpRule: { ...definition.xpRule },
  };
}

function requireById<T extends Readonly<{ id: string }>>(
  values: readonly T[],
  id: string | SourceVerificationCriterionId,
  label: string,
): T {
  const value = values.find((candidate) => candidate.id === id);
  if (!value) {
    throw new Error(`missing ${label}: ${id}.`);
  }
  return value;
}
