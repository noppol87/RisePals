import type { AssessmentPlayerView } from "@/modules/assessment/player/view";

export type AssessmentPlayerPhase = "intro" | "question" | "complete";

export type AssessmentPlayerSelection = Readonly<{
  itemKey: string;
  optionId: string;
}>;

export type AssessmentPlayerState = Readonly<{
  phase: AssessmentPlayerPhase;
  currentItemKey: string | null;
  selections: readonly AssessmentPlayerSelection[];
}>;

export type AssessmentPlayerProgress = Readonly<{
  currentPosition: number | null;
  totalItems: number;
  answeredCount: number;
}>;

export type AdvancePlayerResult =
  | Readonly<{ ok: true; state: AssessmentPlayerState }>
  | Readonly<{ ok: false; reason: "answer-required" | "assessment-incomplete" }>;

const stateKeys = ["currentItemKey", "phase", "selections"] as const;
const selectionKeys = ["itemKey", "optionId"] as const;

export function createInitialPlayerState(): AssessmentPlayerState {
  return {
    phase: "intro",
    currentItemKey: null,
    selections: [],
  };
}

export function startPlayer(
  state: AssessmentPlayerState,
  view: AssessmentPlayerView,
): AssessmentPlayerState {
  const firstItem = view.items[0];
  if (!firstItem) {
    throw new Error("assessment player requires at least one item.");
  }

  return {
    phase: "question",
    currentItemKey: firstItem.key,
    selections: state.selections,
  };
}

export function selectPlayerOption(
  state: AssessmentPlayerState,
  view: AssessmentPlayerView,
  optionId: string,
): AssessmentPlayerState {
  if (state.phase !== "question" || state.currentItemKey === null) {
    throw new Error("an option can be selected only on a question step.");
  }

  const item = view.items.find((candidate) => candidate.key === state.currentItemKey);
  if (!item || !item.options.some((option) => option.id === optionId)) {
    throw new Error("selected option is unknown for the current assessment item.");
  }

  const replacement = { itemKey: item.key, optionId };
  const selections = view.items.flatMap((candidate) => {
    if (candidate.key === item.key) {
      return [replacement];
    }

    const existing = state.selections.find((selection) => selection.itemKey === candidate.key);
    return existing ? [existing] : [];
  });

  return { ...state, selections };
}

export function advancePlayer(
  state: AssessmentPlayerState,
  view: AssessmentPlayerView,
): AdvancePlayerResult {
  if (state.phase !== "question" || state.currentItemKey === null) {
    return { ok: false, reason: "answer-required" };
  }

  const currentIndex = view.items.findIndex((item) => item.key === state.currentItemKey);
  if (currentIndex < 0) {
    return { ok: false, reason: "answer-required" };
  }

  const hasCurrentAnswer = state.selections.some(
    (selection) => selection.itemKey === state.currentItemKey,
  );
  if (!hasCurrentAnswer) {
    return { ok: false, reason: "answer-required" };
  }

  const nextItem = view.items[currentIndex + 1];
  if (nextItem) {
    return {
      ok: true,
      state: {
        phase: "question",
        currentItemKey: nextItem.key,
        selections: state.selections,
      },
    };
  }

  if (state.selections.length !== view.items.length) {
    return { ok: false, reason: "assessment-incomplete" };
  }

  return {
    ok: true,
    state: {
      phase: "complete",
      currentItemKey: null,
      selections: state.selections,
    },
  };
}

export function movePlayerBack(
  state: AssessmentPlayerState,
  view: AssessmentPlayerView,
): AssessmentPlayerState {
  if (state.phase !== "question" || state.currentItemKey === null) {
    return state;
  }

  const currentIndex = view.items.findIndex((item) => item.key === state.currentItemKey);
  if (currentIndex <= 0) {
    return {
      phase: "intro",
      currentItemKey: null,
      selections: state.selections,
    };
  }

  return {
    phase: "question",
    currentItemKey: view.items[currentIndex - 1]!.key,
    selections: state.selections,
  };
}

export function reviewPlayerAnswers(
  state: AssessmentPlayerState,
  view: AssessmentPlayerView,
): AssessmentPlayerState {
  return startPlayer(state, view);
}

export function resetPlayer(): AssessmentPlayerState {
  return createInitialPlayerState();
}

export function getPlayerProgress(
  state: AssessmentPlayerState,
  view: AssessmentPlayerView,
): AssessmentPlayerProgress {
  const currentIndex =
    state.phase === "question" && state.currentItemKey !== null
      ? view.items.findIndex((item) => item.key === state.currentItemKey)
      : -1;

  return {
    currentPosition: currentIndex >= 0 ? currentIndex + 1 : null,
    totalItems: view.items.length,
    answeredCount: state.selections.length,
  };
}

export function validatePlayerState(
  value: unknown,
  view: AssessmentPlayerView,
): AssessmentPlayerState | null {
  if (!isExactRecord(value, stateKeys)) {
    return null;
  }

  const { phase, currentItemKey, selections } = value;
  if (phase !== "intro" && phase !== "question" && phase !== "complete") {
    return null;
  }
  if (currentItemKey !== null && typeof currentItemKey !== "string") {
    return null;
  }
  if (!Array.isArray(selections) || selections.length > view.items.length) {
    return null;
  }

  const itemsByKey = new Map(view.items.map((item) => [item.key, item]));
  const seenItemKeys = new Set<string>();
  const normalizedSelections: AssessmentPlayerSelection[] = [];

  for (const selection of selections) {
    if (!isExactRecord(selection, selectionKeys)) {
      return null;
    }
    if (typeof selection.itemKey !== "string" || typeof selection.optionId !== "string") {
      return null;
    }
    if (seenItemKeys.has(selection.itemKey)) {
      return null;
    }

    const item = itemsByKey.get(selection.itemKey);
    if (!item || !item.options.some((option) => option.id === selection.optionId)) {
      return null;
    }

    seenItemKeys.add(selection.itemKey);
    normalizedSelections.push({ itemKey: selection.itemKey, optionId: selection.optionId });
  }

  normalizedSelections.sort(
    (left, right) =>
      view.items.findIndex((item) => item.key === left.itemKey) -
      view.items.findIndex((item) => item.key === right.itemKey),
  );

  if (phase === "intro" && currentItemKey !== null) {
    return null;
  }

  if (phase === "question") {
    if (currentItemKey === null || !itemsByKey.has(currentItemKey)) {
      return null;
    }

    const currentIndex = view.items.findIndex((item) => item.key === currentItemKey);
    const priorItemsAnswered = view.items
      .slice(0, currentIndex)
      .every((item) => seenItemKeys.has(item.key));
    if (!priorItemsAnswered) {
      return null;
    }
  }

  if (
    phase === "complete" &&
    (currentItemKey !== null || normalizedSelections.length !== view.items.length)
  ) {
    return null;
  }

  return {
    phase,
    currentItemKey,
    selections: normalizedSelections,
  };
}

function isExactRecord<const Keys extends readonly string[]>(
  value: unknown,
  keys: Keys,
): value is Record<Keys[number], unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false;
  }

  const actualKeys = Object.keys(value).sort();
  const expectedKeys = [...keys].sort();
  return (
    actualKeys.length === expectedKeys.length &&
    actualKeys.every((key, index) => key === expectedKeys[index])
  );
}
