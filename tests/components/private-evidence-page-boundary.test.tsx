import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { evidenceCopy } from "@/modules/evidence/copy";
import type { EvidenceArtifactPayload } from "@/modules/evidence/types";

const boundary = vi.hoisted(() => ({
  load: vi.fn(),
  artifactProps: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("@/modules/evidence/dal", () => ({
  loadEvidencePageState: boundary.load,
}));
vi.mock("@/components/private-evidence-artifact", () => ({
  PrivateEvidenceArtifact: (props: unknown) => {
    boundary.artifactProps(props);
    return <div data-testid="authenticated-artifact" />;
  },
  StartEvidenceArtifact: () => <div data-testid="start-artifact" />,
}));
vi.mock("next/navigation", () => ({
  notFound: vi.fn(),
  redirect: vi.fn(),
}));

import SourceVerificationEvidencePage from "@/app/[locale]/evidence/source-verification-note/page";

const payload: EvidenceArtifactPayload = {
  schemaVersion: "source-verification-note-artifact-payload-v1",
  claimId: "bright-river-ai-summary-claim-v1",
  sourceReferenceIds: ["pilot-table", "scope-note", "risk-log"],
  fitCheckId: "partially-supported-overgeneralized",
  correctedWordingOptionId: "fit-narrow-to-supported-teams",
  safeNextActionOptionId: "safe-hold-and-resolve-gaps",
};

const feedback = [
  { fieldId: "claim", status: "complete", message: "claim" },
  { fieldId: "source-reference", status: "complete", message: "source" },
  { fieldId: "fit-check", status: "complete", message: "fit" },
  { fieldId: "corrected-wording", status: "complete", message: "wording" },
  { fieldId: "safe-next-action", status: "complete", message: "action" },
] as const;

describe("authenticated evidence server-to-client boundary", () => {
  beforeEach(() => {
    boundary.load.mockReset();
    boundary.artifactProps.mockReset();
  });

  it.each(["th", "en"] as const)(
    "passes only the approved %s controlled payload to the Client Component",
    async (locale) => {
      boundary.load.mockResolvedValue({
        state: "artifact",
        artifact: { status: "draft", revision: 2, payload, feedback },
      });
      render(await SourceVerificationEvidencePage({ params: Promise.resolve({ locale }) }));
      expect(screen.getByTestId("authenticated-artifact")).toBeVisible();
      expect(boundary.artifactProps).toHaveBeenCalledOnce();
      const props = boundary.artifactProps.mock.calls[0]![0] as Record<string, unknown>;
      expect(Object.keys(props).sort()).toEqual(["copy", "initialArtifact", "locale", "view"]);
      expect(props.locale).toBe(locale);
      expect(props.copy).toBe(evidenceCopy[locale]);
      expect(Object.keys(props.view as Record<string, unknown>).sort()).toEqual([
        "claim",
        "correctedWordingOptions",
        "fitChecks",
        "safeNextActionOptions",
        "sourceReferences",
      ]);
      expect(Object.keys(props.initialArtifact as Record<string, unknown>).sort()).toEqual([
        "feedback",
        "payload",
        "revision",
        "status",
      ]);
      const flightCandidate = JSON.stringify(props);
      for (const approved of [
        "bright-river-ai-summary-claim-v1",
        "pilot-table",
        "scope-note",
        "risk-log",
        "partially-supported-overgeneralized",
      ]) {
        expect(flightCandidate).toContain(approved);
      }
      for (const prohibited of [
        "source-verification-note-artifact-v1",
        "source-verification-note-placeholder-v1@1.0.0",
        "bright-river-operations-synthetic-source-pack-v1",
        "51903ea9e6053a1102b4d60ad072c9a1dcde26a90d6a0ca7ae36cba8a6995e91",
        "synthetic-private-evidence",
        "sourcePracticeAttemptId",
        "consentRecordId",
        "providerSubject",
        "20000000-0000-4000-8000-000000000001",
      ]) {
        expect(flightCandidate).not.toContain(prohibited);
      }
    },
  );
});
