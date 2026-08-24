import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  revalidatePath: vi.fn(),
  redirect: vi.fn(),
  capture: vi.fn(),
  report: vi.fn(),
  saveAssessment: vi.fn(),
  generateResult: vi.fn(),
  mutateLesson: vi.fn(),
  startLesson: vi.fn(),
  startEvidence: vi.fn(),
  saveEvidence: vi.fn(),
  mutateEvidence: vi.fn(),
}));

vi.mock("server-only", () => ({}));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock("next/navigation", () => ({ redirect: mocks.redirect }));
vi.mock("@/modules/measurement/server", () => ({
  captureSuccessfulProductAction: mocks.capture,
  reportControlledErrorOccurrence: mocks.report,
}));
vi.mock("@/modules/assessment/persistence/dal", () => ({
  savePersistedAssessmentResponse: mocks.saveAssessment,
  startPersistedAssessment: vi.fn(),
  submitPersistedAssessment: vi.fn(),
}));
vi.mock("@/modules/assessment/persisted-result/dal", () => ({
  generatePersistedResult: mocks.generateResult,
}));
vi.mock("@/modules/lesson/persistence/dal", () => ({
  mutatePersistedLesson: mocks.mutateLesson,
  startPersistedLesson: mocks.startLesson,
}));
vi.mock("@/modules/evidence/dal", () => ({
  startEvidenceArtifact: mocks.startEvidence,
  saveEvidenceArtifact: mocks.saveEvidence,
  mutateEvidenceLifecycle: mocks.mutateEvidence,
}));

import { savePersistedAssessmentResponseAction } from "@/app/[locale]/assessment/attempt/actions";
import { generatePersistedResultAction } from "@/app/[locale]/assessment/result/actions";
import { mutateEvidenceLifecycleAction } from "@/app/[locale]/evidence/source-verification-note/actions";
import { mutatePersistedLessonAction } from "@/app/[locale]/lessons/source-verification-practice/attempt/actions";

const mutationId = "10000000-0000-4000-8000-000000000001";

describe("non-authoritative action instrumentation", () => {
  beforeEach(() => {
    for (const mock of Object.values(mocks)) mock.mockReset();
    mocks.capture.mockResolvedValue({ state: "recorded" });
    mocks.report.mockResolvedValue({ state: "recorded" });
  });

  it("captures only a successful persisted assessment save and never sends answer content", async () => {
    const input = {
      locale: "th" as const,
      itemKey: "verify-ai-summary-source",
      selectedOptionId: "ask-for-source",
      expectedRevision: 0,
      clientMutationId: mutationId,
    };
    mocks.saveAssessment.mockResolvedValue({ state: "conflict", selection: null });
    await expect(savePersistedAssessmentResponseAction(input)).resolves.toMatchObject({
      state: "conflict",
    });
    expect(mocks.capture).not.toHaveBeenCalled();

    mocks.saveAssessment.mockResolvedValue({ state: "saved", selection: { revision: 1 } });
    await savePersistedAssessmentResponseAction(input);
    expect(mocks.capture).toHaveBeenCalledWith({
      surface: "assessment",
      operationCode: "assessment_response_saved",
      locale: "th",
      clientMutationId: mutationId,
    });
    const captured = JSON.stringify(mocks.capture.mock.calls[0]);
    expect(captured).not.toContain(input.itemKey);
    expect(captured).not.toContain(input.selectedOptionId);
  });

  it("reports a controlled occurrence and rethrows the original unexpected failure", async () => {
    const original = new Error("raw database message must not be reported");
    mocks.saveAssessment.mockRejectedValue(original);
    await expect(
      savePersistedAssessmentResponseAction({
        locale: "en",
        itemKey: "verify-ai-summary-source",
        selectedOptionId: "ask-for-source",
        expectedRevision: 0,
        clientMutationId: mutationId,
      }),
    ).rejects.toBe(original);
    expect(mocks.report).toHaveBeenCalledWith({
      surface: "assessment",
      operationCode: "assessment_response_saved",
      locale: "en",
      category: "unexpected_domain",
      retryable: true,
      clientMutationId: mutationId,
    });
    expect(JSON.stringify(mocks.report.mock.calls[0])).not.toContain(original.message);
    expect(mocks.capture).not.toHaveBeenCalled();
  });

  it("does not label failed result generation as a successful outcome", async () => {
    mocks.generateResult.mockResolvedValue({ state: "failed" });
    const form = new FormData();
    form.set("locale", "th");
    form.set("mutationId", mutationId);
    await expect(generatePersistedResultAction({ state: "idle" }, form)).resolves.toEqual({
      state: "failed",
    });
    expect(mocks.capture).not.toHaveBeenCalled();
    expect(mocks.report).toHaveBeenCalledOnce();
  });

  it("maps lesson intent to a controlled operation and ignores denial/conflict", async () => {
    const input = {
      locale: "en" as const,
      intent: "retry" as const,
      expectedRevision: 2,
      clientMutationId: mutationId,
    };
    mocks.mutateLesson.mockResolvedValue({ state: "not-ready" });
    await mutatePersistedLessonAction(input);
    expect(mocks.capture).not.toHaveBeenCalled();
    mocks.mutateLesson.mockResolvedValue({
      state: "saved",
      revision: 3,
      selections: [],
      results: null,
    });
    await mutatePersistedLessonAction(input);
    expect(mocks.capture).toHaveBeenCalledWith({
      surface: "lesson_practice",
      operationCode: "lesson_practice_retry_started",
      locale: "en",
      clientMutationId: mutationId,
    });
  });

  it("captures only successful ready/withdrawn evidence lifecycle outcomes", async () => {
    const input = {
      locale: "th" as const,
      intent: "ready" as const,
      expectedRevision: 2,
      clientMutationId: mutationId,
    };
    mocks.mutateEvidence.mockResolvedValue({ state: "conflict" });
    await mutateEvidenceLifecycleAction(input);
    expect(mocks.capture).not.toHaveBeenCalled();
    mocks.mutateEvidence.mockResolvedValue({ state: "ready", artifact: {} });
    await mutateEvidenceLifecycleAction(input);
    expect(mocks.capture).toHaveBeenCalledWith({
      surface: "private_evidence",
      operationCode: "private_evidence_marked_ready",
      locale: "th",
      clientMutationId: mutationId,
    });
  });
});
