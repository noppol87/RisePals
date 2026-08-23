import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  PrivateEvidenceArtifact,
  StartEvidenceArtifact,
} from "@/components/private-evidence-artifact";
import { evidenceCopy } from "@/modules/evidence/copy";
import type { EvidenceArtifactClientState } from "@/modules/evidence/dal";
import type { EvidenceArtifactPayload, EvidenceArtifactView } from "@/modules/evidence/types";

const actions = vi.hoisted(() => ({ start: vi.fn(), save: vi.fn(), lifecycle: vi.fn() }));
const navigation = vi.hoisted(() => ({ refresh: vi.fn() }));

vi.mock("@/app/[locale]/evidence/source-verification-note/actions", () => ({
  startEvidenceArtifactAction: actions.start,
  saveEvidenceArtifactAction: actions.save,
  mutateEvidenceLifecycleAction: actions.lifecycle,
}));
vi.mock("next/navigation", () => ({ useRouter: () => navigation }));

const emptyPayload: EvidenceArtifactPayload = {
  schemaVersion: "source-verification-note-artifact-payload-v1",
  claimId: null,
  sourceReferenceIds: [],
  fitCheckId: null,
  correctedWordingOptionId: null,
  safeNextActionOptionId: null,
};
const readyPayload: EvidenceArtifactPayload = {
  ...emptyPayload,
  claimId: "bright-river-ai-summary-claim-v1",
  sourceReferenceIds: ["pilot-table", "scope-note", "risk-log"],
  fitCheckId: "partially-supported-overgeneralized",
  correctedWordingOptionId: "fit-narrow-to-supported-teams",
  safeNextActionOptionId: "safe-hold-and-resolve-gaps",
};
const feedback = [
  { fieldId: "claim", status: "complete", message: "claim feedback" },
  { fieldId: "source-reference", status: "complete", message: "source feedback" },
  { fieldId: "fit-check", status: "complete", message: "fit feedback" },
  { fieldId: "corrected-wording", status: "complete", message: "correction feedback" },
  { fieldId: "safe-next-action", status: "complete", message: "action feedback" },
] as const;
const view: EvidenceArtifactView = {
  contract: {
    id: "source-verification-note-artifact-v1",
    version: "1.0.0",
    artifactType: "source-verification-note",
    sourceProofIdentity: "source-verification-note-placeholder-v1@1.0.0",
    sourceLessonIdentity: "source-verification-practice@1.0.0",
    sourcePackId: "bright-river-operations-synthetic-source-pack-v1",
    classification: "synthetic-private-evidence",
    validationStatus: "prototype-unvalidated",
  },
  claim: {
    id: "bright-river-ai-summary-claim-v1",
    label: "AI-summary claim",
    value: "A fixed synthetic claim",
  },
  sourceReferences: [
    { id: "pilot-table", label: "Pilot", detail: "Synthetic results" },
    { id: "scope-note", label: "Scope", detail: "Synthetic scope" },
    { id: "risk-log", label: "Risk", detail: "Synthetic risks" },
  ],
  fitChecks: [
    { id: "supported", label: "Supported" },
    { id: "partially-supported-overgeneralized", label: "Overgeneralized" },
    { id: "unsupported", label: "Unsupported" },
  ],
  correctedWordingOptions: [
    { id: "fit-narrow-to-supported-teams", label: "Narrow" },
    { id: "fit-keep-all-team-claim", label: "Keep" },
    { id: "fit-convert-to-broad-average", label: "Average" },
  ],
  safeNextActionOptions: [
    { id: "safe-hold-and-resolve-gaps", label: "Hold" },
    { id: "safe-publish-with-small-note", label: "Publish" },
    { id: "safe-ask-ai-for-confidence", label: "Ask AI" },
  ],
};

function state(payload = emptyPayload, status: EvidenceArtifactClientState["status"] = "draft") {
  return { status, revision: payload === emptyPayload ? 0 : 1, payload, feedback } as const;
}

