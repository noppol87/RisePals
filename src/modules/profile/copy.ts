import type { Locale } from "@/lib/i18n/config";

export type ProfileCopy = Readonly<{
  eyebrow: string;
  onboardingHeading: string;
  profileHeading: string;
  introduction: string;
  provisional: string;
  consentStatus: string;
  consentStates: Readonly<Record<"none" | "granted" | "declined" | "withdrawn", string>>;
  grant: string;
  decline: string;
  withdraw: string;
  withdrawalBoundary: string;
  roleFamily: string;
  function: string;
  experienceBand: string;
  timezone: string;
  goals: string;
  goalHint: string;
  save: string;
  logout: string;
  unavailableHeading: string;
  unavailableBody: string;
  signInHeading: string;
  signInIntroduction: string;
  syntheticBoundary: string;
  localizationFallback: string;
  accountStateHeading: string;
  accountState: Readonly<Record<"suspended" | "deletion_pending" | "deleted", string>>;
}>;

export const profileCopy = {
  th: {
    eyebrow: "โปรไฟล์อัลฟาแบบข้อมูลสังเคราะห์",
    onboardingHeading: "ตั้งค่าโปรไฟล์แบบควบคุม",
    profileHeading: "โปรไฟล์ของคุณ",
    introduction:
      "เลือกรหัสที่ใกล้เคียงที่สุด ระบบไม่เก็บชื่อนายจ้าง ตำแหน่งงานแบบเจาะจง เงินเดือน เลขประจำตัว หรือข้อความกังวลด้านอาชีพ",
    provisional:
      "ชุดตัวเลือก profile-v1 นี้เป็นเพียงคำศัพท์ชั่วคราวสำหรับอัลฟา และยังไม่ผ่านการตรวจสอบกับผู้ใช้จริง",
    consentStatus: "สถานะความยินยอมข้อมูลบริการ",
    consentStates: {
      none: "ยังไม่ได้เลือก",
      granted: "ยินยอม",
      declined: "ปฏิเสธ",
      withdrawn: "ถอนความยินยอม",
    },
    grant: "ยินยอมสำหรับข้อมูลบริการ",
    decline: "ปฏิเสธ",
    withdraw: "ถอนความยินยอม",
    withdrawalBoundary: "การถอนความยินยอมไม่ใช่การลบบัญชีหรือข้อมูล",
    roleFamily: "ลักษณะบทบาท",
    function: "สายงาน",
    experienceBand: "ช่วงประสบการณ์",
    timezone: "เขตเวลา",
    goals: "เป้าหมาย (เลือก 1–3 ข้อ)",
    goalHint: "เป้าหมายเป็นข้อมูลอาชีพที่มีความละเอียดอ่อน",
    save: "บันทึกโปรไฟล์",
    logout: "ออกจากระบบ",
    unavailableHeading: "ยังไม่ได้เชื่อมต่อการยืนยันตัวตนทดลอง",
    unavailableBody:
      "หน้านี้พร้อมสำหรับ Clerk Development แต่เครื่องนี้ยังไม่มีคู่กุญแจ Development ที่ Jeff จัดเตรียมไว้ จึงไม่สร้างบัญชีหรือข้อมูลใด ๆ",
    signInHeading: "เข้าสู่ระบบอัลฟาด้วยอีเมลโค้ด",
    signInIntroduction: "ใช้เฉพาะอีเมลทดสอบสังเคราะห์ใน Clerk Development ห้ามใช้ข้อมูลบุคคลจริง",
    syntheticBoundary:
      "Clerk เก็บข้อมูลตัวตนทดลองในสหรัฐอเมริกา และยังไม่ได้รับอนุมัติสำหรับระบบจริง",
    localizationFallback:
      "การแปลส่วนยืนยันตัวตนของ Clerk ยังเป็นฟีเจอร์ทดลอง หากข้อความใดแสดงเป็นอังกฤษ ให้ยึดประกาศภาษาไทยในหน้านี้เป็นหลัก",
    accountStateHeading: "บัญชีนี้ยังใช้งานโปรไฟล์ไม่ได้",
    accountState: {
      suspended: "บัญชีถูกระงับ ระบบจึงปฏิเสธการเข้าถึงข้อมูลแบบไม่เปิดเผยรายละเอียดเพิ่มเติม",
      deletion_pending: "บัญชีอยู่ระหว่างรอการลบ ระบบจึงปฏิเสธการเข้าถึงข้อมูล",
      deleted: "บัญชีถูกทำเครื่องหมายว่าลบแล้ว ระบบจึงปฏิเสธการเข้าถึงข้อมูล",
    },
  },
  en: {
    eyebrow: "Synthetic alpha profile",
    onboardingHeading: "Set up a controlled profile",
    profileHeading: "Your profile",
    introduction:
      "Choose the closest controlled codes. The service does not collect employer name, exact job title, salary, national identifier or free-text career concerns.",
    provisional:
      "This profile-v1 vocabulary is provisional for alpha testing and has not been validated with real users.",
    consentStatus: "Service-data consent status",
    consentStates: {
      none: "No decision yet",
      granted: "Granted",
      declined: "Declined",
      withdrawn: "Withdrawn",
    },
    grant: "Grant service-data consent",
    decline: "Decline",
    withdraw: "Withdraw consent",
    withdrawalBoundary: "Withdrawal is not account or data deletion.",
    roleFamily: "Role family",
    function: "Work function",
    experienceBand: "Experience band",
    timezone: "Timezone",
    goals: "Goals (choose 1–3)",
    goalHint: "Goals are sensitive career data.",
    save: "Save profile",
    logout: "Sign out",
    unavailableHeading: "Synthetic authentication is not connected",
    unavailableBody:
      "This route is prepared for Clerk Development, but this machine does not have Jeff-supplied Development keys. No account or data was created.",
    signInHeading: "Sign in to the alpha with an email code",
    signInIntroduction:
      "Use synthetic test email identities in Clerk Development only. Real personal data is prohibited.",
    syntheticBoundary:
      "Clerk hosts synthetic identity data in the United States and is not approved for production.",
    localizationFallback:
      "Clerk localization is experimental. If vendor UI copy falls back to English, this page remains the authoritative product boundary.",
    accountStateHeading: "This account cannot access the profile",
    accountState: {
      suspended:
        "The account is suspended, so access fails closed without exposing further details.",
      deletion_pending: "The account is pending deletion, so access fails closed.",
      deleted: "The account is marked deleted, so access fails closed.",
    },
  },
} as const satisfies Record<Locale, ProfileCopy>;
