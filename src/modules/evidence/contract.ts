import { isLocale } from "@/lib/i18n/config";
import { sourceVerificationLessonDefinition } from "@/modules/lesson/publication/registry";
import {
  EVIDENCE_ARTIFACT_CONTRACT_ID,
  EVIDENCE_ARTIFACT_CONTRACT_VERSION,
  EVIDENCE_ARTIFACT_TYPE,
  EVIDENCE_CLAIM_ID,
  EVIDENCE_CLASSIFICATION,
  EVIDENCE_PAYLOAD_SCHEMA_VERSION,
  EVIDENCE_SOURCE_LESSON_IDENTITY,
  EVIDENCE_SOURCE_PACK_ID,
  EVIDENCE_SOURCE_PROOF_ID,
  EVIDENCE_SOURCE_PROOF_VERSION,
  EVIDENCE_VALIDATION_STATUS,
  evidenceFieldIds,
  evidenceFitCheckIds,
  evidenceSourceReferenceIds,
  type EvidenceArtifactPayload,
  type EvidenceFieldId,
  type EvidenceLifecycleInput,
  type EvidenceSaveInput,
} from "@/modules/evidence/types";

export const acceptedCorrectedWordingOptionIds = sourceVerificationLessonDefinition.practice.options
  .filter((option) => option.criterionId === "claim-source-fit")
  .map((option) => option.id);

export const acceptedSafeNextActionOptionIds = sourceVerificationLessonDefinition.practice.options
  .filter((option) => option.criterionId === "safe-next-action")
  .map((option) => option.id);

const readyValues = {
  claimId: EVIDENCE_CLAIM_ID,
  fitCheckId: "partially-supported-overgeneralized",
  correctedWordingOptionId: "fit-narrow-to-supported-teams",
  safeNextActionOptionId: "safe-hold-and-resolve-gaps",
} as const;

export type EvidenceEvaluation = Readonly<{
  ready: boolean;
  fields: readonly Readonly<{
    fieldId: EvidenceFieldId;
    state: "complete" | "incomplete" | "needs-review";
  }>[];
}>;

export function getEvidenceArtifactContract() {
  if (
    sourceVerificationLessonDefinition.proof.id !== EVIDENCE_SOURCE_PROOF_ID ||
    sourceVerificationLessonDefinition.proof.version !== EVIDENCE_SOURCE_PROOF_VERSION ||
    sourceVerificationLessonDefinition.proof.capturesInput !== false ||
    sourceVerificationLessonDefinition.lesson.key !== "source-verification-practice" ||
    sourceVerificationLessonDefinition.lesson.version !== "1.0.0"
  ) {
    throw new Error("The evidence artifact source contract is not canonical.");
  }
  if (
    acceptedCorrectedWordingOptionIds.length !== 3 ||
    acceptedSafeNextActionOptionIds.length !== 3 ||
    !acceptedCorrectedWordingOptionIds.includes(readyValues.correctedWordingOptionId) ||
    !acceptedSafeNextActionOptionIds.includes(readyValues.safeNextActionOptionId)
  ) {
    throw new Error("The evidence artifact option registry is not canonical.");
  }
  return {
    id: EVIDENCE_ARTIFACT_CONTRACT_ID,
    version: EVIDENCE_ARTIFACT_CONTRACT_VERSION,
    artifactType: EVIDENCE_ARTIFACT_TYPE,
    sourceProofIdentity: `${EVIDENCE_SOURCE_PROOF_ID}@${EVIDENCE_SOURCE_PROOF_VERSION}`,
    sourceLessonIdentity: EVIDENCE_SOURCE_LESSON_IDENTITY,
    sourcePackId: EVIDENCE_SOURCE_PACK_ID,
    classification: EVIDENCE_CLASSIFICATION,
    validationStatus: EVIDENCE_VALIDATION_STATUS,
  } as const;
}

export function createEmptyEvidencePayload(): EvidenceArtifactPayload {
  return {
    schemaVersion: EVIDENCE_PAYLOAD_SCHEMA_VERSION,
    claimId: null,
    sourceReferenceIds: [],
    fitCheckId: null,
    correctedWordingOptionId: null,
    safeNextActionOptionId: null,
  };
}

export function parseEvidenceArtifactPayload(value: unknown): EvidenceArtifactPayload {
  const input = requireRecord(value, "Evidence payload");
  requireExactKeys(
    input,
    [
      "claimId",
      "correctedWordingOptionId",
      "fitCheckId",
      "safeNextActionOptionId",
      "schemaVersion",
      "sourceReferenceIds",
    ],
    "Evidence payload",
  );
  if (input.schemaVersion !== EVIDENCE_PAYLOAD_SCHEMA_VERSION) {
    throw new Error("Evidence payload schema version is unsupported.");
  }
  const claimId = nullableAllowedValue(input.claimId, [EVIDENCE_CLAIM_ID], "claim");
  const fitCheckId = nullableAllowedValue(input.fitCheckId, evidenceFitCheckIds, "fit check");
  const correctedWordingOptionId = nullableAllowedValue(
    input.correctedWordingOptionId,
    acceptedCorrectedWordingOptionIds,
    "corrected wording",
  );
  const safeNextActionOptionId = nullableAllowedValue(
    input.safeNextActionOptionId,
    acceptedSafeNextActionOptionIds,
    "safe next action",
  );
  if (!Array.isArray(input.sourceReferenceIds)) {
    throw new Error("Evidence source references must be an array.");
  }
  let previousRank = -1;
  const seen = new Set<string>();
  const sourceReferenceIds = input.sourceReferenceIds.map((candidate) => {
    if (typeof candidate !== "string") {
      throw new Error("Evidence source reference is invalid.");
    }
    const rank = evidenceSourceReferenceIds.indexOf(
      candidate as (typeof evidenceSourceReferenceIds)[number],
    );
    if (rank < 0 || rank <= previousRank || seen.has(candidate)) {
      throw new Error("Evidence source references are unknown, duplicated, or out of order.");
    }
    previousRank = rank;
    seen.add(candidate);
    return candidate as (typeof evidenceSourceReferenceIds)[number];
  });

  return {
    schemaVersion: EVIDENCE_PAYLOAD_SCHEMA_VERSION,
    claimId: claimId as EvidenceArtifactPayload["claimId"],
    sourceReferenceIds,
    fitCheckId: fitCheckId as EvidenceArtifactPayload["fitCheckId"],
    correctedWordingOptionId,
    safeNextActionOptionId,
  };
}

