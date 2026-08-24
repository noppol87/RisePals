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
  savePersistedAssessmentResponseWithExecution: mocks.saveAssessment,
  startPersistedAssessment: vi.fn(),
  submitPersistedAssessment: vi.fn(),
}));
vi.mock("@/modules/assessment/persisted-result/dal", () => ({
  generatePersistedResultWithExecution: mocks.generateResult,
}));
vi.mock("@/modules/lesson/persistence/dal", () => ({
  mutatePersistedLessonWithExecution: mocks.mutateLesson,
  startPersistedLesson: mocks.startLesson,
}));
vi.mock("@/modules/evidence/dal", () => ({
  startEvidenceArtifact: mocks.startEvidence,
  saveEvidenceArtifactWithExecution: mocks.saveEvidence,
  mutateEvidenceLifecycleWithExecution: mocks.mutateEvidence,
}));

import { savePersistedAssessmentResponseAction } from "@/app/[locale]/assessment/attempt/actions";
import { generatePersistedResultAction } from "@/app/[locale]/assessment/result/actions";
import { mutateEvidenceLifecycleAction } from "@/app/[locale]/evidence/source-verification-note/actions";
import { mutatePersistedLessonAction } from "@/app/[locale]/lessons/source-verification-practice/attempt/actions";

const mutationId = "10000000-0000-4000-8000-000000000001";

function execution<T>(result: T, disposition: "applied" | "replayed" | "not-applied" = "applied") {
  return { result, disposition } as const;
}

