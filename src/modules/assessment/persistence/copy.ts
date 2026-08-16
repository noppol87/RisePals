import type { Locale } from "@/lib/i18n/config";

export type PersistedAssessmentCopy = Readonly<{
  metadataTitle: string;
  metadataDescription: string;
  eyebrow: string;
  heading: string;
  introduction: string;
  boundaryHeading: string;
  boundaries: readonly string[];
  consentRequiredHeading: string;
  consentRequiredBody: string;
  consentLink: string;
  unavailableHeading: string;
  unavailableBody: string;
  startHeading: string;
  startBody: string;
  startLabel: string;
  localPrototypeLink: string;
  positionTemplate: string;
  answeredTemplate: string;
  optionHint: string;
  saveLabel: string;
  saveAndReviewLabel: string;
  backLabel: string;
  answerRequired: string;
  saveConflict: string;
  saveFailed: string;
  savedStatus: string;
  reviewHeading: string;
  reviewBody: string;
  editLabel: string;
  submitLabel: string;
  submitFailed: string;
  completionEyebrow: string;
  completionHeading: string;
  completionBody: string;
  completionBoundary: string;
  homeLabel: string;
}>;

export const persistedAssessmentCopy = {
  th: {
    metadataTitle: "บันทึกการตอบสถานการณ์จำลอง | Rise Pals",
    metadataDescription: "เส้นทางอัลฟาสำหรับบันทึกคำตอบดิบของสถานการณ์จำลองอย่างมีขอบเขต",
    eyebrow: "อัลฟาที่ต้องลงชื่อเข้าใช้",
    heading: "บันทึกการตอบ 6 สถานการณ์จำลองอย่างปลอดภัย",
    introduction:
      "เส้นทางนี้เป็นต้นแบบแยกต่างหากสำหรับทดสอบการบันทึกคำตอบดิบในฐานข้อมูล โดยไม่คัดลอกคำตอบชั่วคราวจากแท็บเบราว์เซอร์",
    boundaryHeading: "ข้อมูลและขอบเขต",
    boundaries: [
      "ระบบบันทึกเฉพาะรหัสตัวเลือกของสถานการณ์จำลอง รุ่นแบบประเมิน และประวัติการแก้คำตอบ",
      "ระบบไม่บันทึกข้อความอิสระ คะแนน ผลลัพธ์ ระดับความสามารถ คำแนะนำ หรือข้อสรุปเกี่ยวกับการจ้างงาน",
      "คำตอบเป็นข้อมูลอาชีพอ่อนไหวระดับ P3 สำหรับอัลฟาสังเคราะห์เท่านั้น ห้ามใช้ข้อมูลบุคคลจริง",
      "การเริ่มเส้นทางนี้จะไม่อ่าน นำเข้า หรือแก้ไขคำตอบใน sessionStorage ของต้นแบบเดิม",
    ],
    consentRequiredHeading: "ต้องให้ความยินยอมฉบับปัจจุบันก่อน",
    consentRequiredBody:
      "ยังไม่มีการสร้างเซสชันหรือบันทึกคำตอบ โปรดตรวจประกาศความเป็นส่วนตัวอัลฟาและให้ความยินยอมสำหรับข้อมูลบริการก่อน",
    consentLink: "ไปยังการตั้งค่าความยินยอม",
    unavailableHeading: "ยังไม่พร้อมเริ่มการตอบแบบบันทึก",
    unavailableBody:
      "ข้อมูลสถานการณ์จำลองรุ่นที่ยอมรับยังไม่พร้อมในฐานข้อมูล จึงไม่มีการสร้างเซสชันหรือบันทึกคำตอบ",
    startHeading: "เริ่มเซสชันใหม่อย่างชัดเจน",
    startBody:
      "เมื่อกดเริ่ม ระบบจะสร้างเซสชันหนึ่งรายการที่ผูกกับบัญชีภายใน ความยินยอมปัจจุบัน และรุ่นสถานการณ์ที่เผยแพร่แล้ว",
    startLabel: "เริ่มการตอบแบบบันทึก",
    localPrototypeLink: "กลับไปต้นแบบชั่วคราวที่ไม่ส่งคำตอบไปเซิร์ฟเวอร์",
    positionTemplate: "สถานการณ์ {current} จาก {total}",
    answeredTemplate: "บันทึกแล้ว {answered} จาก {total} สถานการณ์",
    optionHint: "เลือกหนึ่งคำตอบแล้วบันทึกก่อนดำเนินการต่อ",
    saveLabel: "บันทึกและไปข้อต่อไป",
    saveAndReviewLabel: "บันทึกและตรวจทาน",
    backLabel: "ย้อนกลับ",
    answerRequired: "โปรดเลือกหนึ่งคำตอบก่อนบันทึก",
    saveConflict: "คำตอบถูกแก้จากอีกหน้าต่างแล้ว ระบบโหลดรุ่นล่าสุด โปรดตรวจและบันทึกอีกครั้ง",
    saveFailed: "ไม่สามารถบันทึกคำตอบได้อย่างปลอดภัย โปรดลองใหม่",
    savedStatus: "บันทึกคำตอบแล้ว",
    reviewHeading: "ตรวจทานก่อนส่ง",
    reviewBody:
      "คำตอบทั้งหกถูกบันทึกแล้ว การส่งจะล็อกเซสชันนี้ถาวรในขอบเขตอัลฟาและยังไม่สร้างคะแนนหรือผลลัพธ์",
    editLabel: "กลับไปแก้คำตอบ",
    submitLabel: "ส่งและล็อกคำตอบดิบ",
    submitFailed: "ยังส่งไม่ได้ โปรดตรวจว่าบันทึกครบทุกสถานการณ์แล้ว",
    completionEyebrow: "ส่งคำตอบดิบแล้ว",
    completionHeading: "เซสชันถูกล็อกเรียบร้อย",
    completionBody:
      "ระบบเก็บคำตอบดิบทั้งหกและประวัติการแก้ไขตามบัญชีของคุณ การรีเฟรชหรือเข้าสู่ระบบใหม่จะแสดงสถานะส่งแล้วนี้",
    completionBoundary:
      "ไม่มีคะแนน ผลลัพธ์ คำแนะนำ ระดับความสามารถ การวิเคราะห์บุคลิกภาพ หรือข้อสรุปเกี่ยวกับงานใน RP-TURN-012",
    homeLabel: "กลับหน้าหลัก",
  },
  en: {
    metadataTitle: "Persisted synthetic assessment attempt | Rise Pals",
    metadataDescription: "A bounded alpha path for persisting raw synthetic-scenario responses.",
    eyebrow: "Signed-in alpha",
    heading: "Persist responses to six synthetic scenarios safely",
    introduction:
      "This separate prototype tests database persistence of raw responses. It never copies temporary answers from the browser-tab prototype.",
    boundaryHeading: "Data and use boundaries",
    boundaries: [
      "The service stores only synthetic-scenario option IDs, the exact assessment version, and answer revision history.",
      "It stores no free text, score, result, proficiency, recommendation, or employment inference.",
      "Responses are sensitive P3 career data for synthetic alpha use only. Real personal data is prohibited.",
      "Starting this path never reads, imports, or changes the original prototype's sessionStorage answers.",
    ],
    consentRequiredHeading: "Current consent is required first",
    consentRequiredBody:
      "No session or response has been created. Review the alpha privacy notice and grant current service-data consent before continuing.",
    consentLink: "Open consent settings",
    unavailableHeading: "The persisted attempt is not available",
    unavailableBody:
      "The accepted published synthetic-scenario version is unavailable in PostgreSQL, so no session or response was created.",
    startHeading: "Explicitly start one session",
    startBody:
      "Starting creates one session anchored to your internal account, the current consent receipt, and the exact published scenario version.",
    startLabel: "Start the persisted attempt",
    localPrototypeLink: "Return to the temporary prototype that sends no answers to the server",
    positionTemplate: "Scenario {current} of {total}",
    answeredTemplate: "Saved {answered} of {total} scenarios",
    optionHint: "Choose one response and save it before continuing.",
    saveLabel: "Save and continue",
    saveAndReviewLabel: "Save and review",
    backLabel: "Back",
    answerRequired: "Choose one response before saving.",
    saveConflict:
      "This answer changed in another window. The latest revision is loaded; review it and save again.",
    saveFailed: "The answer could not be saved safely. Try again.",
    savedStatus: "Response saved.",
    reviewHeading: "Review before submission",
    reviewBody:
      "All six responses are saved. Submission permanently locks this alpha session and still creates no score or result.",
    editLabel: "Return to edit responses",
    submitLabel: "Submit and lock raw responses",
    submitFailed: "Submission is not ready. Confirm that every scenario is saved.",
    completionEyebrow: "Raw responses submitted",
    completionHeading: "The session is locked",
    completionBody:
      "The service retains six raw responses and their revision history for your account. Refreshing or signing in again restores this submitted state.",
    completionBoundary:
      "RP-TURN-012 provides no score, result, recommendation, proficiency, personality analysis, or employment inference.",
    homeLabel: "Return home",
  },
} as const satisfies Record<Locale, PersistedAssessmentCopy>;
