import { describe, expect, it } from "vitest";
import {
  advancePlayer,
  createInitialPlayerState,
  getPlayerProgress,
  movePlayerBack,
  resetPlayer,
  reviewPlayerAnswers,
  selectPlayerOption,
  startPlayer,
  validatePlayerState,
  type AssessmentPlayerState,
} from "@/modules/assessment/player/state";
import { createAssessmentPlayerView } from "@/modules/assessment/player/view";

const view = createAssessmentPlayerView("en");

function answerCurrent(state: AssessmentPlayerState, optionIndex = 0): AssessmentPlayerState {
  const item = view.items.find((candidate) => candidate.key === state.currentItemKey)!;
  return selectPlayerOption(state, view, item.options[optionIndex]!.id);
}

describe("assessment player state", () => {
  it("moves from intro through six questions to completion without a result state", () => {
    let state = startPlayer(createInitialPlayerState(), view);
    expect(state.phase).toBe("question");
    expect(state.currentItemKey).toBe(view.items[0]!.key);

    for (const item of view.items) {
      expect(state.currentItemKey).toBe(item.key);
      state = answerCurrent(state);
      const advanced = advancePlayer(state, view);
      expect(advanced.ok).toBe(true);
      state = advanced.ok ? advanced.state : state;
    }

    expect(state).toEqual({
      phase: "complete",
      currentItemKey: null,
      selections: view.items.map((item) => ({
        itemKey: item.key,
        optionId: item.options[0]!.id,
      })),
    });
    expect(JSON.stringify(state)).not.toMatch(
      /score|result|proficiency|confidence|priority|recommendation|multiplier/i,
    );
  });

  it("selects and replaces one answer for the current item", () => {
    const started = startPlayer(createInitialPlayerState(), view);
    const first = answerCurrent(started, 0);
    const replacement = answerCurrent(first, 1);

    expect(replacement.selections).toEqual([
      { itemKey: view.items[0]!.key, optionId: view.items[0]!.options[1]!.id },
    ]);
  });

  it("requires an answer before continuing and all answers before completion", () => {
    const started = startPlayer(createInitialPlayerState(), view);
    expect(advancePlayer(started, view)).toEqual({ ok: false, reason: "answer-required" });

    const incompleteLastStep: AssessmentPlayerState = {
      phase: "question",
      currentItemKey: view.items.at(-1)!.key,
      selections: [
        {
          itemKey: view.items.at(-1)!.key,
          optionId: view.items.at(-1)!.options[0]!.id,
        },
      ],
    };
    expect(advancePlayer(incompleteLastStep, view)).toEqual({
      ok: false,
      reason: "assessment-incomplete",
    });
  });

  it("keeps current position and answered count honest and separate", () => {
    let state = startPlayer(createInitialPlayerState(), view);
    expect(getPlayerProgress(state, view)).toEqual({
      currentPosition: 1,
      totalItems: 6,
      answeredCount: 0,
    });

    state = answerCurrent(state);
    const advanced = advancePlayer(state, view);
    state = advanced.ok ? advanced.state : state;
    expect(getPlayerProgress(state, view)).toEqual({
      currentPosition: 2,
      totalItems: 6,
      answeredCount: 1,
    });
  });

  it("preserves selections through Back and review navigation", () => {
    let state = answerCurrent(startPlayer(createInitialPlayerState(), view), 1);
    const advanced = advancePlayer(state, view);
    state = advanced.ok ? advanced.state : state;
    state = answerCurrent(state, 2);

    const back = movePlayerBack(state, view);
    expect(back.currentItemKey).toBe(view.items[0]!.key);
    expect(back.selections).toEqual(state.selections);

    const complete: AssessmentPlayerState = {
      phase: "complete",
      currentItemKey: null,
      selections: view.items.map((item) => ({
        itemKey: item.key,
        optionId: item.options[0]!.id,
      })),
    };
    expect(reviewPlayerAnswers(complete, view)).toEqual({
      phase: "question",
      currentItemKey: view.items[0]!.key,
      selections: complete.selections,
    });
  });

  it("resets to an empty intro state", () => {
    expect(resetPlayer()).toEqual(createInitialPlayerState());
  });

  it("rejects incomplete, duplicate, and unknown loaded state", () => {
    expect(
      validatePlayerState({ phase: "question", currentItemKey: null, selections: [] }, view),
    ).toBeNull();
    expect(
      validatePlayerState(
        {
          phase: "question",
          currentItemKey: view.items[1]!.key,
          selections: [],
        },
        view,
      ),
    ).toBeNull();
    expect(
      validatePlayerState(
        {
          phase: "intro",
          currentItemKey: null,
          selections: [
            { itemKey: view.items[0]!.key, optionId: view.items[0]!.options[0]!.id },
            { itemKey: view.items[0]!.key, optionId: view.items[0]!.options[1]!.id },
          ],
        },
        view,
      ),
    ).toBeNull();
    expect(
      validatePlayerState(
        {
          phase: "intro",
          currentItemKey: null,
          selections: [{ itemKey: "unknown-item", optionId: "unknown-option" }],
        },
        view,
      ),
    ).toBeNull();
  });
});
