import { assessmentDefinition, scoringModelDefinition } from "@/modules/assessment/assessment";
import { assessmentFramework } from "@/modules/assessment/framework";
import type { AssessmentLocale } from "@/modules/assessment/types";
import { validateAssessmentDomain } from "@/modules/assessment/validate";

export type AssessmentPlayerOptionView = Readonly<{
  id: string;
  label: string;
}>;

export type AssessmentPlayerItemView = Readonly<{
  key: string;
  displayOrder: number;
  prompt: string;
  options: readonly AssessmentPlayerOptionView[];
}>;

export type AssessmentPlayerView = Readonly<{
  assessmentId: string;
  assessmentVersionId: string;
  assessmentVersion: string;
  items: readonly AssessmentPlayerItemView[];
}>;

export function createAssessmentPlayerView(locale: AssessmentLocale): AssessmentPlayerView {
  validateAssessmentDomain(assessmentFramework, assessmentDefinition, scoringModelDefinition);

  return {
    assessmentId: assessmentDefinition.assessmentKey,
    assessmentVersionId: assessmentDefinition.id,
    assessmentVersion: assessmentDefinition.version,
    items: [...assessmentDefinition.items]
      .sort((left, right) => left.displayOrder - right.displayOrder)
      .map((item) => ({
        key: item.key,
        displayOrder: item.displayOrder,
        prompt: item.prompt[locale],
        options: item.options.map((option) => ({
          id: option.id,
          label: option.label[locale],
        })),
      })),
  };
}
