import { describe, expect, it } from "vitest";
import {
  evaluateInfrastructureReadiness,
  hasLoopbackRequestHost,
  hasSafeRehearsalForwardedHeaders,
  isInfrastructureRehearsalEnabled,
  isLoopbackRequest,
  liveHealthPayload,
  parseInfrastructureDrainState,
  rehearsalStreamChunks,
} from "@/lib/infra/health";

describe("infrastructure health contract", () => {
  it("keeps liveness and streaming output fixed and non-sensitive", () => {
    expect(liveHealthPayload).toEqual({ status: "ok" });
    expect(rehearsalStreamChunks).toEqual(["probe-start\n", "probe-mid\n", "probe-end\n"]);
    expect(JSON.stringify({ liveHealthPayload, rehearsalStreamChunks })).not.toMatch(
      /version|environment|database|secret|user|commit/i,
    );
  });

  it("accepts direct and standalone-normalized loopback requests only", () => {
    expect(isLoopbackRequest(new Request("http://127.0.0.1:3100/health/ready"))).toBe(true);
    expect(isLoopbackRequest(new Request("http://localhost:3100/health/ready"))).toBe(true);
    expect(
      isLoopbackRequest(
        new Request("http://127.0.0.1:3100/health/ready", {
          headers: { "x-forwarded-for": "127.0.0.1" },
        }),
      ),
    ).toBe(true);
    expect(
      isLoopbackRequest(
        new Request("http://127.0.0.1:3100/health/ready", {
          headers: { "x-forwarded-for": "::ffff:127.0.0.1" },
        }),
      ),
    ).toBe(true);
    expect(
      isLoopbackRequest(
        new Request("http://127.0.0.1:3100/health/ready", {
          headers: { "x-forwarded-for": "127.0.0.1, 203.0.113.1" },
        }),
      ),
    ).toBe(false);
    expect(
      isLoopbackRequest(
        new Request("http://127.0.0.1:3100/health/ready", {
          headers: { "x-forwarded-for": "203.0.113.1" },
        }),
      ),
    ).toBe(false);
    expect(isLoopbackRequest(new Request("https://example.test/health/ready"))).toBe(false);
  });

  it("enables rehearsal only for the exact value 1", () => {
    expect(isInfrastructureRehearsalEnabled({ RISE_PALS_INFRA_REHEARSAL: "1" })).toBe(true);
    expect(isInfrastructureRehearsalEnabled({ RISE_PALS_INFRA_REHEARSAL: "true" })).toBe(false);
    expect(isInfrastructureRehearsalEnabled({})).toBe(false);
  });

  it("accepts direct probes and only the exact replaced proxy headers", () => {
    expect(hasLoopbackRequestHost(new Request("http://127.0.0.1:3100/"))).toBe(true);
    expect(hasSafeRehearsalForwardedHeaders(new Request("http://127.0.0.1/"))).toBe(true);
    expect(
      hasSafeRehearsalForwardedHeaders(
        new Request("http://127.0.0.1/", {
          headers: {
            "x-forwarded-for": "127.0.0.1",
            "x-forwarded-host": "127.0.0.1",
            "x-forwarded-proto": "https",
          },
        }),
      ),
    ).toBe(true);
    expect(
      hasSafeRehearsalForwardedHeaders(
        new Request("http://127.0.0.1/", {
          headers: {
            "x-forwarded-for": "127.0.0.1",
            "x-forwarded-host": "127.0.0.1:8443",
            "x-forwarded-proto": "https",
          },
        }),
      ),
    ).toBe(true);
    expect(
      hasSafeRehearsalForwardedHeaders(
        new Request("http://127.0.0.1/", {
          headers: {
            "x-forwarded-for": "127.0.0.1",
            "x-forwarded-host": "127.0.0.1:8444",
            "x-forwarded-proto": "https",
          },
        }),
      ),
    ).toBe(false);
    expect(
      hasSafeRehearsalForwardedHeaders(
        new Request("http://127.0.0.1/", {
          headers: {
            "x-forwarded-for": "203.0.113.1",
            "x-forwarded-host": "attacker.invalid",
            "x-forwarded-proto": "http",
          },
        }),
      ),
    ).toBe(false);
  });

  it.each([
    {
      loopback: false,
      rehearsalEnabled: true,
      releaseMarkerPresent: true,
      rehearsalSecretReadable: true,
      drainState: "ready" as const,
    },
    {
      loopback: true,
      rehearsalEnabled: false,
      releaseMarkerPresent: true,
      rehearsalSecretReadable: true,
      drainState: "ready" as const,
    },
    {
      loopback: true,
      rehearsalEnabled: true,
      releaseMarkerPresent: false,
      rehearsalSecretReadable: true,
      drainState: "ready" as const,
    },
    {
      loopback: true,
      rehearsalEnabled: true,
      releaseMarkerPresent: true,
      rehearsalSecretReadable: false,
      drainState: "ready" as const,
    },
    {
      loopback: true,
      rehearsalEnabled: true,
      releaseMarkerPresent: true,
      rehearsalSecretReadable: true,
      drainState: "unavailable" as const,
    },
  ])("fails closed for an incomplete readiness boundary", (input) => {
    expect(evaluateInfrastructureReadiness(input)).toEqual({ ready: false, status: "unavailable" });
  });

  it("reports ready only after all rehearsal gates pass", () => {
    expect(
      evaluateInfrastructureReadiness({
        loopback: true,
        rehearsalEnabled: true,
        releaseMarkerPresent: true,
        rehearsalSecretReadable: true,
        drainState: "ready",
      }),
    ).toEqual({ ready: true, status: "ready" });
  });

  it("distinguishes a valid draining lifecycle from ready and malformed state", () => {
    expect(
      parseInfrastructureDrainState(
        JSON.stringify({
          schemaVersion: "rise-pals-drain-state-v1",
          state: "ready",
          recordedAtUtc: "2026-08-26T00:00:00.000Z",
        }),
      ),
    ).toBe("ready");
    expect(
      parseInfrastructureDrainState(
        JSON.stringify({
          schemaVersion: "rise-pals-drain-state-v1",
          state: "draining",
          startedAtUtc: "2026-08-26T00:00:00.000Z",
          deadlineAtUtc: "2026-08-26T00:00:15.000Z",
        }),
      ),
    ).toBe("draining");
    expect(parseInfrastructureDrainState('{"state":"ready"}')).toBe("unavailable");
    expect(
      parseInfrastructureDrainState(
        JSON.stringify({
          schemaVersion: "rise-pals-drain-state-v1",
          state: "ready",
          recordedAtUtc: "2026-08-26T00:00:00.000Z",
          extra: true,
        }),
      ),
    ).toBe("unavailable");
    expect(
      parseInfrastructureDrainState(
        JSON.stringify({
          schemaVersion: "rise-pals-drain-state-v1",
          state: "draining",
          startedAtUtc: "2026-08-26T00:00:00.000Z",
          deadlineAtUtc: "2026-08-26T00:00:15.001Z",
        }),
      ),
    ).toBe("unavailable");
    expect(parseInfrastructureDrainState("not-json")).toBe("unavailable");
  });

  it("reports draining only inside the exact rehearsal loopback boundary", () => {
    expect(
      evaluateInfrastructureReadiness({
        loopback: true,
        rehearsalEnabled: true,
        releaseMarkerPresent: true,
        rehearsalSecretReadable: true,
        drainState: "draining",
      }),
    ).toEqual({ ready: false, status: "draining" });
  });
});
