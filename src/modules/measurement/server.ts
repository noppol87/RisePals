import "server-only";
import type { Locale } from "@/lib/i18n/config";
import type { MeasurementMonitoringAdapter } from "./adapter";
import { disabledMeasurementMonitoringAdapter } from "./disabled-adapter";
import {
  createRedactedErrorOccurrence,
  type ErrorCategory,
  type ErrorOperationCode,
  type MeasurementOperationCode,
  type MeasurementSurface,
} from "./contract";

let adapterPromise: Promise<MeasurementMonitoringAdapter> | null = null;

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
    return await (selectedAdapter ?? (await defaultAdapter())).recordSuccessfulAction(input);
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
      createRedactedErrorOccurrence({ ...input, severity: "error" }),
    );
  } catch {
    return { state: "skipped" } as const;
  }
}
