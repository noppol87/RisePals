import type { Locale } from "@/lib/i18n/config";

export const PROFILE_SCHEMA_VERSION = "profile-v1" as const;

export const profileVocabulary = {
  roleFamily: [
    "individual-contributor",
    "people-manager",
    "business-owner",
    "student-transitioner",
    "other",
  ],
  function: [
    "operations",
    "technology-data",
    "sales-marketing",
    "people-support",
    "finance-risk",
    "other",
  ],
  experienceBand: ["early", "mid", "senior", "other"],
  goals: ["adapt-to-change", "improve-judgement", "communicate-impact", "build-evidence", "other"],
  timezone: ["Asia/Bangkok", "Europe/Berlin", "UTC"],
} as const;

export type RoleFamily = (typeof profileVocabulary.roleFamily)[number];
export type WorkFunction = (typeof profileVocabulary.function)[number];
export type ExperienceBand = (typeof profileVocabulary.experienceBand)[number];
export type ProfileGoal = (typeof profileVocabulary.goals)[number];
export type ProfileTimezone = (typeof profileVocabulary.timezone)[number];

type ProfileVocabularyLabels = Readonly<{
  roleFamily: Readonly<Record<RoleFamily, string>>;
  function: Readonly<Record<WorkFunction, string>>;
  experienceBand: Readonly<Record<ExperienceBand, string>>;
  goals: Readonly<Record<ProfileGoal, string>>;
  timezone: Readonly<Record<ProfileTimezone, string>>;
}>;

export const profileVocabularyLabels = {
  th: {
    roleFamily: {
      "individual-contributor": "ผู้ปฏิบัติงานรายบุคคล",
      "people-manager": "ผู้ดูแลทีมหรือบุคลากร",
      "business-owner": "เจ้าของกิจการ",
      "student-transitioner": "ผู้เรียนหรือผู้กำลังเปลี่ยนสายงาน",
      other: "อื่น ๆ (ไม่เก็บข้อความเพิ่มเติม)",
    },
    function: {
      operations: "ปฏิบัติการ",
      "technology-data": "เทคโนโลยีและข้อมูล",
      "sales-marketing": "การขายและการตลาด",
      "people-support": "บุคลากรและงานสนับสนุน",
      "finance-risk": "การเงินและความเสี่ยง",
      other: "อื่น ๆ (ไม่เก็บข้อความเพิ่มเติม)",
    },
    experienceBand: {
      early: "ช่วงเริ่มต้น",
      mid: "ช่วงกลาง",
      senior: "ช่วงอาวุโส",
      other: "อื่น ๆ",
    },
    goals: {
      "adapt-to-change": "ปรับตัวต่อการเปลี่ยนแปลง",
      "improve-judgement": "พัฒนาการตัดสินใจ",
      "communicate-impact": "สื่อสารผลกระทบของงาน",
      "build-evidence": "สร้างหลักฐานผลงาน",
      other: "เป้าหมายอื่น (ไม่เก็บข้อความเพิ่มเติม)",
    },
    timezone: {
      "Asia/Bangkok": "กรุงเทพฯ (UTC+7)",
      "Europe/Berlin": "เบอร์ลิน",
      UTC: "UTC",
    },
  },
  en: {
    roleFamily: {
      "individual-contributor": "Individual contributor",
      "people-manager": "People manager",
      "business-owner": "Business owner",
      "student-transitioner": "Student or career transitioner",
      other: "Other (no free text collected)",
    },
    function: {
      operations: "Operations",
      "technology-data": "Technology and data",
      "sales-marketing": "Sales and marketing",
      "people-support": "People and support",
      "finance-risk": "Finance and risk",
      other: "Other (no free text collected)",
    },
    experienceBand: {
      early: "Early",
      mid: "Mid",
      senior: "Senior",
      other: "Other",
    },
    goals: {
      "adapt-to-change": "Adapt to change",
      "improve-judgement": "Improve judgement",
      "communicate-impact": "Communicate work impact",
      "build-evidence": "Build evidence of work",
      other: "Another goal (no free text collected)",
    },
    timezone: {
      "Asia/Bangkok": "Bangkok (UTC+7)",
      "Europe/Berlin": "Berlin",
      UTC: "UTC",
    },
  },
} as const satisfies Record<Locale, ProfileVocabularyLabels>;
