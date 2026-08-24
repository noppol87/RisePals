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

export const MEASUREMENT_CONSENT_PURPOSE = "measurement-monitoring" as const;
export const MEASUREMENT_NOTICE_VERSION = "alpha-measurement-monitoring-v1" as const;
export const MEASUREMENT_CONSENT_SCHEMA_VERSION = "measurement-consent-contract-v1" as const;

const canonicalMeasurementNoticeContract = {
  schemaVersion: MEASUREMENT_CONSENT_SCHEMA_VERSION,
  noticeVersion: MEASUREMENT_NOTICE_VERSION,
  purposeCode: MEASUREMENT_CONSENT_PURPOSE,
  optional: true,
  productEventFields: [
    "schema_version",
    "event_class",
    "surface_code",
    "operation_code",
    "occurred_at_utc",
    "action_digest",
  ],
  errorOccurrenceFields: [
    "schema_version",
    "correlation_uuid",
    "operation_code",
    "surface_code",
    "locale",
    "error_category",
    "severity",
    "retryable",
    "occurred_at_utc",
    "optional_mutation_digest",
  ],
  eventClasses: ["activation_completed", "meaningful_return_completed"],
  surfaces: ["assessment", "result", "lesson_practice", "private_evidence"],
  exclusions: [
    "identity",
    "credentials",
    "raw-urls",
    "device-data",
    "assessment-content",
    "scoring-content",
    "lesson-content",
    "practice-content",
    "evidence-content",
    "free-text",
    "arbitrary-json",
    "external-providers",
  ],
} as const;

export const measurementNoticeProofDigest = createHash("sha256")
  .update(JSON.stringify(canonicalMeasurementNoticeContract), "utf8")
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

export const measurementNotice = {
  th: {
    heading: "การวัดผลการใช้งานและเฝ้าระวังข้อผิดพลาดแบบไม่บังคับ",
    summary:
      "หากคุณยินยอม Rise Pals จะบันทึกเฉพาะผลสำเร็จจากการลงมือทำที่ระบบอนุญาต ได้แก่ การเริ่มใช้งานอย่างมีความหมายและการกลับมาลงมือทำในวัน UTC ถัดไป บนส่วนการประเมิน ผลลัพธ์ การฝึกบทเรียน และหลักฐานส่วนตัว",
    fields:
      "เหตุการณ์เก็บเพียงรุ่นโครงสร้าง ประเภทเหตุการณ์ ส่วนของผลิตภัณฑ์ รหัสการทำงาน เวลา UTC และลายนิ้วมือ SHA-256 ที่ผูกกับบริบท ส่วนข้อผิดพลาดเก็บเพียง UUID สำหรับเชื่อมเหตุการณ์ รหัสการทำงาน/ส่วนผลิตภัณฑ์ ภาษา หมวด ความรุนแรง สถานะลองใหม่ เวลา UTC และลายนิ้วมือการกลายพันธุ์แบบไม่บังคับ",
    exclusions:
      "ระบบไม่เก็บข้อความหรือ stack ของข้อผิดพลาด URL ดิบ IP อุปกรณ์ อีเมล รหัสผู้ให้บริการ token cookie ข้อมูลโปรไฟล์ คำตอบ คะแนน เนื้อหาบทเรียน ตัวเลือกการฝึก หรือเนื้อหาหลักฐาน และไม่ส่งข้อมูลไปผู้ให้บริการภายนอก",
    independence:
      "ความยินยอมนี้แยกจากข้อมูลบริการและเป็นทางเลือก การปฏิเสธหรือถอนจะไม่ปิดกั้นการประเมิน ผลลัพธ์ บทเรียน การฝึก ความคืบหน้า โปรไฟล์ หรือหลักฐานส่วนตัว",
    withdrawal:
      "การถอนมีผลหยุดการบันทึกใหม่ทันที การให้ความยินยอมอีกครั้งจะใช้รหัสนามแฝงใหม่ การเก็บรักษา ส่งออก และลบข้อมูลยังไม่ได้ทำในอัลฟานี้",
  },
  en: {
    heading: "Optional measurement and error monitoring",
    summary:
      "If you consent, Rise Pals records only allowlisted successful explicit outcomes: meaningful activation and a later-UTC-day meaningful return across assessment, result, lesson practice and private evidence surfaces.",
    fields:
      "A product event contains only schema version, event class, product surface, controlled operation code, UTC time and a context-bound SHA-256 digest. An error occurrence contains only a correlation UUID, controlled operation/surface, locale, category, severity, retryability, UTC time and an optional mutation digest.",
    exclusions:
      "No exception message or stack, raw URL, IP/device data, email, provider identity, token, cookie, profile field, answer, score, lesson/practice selection or evidence content is captured, and no data is sent to an external provider.",
    independence:
      "This optional consent is separate from service-data consent. Declining or withdrawing does not block assessment, results, lessons, practice, progress, profile or private evidence.",
    withdrawal:
      "Withdrawal immediately stops new capture. A later grant uses a new pseudonymous subject. Retention, export and erasure are not implemented in this alpha.",
  },
} as const satisfies Record<
  Locale,
  Readonly<{
    heading: string;
    summary: string;
    fields: string;
    exclusions: string;
    independence: string;
    withdrawal: string;
  }>
>;

export type ConsentDecision = "granted" | "declined" | "withdrawn";

export function isConsentDecision(value: unknown): value is ConsentDecision {
  return value === "granted" || value === "declined" || value === "withdrawn";
}
