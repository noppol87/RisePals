export const liveHealthPayload = Object.freeze({ status: "ok" as const });

export const rehearsalStreamChunks = Object.freeze(["probe-start\n", "probe-mid\n", "probe-end\n"]);
export const drainStateSchemaVersion = "rise-pals-drain-state-v1";

const loopbackHosts = new Set(["127.0.0.1", "::1", "localhost"]);
const loopbackForwardedAddresses = new Set(["127.0.0.1", "::1", "::ffff:127.0.0.1"]);

export function hasLoopbackRequestHost(request: Request): boolean {
  const hostHeader = request.headers.get("host")?.trim() || new URL(request.url).host;
  const host = hostHeader.startsWith("[")
    ? hostHeader.slice(1, hostHeader.indexOf("]"))
    : (hostHeader.split(":", 1)[0] ?? "");

  return loopbackHosts.has(host.toLowerCase());
}

export function isLoopbackRequest(request: Request): boolean {
  if (!hasLoopbackRequestHost(request)) {
    return false;
  }
  const forwardedFor = request.headers.get("x-forwarded-for");
  if (forwardedFor === null) {
    return true;
  }
  return loopbackForwardedAddresses.has(forwardedFor.trim().toLowerCase());
}

export function isInfrastructureRehearsalEnabled(
  environment: Readonly<Record<string, string | undefined>>,
): boolean {
  return environment.RISE_PALS_INFRA_REHEARSAL === "1";
}

export function hasSafeRehearsalForwardedHeaders(request: Request): boolean {
  const forwardedFor = request.headers.get("x-forwarded-for");
  if (forwardedFor === null) {
    return true;
  }
  const forwardedHost = request.headers.get("x-forwarded-host");
  return (
    forwardedFor === "127.0.0.1" &&
    (forwardedHost === "127.0.0.1" || forwardedHost === "127.0.0.1:8443") &&
    request.headers.get("x-forwarded-proto") === "https"
  );
}

export type InfrastructureDrainState = "ready" | "draining" | "unavailable";

function hasExactKeys(value: Record<string, unknown>, expected: readonly string[]): boolean {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  return actual.length === wanted.length && actual.every((key, index) => key === wanted[index]);
}

function isExactIsoInstant(value: unknown): value is string {
  if (typeof value !== "string") return false;
  const parsed = new Date(value);
  return !Number.isNaN(parsed.valueOf()) && parsed.toISOString() === value;
}

export function parseInfrastructureDrainState(value: string): InfrastructureDrainState {
  try {
    const parsed: unknown = JSON.parse(value);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return "unavailable";
    const state = parsed as Record<string, unknown>;
    if (state.schemaVersion !== drainStateSchemaVersion) return "unavailable";
    if (
      state.state === "ready" &&
      hasExactKeys(state, ["schemaVersion", "state", "recordedAtUtc"]) &&
      isExactIsoInstant(state.recordedAtUtc)
    ) {
      return "ready";
    }
    if (
      state.state === "draining" &&
      hasExactKeys(state, ["schemaVersion", "state", "startedAtUtc", "deadlineAtUtc"]) &&
      isExactIsoInstant(state.startedAtUtc) &&
      isExactIsoInstant(state.deadlineAtUtc)
    ) {
      const duration = Date.parse(state.deadlineAtUtc) - Date.parse(state.startedAtUtc);
      if (duration >= 1 && duration <= 15_000) return "draining";
    }
    return "unavailable";
  } catch {
    return "unavailable";
  }
}

export function evaluateInfrastructureReadiness(input: {
  loopback: boolean;
  rehearsalEnabled: boolean;
  releaseMarkerPresent: boolean;
  rehearsalSecretReadable: boolean;
  drainState: InfrastructureDrainState;
}): Readonly<{ ready: boolean; status: "ready" | "draining" | "unavailable" }> {
  if (input.loopback && input.rehearsalEnabled && input.drainState === "draining") {
    return Object.freeze({ ready: false, status: "draining" });
  }
  const ready =
    input.loopback &&
    input.rehearsalEnabled &&
    input.releaseMarkerPresent &&
    input.rehearsalSecretReadable &&
    input.drainState === "ready";
  return Object.freeze({ ready, status: ready ? "ready" : "unavailable" });
}
