import { mkdtemp, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, parse, resolve } from "node:path";
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
  validateDrainAclSnapshot,
  validateDrainState,
  windowsDrainAclRights,
  writeDrainStateAtomic,
} from "../../scripts/infra/drain-control.mjs";

const temporaryRoots: string[] = [];

async function statePath(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "risepals-drain-test-"));
  temporaryRoots.push(root);
  return join(root, "app-drain-state.json");
}

const approvedSids = Object.freeze({
  system: "S-1-5-18",
  administrators: "S-1-5-32-544",
  application: "S-1-5-80-3867566358-1883904136-105235150-316491909-788635434",
});

function aclRule(
  sid: string,
  rightsMask: number,
  { inherited, inheritanceFlagsMask }: { inherited: boolean; inheritanceFlagsMask: number },
) {
  return {
    sid,
    identityResolved: true,
    rightsMask,
    accessControlType: 0,
    isInherited: inherited,
    inheritanceFlagsMask,
    propagationFlagsMask: 0,
  };
}

function exactRules({ inherited }: { inherited: boolean }) {
  const inheritanceFlagsMask = inherited ? 0 : 3;
  return [
    aclRule(approvedSids.system, windowsDrainAclRights.fullControl, {
      inherited,
      inheritanceFlagsMask,
    }),
    aclRule(approvedSids.administrators, windowsDrainAclRights.fullControl, {
      inherited,
      inheritanceFlagsMask,
    }),
    aclRule(approvedSids.application, windowsDrainAclRights.modifySynchronize, {
      inherited,
      inheritanceFlagsMask,
    }),
  ];
}

function aclSnapshot(controlDirectory: string, childPath?: string) {
  const parentPath = resolve(controlDirectory);
  return {
    schemaVersion: "rise-pals-drain-acl-snapshot-v1",
    approvedSids: { ...approvedSids },
    parent: {
      path: parentPath,
      volumeRoot: parse(parentPath).root,
      areAccessRulesProtected: true,
      rules: exactRules({ inherited: false }),
    },
    child:
      childPath === undefined
        ? null
        : {
            path: resolve(childPath),
            volumeRoot: parse(resolve(childPath)).root,
            areAccessRulesProtected: false,
            rules: exactRules({ inherited: true }),
          },
  };
}

