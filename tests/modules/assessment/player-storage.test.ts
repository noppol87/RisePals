import { describe, expect, it } from "vitest";
import {
  createInitialPlayerState,
  selectPlayerOption,
  startPlayer,
} from "@/modules/assessment/player/state";
import {
  ASSESSMENT_PLAYER_STORAGE_KEY,
  ASSESSMENT_PLAYER_STORAGE_SCHEMA_VERSION,
  clearPlayerState,
  deserializePlayerState,
  loadPlayerState,
  persistPlayerState,
  serializePlayerState,
  type SessionStorageLike,
} from "@/modules/assessment/player/storage";
import { createAssessmentPlayerView } from "@/modules/assessment/player/view";

const view = createAssessmentPlayerView("en");

class MemoryStorage implements SessionStorageLike {
  readonly values = new Map<string, string>();

  getItem(key: string): string | null {
    return this.values.get(key) ?? null;
  }

  setItem(key: string, value: string): void {
    this.values.set(key, value);
  }

  removeItem(key: string): void {
    this.values.delete(key);
  }
}

function selectedState() {
  const started = startPlayer(createInitialPlayerState(), view);
  return selectPlayerOption(started, view, view.items[0]!.options[1]!.id);
}

function storedPayload(overrides: Readonly<Record<string, unknown>> = {}) {
  return {
    schemaVersion: ASSESSMENT_PLAYER_STORAGE_SCHEMA_VERSION,
    assessmentVersionId: view.assessmentVersionId,
    phase: "question",
    currentItemKey: view.items[0]!.key,
    selections: [{ itemKey: view.items[0]!.key, optionId: view.items[0]!.options[1]!.id }],
    ...overrides,
  };
}

describe("assessment player session storage contract", () => {
  it("round-trips the versioned minimum allowlisted state", () => {
    const state = selectedState();
    const serialized = serializePlayerState(state, view);

    expect(deserializePlayerState(serialized, view)).toEqual(state);
    expect(Object.keys(JSON.parse(serialized)).sort()).toEqual([
      "assessmentVersionId",
      "currentItemKey",
      "phase",
      "schemaVersion",
      "selections",
    ]);
    expect(Object.keys(JSON.parse(serialized).selections[0]).sort()).toEqual([
      "itemKey",
      "optionId",
    ]);
    expect(serialized).not.toMatch(
      /prompt|label|rubric|score|result|timestamp|profile|email|employer|freeText/i,
    );
  });

  it("persists, loads, and explicitly clears temporary state", () => {
    const storage = new MemoryStorage();
    const state = selectedState();

    expect(persistPlayerState(storage, state, view)).toBe(true);
    expect(loadPlayerState(storage, view)).toEqual({ state, status: "loaded" });
    expect(clearPlayerState(storage)).toBe(true);
    expect(storage.getItem(ASSESSMENT_PLAYER_STORAGE_KEY)).toBeNull();
  });

  it.each([
    ["storage schema mismatch", { schemaVersion: 99 }],
    ["assessment version mismatch", { assessmentVersionId: "different-assessment" }],
    ["unknown current item", { currentItemKey: "unknown-item" }],
    [
      "unknown option",
      { selections: [{ itemKey: view.items[0]!.key, optionId: "unknown-option" }] },
    ],
    [
      "duplicate item",
      {
        selections: [
          { itemKey: view.items[0]!.key, optionId: view.items[0]!.options[0]!.id },
          { itemKey: view.items[0]!.key, optionId: view.items[0]!.options[1]!.id },
        ],
      },
    ],
    ["incomplete completion", { phase: "complete", currentItemKey: null }],
    ["prohibited extra field", { score: 100 }],
  ])("rejects and clears %s", (_name, overrides) => {
    const storage = new MemoryStorage();
    storage.setItem(ASSESSMENT_PLAYER_STORAGE_KEY, JSON.stringify(storedPayload(overrides)));

    expect(loadPlayerState(storage, view)).toEqual({
      state: createInitialPlayerState(),
      status: "discarded",
    });
    expect(storage.getItem(ASSESSMENT_PLAYER_STORAGE_KEY)).toBeNull();
  });

  it("rejects malformed JSON", () => {
    const storage = new MemoryStorage();
    storage.setItem(ASSESSMENT_PLAYER_STORAGE_KEY, "{not-json");

    expect(loadPlayerState(storage, view).status).toBe("discarded");
    expect(storage.getItem(ASSESSMENT_PLAYER_STORAGE_KEY)).toBeNull();
  });

  it("handles unavailable and throwing storage without crashing", () => {
    const throwingStorage: SessionStorageLike = {
      getItem() {
        throw new Error("blocked");
      },
      setItem() {
        throw new Error("blocked");
      },
      removeItem() {
        throw new Error("blocked");
      },
    };

    expect(loadPlayerState(null, view).status).toBe("unavailable");
    expect(loadPlayerState(throwingStorage, view).status).toBe("unavailable");
    expect(persistPlayerState(throwingStorage, selectedState(), view)).toBe(false);
    expect(clearPlayerState(throwingStorage)).toBe(false);
  });
});