describe("non-authoritative action instrumentation", () => {
  beforeEach(() => {
    for (const mock of Object.values(mocks)) mock.mockReset();
    mocks.capture.mockResolvedValue({ state: "recorded" });
    mocks.report.mockResolvedValue({ state: "recorded" });
  });

  it("captures only a newly applied assessment save and never sends answer content", async () => {
    const input = {
      locale: "th" as const,
      itemKey: "verify-ai-summary-source",
      selectedOptionId: "ask-for-source",
      expectedRevision: 0,
      clientMutationId: mutationId,
    };
    mocks.saveAssessment.mockResolvedValue(
      execution({ state: "conflict", selection: null }, "not-applied"),
    );
    await expect(savePersistedAssessmentResponseAction(input)).resolves.toMatchObject({
      state: "conflict",
    });
    expect(mocks.capture).not.toHaveBeenCalled();

    mocks.saveAssessment.mockResolvedValue(
      execution({ state: "saved", selection: { revision: 1 } }),
    );
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

  it("never captures exact replay before grant, under the same grant or after subject rotation", async () => {
    const input = {
      locale: "th" as const,
      itemKey: "verify-ai-summary-source",
      selectedOptionId: "ask-for-source",
      expectedRevision: 0,
      clientMutationId: mutationId,
    };
    const replay = execution({ state: "saved", selection: { revision: 1 } }, "replayed");
    mocks.saveAssessment.mockResolvedValue(replay);
    await savePersistedAssessmentResponseAction(input);
    await savePersistedAssessmentResponseAction(input);
    await savePersistedAssessmentResponseAction(input);
    expect(mocks.capture).not.toHaveBeenCalled();

    mocks.saveAssessment.mockResolvedValue(
      execution({ state: "saved", selection: { revision: 2 } }),
    );
    await savePersistedAssessmentResponseAction({
      ...input,
      expectedRevision: 1,
      clientMutationId: "10000000-0000-4000-8000-000000000002",
    });
    expect(mocks.capture).toHaveBeenCalledOnce();
  });

  it("captures at most once when concurrent identical mutations converge", async () => {
    const input = {
      locale: "en" as const,
      itemKey: "verify-ai-summary-source",
      selectedOptionId: "ask-for-source",
      expectedRevision: 0,
      clientMutationId: mutationId,
    };
    mocks.saveAssessment
      .mockResolvedValueOnce(execution({ state: "saved", selection: { revision: 1 } }))
      .mockResolvedValueOnce(execution({ state: "saved", selection: { revision: 1 } }, "replayed"));
    await Promise.all([
      savePersistedAssessmentResponseAction(input),
      savePersistedAssessmentResponseAction(input),
    ]);
    expect(mocks.capture).toHaveBeenCalledOnce();
  });

  it("does not label replayed or failed result generation as newly successful", async () => {
    const form = new FormData();
    form.set("locale", "th");
    form.set("mutationId", mutationId);

    mocks.generateResult.mockResolvedValue(execution({ state: "ready" }, "replayed"));
    await generatePersistedResultAction({ state: "idle" }, form);
    expect(mocks.capture).not.toHaveBeenCalled();

    mocks.generateResult.mockResolvedValue(execution({ state: "failed" }, "not-applied"));
    await expect(generatePersistedResultAction({ state: "idle" }, form)).resolves.toEqual({
      state: "failed",
    });
    expect(mocks.capture).not.toHaveBeenCalled();
    expect(mocks.report).toHaveBeenCalledOnce();
  });

  it("maps lesson intent to a controlled operation and ignores replay/denial/conflict", async () => {
    const input = {
      locale: "en" as const,
      intent: "retry" as const,
      expectedRevision: 2,
      clientMutationId: mutationId,
    };
    mocks.mutateLesson.mockResolvedValue(execution({ state: "not-ready" }, "not-applied"));
    await mutatePersistedLessonAction(input);
    mocks.mutateLesson.mockResolvedValue(
      execution({ state: "saved", revision: 3, selections: [], results: null }, "replayed"),
    );
    await mutatePersistedLessonAction(input);
    expect(mocks.capture).not.toHaveBeenCalled();

    mocks.mutateLesson.mockResolvedValue(
      execution({ state: "saved", revision: 3, selections: [], results: null }),
    );
    await mutatePersistedLessonAction(input);
    expect(mocks.capture).toHaveBeenCalledWith({
      surface: "lesson_practice",
      operationCode: "lesson_practice_retry_started",
      locale: "en",
      clientMutationId: mutationId,
    });
  });

  it("captures only a newly applied evidence lifecycle outcome", async () => {
    const input = {
      locale: "th" as const,
      intent: "ready" as const,
      expectedRevision: 2,
      clientMutationId: mutationId,
    };
    mocks.mutateEvidence.mockResolvedValue(execution({ state: "conflict" }, "not-applied"));
    await mutateEvidenceLifecycleAction(input);
    mocks.mutateEvidence.mockResolvedValue(execution({ state: "ready", artifact: {} }, "replayed"));
    await mutateEvidenceLifecycleAction(input);
    expect(mocks.capture).not.toHaveBeenCalled();

    mocks.mutateEvidence.mockResolvedValue(execution({ state: "ready", artifact: {} }));
    await mutateEvidenceLifecycleAction(input);
    expect(mocks.capture).toHaveBeenCalledWith({
      surface: "private_evidence",
      operationCode: "private_evidence_marked_ready",
      locale: "th",
      clientMutationId: mutationId,
    });
  });

  it("contains unexpected assessment, lesson and evidence errors without raw propagation", async () => {
    const sentinel = "RP17_PROHIBITED_SENTINEL_MESSAGE";
    const original = new Error(sentinel, { cause: new Error(`${sentinel}_CAUSE`) });
    const reporterFailure = new Error(`${sentinel}_REPORTER`);
    const consoleSpies = [
      vi.spyOn(console, "error").mockImplementation(() => undefined),
      vi.spyOn(console, "warn").mockImplementation(() => undefined),
      vi.spyOn(console, "log").mockImplementation(() => undefined),
    ];
    mocks.report.mockRejectedValue(reporterFailure);

    mocks.saveAssessment.mockRejectedValue(original);
    const assessmentResult = await savePersistedAssessmentResponseAction({
      locale: "en",
      itemKey: "verify-ai-summary-source",
      selectedOptionId: "ask-for-source",
      expectedRevision: 0,
      clientMutationId: mutationId,
    });
    mocks.mutateLesson.mockRejectedValue(original);
    const lessonResult = await mutatePersistedLessonAction({
      locale: "en",
      intent: "retry",
      expectedRevision: 2,
      clientMutationId: mutationId,
    });
    mocks.mutateEvidence.mockRejectedValue(original);
    const evidenceResult = await mutateEvidenceLifecycleAction({
      locale: "th",
      intent: "ready",
      expectedRevision: 2,
      clientMutationId: mutationId,
    });

    expect([assessmentResult, lessonResult, evidenceResult]).toEqual([
      { state: "not-ready" },
      { state: "not-ready" },
      { state: "not-ready" },
    ]);
    expect(mocks.report).toHaveBeenCalledTimes(3);
    expect(mocks.capture).not.toHaveBeenCalled();
    const observed = JSON.stringify({
      results: [assessmentResult, lessonResult, evidenceResult],
      reporterInputs: mocks.report.mock.calls,
      console: consoleSpies.flatMap((spy) => spy.mock.calls),
    });
    expect(observed).not.toContain(sentinel);
    expect(observed).not.toContain("stack");
    expect(observed).not.toContain("cause");
    for (const spy of consoleSpies) spy.mockRestore();
  });
});
