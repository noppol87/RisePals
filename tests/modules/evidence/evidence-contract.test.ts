import { beforeAll, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import {
  acceptedCorrectedWordingOptionIds,
  acceptedSafeNextActionOptionIds,
  createEmptyEvidencePayload,
  evaluateEvidenceArtifactPayload,
  getEvidenceArtifactContract,
  parseEvidenceArtifactPayload,
  parseEvidenceLifecycleInput,
  parseEvidenceSaveInput,
  parseEvidenceStartInput,
} from "@/modules/evidence/contract";
import { createEvidenceArtifactView, createEvidenceFeedback } from "@/modules/evidence/view";
import {
  EVIDENCE_ARTIFACT_CONTRACT_ID,
  EVIDENCE_ARTIFACT_CONTRACT_VERSION,
  EVIDENCE_CLAIM_ID,
  EVIDENCE_PAYLOAD_SCHEMA_VERSION,
  evidenceSourceReferenceIds,
  type EvidenceArtifactPayload,
} from "@/modules/evidence/types";
import { sourceVerificationLessonDefinition } from "@/modules/lesson/publication/registry";

const mutationId = "10000000-0000-4000-8000-000000000001";
const readyPayload: EvidenceArtifactPayload = {
  schemaVersion: EVIDENCE_PAYLOAD_SCHEMA_VERSION,
  claimId: EVIDENCE_CLAIM_ID,
  sourceReferenceIds: evidenceSourceReferenceIds,
  fitCheckId: "partially-supported-overgeneralized",
  correctedWordingOptionId: "fit-narrow-to-supported-teams",
  safeNextActionOptionId: "safe-hold-and-resolve-gaps",
};

function collectKeys(value: unknown): string[] {
  if (!value || typeof value !== "object") return [];
  if (Array.isArray(value)) return value.flatMap(collectKeys);
  return Object.entries(value).flatMap(([key, child]) => [key, ...collectKeys(child)]);
}

describe("private evidence artifact contract", () => {
  beforeAll(() => {
    expect(sourceVerificationLessonDefinition.proof.capturesInput).toBe(false);
  });

  it("anchors the separate artifact to the exact accepted placeholder and source lesson", () => {
    expect(getEvidenceArtifactContract()).toEqual({
      id: EVIDENCE_ARTIFACT_CONTRACT_ID,
      version: EVIDENCE_ARTIFACT_CONTRACT_VERSION,
      artifactType: "source-verification-note",
      sourceProofIdentity: "source-verification-note-placeholder-v1@1.0.0",
      sourceLessonIdentity: "source-verification-practice@1.0.0",
      sourcePackId: "bright-river-operations-synthetic-source-pack-v1",
      classification: "synthetic-private-evidence",
      validationStatus: "prototype-unvalidated",
    });
    expect(sourceVerificationLessonDefinition.proof.capturesInput).toBe(false);
  });

  it("derives only the accepted controlled practice options", () => {
    expect(acceptedCorrectedWordingOptionIds).toEqual([
      "fit-narrow-to-supported-teams",
      "fit-keep-all-team-claim",
      "fit-convert-to-broad-average",
    ]);
    expect(acceptedSafeNextActionOptionIds).toEqual([
      "safe-hold-and-resolve-gaps",
      "safe-publish-with-small-note",
      "safe-ask-ai-for-confidence",
    ]);
  });

  it("accepts a partial draft and preserves the exact six-key payload", () => {
    expect(parseEvidenceArtifactPayload(createEmptyEvidencePayload())).toEqual({
      schemaVersion: EVIDENCE_PAYLOAD_SCHEMA_VERSION,
      claimId: null,
      sourceReferenceIds: [],
      fitCheckId: null,
      correctedWordingOptionId: null,
      safeNextActionOptionId: null,
    });
  });

  it("marks only the exact complete canonical structure ready", () => {
    expect(evaluateEvidenceArtifactPayload(readyPayload)).toMatchObject({ ready: true });
    for (const [field, value] of [
      ["claimId", null],
      ["sourceReferenceIds", ["pilot-table"]],
      ["fitCheckId", "supported"],
      ["correctedWordingOptionId", "fit-keep-all-team-claim"],
      ["safeNextActionOptionId", "safe-publish-with-small-note"],
    ] as const) {
      expect(evaluateEvidenceArtifactPayload({ ...readyPayload, [field]: value }).ready).toBe(
        false,
      );
    }
  });

  it.each([
    ["extra key", { ...readyPayload, extra: true }],
    ["wrong schema", { ...readyPayload, schemaVersion: "future" }],
    ["unknown claim", { ...readyPayload, claimId: "unknown" }],
    ["unknown source", { ...readyPayload, sourceReferenceIds: ["unknown"] }],
    ["duplicate source", { ...readyPayload, sourceReferenceIds: ["pilot-table", "pilot-table"] }],
    [
      "noncanonical source order",
      { ...readyPayload, sourceReferenceIds: ["risk-log", "pilot-table"] },
    ],
    ["unknown fit", { ...readyPayload, fitCheckId: "unknown" }],
    ["unknown correction", { ...readyPayload, correctedWordingOptionId: "unknown" }],
    ["unknown action", { ...readyPayload, safeNextActionOptionId: "unknown" }],
  ])("rejects %s", (_label, value) => {
    expect(() => parseEvidenceArtifactPayload(value)).toThrow();
  });

  it("accepts only exact start, save, ready and withdraw mutation envelopes", () => {
    expect(parseEvidenceStartInput({ locale: "th", clientMutationId: mutationId })).toEqual({
      locale: "th",
      clientMutationId: mutationId,
    });
    expect(
      parseEvidenceSaveInput({
        locale: "en",
        intent: "save",
        payload: readyPayload,
        expectedRevision: 0,
        clientMutationId: mutationId,
      }),
    ).toMatchObject({ intent: "save", expectedRevision: 0, payload: readyPayload });
    for (const intent of ["ready", "withdraw"] as const) {
      expect(
        parseEvidenceLifecycleInput({
          locale: "en",
          intent,
          expectedRevision: 1,
          clientMutationId: mutationId,
        }),
      ).toMatchObject({ intent, expectedRevision: 1 });
    }
    expect(() =>
      parseEvidenceStartInput({ locale: "th", clientMutationId: mutationId, artifactId: "hidden" }),
    ).toThrow();
  });

  it("creates equivalent bilingual views without private or scoring data", () => {
    for (const locale of ["th", "en"] as const) {
      const view = createEvidenceArtifactView(locale);
      expect(view.sourceReferences.map(({ id }) => id)).toEqual(evidenceSourceReferenceIds);
      expect(view.correctedWordingOptions.map(({ id }) => id)).toEqual(
        acceptedCorrectedWordingOptionIds,
      );
      expect(view.safeNextActionOptions.map(({ id }) => id)).toEqual(
        acceptedSafeNextActionOptionIds,
      );
      expect(collectKeys(view).join(" ")).not.toMatch(
        /userId|artifactId|consentId|score|priority/iu,
      );
      expect(
        createEvidenceFeedback(locale, readyPayload).every(({ status }) => status === "complete"),
      ).toBe(true);
    }
  });
});