const inspectAcl = ({
  controlDirectory,
  childPath,
}: {
  controlDirectory: string;
  childPath?: string;
}) => aclSnapshot(controlDirectory, childPath);

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

    await expect(
      prepareDrainStateForStartup({ statePath: path, now, inspectAcl }),
    ).resolves.toMatchObject({
      previous: null,
      current: { state: "starting" },
    });
    await expect(markDrainReady({ statePath: path, now, inspectAcl })).resolves.toMatchObject({
      state: "ready",
    });

    clock.value += 1_000;
    const first = await requestDrain({ statePath: path, now, timeoutMs: 15_000, inspectAcl });
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
    const replay = await requestDrain({
      statePath: path,
      now,
      timeoutMs: 15_000,
      inspectAcl,
    });
    expect(replay).toEqual({ reused: true, state: first.state });

    clock.value += 1_000;
    await expect(markDrainStopped({ statePath: path, now, inspectAcl })).resolves.toMatchObject({
      state: "stopped",
      startedAtUtc: first.state.startedAtUtc,
      deadlineAtUtc: first.state.deadlineAtUtc,
      stoppedAtUtc: "2026-08-26T00:00:07.000Z",
    });
    await expect(requestDrain({ statePath: path, now, inspectAcl })).resolves.toMatchObject({
      reused: true,
      state: { state: "stopped" },
    });
  });

  it("converges concurrent drain requests without extending the first deadline", async () => {
    const path = await statePath();
    let time = Date.parse("2026-08-26T01:00:00.000Z");
    const now = () => time++;
    await prepareDrainStateForStartup({ statePath: path, now, inspectAcl });
    await markDrainReady({ statePath: path, now, inspectAcl });

    const results = await Promise.all([
      requestDrain({ statePath: path, now, inspectAcl }),
      requestDrain({ statePath: path, now, inspectAcl }),
      requestDrain({ statePath: path, now, inspectAcl }),
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
    writeDrainStateAtomic(
      path,
      {
        schemaVersion: drainStateSchemaVersion,
        state: "stopped",
        startedAtUtc: "2026-08-26T02:00:00.000Z",
        deadlineAtUtc: "2026-08-26T02:00:15.000Z",
        stoppedAtUtc: "2026-08-26T02:00:01.000Z",
      },
      { inspectAcl },
    );
    const prepared = await prepareDrainStateForStartup({
      statePath: path,
      now: () => Date.parse("2026-08-26T03:00:00.000Z"),
      inspectAcl,
    });
    expect(prepared.previous?.state).toBe("stopped");
    expect(readDrainState(path).state).toBe("starting");
  });

  it("records a controlled timeout without reporting graceful success", async () => {
    const path = await statePath();
    const clock = { value: Date.parse("2026-08-26T04:00:00.000Z") };
    const now = () => clock.value;
    await prepareDrainStateForStartup({ statePath: path, now, inspectAcl });
    await markDrainReady({ statePath: path, now, inspectAcl });
    await requestDrain({ statePath: path, now, inspectAcl });
    clock.value += 15_000;
    await expect(markDrainTimeout({ statePath: path, now, inspectAcl })).resolves.toMatchObject({
      state: "drain_timeout",
      failedAtUtc: "2026-08-26T04:00:15.000Z",
    });
    await expect(markDrainStopped({ statePath: path, now, inspectAcl })).rejects.toThrow(
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
    await expect(prepareDrainStateForStartup({ statePath: path, inspectAcl })).rejects.toThrow(
      "identity is invalid",
    );
  });
});

describe("canonical drain ACL and atomic file boundary", () => {
  it("accepts the protected parent and exact inherited child with Modify plus Synchronize", async () => {
    const path = await statePath();
    const controlDirectory = dirname(path);
    expect(validateDrainAclSnapshot(aclSnapshot(controlDirectory), { controlDirectory })).toBe(
      true,
    );
    expect(
      validateDrainAclSnapshot(aclSnapshot(controlDirectory, path), {
        controlDirectory,
        childPath: path,
      }),
    ).toBe(true);
  });

  it.each([
    ["bare Modify", windowsDrainAclRights.modify],
    ["FullControl", windowsDrainAclRights.fullControl],
    ["an additional permission bit", windowsDrainAclRights.modifySynchronize | 262_144],
  ])("rejects %s for the application identity", async (_description, rightsMask) => {
    const path = await statePath();
    const snapshot = aclSnapshot(dirname(path), path);
    const applicationRule = snapshot.child?.rules.find(
      (rule) => rule.sid === approvedSids.application,
    );
    if (!applicationRule) throw new Error("Expected the application ACL fixture.");
    applicationRule.rightsMask = rightsMask;
    expect(() =>
      validateDrainAclSnapshot(snapshot, {
        controlDirectory: dirname(path),
        childPath: path,
      }),
    ).toThrow("outside the exact approved bitmask");
  });

  it("rejects an unprotected parent", async () => {
    const path = await statePath();
    const snapshot = aclSnapshot(dirname(path), path);
    snapshot.parent.areAccessRulesProtected = false;
    expect(() =>
      validateDrainAclSnapshot(snapshot, {
        controlDirectory: dirname(path),
        childPath: path,
      }),
    ).toThrow("parent must be protected");
  });

  it("rejects an explicit child ACE", async () => {
    const path = await statePath();
    const snapshot = aclSnapshot(dirname(path), path);
    if (!snapshot.child) throw new Error("Expected the child ACL fixture.");
    const rule = snapshot.child.rules.at(0);
    if (!rule) throw new Error("Expected an inherited ACL rule.");
    rule.isInherited = false;
    expect(() =>
      validateDrainAclSnapshot(snapshot, {
        controlDirectory: dirname(path),
        childPath: path,
      }),
    ).toThrow("explicit/inherited ACE boundary");
  });

  it("rejects an unexpected principal", async () => {
    const path = await statePath();
    const snapshot = aclSnapshot(dirname(path), path);
    if (!snapshot.child) throw new Error("Expected the child ACL fixture.");
    snapshot.child.rules.push(
      aclRule("S-1-5-11", windowsDrainAclRights.modifySynchronize, {
        inherited: true,
        inheritanceFlagsMask: 0,
      }),
    );
    expect(() =>
      validateDrainAclSnapshot(snapshot, {
        controlDirectory: dirname(path),
        childPath: path,
      }),
    ).toThrow("exactly three approved ACEs");
  });

  it("rejects an unresolved SID", async () => {
    const path = await statePath();
    const snapshot = aclSnapshot(dirname(path), path);
    if (!snapshot.child) throw new Error("Expected the child ACL fixture.");
    const rule = snapshot.child.rules.at(0);
    if (!rule) throw new Error("Expected an inherited ACL rule.");
    rule.identityResolved = false;
    expect(() =>
      validateDrainAclSnapshot(snapshot, {
        controlDirectory: dirname(path),
        childPath: path,
      }),
    ).toThrow("identity is unresolved");
  });

  it("rejects a Deny ACE independently of its exact rights", async () => {
    const path = await statePath();
    const snapshot = aclSnapshot(dirname(path), path);
    if (!snapshot.child) throw new Error("Expected the child ACL fixture.");
    const rule = snapshot.child.rules.at(0);
    if (!rule) throw new Error("Expected an inherited ACL rule.");
    rule.accessControlType = 1;
    expect(() =>
      validateDrainAclSnapshot(snapshot, {
        controlDirectory: dirname(path),
        childPath: path,
      }),
    ).toThrow("Deny ACE");
  });

  it("rejects a temporary file outside the exact control directory", async () => {
    const path = await statePath();
    const outside = join(dirname(dirname(path)), "outside-drain-state.tmp");
    const snapshot = aclSnapshot(dirname(path), outside);
    expect(() =>
      validateDrainAclSnapshot(snapshot, {
        controlDirectory: dirname(path),
        childPath: outside,
      }),
    ).toThrow("outside the exact protected control directory");
  });

  it("creates and updates in the same directory with no temporary leak", async () => {
    const path = await statePath();
    const inspectedPaths: string[] = [];
    const recordingInspector = ({
      controlDirectory,
      childPath,
    }: {
      controlDirectory: string;
      childPath?: string;
    }) => {
      if (childPath) inspectedPaths.push(childPath);
      return aclSnapshot(controlDirectory, childPath);
    };
    const ready = {
      schemaVersion: drainStateSchemaVersion,
      state: "ready" as const,
      recordedAtUtc: "2026-08-26T06:00:00.000Z",
    };
    writeDrainStateAtomic(path, ready, { inspectAcl: recordingInspector });
    writeDrainStateAtomic(
      path,
      { ...ready, recordedAtUtc: "2026-08-26T06:00:01.000Z" },
      { inspectAcl: recordingInspector },
    );
    expect(inspectedPaths).toHaveLength(4);
    expect(inspectedPaths.every((candidate) => dirname(candidate) === dirname(path))).toBe(true);
    expect(new Set(inspectedPaths.filter((candidate) => candidate.endsWith(".tmp"))).size).toBe(2);
    expect(await readdir(dirname(path))).toEqual(["app-drain-state.json"]);
  });

  it("cleans only its exact temporary file after a failed rename", async () => {
    const path = await statePath();
    expect(() =>
      writeDrainStateAtomic(
        path,
        {
          schemaVersion: drainStateSchemaVersion,
          state: "ready",
          recordedAtUtc: "2026-08-26T07:00:00.000Z",
        },
        {
          inspectAcl,
          temporaryIdentity: "00000000-0000-4000-8000-000000000001",
          renameFile: () => {
            throw new Error("synthetic rename failure");
          },
        },
      ),
    ).toThrow("synthetic rename failure");
    expect(await readdir(dirname(path))).toEqual([]);
  });
});
