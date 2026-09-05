export const drainStateSchemaVersion: "rise-pals-drain-state-v1";
export const approvedDrainStatePath: string;
export const approvedDrainControlDirectory: string;
export const approvedDrainTimeoutMs: 15000;
export const windowsDrainAclRights: Readonly<{
  fullControl: 2032127;
  modify: 197055;
  modifySynchronize: 1245631;
}>;

export type DrainState =
  | Readonly<{
      schemaVersion: "rise-pals-drain-state-v1";
      state: "starting" | "ready";
      recordedAtUtc: string;
    }>
  | Readonly<{
      schemaVersion: "rise-pals-drain-state-v1";
      state: "draining";
      startedAtUtc: string;
      deadlineAtUtc: string;
    }>
  | Readonly<{
      schemaVersion: "rise-pals-drain-state-v1";
      state: "stopped";
      startedAtUtc: string;
      deadlineAtUtc: string;
      stoppedAtUtc: string;
    }>
  | Readonly<{
      schemaVersion: "rise-pals-drain-state-v1";
      state: "drain_timeout";
      startedAtUtc: string;
      deadlineAtUtc: string;
      failedAtUtc: string;
    }>;

export type DrainOptions = Readonly<{
  statePath?: string;
  now?: () => number;
  sleep?: (milliseconds: number) => Promise<void>;
  inspectAcl?: (input: Readonly<{ controlDirectory: string; childPath?: string }>) => unknown;
}>;

export type DrainAtomicWriteOptions = Readonly<{
  inspectAcl?: (input: Readonly<{ controlDirectory: string; childPath?: string }>) => unknown;
  renameFile?: (oldPath: string, newPath: string) => void;
  temporaryIdentity?: string;
}>;

export function validateDrainState(value: unknown): DrainState;
export function readDrainState(statePath?: string): DrainState;
export function classifyDrainRequest(
  state: DrainState,
  url: string,
):
  | "admit"
  | "live"
  | "ready-draining"
  | "ready-unavailable"
  | "reject-draining"
  | "reject-unavailable";
export function createActiveRequestRegistry(): Readonly<{
  admit(): () => void;
  count(): number;
}>;
export function validateDrainAclSnapshot(
  snapshot: unknown,
  options: Readonly<{ controlDirectory: string; childPath?: string }>,
): true;
export function assertApprovedDrainControlAcl(): true;
export function assertApprovedDrainStateAcl(): true;
export function writeDrainStateAtomic(
  statePath: string,
  value: unknown,
  options?: DrainAtomicWriteOptions,
): DrainState;
export function prepareDrainStateForStartup(
  options?: DrainOptions,
): Promise<Readonly<{ previous: DrainState | null; current: DrainState }>>;
export function markDrainReady(options?: DrainOptions): Promise<DrainState>;
export function requestDrain(
  options?: DrainOptions & Readonly<{ timeoutMs?: number }>,
): Promise<Readonly<{ state: DrainState; reused: boolean }>>;
export function markDrainStopped(options?: DrainOptions): Promise<DrainState>;
export function markDrainTimeout(options?: DrainOptions): Promise<DrainState>;
