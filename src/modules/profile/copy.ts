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
  signUpHeading: string;
  signUpIntroduction: string;
  syntheticBoundary: string;
  localizationFallback: string;
  accountStateHeading: string;
  accountState: Readonly<Record<"suspended" | "deletion_pending" | "deleted", string>>;
}>;

export const profileCopy = {
  th: {
    eyebrow: "บัญชีทดลอง",
    onboardingHeading: "ตั้งค่าโปรไฟล์",
    profileHeading: "โปรไฟล์ของคุณ",
    introduction:
      "เลือกสายงานและเป้าหมายที่ใกล้เคียงคุณ ไม่ต้องใส่ชื่อนายจ้าง ตำแหน่งเฉพาะ เงินเดือน เลขประจำตัว หรือเรื่องส่วนตัว",
    provisional: "ตัวเลือกชุดนี้ใช้ทดสอบเท่านั้น ยังไม่ผ่านการทดสอบกับผู้ใช้จริง",
    consentStatus: "การยินยอมใช้ข้อมูล",
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
    roleFamily: "ลักษณะงาน",
    function: "สายงาน",
    experienceBand: "ประสบการณ์",
    timezone: "เขตเวลา",
    goals: "เป้าหมาย (เลือก 1–3 ข้อ)",
    goalHint: "เป้าหมายเป็นข้อมูลอาชีพที่มีความละเอียดอ่อน",
    save: "บันทึกโปรไฟล์",
    logout: "ออกจากระบบ",
    unavailableHeading: "ยังเข้าสู่ระบบไม่ได้",
    unavailableBody: "กำลังเตรียมระบบ ลองกลับมาใหม่นะ",
    signInHeading: "เข้าสู่บัญชีทดลอง",
    signInIntroduction: "ใช้รหัสที่ส่งไปยังอีเมลทดสอบ",
    signUpHeading: "สร้างบัญชีทดลอง",
    signUpIntroduction: "เริ่มด้วยอีเมลทดสอบ แล้วรับรหัสยืนยัน",
    syntheticBoundary: "ใช้ข้อมูลและอีเมลสมมติเท่านั้น ยังไม่เปิดรับข้อมูลคนจริง",
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
    eyebrow: "TEST ACCOUNT",
    onboardingHeading: "Set up your profile",
    profileHeading: "Your profile",
    introduction:
      "Choose your work area and goals. No employer name, exact job title, salary, ID number or personal story needed.",
    provisional: "These choices are for testing and have not been validated with real users.",
    consentStatus: "Data consent",
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
    unavailableHeading: "Sign-in isn’t ready yet",
    unavailableBody: "We’re setting things up. Please check back later.",
    signInHeading: "Sign in to your test account",
    signInIntroduction: "Use the code sent to your test email.",
    signUpHeading: "Create a test account",
    signUpIntroduction: "Start with a test email to get your sign-in code.",
    syntheticBoundary:
      "Fictional identities and emails only. Real personal data isn’t accepted yet.",
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
