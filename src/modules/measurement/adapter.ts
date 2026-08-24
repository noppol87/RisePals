import "server-only";
import type {
  ProductEventClass,
  RedactedErrorOccurrence,
  SuccessfulProductAction,
} from "./contract";

export type MeasurementCaptureResult = Readonly<{
  state: "recorded" | "skipped" | "disabled";
  eventClass?: ProductEventClass;
}>;

export type ErrorReportResult = Readonly<{
  state: "recorded" | "skipped" | "disabled";
}>;

export interface ProductMeasurementAdapter {
  recordSuccessfulAction(input: SuccessfulProductAction): Promise<MeasurementCaptureResult>;
}

export interface RedactedErrorReporter {
  reportOccurrence(input: RedactedErrorOccurrence): Promise<ErrorReportResult>;
}

export type MeasurementMonitoringAdapter = ProductMeasurementAdapter & RedactedErrorReporter;
