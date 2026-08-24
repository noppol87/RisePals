import type { Locale } from "@/lib/i18n/config";
import { measurementNotice } from "./notice";

export type MeasurementConsentStatus = "not-set" | "granted" | "declined" | "withdrawn" | "stale";

const statusCopy = {
  th: {
    "not-set": "ยังไม่ได้เลือก",
    granted: "ยินยอม",
    declined: "ปฏิเสธ",
    withdrawn: "ถอนความยินยอมแล้ว",
    stale: "ต้องยืนยันประกาศฉบับปัจจุบันใหม่",
  },
  en: {
    "not-set": "Not selected",
    granted: "Granted",
    declined: "Declined",
    withdrawn: "Withdrawn",
    stale: "Current notice requires a new decision",
  },
} as const;

const actionCopy = {
  th: { grant: "ยินยอมแบบไม่บังคับ", decline: "ปฏิเสธ", withdraw: "ถอนความยินยอม" },
  en: { grant: "Grant optional consent", decline: "Decline", withdraw: "Withdraw" },
} as const;

export function createMeasurementConsentView(locale: Locale, status: MeasurementConsentStatus) {
  return {
    ...measurementNotice[locale],
    statusLabel: locale === "th" ? "สถานะปัจจุบัน" : "Current status",
    status: statusCopy[locale][status],
    actions:
      status === "granted"
        ? [{ decision: "withdrawn" as const, label: actionCopy[locale].withdraw }]
        : [
            { decision: "granted" as const, label: actionCopy[locale].grant },
            { decision: "declined" as const, label: actionCopy[locale].decline },
          ],
  } as const;
}
