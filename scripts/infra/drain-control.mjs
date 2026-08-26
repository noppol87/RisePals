import {
  closeSync,
  openSync,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, resolve } from "node:path";

export const drainStateSchemaVersion = "rise-pals-drain-state-v1";
export const approvedDrainStatePath = resolve(
  "C:\\RisePals\\shared\\control\\app-drain-state.json",
);
export const approvedDrainTimeoutMs = 15_000;

const lifecycleStates = new Set(["starting", "ready", "draining", "stopped", "drain_timeout"]);
let temporarySequence = 0;

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

export function writeDrainStateAtomic(statePath, value) {
  const state = validateDrainState(value);
  const directory = dirname(statePath);
  temporarySequence += 1;
  const temporaryPath = resolve(
    directory,
    `.app-drain-state.${process.pid}.${temporarySequence}.tmp`,
  );
  try {
    writeFileSync(temporaryPath, `${JSON.stringify(state)}\n`, {
      encoding: "utf8",
      flag: "wx",
      mode: 0o600,
    });
    renameSync(temporaryPath, statePath);
  } finally {
    rmSync(temporaryPath, { force: true });
  }
  return state;
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
      const starting = writeDrainStateAtomic(statePath, {
        schemaVersion: drainStateSchemaVersion,
        state: "starting",
        recordedAtUtc: new Date(now()).toISOString(),
      });
      return Object.freeze({ previous, current: starting });
    },
    { now, sleep },
  );
}

export async function markDrainReady({
  statePath = approvedDrainStatePath,
  now = Date.now,
  sleep,
} = {}) {
  return withDrainLock(
    statePath,
    async () => {
      const current = readDrainState(statePath);
      if (current.state !== "starting") {
        throw new Error("Only a starting process may enter Ready.");
      }
      return writeDrainStateAtomic(statePath, {
        schemaVersion: drainStateSchemaVersion,
        state: "ready",
        recordedAtUtc: new Date(now()).toISOString(),
      });
    },
    { now, sleep },
  );
}

export async function requestDrain({
  statePath = approvedDrainStatePath,
  timeoutMs = approvedDrainTimeoutMs,
  now = Date.now,
  sleep,
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
      const draining = writeDrainStateAtomic(statePath, {
        schemaVersion: drainStateSchemaVersion,
        state: "draining",
        startedAtUtc: new Date(startedAt).toISOString(),
        deadlineAtUtc: new Date(startedAt + timeoutMs).toISOString(),
      });
      return Object.freeze({ state: draining, reused: false });
    },
    { now, sleep },
  );
}

export async function markDrainStopped({
  statePath = approvedDrainStatePath,
  now = Date.now,
  sleep,
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
      return writeDrainStateAtomic(statePath, {
        ...current,
        state: "stopped",
        stoppedAtUtc: new Date(stoppedAt).toISOString(),
      });
    },
    { now, sleep },
  );
}

export async function markDrainTimeout({
  statePath = approvedDrainStatePath,
  now = Date.now,
  sleep,
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
      return writeDrainStateAtomic(statePath, {
        ...current,
        state: "drain_timeout",
        failedAtUtc: new Date(failedAt).toISOString(),
      });
    },
    { now, sleep },
  );
}
