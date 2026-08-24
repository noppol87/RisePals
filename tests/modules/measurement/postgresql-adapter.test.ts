import type { PoolClient } from "pg";
import { describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import { createRedactedErrorOccurrence } from "@/modules/measurement/contract";
import { createPostgresqlMeasurementMonitoringAdapter } from "@/modules/measurement/postgresql-adapter";

const userId = "10000000-0000-4000-8000-000000000001";
const consentId = "20000000-0000-4000-8000-000000000001";
const subjectId = "30000000-0000-4000-8000-000000000001";
const mutationId = "40000000-0000-4000-8000-000000000001";

function transactionRunner(client: PoolClient) {
  return async <T>(operation: (value: PoolClient, owner: string) => Promise<T>) => ({
    state: "authorized" as const,
    value: await operation(client, userId),
  });
}

describe("PostgreSQL measurement adapter", () => {
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
    await expect(
      adapter.recordSuccessfulAction({
        surface: "assessment",
        operationCode: "assessment_response_saved",
        locale: "th",
        clientMutationId: mutationId,
      }),
    ).resolves.toEqual({ state: "skipped" });
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
        if (sql.includes("action_digest=$2")) {
          return { rows: events.filter((event) => event.actionDigest === params[1]) };
        }
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
          return { rows: [] };
        }
        throw new Error(`Unexpected query: ${sql}`);
      }),
    } as unknown as PoolClient;
    const dayOne = createPostgresqlMeasurementMonitoringAdapter({
      transactionRunner: transactionRunner(client),
      now: () => new Date("2026-08-24T23:59:59.000Z"),
    });
    const action = {
      surface: "assessment" as const,
      operationCode: "assessment_response_saved" as const,
      locale: "th" as const,
      clientMutationId: mutationId,
    };
    await expect(dayOne.recordSuccessfulAction(action)).resolves.toEqual({
      state: "recorded",
      eventClass: "activation_completed",
    });
    await expect(dayOne.recordSuccessfulAction(action)).resolves.toEqual({ state: "skipped" });
    await expect(
      dayOne.recordSuccessfulAction({
        ...action,
        clientMutationId: "40000000-0000-4000-8000-000000000002",
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
        clientMutationId: "40000000-0000-4000-8000-000000000003",
      }),
    ).resolves.toEqual({ state: "recorded", eventClass: "meaningful_return_completed" });
    expect(events.map((event) => event.eventClass)).toEqual([
      "activation_completed",
      "meaningful_return_completed",
    ]);
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
      clientMutationId: mutationId,
      now: new Date("2026-08-24T12:00:00.000Z"),
    });
    await expect(adapter.reportOccurrence(occurrence)).resolves.toEqual({ state: "recorded" });
    expect(inserted).toHaveLength(1);
    const serialized = JSON.stringify(inserted[0]);
    expect(serialized).not.toContain(mutationId);
    for (const prohibited of ["message", "stack", "token", "answer", "score", "email"])
      expect(serialized).not.toContain(prohibited);
  });
});
