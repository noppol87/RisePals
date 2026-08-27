import {
  closeSync,
  fsyncSync,
  openSync,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { dirname, parse, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const drainStateSchemaVersion = "rise-pals-drain-state-v1";
export const approvedDrainStatePath = resolve(
  "C:\\RisePals\\shared\\control\\app-drain-state.json",
);
export const approvedDrainControlDirectory = dirname(approvedDrainStatePath);
export const approvedDrainTimeoutMs = 15_000;

export const windowsDrainAclRights = Object.freeze({
  fullControl: 2_032_127,
  modify: 197_055,
  modifySynchronize: 1_245_631,
});

const drainAclSnapshotSchemaVersion = "rise-pals-drain-acl-snapshot-v1";
const approvedDrainSids = Object.freeze({
  system: "S-1-5-18",
  administrators: "S-1-5-32-544",
  application: "S-1-5-80-3867566358-1883904136-105235150-316491909-788635434",
});
const allowAccessControlType = 0;
const parentInheritanceFlags = 3;
const noFlags = 0;

const lifecycleStates = new Set(["starting", "ready", "draining", "stopped", "drain_timeout"]);

function sameWindowsPath(left, right) {
  return resolve(left).toLowerCase() === resolve(right).toLowerCase();
}

function requireRecord(value, description) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${description} must be an object.`);
  }
  return value;
}

function requireExactRecordKeys(value, keys, description) {
  requireRecord(value, description);
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
    throw new Error(`${description} contains an unexpected field set.`);
  }
}

function assertApprovedSidMap(value) {
  requireExactRecordKeys(
    value,
    ["system", "administrators", "application"],
    "Drain ACL approved identity map",
  );
  for (const [key, expected] of Object.entries(approvedDrainSids)) {
    if (value[key] !== expected) {
      throw new Error("A drain ACL identity did not resolve to its approved canonical SID.");
    }
  }
}

function normalizedRule(rule, description) {
  requireExactRecordKeys(
    rule,
    [
      "sid",
      "identityResolved",
      "rightsMask",
      "accessControlType",
      "isInherited",
      "inheritanceFlagsMask",
      "propagationFlagsMask",
    ],
    description,
  );
  if (typeof rule.sid !== "string" || rule.identityResolved !== true) {
    throw new Error("A drain ACL identity is unresolved.");
  }
  for (const field of [
    "rightsMask",
    "accessControlType",
    "inheritanceFlagsMask",
    "propagationFlagsMask",
  ]) {
    if (!Number.isSafeInteger(rule[field])) {
      throw new Error("A drain ACL numeric field is invalid.");
    }
  }
  if (typeof rule.isInherited !== "boolean") {
    throw new Error("A drain ACL inheritance marker is invalid.");
  }
  return rule;
}

function assertExactRuleSet(rules, { inherited, inheritanceFlagsMask, description }) {
  if (!Array.isArray(rules) || rules.length !== 3) {
    throw new Error(`${description} must contain exactly three approved ACEs.`);
  }
  const expectedBySid = new Map([
    [approvedDrainSids.system, windowsDrainAclRights.fullControl],
    [approvedDrainSids.administrators, windowsDrainAclRights.fullControl],
    [approvedDrainSids.application, windowsDrainAclRights.modifySynchronize],
  ]);
  const observed = new Set();
  for (const candidate of rules) {
    const rule = normalizedRule(candidate, `${description} ACE`);
    if (observed.has(rule.sid) || !expectedBySid.has(rule.sid)) {
      throw new Error(`${description} contains an additional or duplicate principal.`);
    }
    observed.add(rule.sid);
    if (rule.accessControlType !== allowAccessControlType) {
      throw new Error(`${description} contains a Deny ACE.`);
    }
    if (rule.isInherited !== inherited) {
      throw new Error(`${description} has an invalid explicit/inherited ACE boundary.`);
    }
    if (
      rule.inheritanceFlagsMask !== inheritanceFlagsMask ||
      rule.propagationFlagsMask !== noFlags
    ) {
      throw new Error(`${description} has invalid inheritance or propagation flags.`);
    }
    if (rule.rightsMask !== expectedBySid.get(rule.sid)) {
      throw new Error(`${description} has rights outside the exact approved bitmask.`);
    }
  }
}

function assertSnapshotEntry(value, description) {
  requireExactRecordKeys(
    value,
    ["path", "volumeRoot", "areAccessRulesProtected", "rules"],
    description,
  );
  if (typeof value.path !== "string" || typeof value.volumeRoot !== "string") {
    throw new Error(`${description} path metadata is invalid.`);
  }
  if (typeof value.areAccessRulesProtected !== "boolean") {
    throw new Error(`${description} protection marker is invalid.`);
  }
  return value;
}

export function validateDrainAclSnapshot(
  snapshot,
  { controlDirectory, childPath = undefined } = {},
) {
  requireExactRecordKeys(
    snapshot,
    ["schemaVersion", "approvedSids", "parent", "child"],
    "Drain ACL snapshot",
  );
  if (snapshot.schemaVersion !== drainAclSnapshotSchemaVersion) {
    throw new Error("Drain ACL snapshot identity is invalid.");
  }
  if (typeof controlDirectory !== "string") {
    throw new Error("Drain ACL validation requires an exact control directory.");
  }
  assertApprovedSidMap(snapshot.approvedSids);

  const parent = assertSnapshotEntry(snapshot.parent, "Drain ACL parent");
  if (!sameWindowsPath(parent.path, controlDirectory)) {
    throw new Error("Drain ACL parent path does not match the exact control directory.");
  }
  if (parent.volumeRoot.toLowerCase() !== parse(resolve(parent.path)).root.toLowerCase()) {
    throw new Error("Drain ACL parent volume metadata is invalid.");
  }
  if (parent.areAccessRulesProtected !== true) {
    throw new Error("The drain ACL parent must be protected.");
  }
  assertExactRuleSet(parent.rules, {
    inherited: false,
    inheritanceFlagsMask: parentInheritanceFlags,
    description: "Drain ACL parent",
  });

  if (childPath === undefined) {
    if (snapshot.child !== null) {
      throw new Error("A parent-only drain ACL snapshot contains an unexpected child.");
    }
    return true;
  }

  const child = assertSnapshotEntry(snapshot.child, "Drain ACL child");
  if (!sameWindowsPath(child.path, childPath)) {
    throw new Error("Drain ACL child path does not match the inspected file.");
  }
  if (!sameWindowsPath(dirname(child.path), parent.path)) {
    throw new Error("Drain ACL child is outside the exact protected control directory.");
  }
  if (
    parse(resolve(child.path)).root.toLowerCase() !==
      parse(resolve(parent.path)).root.toLowerCase() ||
    child.volumeRoot.toLowerCase() !== parse(resolve(child.path)).root.toLowerCase() ||
    child.volumeRoot.toLowerCase() !== parent.volumeRoot.toLowerCase()
  ) {
    throw new Error("Drain ACL child is outside the parent volume.");
  }
  if (child.areAccessRulesProtected !== false) {
    throw new Error("The drain ACL child must use inheritance from the exact protected parent.");
  }
  assertExactRuleSet(child.rules, {
    inherited: true,
    inheritanceFlagsMask: noFlags,
    description: "Drain ACL child",
  });
  return true;
}

function inspectWindowsDrainAcl({ controlDirectory, childPath = undefined }) {
  const systemRoot = process.env.SystemRoot ?? "C:\\Windows";
  const executable = resolve(systemRoot, "System32/WindowsPowerShell/v1.0/powershell.exe");
  const helper = fileURLToPath(new URL("./Get-RisePalsDrainAclSnapshot.ps1", import.meta.url));
  const argumentsList = [
    "-NoLogo",
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    helper,
    "-ControlDirectory",
    controlDirectory,
  ];
  if (childPath !== undefined) argumentsList.push("-ChildPath", childPath);
  const inspected = spawnSync(executable, argumentsList, {
    encoding: "utf8",
    windowsHide: true,
    maxBuffer: 32 * 1024,
  });
  if (inspected.error || inspected.status !== 0 || (inspected.stderr ?? "").trim() !== "") {
    throw new Error("Windows drain ACL inspection failed closed.");
  }
  try {
    return JSON.parse(inspected.stdout.trim());
  } catch {
    throw new Error("Windows drain ACL inspection returned invalid structured evidence.");
  }
}

function resolveAclInspector(statePath, providedInspector) {
  if (sameWindowsPath(statePath, approvedDrainStatePath)) return inspectWindowsDrainAcl;
  if (typeof providedInspector !== "function") {
    throw new Error("A non-production drain state path requires an explicit ACL inspector.");
  }
  return providedInspector;
}

export function assertApprovedDrainControlAcl() {
  const snapshot = inspectWindowsDrainAcl({
    controlDirectory: approvedDrainControlDirectory,
  });
  return validateDrainAclSnapshot(snapshot, {
    controlDirectory: approvedDrainControlDirectory,
  });
}

export function assertApprovedDrainStateAcl() {
  const snapshot = inspectWindowsDrainAcl({
    controlDirectory: approvedDrainControlDirectory,
    childPath: approvedDrainStatePath,
  });
  return validateDrainAclSnapshot(snapshot, {
    controlDirectory: approvedDrainControlDirectory,
    childPath: approvedDrainStatePath,
  });
}

function isExactIsoInstant(value) {
  if (typeof value !== "string") return false;
  const parsed = new Date(value);
  return !Number.isNaN(parsed.valueOf()) && parsed.toISOString() === value;
}

function requireExactKeys(value, expected) {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (actual.length !== wanted.length || actual.some((key, index) => key !== wanted[index])) {
    throw new Error("Drain lifecycle state contains an unexpected field set.");
  }
}

export function validateDrainState(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Drain lifecycle state must be an object.");
  }
  if (value.schemaVersion !== drainStateSchemaVersion || !lifecycleStates.has(value.state)) {
    throw new Error("Drain lifecycle state identity is invalid.");
  }

  if (value.state === "starting" || value.state === "ready") {
    requireExactKeys(value, ["schemaVersion", "state", "recordedAtUtc"]);
    if (!isExactIsoInstant(value.recordedAtUtc)) {
      throw new Error("Drain lifecycle timestamp is invalid.");
    }
    return Object.freeze({ ...value });
  }

  const terminalField =
    value.state === "stopped"
      ? "stoppedAtUtc"
      : value.state === "drain_timeout"
        ? "failedAtUtc"
        : undefined;
  requireExactKeys(value, [
    "schemaVersion",
    "state",
    "startedAtUtc",
    "deadlineAtUtc",
    ...(terminalField ? [terminalField] : []),
  ]);
  if (!isExactIsoInstant(value.startedAtUtc) || !isExactIsoInstant(value.deadlineAtUtc)) {
    throw new Error("Drain lifecycle deadline metadata is invalid.");
  }
  const duration = Date.parse(value.deadlineAtUtc) - Date.parse(value.startedAtUtc);
  if (duration < 1 || duration > approvedDrainTimeoutMs) {
    throw new Error("Drain lifecycle deadline is outside the approved bound.");
  }
  if (terminalField && !isExactIsoInstant(value[terminalField])) {
    throw new Error("Drain lifecycle terminal timestamp is invalid.");
  }
  if (terminalField) {
    const terminal = Date.parse(value[terminalField]);
    const started = Date.parse(value.startedAtUtc);
    const deadline = Date.parse(value.deadlineAtUtc);
    if (
      terminal < started ||
      (value.state === "stopped" && terminal >= deadline) ||
      (value.state === "drain_timeout" && terminal < deadline)
    ) {
      throw new Error("Drain lifecycle terminal chronology is invalid.");
    }
  }
  return Object.freeze({ ...value });
}

export function readDrainState(statePath = approvedDrainStatePath) {
  const parsed = JSON.parse(readFileSync(statePath, "utf8"));
  return validateDrainState(parsed);
}

export function classifyDrainRequest(state, url) {
  const lifecycle = validateDrainState(state);
  if (lifecycle.state === "ready") return "admit";
  if (url === "/health/live") return "live";
  if (url === "/health/ready") {
    return lifecycle.state === "draining" ? "ready-draining" : "ready-unavailable";
  }
  return lifecycle.state === "draining" ? "reject-draining" : "reject-unavailable";
}

export function createActiveRequestRegistry() {
  let count = 0;
  return Object.freeze({
    admit() {
      count += 1;
      let completed = false;
      return () => {
        if (completed) return;
        completed = true;
        count -= 1;
      };
    },
    count() {
      return count;
    },
  });
}

export function writeDrainStateAtomic(statePath, value, options = {}) {
  const state = validateDrainState(value);
  const resolvedStatePath = resolve(statePath);
  const directory = dirname(resolvedStatePath);
  const inspectAcl = resolveAclInspector(resolvedStatePath, options.inspectAcl);
  const renameFile = options.renameFile ?? renameSync;
  const temporaryIdentity = (options.temporaryIdentity ?? randomUUID()).toLowerCase();
  if (
    !/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/.test(temporaryIdentity)
  ) {
    throw new Error("Drain lifecycle temporary identity is invalid.");
  }
  const temporaryPath = resolve(
    directory,
    `.app-drain-state.${process.pid}.${temporaryIdentity}.tmp`,
  );
  if (!sameWindowsPath(dirname(temporaryPath), directory)) {
    throw new Error("Drain lifecycle temporary file escaped the control directory.");
  }
  let descriptor;
  try {
    descriptor = openSync(temporaryPath, "wx", 0o600);
    try {
      writeFileSync(descriptor, `${JSON.stringify(state)}\n`, { encoding: "utf8" });
      fsyncSync(descriptor);
    } finally {
      closeSync(descriptor);
      descriptor = undefined;
    }
    validateDrainState(JSON.parse(readFileSync(temporaryPath, "utf8")));
    validateDrainAclSnapshot(
      inspectAcl({ controlDirectory: directory, childPath: temporaryPath }),
      {
        controlDirectory: directory,
        childPath: temporaryPath,
      },
    );
    renameFile(temporaryPath, resolvedStatePath);
    validateDrainAclSnapshot(
      inspectAcl({ controlDirectory: directory, childPath: resolvedStatePath }),
      { controlDirectory: directory, childPath: resolvedStatePath },
    );
  } finally {
    if (descriptor !== undefined) closeSync(descriptor);
    rmSync(temporaryPath, { force: true });
  }
  return state;
}

function atomicWriteOptions(options) {
  return options.inspectAcl === undefined ? undefined : { inspectAcl: options.inspectAcl };
}

function lockPathFor(statePath) {
  return `${statePath}.lock`;
}

function tryRemoveStaleLock(lockPath, nowMs) {
  try {
    const ageMs = nowMs - statSync(lockPath).mtimeMs;
    if (ageMs > approvedDrainTimeoutMs * 2) {
      rmSync(lockPath, { force: true });
    }
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
}

async function withDrainLock(statePath, operation, options = {}) {
  const now = options.now ?? Date.now;
  const sleep =
    options.sleep ??
    ((milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)));
  const lockPath = lockPathFor(statePath);
  const waitDeadline = now() + 1_000;
  let descriptor;

  while (descriptor === undefined) {
    try {
      descriptor = openSync(lockPath, "wx", 0o600);
    } catch (error) {
      if (error?.code !== "EEXIST") throw error;
      tryRemoveStaleLock(lockPath, now());
      if (now() >= waitDeadline) {
        throw new Error("Drain lifecycle lock acquisition timed out.");
      }
      await sleep(20);
    }
  }

  try {
    return await operation();
  } finally {
    closeSync(descriptor);
    rmSync(lockPath, { force: true });
  }
}

export async function prepareDrainStateForStartup({
  statePath = approvedDrainStatePath,
  now = Date.now,
  sleep,
  inspectAcl,
} = {}) {
  return withDrainLock(
    statePath,
    async () => {
      let previous = null;
      try {
        previous = readDrainState(statePath);
      } catch (error) {
        if (error?.code !== "ENOENT") throw error;
      }
      const starting = writeDrainStateAtomic(
        statePath,
        {
          schemaVersion: drainStateSchemaVersion,
          state: "starting",
          recordedAtUtc: new Date(now()).toISOString(),
        },
        atomicWriteOptions({ inspectAcl }),
      );
      return Object.freeze({ previous, current: starting });
    },
    { now, sleep },
  );
}

export async function markDrainReady({
  statePath = approvedDrainStatePath,
  now = Date.now,
  sleep,
  inspectAcl,
} = {}) {
  return withDrainLock(
    statePath,
    async () => {
      const current = readDrainState(statePath);
      if (current.state !== "starting") {
        throw new Error("Only a starting process may enter Ready.");
      }
      return writeDrainStateAtomic(
        statePath,
        {
          schemaVersion: drainStateSchemaVersion,
          state: "ready",
          recordedAtUtc: new Date(now()).toISOString(),
        },
        atomicWriteOptions({ inspectAcl }),
      );
    },
    { now, sleep },
  );
}

export async function requestDrain({
  statePath = approvedDrainStatePath,
  timeoutMs = approvedDrainTimeoutMs,
  now = Date.now,
  sleep,
  inspectAcl,
} = {}) {
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > approvedDrainTimeoutMs) {
    throw new Error("Requested drain timeout is outside the approved bound.");
  }
  return withDrainLock(
    statePath,
    async () => {
      const current = readDrainState(statePath);
      if (current.state === "draining" || current.state === "stopped") {
        return Object.freeze({ state: current, reused: true });
      }
      if (current.state !== "ready") {
        throw new Error("The application is not Ready for a drain transition.");
      }
      const startedAt = now();
      const draining = writeDrainStateAtomic(
        statePath,
        {
          schemaVersion: drainStateSchemaVersion,
          state: "draining",
          startedAtUtc: new Date(startedAt).toISOString(),
          deadlineAtUtc: new Date(startedAt + timeoutMs).toISOString(),
        },
        atomicWriteOptions({ inspectAcl }),
      );
      return Object.freeze({ state: draining, reused: false });
    },
    { now, sleep },
  );
}

export async function markDrainStopped({
  statePath = approvedDrainStatePath,
  now = Date.now,
  sleep,
  inspectAcl,
} = {}) {
  return withDrainLock(
    statePath,
    async () => {
      const current = readDrainState(statePath);
      if (current.state === "stopped") return current;
      if (current.state !== "draining") {
        throw new Error("Only a draining process may enter Stopped.");
      }
      const stoppedAt = now();
      if (stoppedAt >= Date.parse(current.deadlineAtUtc)) {
        throw new Error("A drain cannot report graceful success at or after its deadline.");
      }
      return writeDrainStateAtomic(
        statePath,
        {
          ...current,
          state: "stopped",
          stoppedAtUtc: new Date(stoppedAt).toISOString(),
        },
        atomicWriteOptions({ inspectAcl }),
      );
    },
    { now, sleep },
  );
}

export async function markDrainTimeout({
  statePath = approvedDrainStatePath,
  now = Date.now,
  sleep,
  inspectAcl,
} = {}) {
  return withDrainLock(
    statePath,
    async () => {
      const current = readDrainState(statePath);
      if (current.state === "drain_timeout") return current;
      if (current.state !== "draining") {
        throw new Error("Only a draining process may enter drain_timeout.");
      }
      const failedAt = now();
      if (failedAt < Date.parse(current.deadlineAtUtc)) {
        throw new Error("A drain timeout cannot be recorded before its deadline.");
      }
      return writeDrainStateAtomic(
        statePath,
        {
          ...current,
          state: "drain_timeout",
          failedAtUtc: new Date(failedAt).toISOString(),
        },
        atomicWriteOptions({ inspectAcl }),
      );
    },
    { now, sleep },
  );
}

const invokedPath = process.argv[1];
if (invokedPath && sameWindowsPath(invokedPath, fileURLToPath(import.meta.url))) {
  try {
    if (
      process.argv.length === 4 &&
      process.argv[2] === "--assert-parent" &&
      sameWindowsPath(process.argv[3], approvedDrainControlDirectory)
    ) {
      assertApprovedDrainControlAcl();
    } else if (
      process.argv.length === 4 &&
      process.argv[2] === "--assert-state" &&
      sameWindowsPath(process.argv[3], approvedDrainStatePath)
    ) {
      assertApprovedDrainStateAcl();
    } else {
      throw new Error("The drain ACL command is outside the approved boundary.");
    }
    process.stdout.write("Rise Pals canonical drain ACL validation PASS\n");
  } catch (error) {
    process.stderr.write(
      `Rise Pals canonical drain ACL validation failed type=${error?.name ?? "Error"}\n`,
    );
    process.exitCode = 1;
  }
}
