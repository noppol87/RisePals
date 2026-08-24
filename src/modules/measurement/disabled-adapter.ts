import "server-only";
import type { MeasurementMonitoringAdapter } from "./adapter";

export const disabledMeasurementMonitoringAdapter: MeasurementMonitoringAdapter = {
  async recordSuccessfulAction() {
    return { state: "disabled" };
  },
  async reportOccurrence() {
    return { state: "disabled" };
  },
};
