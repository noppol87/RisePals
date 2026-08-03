import type { Locale } from "@/lib/i18n/config";

export const LESSON_CONTENT_CONTRACT_VERSION_ID = "lesson-local-prototype-contract-v1";
export const SOURCE_VERIFICATION_LESSON_KEY = "source-verification-practice";
export const SOURCE_VERIFICATION_LESSON_VERSION_ID = "lesson-source-verification-practice-v1";
export const SOURCE_VERIFICATION_LESSON_VERSION = "1.0.0";
export const SOURCE_VERIFICATION_PRACTICE_ID = "source-verification-decision-v1";
export const SOURCE_VERIFICATION_RUBRIC_VERSION_ID = "source-verification-rubric-v1";
export const SOURCE_VERIFICATION_PROOF_ID = "source-verification-note-placeholder-v1";
export const SOURCE_VERIFICATION_EVALUATION_CONTRACT_VERSION_ID =
  "source-verification-evaluation-v1";

export const sourceVerificationCriterionIds = [
  "evidence-traceability",
  "claim-source-fit",
  "safe-next-action",
] as const;

export type SourceVerificationCriterionId = (typeof sourceVerificationCriterionIds)[number];

export const sourceVerificationProofFieldIds = [
  "claim",
  "source-reference",
  "fit-check",
  "corrected-wording",
  "safe-next-action",
] as const;

export type SourceVerificationProofFieldId = (typeof sourceVerificationProofFieldIds)[number];

export type SourceVerificationOptionDefinition = Readonly<{
  id: string;
  criterionId: SourceVerificationCriterionId;
  meetsCriterion: boolean;
}>;

export type SourceVerificationRubricCriterionDefinition = Readonly<{
  id: string;
  practiceCriterionId: SourceVerificationCriterionId;
}>;

export type LocalizedSourceVerificationContent = Readonly<{
  locale: Locale;
  metadata: Readonly<{
    title: string;
    description: string;
  }>;
  hero: Readonly<{
    eyebrow: string;
    heading: string;
    introduction: string;
    prototypeLabel: string;
    boundary: string;
  }>;
  overview: Readonly<{
    heading: string;
    targetLabel: string;
    stageLabel: string;
    roiLabel: string;
    timeLabel: string;
    timeValue: string;
  }>;
  scenario: Readonly<{
    heading: string;
    introduction: string;
    syntheticLabel: string;
    organizationLabel: string;
    organization: string;
    documentLabel: string;
    document: string;
    aiSummaryLabel: string;
    aiSummary: string;
    sourceHeading: string;
    sourceRecords: readonly Readonly<{
      id: string;
      label: string;
      detail: string;
    }>[];
  }>;
  concepts: Readonly<{
    heading: string;
    introduction: string;
    items: readonly Readonly<{
      id: SourceVerificationCriterionId;
      heading: string;
      body: string;
    }>[];
  }>;
  practice: Readonly<{
    eyebrow: string;
    heading: string;
    introduction: string;
    instruction: string;
    criteria: readonly Readonly<{
      id: SourceVerificationCriterionId;
      label: string;
      prompt: string;
      options: readonly Readonly<{
        id: string;
        label: string;
      }>[];
    }>[];
  }>;
  rubric: Readonly<{
    heading: string;
    introduction: string;
    demonstratedRule: string;
    criteria: readonly Readonly<{
      id: SourceVerificationCriterionId;
      label: string;
      metDescription: string;
      notMetDescription: string;
    }>[];
  }>;
  feedback: Readonly<{
    incompleteError: string;
    heading: string;
    demonstratedHeading: string;
    partialHeading: string;
    demonstratedSummary: string;
    partialSummary: string;
    metLabel: string;
    notMetLabel: string;
    previewXpTemplate: string;
    unsavedXpBoundary: string;
    evaluateLabel: string;
    retryLabel: string;
    resetLabel: string;
    demonstratedAnnouncement: string;
    partialAnnouncement: string;
  }>;
  proof: Readonly<{
    eyebrow: string;
    heading: string;
    introduction: string;
    placeholderLabel: string;
    fieldsHeading: string;
    fields: readonly Readonly<{
      id: SourceVerificationProofFieldId;
      label: string;
    }>[];
    boundary: string;
  }>;
  reflection: Readonly<{
    heading: string;
    prompt: string;
    boundary: string;
  }>;
  actions: Readonly<{
    backToExampleLabel: string;
    homeLabel: string;
  }>;
}>;

