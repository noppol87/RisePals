import { describe, expect, it, vi } from "vitest";
import { sourceVerificationLessonDefinition } from "@/modules/lesson/publication/registry";
import {
  createInitialSourceVerificationPracticeState,
  createSourceVerificationLessonView,
  evaluateSourceVerificationPractice,
  getSourceVerificationPracticeOutcome,
  resetSourceVerificationPractice,
  retrySourceVerificationPractice,
  selectSourceVerificationOption,
  submitSourceVerificationPractice,
  type SourceVerificationLessonView,
  type SourceVerificationPracticeState,
} from "@/modules/lesson/source-verification";

vi.mock("server-only", () => ({}));

const view = createSourceVerificationLessonView("en", sourceVerificationLessonDefinition);

function answerAll(
  lessonView: SourceVerificationLessonView,
  chooseMet: (index: number) => boolean,
): SourceVerificationPracticeState {
  return lessonView.practice.criteria.reduce((state, criterion, index) => {
    const option = criterion.options.find(
      (candidate) => candidate.meetsCriterion === chooseMet(index),
    )!;
    return selectSourceVerificationOption(state, lessonView, criterion.id, option.id);
  }, createInitialSourceVerificationPracticeState());
}

describe("source-verification practice evaluation and state", () => {
  it("keeps passive viewing non-demonstrated with zero preview XP", () => {
    const state = createInitialSourceVerificationPracticeState();
    expect(state).toEqual({ phase: "practice", selections: [], evaluation: null });
    expect(getSourceVerificationPracticeOutcome(state)).toEqual({
      demonstrated: false,
      previewXp: 0,
    });
  });

  it("rejects incomplete practice without creating feedback or XP", () => {
    const criterion = view.practice.criteria[0]!;
    const state = selectSourceVerificationOption(
      createInitialSourceVerificationPracticeState(),
      view,
      criterion.id,
      criterion.options[0]!.id,
    );
    const result = submitSourceVerificationPractice(state, view);

    expect(result).toEqual({ ok: false, reason: "incomplete", state });
    expect(getSourceVerificationPracticeOutcome(result.state)).toEqual({
      demonstrated: false,
      previewXp: 0,
    });
  });

  it("returns criterion-level met/not-met feedback and zero XP below threshold", () => {
    const state = answerAll(view, (index) => index !== 1);
    const result = submitSourceVerificationPractice(state, view);
    expect(result.ok).toBe(true);
    if (!result.ok) return;

    expect(result.state.evaluation?.criterionResults.map((criterion) => criterion.status)).toEqual([
      "met",
      "not-met",
      "met",
    ]);
    expect(result.state.evaluation).toMatchObject({
      demonstrated: false,
      previewXp: 0,
      xpSaved: false,
    });
  });

  it("requires all three criteria for demonstrated practice and exactly 20 preview XP", () => {
    const result = submitSourceVerificationPractice(
      answerAll(view, () => true),
      view,
    );
    expect(result.ok).toBe(true);
    if (!result.ok) return;

    expect(result.state.evaluation?.criterionResults).toHaveLength(3);
    expect(result.state.evaluation?.criterionResults.every((item) => item.status === "met")).toBe(
      true,
    );
    expect(getSourceVerificationPracticeOutcome(result.state)).toEqual({
      demonstrated: true,
      previewXp: 20,
    });
    expect(result.state.evaluation?.xpSaved).toBe(false);
  });

  it("retries and re-evaluates by replacement without accumulating XP", () => {
    const first = submitSourceVerificationPractice(
      answerAll(view, () => true),
      view,
    );
    expect(first.ok).toBe(true);
    if (!first.ok) return;

    const retry = retrySourceVerificationPractice(first.state);
    expect(getSourceVerificationPracticeOutcome(retry)).toEqual({
      demonstrated: false,
      previewXp: 0,
    });
    const second = submitSourceVerificationPractice(retry, view);
    expect(second.ok).toBe(true);
    if (!second.ok) return;

    expect(second.state.evaluation?.previewXp).toBe(20);
    expect(second.state.evaluation).not.toHaveProperty("accumulatedXp");
    expect(resetSourceVerificationPractice()).toEqual(
      createInitialSourceVerificationPracticeState(),
    );
  });

  it("rejects duplicate or unknown practice selections", () => {
    const criterion = view.practice.criteria[0]!;
    const option = criterion.options[0]!;
    expect(() =>
      evaluateSourceVerificationPractice(view, [
        { criterionId: criterion.id, optionId: option.id },
        { criterionId: criterion.id, optionId: option.id },
      ]),
    ).toThrow(`duplicate practice selection: ${criterion.id}.`);
    expect(() =>
      evaluateSourceVerificationPractice(view, [
        { criterionId: criterion.id, optionId: "unknown-option" },
      ]),
    ).toThrow(`unknown practice selection: ${criterion.id}/unknown-option.`);
  });
});
