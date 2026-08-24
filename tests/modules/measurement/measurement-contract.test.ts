import { describe, expect, it, vi } from "vitest";
import type { MeasurementMonitoringAdapter } from "@/modules/measurement/adapter";
import { disabledMeasurementMonitoringAdapter } from "@/modules/measurement/disabled-adapter";
import {
  createRedactedErrorOccurrence,
  ERROR_OCCURRENCE_SCHEMA_VERSION,
  errorCategories,
  errorOperationCodes,
  errorSeverities,
  measurementOperationCodes,
  measurementSurfaces,
  parseProductMeasurementCandidate,
  parseRedactedErrorOccurrence,
  productEventClasses,
  type RedactedErrorOccurrence,
} from "@/modules/measurement/contract";
import {
  captureSuccessfulProductAction,
  reportControlledErrorOccurrence,
} from "@/modules/measurement/server";

vi.mock("server-only", () => ({}));

const mutationId = "10000000-0000-4000-8000-000000000001";

describe("measurement and redacted error contract", () => {
  it("pins the exact product and error allowlists", () => {
    expect(productEventClasses).toEqual(["activation_completed", "meaningful_return_completed"]);
    expect(measurementSurfaces).toEqual([
      "assessment",
      "result",
      "lesson_practice",
      "private_evidence",
    ]);
    expect(measurementOperationCodes).toEqual([
      "assessment_response_saved",
      "result_generated",
      "lesson_started",
      "lesson_practice_saved",
      "lesson_practice_evaluated",
      "lesson_practice_retry_started",
      "private_evidence_started",
      "private_evidence_saved",
      "private_evidence_marked_ready",
      "private_evidence_withdrawn",
    ]);
    expect(errorOperationCodes).toEqual(measurementOperationCodes);
    expect(errorCategories).toEqual([
      "unexpected_database",
      "unexpected_identity",
      "unexpected_domain",
      "unexpected_internal",
    ]);
    expect(errorSeverities).toEqual(["warning", "error"]);
  });

  it("accepts only the exact controlled product-measurement candidate", () => {
    const candidate = {
      schemaVersion: "product-measurement-v1" as const,
      surface: "assessment" as const,
      operationCode: "assessment_response_saved" as const,
      locale: "th" as const,
      actionDigest: "a".repeat(64),
    };
    expect(parseProductMeasurementCandidate(candidate)).toEqual(candidate);
    expect(() =>
      parseProductMeasurementCandidate({ ...candidate, actionDigest: "not-a-digest" }),
    ).toThrow("controlled schema");
    expect(() =>
      parseProductMeasurementCandidate({ ...candidate, clientMutationId: mutationId }),
    ).toThrow("unexpected field");
  });

  it("hashes and validates the mutation before every injected adapter boundary", async () => {
    const recordSuccessfulAction = vi.fn(
      async (input: Parameters<MeasurementMonitoringAdapter["recordSuccessfulAction"]>[0]) => {
        void input;
        return { state: "recorded" as const };
      },
    );
    const reportOccurrence = vi.fn(
      async (input: Parameters<MeasurementMonitoringAdapter["reportOccurrence"]>[0]) => {
        void input;
        return { state: "recorded" as const };
      },
    );
    const adapter: MeasurementMonitoringAdapter = {
      recordSuccessfulAction,
      reportOccurrence,
    };
    await expect(
      captureSuccessfulProductAction(
        {
          surface: "assessment",
          operationCode: "assessment_response_saved",
          locale: "th",
          clientMutationId: mutationId,
        },
        adapter,
      ),
    ).resolves.toEqual({ state: "recorded" });

    expect(recordSuccessfulAction).toHaveBeenCalledOnce();
    const boundaryInput = recordSuccessfulAction.mock.calls[0]?.[0];
    expect(Object.keys(boundaryInput ?? {}).sort()).toEqual(
      ["schemaVersion", "surface", "operationCode", "locale", "actionDigest"].sort(),
    );
    expect(boundaryInput?.actionDigest).toMatch(/^[0-9a-f]{64}$/);
    expect(JSON.stringify(boundaryInput)).not.toContain(mutationId);
    for (const prohibited of ["itemKey", "selectedOptionId", "payload", "formData"]) {
      expect(JSON.stringify(boundaryInput)).not.toContain(prohibited);
    }

    recordSuccessfulAction.mockClear();
    await expect(
      captureSuccessfulProductAction(
        {
          surface: "assessment",
          operationCode: "assessment_response_saved",
          locale: "th",
          clientMutationId: "not-a-uuid",
        },
        adapter,
      ),
    ).resolves.toEqual({ state: "skipped" });
    expect(recordSuccessfulAction).not.toHaveBeenCalled();

    await expect(
      captureSuccessfulProductAction(
        {
          surface: "assessment",
          operationCode: "assessment_response_saved",
          locale: "th",
          clientMutationId: mutationId,
        },
        disabledMeasurementMonitoringAdapter,
      ),
    ).resolves.toEqual({ state: "disabled" });

    await expect(
      reportControlledErrorOccurrence(
        {
          surface: "assessment",
          operationCode: "assessment_response_saved",
          locale: "th",
          category: "unexpected_database",
          retryable: true,
          clientMutationId: mutationId,
        },
        adapter,
      ),
    ).resolves.toEqual({ state: "recorded" });
    const occurrence = reportOccurrence.mock.calls[0]?.[0];
    expect(JSON.stringify(occurrence)).not.toContain(mutationId);
    expect(occurrence?.mutationDigest).toMatch(/^[0-9a-f]{64}$/);
  });

  it("creates only the controlled redacted occurrence fields", () => {
    const occurrence = createRedactedErrorOccurrence({
      operationCode: "result_generated",
      surface: "result",
      locale: "en",
      category: "unexpected_domain",
      severity: "error",
      retryable: true,
      mutationDigest: "b".repeat(64),
      now: new Date("2026-08-24T12:00:00.000Z"),
    });
    expect(Object.keys(occurrence).sort()).toEqual(
      [
        "schemaVersion",
        "correlationId",
        "operationCode",
        "surface",
        "locale",
        "category",
        "severity",
        "retryable",
        "occurredAt",
        "mutationDigest",
      ].sort(),
    );
    expect(occurrence.schemaVersion).toBe(ERROR_OCCURRENCE_SCHEMA_VERSION);
    expect(occurrence.mutationDigest).toMatch(/^[0-9a-f]{64}$/);
    expect(JSON.stringify(occurrence)).not.toContain(mutationId);
  });

  it.each([
    ["null", null],
    ["number", 42],
    ["boolean", true],
    ["array", ["unexpected"]],
    ["Error", new Error("secret stack and message")],
    ["URL", new URL("https://example.test/path?token=secret")],
    ["nested object", { message: { token: "secret" } }],
  ])("rejects %s instead of sanitizing arbitrary input", (_label, input) => {
    expect(() => parseRedactedErrorOccurrence(input)).toThrow();
  });

  it("rejects unexpected message, stack, URL, token and nested metadata keys", () => {
    const valid = createRedactedErrorOccurrence({
      operationCode: "private_evidence_saved",
      surface: "private_evidence",
      locale: "th",
      category: "unexpected_internal",
      severity: "warning",
      retryable: false,
      now: new Date("2026-08-24T12:00:00.000Z"),
    });
    for (const extra of [
      { message: "raw" },
      { stack: "raw" },
      { url: "https://example.test/?secret=value" },
      { token: "secret" },
      { metadata: { answer: "raw" } },
      { values: ["raw"] },
    ]) {
      expect(() => parseRedactedErrorOccurrence({ ...valid, ...extra })).toThrow(
        "unexpected field",
      );
    }
  });

  it("keeps measurement and reporter failures non-authoritative", async () => {
    const failingAdapter: MeasurementMonitoringAdapter = {
      recordSuccessfulAction: vi.fn(async () => {
        throw new Error("measurement unavailable");
      }),
      reportOccurrence: vi.fn(async () => {
        throw new Error("reporter unavailable");
      }),
    };
    await expect(
      captureSuccessfulProductAction(
        {
          surface: "assessment",
          operationCode: "assessment_response_saved",
          locale: "th",
          clientMutationId: mutationId,
        },
        failingAdapter,
      ),
    ).resolves.toEqual({ state: "skipped" });
    await expect(
      reportControlledErrorOccurrence(
        {
          surface: "assessment",
          operationCode: "assessment_response_saved",
          locale: "th",
          category: "unexpected_database",
          retryable: true,
          clientMutationId: mutationId,
        },
        failingAdapter,
      ),
    ).resolves.toEqual({ state: "skipped" });
  });
});

if (false) {
  const prohibitedCompileBoundary: RedactedErrorOccurrence = {
    schemaVersion: ERROR_OCCURRENCE_SCHEMA_VERSION,
    correlationId: mutationId,
    operationCode: "result_generated",
    surface: "result",
    locale: "en",
    category: "unexpected_internal",
    severity: "error",
    retryable: false,
    occurredAt: new Date(),
    mutationDigest: null,
    // @ts-expect-error raw exception messages are not part of the storage contract
    message: "raw error",
  };
  void prohibitedCompileBoundary;
}
