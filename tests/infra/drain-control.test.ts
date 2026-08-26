import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  classifyDrainRequest,
  createActiveRequestRegistry,
  drainStateSchemaVersion,
  markDrainReady,
  markDrainStopped,
  markDrainTimeout,
  prepareDrainStateForStartup,
  readDrainState,
  requestDrain,
  validateDrainState,
  writeDrainStateAtomic,
} from "../../scripts/infra/drain-control.mjs";

const temporaryRoots: string[] = [];

async function statePath(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "risepals-drain-test-"));
  temporaryRoots.push(root);
  return join(root, "app-drain-state.json");
}

afterEach(async () => {
  await Promise.all(
    temporaryRoots.splice(0).map((root) => rm(root, { force: true, recursive: true })),
  );
});

describe("local drain lifecycle", () => {
  it("moves atomically from startup to ready, draining and stopped", async () => {
    const path = await statePath();
    const clock = { value: Date.parse("2026-08-26T00:00:00.000Z") };
    const now = () => clock.value;

    await expect(prepareDrainStateForStartup({ statePath: path, now })).resolves.toMatchObject({
      previous: null,
      current: { state: "starting" },
    });
    await expect(markDrainReady({ statePath: path, now })).resolves.toMatchObject({
      state: "ready",
    });

    clock.value += 1_000;
    const first = await requestDrain({ statePath: path, now, timeoutMs: 15_000 });
    if (first.state.state !== "draining") throw new Error("Expected the initial drain transition.");
    expect(first).toEqual({
      reused: false,
      state: {
        schemaVersion: drainStateSchemaVersion,
        state: "draining",
        startedAtUtc: "2026-08-26T00:00:01.000Z",
        deadlineAtUtc: "2026-08-26T00:00:16.000Z",
      },
    });

    clock.value += 5_000;
    const replay = await requestDrain({ statePath: path, now, timeoutMs: 15_000 });
    expect(replay).toEqual({ reused: true, state: first.state });

    clock.value += 1_000;
    await expect(markDrainStopped({ statePath: path, now })).resolves.toMatchObject({
      state: "stopped",
      startedAtUtc: first.state.startedAtUtc,
      deadlineAtUtc: first.state.deadlineAtUtc,
      stoppedAtUtc: "2026-08-26T00:00:07.000Z",
    });
    await expect(requestDrain({ statePath: path, now })).resolves.toMatchObject({
      reused: true,
      state: { state: "stopped" },
    });
  });

  it("converges concurrent drain requests without extending the first deadline", async () => {
    const path = await statePath();
    let time = Date.parse("2026-08-26T01:00:00.000Z");
    const now = () => time++;
    await prepareDrainStateForStartup({ statePath: path, now });
    await markDrainReady({ statePath: path, now });

    const results = await Promise.all([
      requestDrain({ statePath: path, now }),
      requestDrain({ statePath: path, now }),
      requestDrain({ statePath: path, now }),
    ]);
    if (results.some(({ state }) => state.state !== "draining")) {
      throw new Error("Concurrent drain requests must converge on Draining.");
    }
    expect(results.filter(({ reused }) => !reused)).toHaveLength(1);
    expect(
      new Set(results.map(({ state }) => (state.state === "draining" ? state.startedAtUtc : ""))),
    ).toHaveLength(1);
    expect(
      new Set(results.map(({ state }) => (state.state === "draining" ? state.deadlineAtUtc : ""))),
    ).toHaveLength(1);
  });

  it("reconciles a valid stale stopped state before advertising ready", async () => {
    const path = await statePath();
    writeDrainStateAtomic(path, {
      schemaVersion: drainStateSchemaVersion,
      state: "stopped",
      startedAtUtc: "2026-08-26T02:00:00.000Z",
      deadlineAtUtc: "2026-08-26T02:00:15.000Z",
      stoppedAtUtc: "2026-08-26T02:00:01.000Z",
    });
    const prepared = await prepareDrainStateForStartup({
      statePath: path,
      now: () => Date.parse("2026-08-26T03:00:00.000Z"),
    });
    expect(prepared.previous?.state).toBe("stopped");
    expect(readDrainState(path).state).toBe("starting");
  });

  it("records a controlled timeout without reporting graceful success", async () => {
    const path = await statePath();
    const clock = { value: Date.parse("2026-08-26T04:00:00.000Z") };
    const now = () => clock.value;
    await prepareDrainStateForStartup({ statePath: path, now });
    await markDrainReady({ statePath: path, now });
    await requestDrain({ statePath: path, now });
    clock.value += 15_000;
    await expect(markDrainTimeout({ statePath: path, now })).resolves.toMatchObject({
      state: "drain_timeout",
      failedAtUtc: "2026-08-26T04:00:15.000Z",
    });
    await expect(markDrainStopped({ statePath: path, now })).rejects.toThrow(
      "Only a draining process may enter Stopped.",
    );
  });

  it("rejects new work during drain while an already admitted request remains active", () => {
    const ready = validateDrainState({
      schemaVersion: drainStateSchemaVersion,
      state: "ready",
      recordedAtUtc: "2026-08-26T05:00:00.000Z",
    });
    const draining = validateDrainState({
      schemaVersion: drainStateSchemaVersion,
      state: "draining",
      startedAtUtc: "2026-08-26T05:00:01.000Z",
      deadlineAtUtc: "2026-08-26T05:00:16.000Z",
    });
    const requests = createActiveRequestRegistry();
    expect(classifyDrainRequest(ready, "/th/assessment/attempt")).toBe("admit");
    const completeAcceptedRequest = requests.admit();
    expect(requests.count()).toBe(1);
    expect(classifyDrainRequest(draining, "/th/assessment/attempt")).toBe("reject-draining");
    expect(classifyDrainRequest(draining, "/health/ready")).toBe("ready-draining");
    expect(classifyDrainRequest(draining, "/health/live")).toBe("live");
    expect(requests.count()).toBe(1);
    completeAcceptedRequest();
    completeAcceptedRequest();
    expect(requests.count()).toBe(0);
  });

  it("fails closed for malformed, overlong or unknown lifecycle state", async () => {
    const path = await statePath();
    expect(() =>
      validateDrainState({
        schemaVersion: drainStateSchemaVersion,
        state: "draining",
        startedAtUtc: "2026-08-26T00:00:00.000Z",
        deadlineAtUtc: "2026-08-26T00:00:15.001Z",
      }),
    ).toThrow("outside the approved bound");
    expect(() =>
      validateDrainState({
        schemaVersion: drainStateSchemaVersion,
        state: "ready",
        recordedAtUtc: "2026-08-26T00:00:00.000Z",
        extra: true,
      }),
    ).toThrow("unexpected field set");
    await writeFile(path, '{"schemaVersion":"rise-pals-drain-state-v1","state":"unknown"}\n');
    await expect(prepareDrainStateForStartup({ statePath: path })).rejects.toThrow(
      "identity is invalid",
    );
  });
});
