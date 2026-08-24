import "server-only";
import { createHash } from "node:crypto";
import type { Locale } from "@/lib/i18n/config";
import type { MeasurementMonitoringAdapter } from "./adapter";
import { disabledMeasurementMonitoringAdapter } from "./disabled-adapter";
import {
  createRedactedErrorOccurrence,
  ERROR_OCCURRENCE_SCHEMA_VERSION,
  isUuid,
  MEASUREMENT_SCHEMA_VERSION,
  parseProductMeasurementCandidate,
  type ErrorCategory,
  type ErrorOperationCode,
  type MeasurementOperationCode,
  type MeasurementSurface,
} from "./contract";

let adapterPromise: Promise<MeasurementMonitoringAdapter> | null = null;

function productMeasurementCandidate(
  input: Readonly<{
    surface: MeasurementSurface;
    operationCode: MeasurementOperationCode;
    locale: Locale;
    clientMutationId: string;
  }>,
) {
  if (!isUuid(input.clientMutationId)) {
    throw new Error("Product measurement mutation context is invalid.");
  }
  return parseProductMeasurementCandidate({
    schemaVersion: MEASUREMENT_SCHEMA_VERSION,
    surface: input.surface,
    operationCode: input.operationCode,
    locale: input.locale,
    actionDigest: createHash("sha256")
      .update(
        [
          MEASUREMENT_SCHEMA_VERSION,
          input.surface,
          input.operationCode,
          input.locale,
          input.clientMutationId.toLowerCase(),
        ].join("\u0000"),
        "utf8",
      )
      .digest("hex"),
  });
}

function errorMutationDigest(
  surface: MeasurementSurface,
  operationCode: ErrorOperationCode,
  clientMutationId: string | null,
): string | null {
  if (clientMutationId === null) return null;
  if (!isUuid(clientMutationId)) {
    throw new Error("Error occurrence mutation context is invalid.");
  }
  return createHash("sha256")
    .update(
      [
        ERROR_OCCURRENCE_SCHEMA_VERSION,
        surface,
        operationCode,
        clientMutationId.toLowerCase(),
      ].join("\u0000"),
      "utf8",
    )
    .digest("hex");
}

async function defaultAdapter(): Promise<MeasurementMonitoringAdapter> {
  if (!process.env.DATABASE_URL) return disabledMeasurementMonitoringAdapter;
  adapterPromise ??= Promise.all([
    import("@/lib/db/server"),
    import("@/modules/account/authorization"),
    import("@/modules/identity/providers/clerk/server"),
    import("./postgresql-adapter"),
  ]).then(([database, authorization, identity, postgres]) => {
    const provider = identity.createClerkDevelopmentIdentityProvider();
    const pool = database.createApplicationPool();
    return postgres.createPostgresqlMeasurementMonitoringAdapter({
      transactionRunner: (operation) =>
        authorization.withAuthorizedUserTransaction(provider, operation, pool),
    });
  });
  return adapterPromise;
}

export async function captureSuccessfulProductAction(
  input: Readonly<{
    surface: MeasurementSurface;
    operationCode: MeasurementOperationCode;
    locale: Locale;
    clientMutationId: string;
  }>,
  selectedAdapter?: MeasurementMonitoringAdapter,
) {
  try {
    const candidate = productMeasurementCandidate(input);
    return await (selectedAdapter ?? (await defaultAdapter())).recordSuccessfulAction(candidate);
  } catch {
    return { state: "skipped" } as const;
  }
}

export async function reportControlledErrorOccurrence(
  input: Readonly<{
    surface: MeasurementSurface;
    operationCode: ErrorOperationCode;
    locale: Locale;
    category: ErrorCategory;
    retryable: boolean;
    clientMutationId?: string | null;
  }>,
  selectedAdapter?: MeasurementMonitoringAdapter,
) {
  try {
    return await (selectedAdapter ?? (await defaultAdapter())).reportOccurrence(
      createRedactedErrorOccurrence({
        ...input,
        severity: "error",
        mutationDigest: errorMutationDigest(
          input.surface,
          input.operationCode,
          input.clientMutationId ?? null,
        ),
      }),
    );
  } catch {
    return { state: "skipped" } as const;
  }
}
