import type { PoolClient } from "pg";
import { describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import { createRedactedErrorOccurrence } from "@/modules/measurement/contract";
import { createPostgresqlMeasurementMonitoringAdapter } from "@/modules/measurement/postgresql-adapter";

const userId = "10000000-0000-4000-8000-000000000001";
const consentId = "20000000-0000-4000-8000-000000000001";
const subjectId = "30000000-0000-4000-8000-000000000001";

function candidate(actionDigest = "a".repeat(64)) {
  return {
    schemaVersion: "product-measurement-v1" as const,
    surface: "assessment" as const,
    operationCode: "assessment_response_saved" as const,
    locale: "th" as const,
    actionDigest,
  };
}

function transactionRunner(client: PoolClient) {
  return async <T>(operation: (value: PoolClient, owner: string) => Promise<T>) => ({
    state: "authorized" as const,
    value: await operation(client, userId),
  });
}

describe("PostgreSQL measurement adapter", () => {
  it("rejects a malformed or expanded candidate before starting authorization", async () => {
    const transaction = vi.fn();
    const adapter = createPostgresqlMeasurementMonitoringAdapter({
      transactionRunner: transaction,
    });
    await expect(
      adapter.recordSuccessfulAction({
        ...candidate(),
        clientMutationId: "40000000-0000-4000-8000-000000000001",
      } as never),
    ).rejects.toThrow("unexpected field");
    await expect(
      adapter.recordSuccessfulAction({ ...candidate(), actionDigest: "invalid" }),
    ).rejects.toThrow("controlled schema");
    expect(transaction).not.toHaveBeenCalled();
  });

  it("fails closed without an exact current granted measurement consent", async () => {
    const queries: string[] = [];
    const client = {
      query: vi.fn(async (sql: string) => {
        queries.push(sql);
        return {
          rows: [
            {
              id: consentId,
              decision: "declined",
              notice_version: "alpha-measurement-monitoring-v1",
              proof_digest: "0".repeat(64),
            },
          ],
        };
      }),
    } as unknown as PoolClient;
    const adapter = createPostgresqlMeasurementMonitoringAdapter({
      transactionRunner: transactionRunner(client),
    });
    await expect(adapter.recordSuccessfulAction(candidate())).resolves.toEqual({
      state: "skipped",
    });
    expect(queries).toHaveLength(1);
    expect(queries[0]).toContain("FROM consent_records");
  });

  it("records activation, skips exact replay and records only a later-day return", async () => {
    const events: Array<{
      eventClass: string;
      actionDigest: string;
      occurredAt: Date;
    }> = [];
    const client = {
      query: vi.fn(async (sql: string, params: readonly unknown[] = []) => {
        if (sql.includes("FROM consent_records")) {
          const { measurementNoticeProofDigest } = await import("@/modules/consent/notice");
          return {
            rows: [
              {
                id: consentId,
                decision: "granted",
                notice_version: "alpha-measurement-monitoring-v1",
                proof_digest: measurementNoticeProofDigest,
              },
            ],
          };
        }
        if (sql.includes("INSERT INTO measurement_subjects")) return { rows: [] };
        if (sql.includes("SELECT id FROM measurement_subjects"))
          return { rows: [{ id: subjectId }] };
        if (sql.includes("pg_advisory_xact_lock")) return { rows: [] };
        if (sql.includes("event_class='activation_completed'")) {
          const activation = events.find((event) => event.eventClass === "activation_completed");
          return { rows: activation ? [{ occurred_at: activation.occurredAt }] : [] };
        }
        if (sql.includes("INSERT INTO product_events")) {
          events.push({
            eventClass: String(params[2]),
            actionDigest: String(params[5]),
            occurredAt: params[6] as Date,
          });
          return { rows: [{ id: String(events.length) }], rowCount: 1 };
        }
        throw new Error(`Unexpected query: ${sql}`);
      }),
    } as unknown as PoolClient;
    const dayOne = createPostgresqlMeasurementMonitoringAdapter({
      transactionRunner: transactionRunner(client),
      now: () => new Date("2026-08-24T23:59:59.000Z"),
    });
    const action = candidate();
    await expect(dayOne.recordSuccessfulAction(action)).resolves.toEqual({
      state: "recorded",
      eventClass: "activation_completed",
    });
    await expect(dayOne.recordSuccessfulAction(action)).resolves.toEqual({ state: "skipped" });
    await expect(
      dayOne.recordSuccessfulAction({
        ...action,
        actionDigest: "b".repeat(64),
      }),
    ).resolves.toEqual({ state: "skipped" });
    const dayTwo = createPostgresqlMeasurementMonitoringAdapter({
      transactionRunner: transactionRunner(client),
      now: () => new Date("2026-08-25T00:00:00.000Z"),
    });
    await expect(
      dayTwo.recordSuccessfulAction({
        ...action,
        surface: "result",
        operationCode: "result_generated",
        actionDigest: "c".repeat(64),
      }),
    ).resolves.toEqual({ state: "recorded", eventClass: "meaningful_return_completed" });
    expect(events.map((event) => event.eventClass)).toEqual([
      "activation_completed",
      "meaningful_return_completed",
    ]);
  });

  it("preserves mutation provenance across withdrawal and re-grant subject rotation", async () => {
    const subjectA = subjectId;
    const subjectB = "30000000-0000-4000-8000-000000000002";
    let currentSubject = subjectA;
    const storedDigests = new Set<string>();
    const activations = new Set<string>();
    const client = {
      query: vi.fn(async (sql: string, params: readonly unknown[] = []) => {
        if (sql.includes("FROM consent_records")) {
          const { measurementNoticeProofDigest } = await import("@/modules/consent/notice");
          return {
            rows: [
              {
                id:
                  currentSubject === subjectA ? consentId : "20000000-0000-4000-8000-000000000002",
                decision: "granted",
                notice_version: "alpha-measurement-monitoring-v1",
                proof_digest: measurementNoticeProofDigest,
              },
            ],
          };
        }
        if (sql.includes("INSERT INTO measurement_subjects")) return { rows: [] };
        if (sql.includes("SELECT id FROM measurement_subjects")) {
          return { rows: [{ id: currentSubject }] };
        }
        if (sql.includes("pg_advisory_xact_lock")) return { rows: [] };
        if (sql.includes("event_class='activation_completed'")) {
          return {
            rows: activations.has(currentSubject)
              ? [{ occurred_at: new Date("2026-08-24T12:00:00.000Z") }]
              : [],
          };
        }
        if (sql.includes("INSERT INTO product_events")) {
          const digest = String(params[5]);
          if (storedDigests.has(digest)) return { rows: [], rowCount: 0 };
          storedDigests.add(digest);
          activations.add(currentSubject);
          return { rows: [{ id: String(storedDigests.size) }], rowCount: 1 };
        }
        throw new Error(`Unexpected query: ${sql}`);
      }),
    } as unknown as PoolClient;
    const adapter = createPostgresqlMeasurementMonitoringAdapter({
      transactionRunner: transactionRunner(client),
      now: () => new Date("2026-08-24T12:00:00.000Z"),
    });
    const original = candidate();
    await expect(adapter.recordSuccessfulAction(original)).resolves.toMatchObject({
      state: "recorded",
    });
    currentSubject = subjectB;
    await expect(adapter.recordSuccessfulAction(original)).resolves.toEqual({ state: "skipped" });
    expect(activations.has(subjectB)).toBe(false);
    await expect(adapter.recordSuccessfulAction(candidate("d".repeat(64)))).resolves.toMatchObject({
      state: "recorded",
    });
    expect(activations.has(subjectB)).toBe(true);
    expect(storedDigests).toHaveLength(2);
  });

  it("persists only controlled redacted error parameters", async () => {
    const inserted: readonly unknown[][] = [];
    const mutableInserted = inserted as unknown as unknown[][];
    const client = {
      query: vi.fn(async (sql: string, params: readonly unknown[] = []) => {
        if (sql.includes("FROM consent_records")) {
          const { measurementNoticeProofDigest } = await import("@/modules/consent/notice");
          return {
            rows: [
              {
                id: consentId,
                decision: "granted",
                notice_version: "alpha-measurement-monitoring-v1",
                proof_digest: measurementNoticeProofDigest,
              },
            ],
          };
        }
        if (sql.includes("INSERT INTO measurement_subjects")) return { rows: [] };
        if (sql.includes("SELECT id FROM measurement_subjects"))
          return { rows: [{ id: subjectId }] };
        if (sql.includes("INSERT INTO error_occurrences")) {
          mutableInserted.push([...params]);
          return { rows: [] };
        }
        throw new Error(`Unexpected query: ${sql}`);
      }),
    } as unknown as PoolClient;
    const adapter = createPostgresqlMeasurementMonitoringAdapter({
      transactionRunner: transactionRunner(client),
    });
    const occurrence = createRedactedErrorOccurrence({
      operationCode: "result_generated",
      surface: "result",
      locale: "en",
      category: "unexpected_internal",
      severity: "error",
      retryable: false,
      mutationDigest: "e".repeat(64),
      now: new Date("2026-08-24T12:00:00.000Z"),
    });
    await expect(adapter.reportOccurrence(occurrence)).resolves.toEqual({ state: "recorded" });
    expect(inserted).toHaveLength(1);
    const serialized = JSON.stringify(inserted[0]);
    expect(serialized).not.toContain("40000000-0000-4000-8000-000000000001");
    for (const prohibited of ["message", "stack", "token", "answer", "score", "email"])
      expect(serialized).not.toContain(prohibited);
  });
});