export function evaluateEvidenceArtifactPayload(value: unknown): EvidenceEvaluation {
  const payload = parseEvidenceArtifactPayload(value);
  const states = {
    claim: state(payload.claimId, readyValues.claimId),
    "source-reference":
      payload.sourceReferenceIds.length === 0
        ? "incomplete"
        : sequenceEquals(payload.sourceReferenceIds, evidenceSourceReferenceIds)
          ? "complete"
          : "needs-review",
    "fit-check": state(payload.fitCheckId, readyValues.fitCheckId),
    "corrected-wording": state(
      payload.correctedWordingOptionId,
      readyValues.correctedWordingOptionId,
    ),
    "safe-next-action": state(payload.safeNextActionOptionId, readyValues.safeNextActionOptionId),
  } as const;
  const fields = evidenceFieldIds.map((fieldId) => ({ fieldId, state: states[fieldId] }));
  return { ready: fields.every((field) => field.state === "complete"), fields };
}

export function parseEvidenceStartInput(value: unknown) {
  const input = requireRecord(value, "Evidence start input");
  requireExactKeys(input, ["clientMutationId", "locale"], "Evidence start input");
  if (
    typeof input.locale !== "string" ||
    !isLocale(input.locale) ||
    !isUuid(input.clientMutationId)
  ) {
    throw new Error("Evidence start input is invalid.");
  }
  return { locale: input.locale, clientMutationId: input.clientMutationId } as const;
}

export function parseEvidenceSaveInput(value: unknown): EvidenceSaveInput {
  const input = requireRecord(value, "Evidence save input");
  requireExactKeys(
    input,
    ["clientMutationId", "expectedRevision", "intent", "locale", "payload"],
    "Evidence save input",
  );
  if (
    input.intent !== "save" ||
    typeof input.locale !== "string" ||
    !isLocale(input.locale) ||
    !Number.isInteger(input.expectedRevision) ||
    (input.expectedRevision as number) < 0 ||
    !isUuid(input.clientMutationId)
  ) {
    throw new Error("Evidence save input is invalid.");
  }
  return {
    locale: input.locale,
    intent: "save",
    payload: parseEvidenceArtifactPayload(input.payload),
    expectedRevision: input.expectedRevision as number,
    clientMutationId: input.clientMutationId,
  };
}

export function parseEvidenceLifecycleInput(value: unknown): EvidenceLifecycleInput {
  const input = requireRecord(value, "Evidence lifecycle input");
  requireExactKeys(
    input,
    ["clientMutationId", "expectedRevision", "intent", "locale"],
    "Evidence lifecycle input",
  );
  if (
    (input.intent !== "ready" && input.intent !== "withdraw") ||
    typeof input.locale !== "string" ||
    !isLocale(input.locale) ||
    !Number.isInteger(input.expectedRevision) ||
    (input.expectedRevision as number) < 0 ||
    !isUuid(input.clientMutationId)
  ) {
    throw new Error("Evidence lifecycle input is invalid.");
  }
  return {
    locale: input.locale,
    intent: input.intent,
    expectedRevision: input.expectedRevision as number,
    clientMutationId: input.clientMutationId,
  };
}

export function evidencePayloadsEqual(
  left: EvidenceArtifactPayload,
  right: EvidenceArtifactPayload,
): boolean {
  return (
    left.schemaVersion === right.schemaVersion &&
    left.claimId === right.claimId &&
    sequenceEquals(left.sourceReferenceIds, right.sourceReferenceIds) &&
    left.fitCheckId === right.fitCheckId &&
    left.correctedWordingOptionId === right.correctedWordingOptionId &&
    left.safeNextActionOptionId === right.safeNextActionOptionId
  );
}

function state(value: string | null, expected: string) {
  return value === null
    ? ("incomplete" as const)
    : value === expected
      ? ("complete" as const)
      : ("needs-review" as const);
}

function sequenceEquals(left: readonly string[], right: readonly string[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function nullableAllowedValue(
  value: unknown,
  allowed: readonly string[],
  label: string,
): string | null {
  if (value === null) return null;
  if (typeof value !== "string" || !allowed.includes(value)) {
    throw new Error(`Evidence ${label} is invalid.`);
  }
  return value;
}

function requireRecord(value: unknown, label: string): Readonly<Record<string, unknown>> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  return value as Readonly<Record<string, unknown>>;
}

function requireExactKeys(
  value: Readonly<Record<string, unknown>>,
  expected: readonly string[],
  label: string,
): void {
  const actual = Object.keys(value).sort();
  const sortedExpected = [...expected].sort();
  if (
    actual.length !== sortedExpected.length ||
    actual.some((key, index) => key !== sortedExpected[index])
  ) {
    throw new Error(`${label} has unsupported fields.`);
  }
}

function isUuid(value: unknown): value is string {
  return (
    typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(value)
  );
}
