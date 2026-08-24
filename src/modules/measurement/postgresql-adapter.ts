import "server-only";
import type { PoolClient } from "pg";
import {
  MEASUREMENT_CONSENT_PURPOSE,
  MEASUREMENT_NOTICE_VERSION,
  measurementNoticeProofDigest,
} from "@/modules/consent/notice";
import type {
  ErrorReportResult,
  MeasurementCaptureResult,
  MeasurementMonitoringAdapter,
} from "./adapter";
import {
  actionDigest,
  MEASUREMENT_SCHEMA_VERSION,
  MEASUREMENT_SUBJECT_SCHEMA_VERSION,
  parseRedactedErrorOccurrence,
  type RedactedErrorOccurrence,
  type SuccessfulProductAction,
} from "./contract";

type Options = Readonly<{
  transactionRunner: AuthorizedTransactionRunner;
  now?: () => Date;
}>;

type AuthorizedTransactionRunner = <T>(
  operation: (client: PoolClient, userId: string) => Promise<T>,
) => Promise<
  Readonly<{ state: "authorized"; value: T }> | Readonly<{ state: "denied"; reason: string }>
>;

type ConsentRow = Readonly<{
  id: unknown;
  decision: unknown;
  notice_version: unknown;
  proof_digest: unknown;
}>;

function validDate(value: Date): Date {
  if (!Number.isFinite(value.getTime())) throw new Error("Measurement clock is invalid.");
  return value;
}

function utcDate(value: Date): string {
  return value.toISOString().slice(0, 10);
}

function stringId(value: unknown, label: string): string {
  if (typeof value !== "string") throw new Error(`${label} is invalid.`);
  return value;
}

export function createPostgresqlMeasurementMonitoringAdapter(
  options: Options,
): MeasurementMonitoringAdapter {
  const clock = options.now ?? (() => new Date());
  const runAuthorized = options.transactionRunner;

  async function currentSubject(client: import("pg").PoolClient, userId: string) {
    const consentResult = await client.query<ConsentRow>(
      `SELECT id, decision, notice_version, proof_digest
       FROM consent_records
       WHERE purpose_code = $1
       ORDER BY occurred_at DESC, id DESC
       LIMIT 1`,
      [MEASUREMENT_CONSENT_PURPOSE],
    );
    const consent = consentResult.rows[0];
    if (
      !consent ||
      consent.decision !== "granted" ||
      consent.notice_version !== MEASUREMENT_NOTICE_VERSION ||
      consent.proof_digest !== measurementNoticeProofDigest
    ) {
      return null;
    }
    const consentId = stringId(consent.id, "Measurement consent receipt");
    await client.query(
      `INSERT INTO measurement_subjects
        (user_id, consent_record_id, subject_schema_version, created_at)
       VALUES ($1,$2,$3,clock_timestamp())
       ON CONFLICT (user_id, consent_record_id) DO NOTHING`,
      [userId, consentId, MEASUREMENT_SUBJECT_SCHEMA_VERSION],
    );
    const subject = await client.query<{ id: unknown }>(
      `SELECT id FROM measurement_subjects
       WHERE user_id=$1 AND consent_record_id=$2`,
      [userId, consentId],
    );
    return stringId(subject.rows[0]?.id, "Measurement subject");
  }

  return {
    async recordSuccessfulAction(
      input: SuccessfulProductAction,
    ): Promise<MeasurementCaptureResult> {
      const digest = actionDigest(input);
      const occurredAt = validDate(clock());
      const result = await runAuthorized(async (client, userId) => {
        const subjectId = await currentSubject(client, userId);
        if (!subjectId) return { state: "skipped" } as const;
        await client.query(
          `SELECT pg_advisory_xact_lock(hashtextextended('measurement-subject:' || $1, 0))`,
          [subjectId],
        );
        const replay = await client.query(
          `SELECT id FROM product_events
             WHERE measurement_subject_id=$1 AND action_digest=$2`,
          [subjectId, digest],
        );
        if (replay.rowCount) return { state: "skipped" } as const;
        const activation = await client.query<{ occurred_at: unknown }>(
          `SELECT occurred_at FROM product_events
             WHERE measurement_subject_id=$1 AND event_class='activation_completed'
             ORDER BY occurred_at, id LIMIT 1`,
          [subjectId],
        );
        const activationTime = activation.rows[0]?.occurred_at;
        const eventClass =
          activationTime === undefined
            ? "activation_completed"
            : activationTime instanceof Date && utcDate(occurredAt) > utcDate(activationTime)
              ? "meaningful_return_completed"
              : null;
        if (!eventClass) return { state: "skipped" } as const;
        await client.query(
          `INSERT INTO product_events
              (measurement_subject_id, schema_version, event_class, surface_code,
               operation_code, action_digest, occurred_at)
             VALUES ($1,$2,$3,$4,$5,$6,$7)`,
          [
            subjectId,
            MEASUREMENT_SCHEMA_VERSION,
            eventClass,
            input.surface,
            input.operationCode,
            digest,
            occurredAt,
          ],
        );
        return { state: "recorded", eventClass } as const;
      });
      return result.state === "authorized" ? result.value : { state: "skipped" };
    },

    async reportOccurrence(input: RedactedErrorOccurrence): Promise<ErrorReportResult> {
      const occurrence = parseRedactedErrorOccurrence(input);
      const result = await runAuthorized(async (client, userId) => {
        const subjectId = await currentSubject(client, userId);
        if (!subjectId) return { state: "skipped" } as const;
        await client.query(
          `INSERT INTO error_occurrences
              (measurement_subject_id, schema_version, correlation_id, operation_code,
               surface_code, locale, error_category, severity, retryable,
               occurred_at, mutation_digest)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
          [
            subjectId,
            occurrence.schemaVersion,
            occurrence.correlationId,
            occurrence.operationCode,
            occurrence.surface,
            occurrence.locale,
            occurrence.category,
            occurrence.severity,
            occurrence.retryable,
            occurrence.occurredAt,
            occurrence.mutationDigest,
          ],
        );
        return { state: "recorded" } as const;
      });
      return result.state === "authorized" ? result.value : { state: "skipped" };
    },
  };
}
