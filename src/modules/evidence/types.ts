import type { Locale } from "@/lib/i18n/config";

export const EVIDENCE_ARTIFACT_CONTRACT_ID = "source-verification-note-artifact-v1" as const;
export const EVIDENCE_ARTIFACT_CONTRACT_VERSION = "1.0.0" as const;
export const EVIDENCE_PAYLOAD_SCHEMA_VERSION =
  "source-verification-note-artifact-payload-v1" as const;
export const EVIDENCE_ARTIFACT_TYPE = "source-verification-note" as const;
export const EVIDENCE_SOURCE_PROOF_ID = "source-verification-note-placeholder-v1" as const;
export const EVIDENCE_SOURCE_PROOF_VERSION = "1.0.0" as const;
export const EVIDENCE_SOURCE_LESSON_IDENTITY = "source-verification-practice@1.0.0" as const;
export const EVIDENCE_SOURCE_PACK_ID = "bright-river-operations-synthetic-source-pack-v1" as const;
export const EVIDENCE_CLASSIFICATION = "synthetic-private-evidence" as const;
export const EVIDENCE_VALIDATION_STATUS = "prototype-unvalidated" as const;
export const EVIDENCE_CLAIM_ID = "bright-river-ai-summary-claim-v1" as const;
export const EVIDENCE_COMPETENCY_RELATIONSHIP = "synthetic-practice-evidence" as const;

export const evidenceSourceReferenceIds = ["pilot-table", "scope-note", "risk-log"] as const;
export type EvidenceSourceReferenceId = (typeof evidenceSourceReferenceIds)[number];

export const evidenceFitCheckIds = [
  "supported",
  "partially-supported-overgeneralized",
  "unsupported",
] as const;
export type EvidenceFitCheckId = (typeof evidenceFitCheckIds)[number];

export const evidenceFieldIds = [
  "claim",
  "source-reference",
  "fit-check",
  "corrected-wording",
  "safe-next-action",
] as const;
export type EvidenceFieldId = (typeof evidenceFieldIds)[number];

export type EvidenceArtifactStatus = "draft" | "ready" | "withdrawn";

export type EvidenceArtifactPayload = Readonly<{
  schemaVersion: typeof EVIDENCE_PAYLOAD_SCHEMA_VERSION;
  claimId: typeof EVIDENCE_CLAIM_ID | null;
  sourceReferenceIds: readonly EvidenceSourceReferenceId[];
  fitCheckId: EvidenceFitCheckId | null;
  correctedWordingOptionId: string | null;
  safeNextActionOptionId: string | null;
}>;

export type EvidenceFieldFeedback = Readonly<{
  fieldId: EvidenceFieldId;
  status: "complete" | "incomplete" | "needs-review";
  message: string;
}>;

export type EvidenceArtifactView = Readonly<{
  claim: Readonly<{ id: typeof EVIDENCE_CLAIM_ID; label: string; value: string }>;
  sourceReferences: readonly Readonly<{
    id: EvidenceSourceReferenceId;
    label: string;
    detail: string;
  }>[];
  fitChecks: readonly Readonly<{ id: EvidenceFitCheckId; label: string }>[];
  correctedWordingOptions: readonly Readonly<{ id: string; label: string }>[];
  safeNextActionOptions: readonly Readonly<{ id: string; label: string }>[];
}>;

export type EvidenceSaveInput = Readonly<{
  locale: Locale;
  intent: "save";
  payload: EvidenceArtifactPayload;
  expectedRevision: number;
  clientMutationId: string;
}>;

export type EvidenceLifecycleInput = Readonly<{
  locale: Locale;
  intent: "ready" | "withdraw";
  expectedRevision: number;
  clientMutationId: string;
}>;
