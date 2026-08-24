import { randomUUID } from "node:crypto";
import type { Locale } from "@/lib/i18n/config";

export const MEASUREMENT_SCHEMA_VERSION = "product-measurement-v1" as const;
export const ERROR_OCCURRENCE_SCHEMA_VERSION = "redacted-error-occurrence-v1" as const;
export const MEASUREMENT_SUBJECT_SCHEMA_VERSION = "measurement-subject-v1" as const;

export const productEventClasses = ["activation_completed", "meaningful_return_completed"] as const;
export type ProductEventClass = (typeof productEventClasses)[number];

export const measurementSurfaces = [
  "assessment",
  "result",
  "lesson_practice",
  "private_evidence",
] as const;
export type MeasurementSurface = (typeof measurementSurfaces)[number];

export const measurementOperationCodes = [
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
] as const;
export type MeasurementOperationCode = (typeof measurementOperationCodes)[number];

export const errorOperationCodes = [...measurementOperationCodes] as const;
export type ErrorOperationCode = (typeof errorOperationCodes)[number];

export const errorCategories = [
  "unexpected_database",
  "unexpected_identity",
  "unexpected_domain",
  "unexpected_internal",
] as const;
export type ErrorCategory = (typeof errorCategories)[number];

export const errorSeverities = ["warning", "error"] as const;
export type ErrorSeverity = (typeof errorSeverities)[number];

export type ProductMeasurementCandidate = Readonly<{
  schemaVersion: typeof MEASUREMENT_SCHEMA_VERSION;
  surface: MeasurementSurface;
  operationCode: MeasurementOperationCode;
  locale: Locale;
  actionDigest: string;
}>;

export type RedactedErrorOccurrence = Readonly<{
  schemaVersion: typeof ERROR_OCCURRENCE_SCHEMA_VERSION;
  correlationId: string;
  operationCode: ErrorOperationCode;
  surface: MeasurementSurface;
  locale: Locale;
  category: ErrorCategory;
  severity: ErrorSeverity;
  retryable: boolean;
  occurredAt: Date;
  mutationDigest: string | null;
}>;

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA256_PATTERN = /^[0-9a-f]{64}$/;

function oneOf<const T extends readonly string[]>(
  value: unknown,
  allowlist: T,
): value is T[number] {
  return typeof value === "string" && allowlist.includes(value);
}

function exactObject(
  value: unknown,
  keys: readonly string[],
  label: string,
): Readonly<Record<string, unknown>> {
  if (!value || typeof value !== "object" || Array.isArray(value) || value instanceof Error) {
    throw new Error(`${label} must be one controlled object.`);
  }
  const candidate = value as Readonly<Record<string, unknown>>;
  const actual = Object.keys(candidate).sort();
  const expected = [...keys].sort();
  if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
    throw new Error(`${label} contains an unexpected field.`);
  }
  return candidate;
}

function validDate(value: unknown): value is Date {
  return value instanceof Date && Number.isFinite(value.getTime());
}

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

export function parseProductMeasurementCandidate(value: unknown): ProductMeasurementCandidate {
  const candidate = exactObject(
    value,
    ["schemaVersion", "surface", "operationCode", "locale", "actionDigest"],
    "Product measurement candidate",
  );
  if (
    candidate.schemaVersion !== MEASUREMENT_SCHEMA_VERSION ||
    !oneOf(candidate.surface, measurementSurfaces) ||
    !oneOf(candidate.operationCode, measurementOperationCodes) ||
    !oneOf(candidate.locale, ["th", "en"] as const) ||
    typeof candidate.actionDigest !== "string" ||
    !SHA256_PATTERN.test(candidate.actionDigest)
  ) {
    throw new Error("Product measurement candidate does not match the controlled schema.");
  }
  return candidate as ProductMeasurementCandidate;
}

export function parseRedactedErrorOccurrence(value: unknown): RedactedErrorOccurrence {
  const candidate = exactObject(
    value,
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
    ],
    "Redacted error input",
  );
  if (
    candidate.schemaVersion !== ERROR_OCCURRENCE_SCHEMA_VERSION ||
    !isUuid(candidate.correlationId) ||
    !oneOf(candidate.operationCode, errorOperationCodes) ||
    !oneOf(candidate.surface, measurementSurfaces) ||
    !oneOf(candidate.locale, ["th", "en"] as const) ||
    !oneOf(candidate.category, errorCategories) ||
    !oneOf(candidate.severity, errorSeverities) ||
    typeof candidate.retryable !== "boolean" ||
    !validDate(candidate.occurredAt) ||
    !(
      candidate.mutationDigest === null ||
      (typeof candidate.mutationDigest === "string" &&
        SHA256_PATTERN.test(candidate.mutationDigest))
    )
  ) {
    throw new Error("Redacted error input does not match the controlled schema.");
  }
  return candidate as RedactedErrorOccurrence;
}

export function createRedactedErrorOccurrence(input: {
  operationCode: ErrorOperationCode;
  surface: MeasurementSurface;
  locale: Locale;
  category: ErrorCategory;
  severity: ErrorSeverity;
  retryable: boolean;
  mutationDigest?: string | null;
  now?: Date;
}): RedactedErrorOccurrence {
  return parseRedactedErrorOccurrence({
    schemaVersion: ERROR_OCCURRENCE_SCHEMA_VERSION,
    correlationId: randomUUID(),
    operationCode: input.operationCode,
    surface: input.surface,
    locale: input.locale,
    category: input.category,
    severity: input.severity,
    retryable: input.retryable,
    occurredAt: input.now ?? new Date(),
    mutationDigest: input.mutationDigest ?? null,
  });
}
