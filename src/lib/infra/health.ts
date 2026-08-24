export const liveHealthPayload = Object.freeze({ status: "ok" as const });

export const rehearsalStreamChunks = Object.freeze(["probe-start\n", "probe-mid\n", "probe-end\n"]);

const loopbackHosts = new Set(["127.0.0.1", "::1", "localhost"]);

export function hasLoopbackRequestHost(request: Request): boolean {
  const hostHeader = request.headers.get("host")?.trim() || new URL(request.url).host;
  const host = hostHeader.startsWith("[")
    ? hostHeader.slice(1, hostHeader.indexOf("]"))
    : (hostHeader.split(":", 1)[0] ?? "");

  return loopbackHosts.has(host.toLowerCase());
}

export function isLoopbackRequest(request: Request): boolean {
  return hasLoopbackRequestHost(request) && !request.headers.has("x-forwarded-for");
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
  return (
    forwardedFor === "127.0.0.1" &&
    request.headers.get("x-forwarded-host") === "127.0.0.1" &&
    request.headers.get("x-forwarded-proto") === "https"
  );
}

export function evaluateInfrastructureReadiness(input: {
  loopback: boolean;
  rehearsalEnabled: boolean;
  releaseMarkerPresent: boolean;
  rehearsalSecretReadable: boolean;
}): Readonly<{ ready: boolean; status: "ready" | "unavailable" }> {
  const ready =
    input.loopback &&
    input.rehearsalEnabled &&
    input.releaseMarkerPresent &&
    input.rehearsalSecretReadable;
  return Object.freeze({ ready, status: ready ? "ready" : "unavailable" });
}