export type SourceVerificationLessonDefinition = Readonly<{
  contractVersionId: typeof LESSON_CONTENT_CONTRACT_VERSION_ID;
  lesson: Readonly<{
    key: typeof SOURCE_VERIFICATION_LESSON_KEY;
    versionId: typeof SOURCE_VERIFICATION_LESSON_VERSION_ID;
    version: typeof SOURCE_VERIFICATION_LESSON_VERSION;
    status: "prototype";
    frameworkVersionId: string;
    targetCompetencyId: "critical-thinking-fact-checking";
    targetWorkingStage: "Practicing";
    primaryRoiPillar: "Intelligent Risk & Governance";
    estimatedActiveMinutes: number;
    provenance: "git-versioned-local-prototype";
    locales: readonly ["th", "en"];
    practiceId: typeof SOURCE_VERIFICATION_PRACTICE_ID;
    rubricVersionId: typeof SOURCE_VERIFICATION_RUBRIC_VERSION_ID;
    proofId: typeof SOURCE_VERIFICATION_PROOF_ID;
  }>;
  practice: Readonly<{
    id: typeof SOURCE_VERIFICATION_PRACTICE_ID;
    version: "1.0.0";
    rubricVersionId: typeof SOURCE_VERIFICATION_RUBRIC_VERSION_ID;
    criterionIds: readonly SourceVerificationCriterionId[];
    options: readonly SourceVerificationOptionDefinition[];
  }>;
  rubric: Readonly<{
    versionId: typeof SOURCE_VERIFICATION_RUBRIC_VERSION_ID;
    version: "1.0.0";
    practiceId: typeof SOURCE_VERIFICATION_PRACTICE_ID;
    demonstratedRequires: "all-criteria-met";
    criteria: readonly SourceVerificationRubricCriterionDefinition[];
  }>;
  proof: Readonly<{
    id: typeof SOURCE_VERIFICATION_PROOF_ID;
    version: "1.0.0";
    status: "placeholder";
    artifactType: "source-verification-note";
    fieldIds: readonly SourceVerificationProofFieldId[];
    capturesInput: false;
  }>;
  xpRule: Readonly<{
    versionId: "source-verification-xp-preview-v1";
    viewingPreviewXp: 0;
    incompletePreviewXp: 0;
    demonstratedPreviewXp: 20;
    accumulation: "replace-not-add";
    persisted: false;
  }>;
  content: Readonly<Record<Locale, LocalizedSourceVerificationContent>>;
}>;

export type SourceVerificationPracticeSelection = Readonly<{
  criterionId: SourceVerificationCriterionId;
  optionId: string;
}>;

export type SourceVerificationPracticeCriterionView = Readonly<{
  id: SourceVerificationCriterionId;
  label: string;
  prompt: string;
  options: readonly Readonly<{
    id: string;
    label: string;
    meetsCriterion: boolean;
  }>[];
  rubric: Readonly<{
    label: string;
    metDescription: string;
    notMetDescription: string;
  }>;
}>;

export type SourceVerificationLessonView = Readonly<{
  contractVersionId: typeof LESSON_CONTENT_CONTRACT_VERSION_ID;
  lesson: SourceVerificationLessonDefinition["lesson"] & Readonly<{ locale: Locale }>;
  metadata: LocalizedSourceVerificationContent["metadata"];
  hero: LocalizedSourceVerificationContent["hero"];
  overview: LocalizedSourceVerificationContent["overview"];
  scenario: LocalizedSourceVerificationContent["scenario"];
  concepts: LocalizedSourceVerificationContent["concepts"];
  practice: Readonly<{
    id: typeof SOURCE_VERIFICATION_PRACTICE_ID;
    version: "1.0.0";
    rubricVersionId: typeof SOURCE_VERIFICATION_RUBRIC_VERSION_ID;
    eyebrow: string;
    heading: string;
    introduction: string;
    instruction: string;
    criteria: readonly SourceVerificationPracticeCriterionView[];
  }>;
  rubric: Pick<
    LocalizedSourceVerificationContent["rubric"],
    "heading" | "introduction" | "demonstratedRule"
  >;
  feedback: LocalizedSourceVerificationContent["feedback"];
  proof: LocalizedSourceVerificationContent["proof"] & SourceVerificationLessonDefinition["proof"];
  reflection: LocalizedSourceVerificationContent["reflection"];
  actions: LocalizedSourceVerificationContent["actions"];
  xpRule: SourceVerificationLessonDefinition["xpRule"];
}>;

export type SourceVerificationCriterionResult = Readonly<{
  criterionId: SourceVerificationCriterionId;
  selectedOptionId: string;
  status: "met" | "not-met";
}>;

export type SourceVerificationPracticeEvaluation = Readonly<{
  contractVersionId: typeof SOURCE_VERIFICATION_EVALUATION_CONTRACT_VERSION_ID;
  practiceId: typeof SOURCE_VERIFICATION_PRACTICE_ID;
  rubricVersionId: typeof SOURCE_VERIFICATION_RUBRIC_VERSION_ID;
  criterionResults: readonly SourceVerificationCriterionResult[];
  demonstrated: boolean;
  previewXp: 0 | 20;
  xpSaved: false;
}>;
