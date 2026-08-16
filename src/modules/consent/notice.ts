import { createHash } from "node:crypto";
import type { Locale } from "@/lib/i18n/config";

export const SERVICE_DATA_PURPOSE = "service-profile-learning-state" as const;
export const PRIVACY_NOTICE_VERSION = "alpha-privacy-v1" as const;

const canonicalNoticeContract = {
  schemaVersion: "consent-contract-v1",
  noticeVersion: PRIVACY_NOTICE_VERSION,
  purposeCode: SERVICE_DATA_PURPOSE,
  collectedFields: [
    "preferred_locale",
    "timezone",
    "role_family",
    "function",
    "experience_band",
    "goals",
  ],
  processing: ["profile", "future-learning-state"],
  exclusions: ["analytics", "marketing", "research"],
  identityProvider: "clerk-development",
  identityHostingRegion: "US",
} as const;

export const privacyNoticeProofDigest = createHash("sha256")
  .update(JSON.stringify(canonicalNoticeContract), "utf8")
  .digest("hex");

export const privacyNotice = {
  th: {
    heading: "ประกาศความเป็นส่วนตัวสำหรับอัลฟา",
    summary:
      "Rise Pals เก็บเฉพาะภาษา เขตเวลา กลุ่มบทบาท สายงาน ช่วงประสบการณ์ และรหัสเป้าหมายที่คุณเลือก เพื่อแสดงโปรไฟล์และรองรับสถานะการเรียนรู้ในอนาคต เป้าหมายถือเป็นข้อมูลอาชีพที่มีความละเอียดอ่อน",
    identity:
      "การยืนยันตัวตนทดลองดำเนินการโดย Clerk Development และข้อมูลตัวตนอยู่ในสหรัฐอเมริกา ระบบ Rise Pals เก็บเพียงการเชื่อมโยงรหัสผู้ให้บริการกับรหัสผู้ใช้ภายใน ไม่คัดลอกอีเมลมาเก็บ",
    boundary:
      "ความยินยอมนี้ครอบคลุมเฉพาะข้อมูลบริการ ไม่รวมการตลาด การวิเคราะห์ หรือการวิจัย นี่คือประกาศผลิตภัณฑ์อัลฟา ไม่ใช่การอนุมัติกฎหมายสำหรับระบบจริง และห้ามใช้ข้อมูลจริง",
    withdrawal:
      "การถอนความยินยอมจะเพิ่มใบรับใหม่และหยุดการแก้ไขโปรไฟล์ แต่ไม่ใช่การลบบัญชีหรือข้อมูล ประเด็นการลบและระยะเวลาเก็บข้อมูลยังอยู่นอกขอบเขต",
  },
  en: {
    heading: "Alpha privacy notice",
    summary:
      "Rise Pals collects only your selected language, timezone, role-family, work-function, experience-band and goal codes to show a profile and support future learning state. Goals are sensitive career data.",
    identity:
      "Synthetic authentication is handled by Clerk Development and Clerk identity data is hosted in the United States. Rise Pals stores only a provider-to-internal-user mapping and does not copy email into its database.",
    boundary:
      "This consent covers service data only, not marketing, analytics or research. This is an alpha product notice, not final production legal approval, and real data is prohibited.",
    withdrawal:
      "Withdrawal appends a new receipt and prevents profile changes. It is not account or data deletion; deletion and retention remain out of scope.",
  },
} as const satisfies Record<
  Locale,
  Readonly<{
    heading: string;
    summary: string;
    identity: string;
    boundary: string;
    withdrawal: string;
  }>
>;

export type ConsentDecision = "granted" | "declined" | "withdrawn";

export function isConsentDecision(value: unknown): value is ConsentDecision {
  return value === "granted" || value === "declined" || value === "withdrawn";
}
