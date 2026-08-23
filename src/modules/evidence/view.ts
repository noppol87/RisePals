import type { Locale } from "@/lib/i18n/config";
import {
  evaluateEvidenceArtifactPayload,
  getEvidenceArtifactContract,
} from "@/modules/evidence/contract";
import { evidenceCopy } from "@/modules/evidence/copy";
import type {
  EvidenceArtifactPayload,
  EvidenceArtifactView,
  EvidenceFieldFeedback,
} from "@/modules/evidence/types";
import { sourceVerificationLessonDefinition } from "@/modules/lesson/publication/registry";
import { createSourceVerificationLessonView } from "@/modules/lesson/source-verification/view";

export function createEvidenceArtifactView(locale: Locale): EvidenceArtifactView {
  getEvidenceArtifactContract();
  const lesson = createSourceVerificationLessonView(locale, sourceVerificationLessonDefinition);
  const fitCriterion = lesson.practice.criteria.find(({ id }) => id === "claim-source-fit");
  const safeCriterion = lesson.practice.criteria.find(({ id }) => id === "safe-next-action");
  if (!fitCriterion || !safeCriterion) {
    throw new Error("The evidence artifact option view is unavailable.");
  }
  return {
    claim: {
      id: "bright-river-ai-summary-claim-v1",
      label: lesson.scenario.aiSummaryLabel,
      value: lesson.scenario.aiSummary,
    },
    sourceReferences: lesson.scenario.sourceRecords.map(({ id, label, detail }) => ({
      id: id as EvidenceArtifactView["sourceReferences"][number]["id"],
      label,
      detail,
    })),
    fitChecks: Object.entries(evidenceCopy[locale].fitLabels).map(([id, label]) => ({
      id: id as EvidenceArtifactView["fitChecks"][number]["id"],
      label,
    })),
    correctedWordingOptions: fitCriterion.options.map(({ id, label }) => ({ id, label })),
    safeNextActionOptions: safeCriterion.options.map(({ id, label }) => ({ id, label })),
  };
}

export function createEvidenceFeedback(
  locale: Locale,
  payload: EvidenceArtifactPayload,
): readonly EvidenceFieldFeedback[] {
  const evaluation = evaluateEvidenceArtifactPayload(payload);
  return evaluation.fields.map(({ fieldId, state }) => ({
    fieldId,
    status: state,
    message:
      evidenceCopy[locale].feedback[fieldId][state === "needs-review" ? "needsReview" : state],
  }));
}