describe("private evidence artifact", () => {
  beforeEach(() => {
    actions.start.mockReset();
    actions.save.mockReset();
    actions.lifecycle.mockReset();
    navigation.refresh.mockReset();
  });

  it("starts explicitly using only locale and a client mutation UUID", async () => {
    actions.start.mockResolvedValue({ state: "saved", artifact: state() });
    render(<StartEvidenceArtifact copy={evidenceCopy.en} locale="en" />);
    fireEvent.click(screen.getByRole("button", { name: evidenceCopy.en.startLabel }));
    await waitFor(() => expect(actions.start).toHaveBeenCalledTimes(1));
    expect(actions.start.mock.calls[0]![0]).toBe("en");
    expect(actions.start.mock.calls[0]![1]).toMatch(/^[0-9a-f-]{36}$/u);
    expect(navigation.refresh).toHaveBeenCalledOnce();
  });

  it("sends only controlled ordered selections and exposes no free-text or file input", async () => {
    actions.save.mockImplementation(async (input) => ({
      state: "saved",
      artifact: { status: "draft", revision: 1, payload: input.payload, feedback },
    }));
    render(
      <PrivateEvidenceArtifact
        copy={evidenceCopy.en}
        initialArtifact={state()}
        locale="en"
        view={view}
      />,
    );
    expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
    expect(document.querySelector('input[type="file"]')).toBeNull();
    fireEvent.click(screen.getByRole("radio", { name: /fixed synthetic claim/iu }));
    for (const label of [
      "Pilot Synthetic results",
      "Scope Synthetic scope",
      "Risk Synthetic risks",
    ]) {
      fireEvent.click(screen.getByRole("checkbox", { name: label }));
    }
    fireEvent.click(screen.getByRole("radio", { name: "Overgeneralized" }));
    fireEvent.click(screen.getByRole("radio", { name: "Narrow" }));
    fireEvent.click(screen.getByRole("radio", { name: "Hold" }));
    fireEvent.click(screen.getByRole("button", { name: evidenceCopy.en.saveLabel }));
    await waitFor(() => expect(actions.save).toHaveBeenCalledOnce());
    expect(actions.save.mock.calls[0]![0]).toMatchObject({
      locale: "en",
      intent: "save",
      expectedRevision: 0,
      payload: readyPayload,
    });
    expect(Object.keys(actions.save.mock.calls[0]![0]).sort()).toEqual([
      "clientMutationId",
      "expectedRevision",
      "intent",
      "locale",
      "payload",
    ]);
    expect(JSON.stringify(actions.save.mock.calls[0]![0])).not.toMatch(
      /userId|artifactId|practiceAttemptId|consentId|provider/iu,
    );
    expect(await screen.findByRole("status")).toHaveTextContent(evidenceCopy.en.saved);
    expect(screen.getByRole("heading", { name: evidenceCopy.en.statusHeading })).toHaveFocus();
  });

  it("saves the canonical structure before ready and makes the result read-only", async () => {
    actions.save.mockResolvedValue({ state: "saved", artifact: state(readyPayload) });
    actions.lifecycle.mockResolvedValue({
      state: "ready",
      artifact: state(readyPayload, "ready"),
    });
    render(
      <PrivateEvidenceArtifact
        copy={evidenceCopy.en}
        initialArtifact={state(readyPayload)}
        locale="en"
        view={view}
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: evidenceCopy.en.readyLabel }));
    await waitFor(() => expect(actions.lifecycle).toHaveBeenCalledOnce());
    expect(actions.save.mock.calls[0]![0]).toMatchObject({ intent: "save", payload: readyPayload });
    expect(actions.lifecycle.mock.calls[0]![0]).toMatchObject({
      intent: "ready",
      locale: "en",
      expectedRevision: 1,
    });
    expect(Object.keys(actions.lifecycle.mock.calls[0]![0]).sort()).toEqual([
      "clientMutationId",
      "expectedRevision",
      "intent",
      "locale",
    ]);
    expect(await screen.findByText(evidenceCopy.en.readOnlyBody)).toBeVisible();
    expect(
      screen.queryByRole("button", { name: evidenceCopy.en.saveLabel }),
    ).not.toBeInTheDocument();
  });
});
