import {
  createInitialPlayerState,
  validatePlayerState,
  type AssessmentPlayerState,
} from "@/modules/assessment/player/state";
import type { AssessmentPlayerView } from "@/modules/assessment/player/view";

export const ASSESSMENT_PLAYER_STORAGE_KEY = "rise-pals:assessment-player:v1";
export const ASSESSMENT_PLAYER_STORAGE_SCHEMA_VERSION = 1;

export type SessionStorageLike = Pick<Storage, "getItem" | "setItem" | "removeItem">;

export type LoadPlayerStateResult = Readonly<{
  state: AssessmentPlayerState;
  status: "empty" | "loaded" | "discarded" | "unavailable";
}>;

const storedStateKeys = [
  "assessmentVersionId",
  "currentItemKey",
  "phase",
  "schemaVersion",
  "selections",
] as const;

export function serializePlayerState(
  state: AssessmentPlayerState,
  view: AssessmentPlayerView,
): string {
  return JSON.stringify({
    schemaVersion: ASSESSMENT_PLAYER_STORAGE_SCHEMA_VERSION,
    assessmentVersionId: view.assessmentVersionId,
    phase: state.phase,
    currentItemKey: state.currentItemKey,
    selections: state.selections.map((selection) => ({
      itemKey: selection.itemKey,
      optionId: selection.optionId,
    })),
  });
}

export function deserializePlayerState(
  serialized: string,
  view: AssessmentPlayerView,
): AssessmentPlayerState | null {
  let value: unknown;
  try {
    value = JSON.parse(serialized);
  } catch {
    return null;
  }

  if (!isExactStoredState(value)) {
    return null;
  }
  if (
    value.schemaVersion !== ASSESSMENT_PLAYER_STORAGE_SCHEMA_VERSION ||
    value.assessmentVersionId !== view.assessmentVersionId
  ) {
    return null;
  }

  return validatePlayerState(
    {
      phase: value.phase,
      currentItemKey: value.currentItemKey,
      selections: value.selections,
    },
    view,
  );
}

export function loadPlayerState(
  storage: SessionStorageLike | null,
  view: AssessmentPlayerView,
): LoadPlayerStateResult {
  if (storage === null) {
    return { state: createInitialPlayerState(), status: "unavailable" };
  }

  let serialized: string | null;
  try {
    serialized = storage.getItem(ASSESSMENT_PLAYER_STORAGE_KEY);
  } catch {
    return { state: createInitialPlayerState(), status: "unavailable" };
  }

  if (serialized === null) {
    return { state: createInitialPlayerState(), status: "empty" };
  }

  const state = deserializePlayerState(serialized, view);
  if (state !== null) {
    return { state, status: "loaded" };
  }

  try {
    storage.removeItem(ASSESSMENT_PLAYER_STORAGE_KEY);
  } catch {
    return { state: createInitialPlayerState(), status: "unavailable" };
  }
  return { state: createInitialPlayerState(), status: "discarded" };
}

export function persistPlayerState(
  storage: SessionStorageLike | null,
  state: AssessmentPlayerState,
  view: AssessmentPlayerView,
): boolean {
  if (storage === null) {
    return false;
  }

  try {
    if (state.phase === "intro" && state.selections.length === 0) {
      storage.removeItem(ASSESSMENT_PLAYER_STORAGE_KEY);
    } else {
      storage.setItem(ASSESSMENT_PLAYER_STORAGE_KEY, serializePlayerState(state, view));
    }
    return true;
  } catch {
    return false;
  }
}

export function clearPlayerState(storage: SessionStorageLike | null): boolean {
  if (storage === null) {
    return false;
  }

  try {
    storage.removeItem(ASSESSMENT_PLAYER_STORAGE_KEY);
    return true;
  } catch {
    return false;
  }
}

function isExactStoredState(
  value: unknown,
): value is Record<(typeof storedStateKeys)[number], unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false;
  }

  const actualKeys = Object.keys(value).sort();
  const expectedKeys = [...storedStateKeys].sort();
  return (
    actualKeys.length === expectedKeys.length &&
    actualKeys.every((key, index) => key === expectedKeys[index])
  );
}
