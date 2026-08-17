import type { Locale } from "@/lib/i18n/config";
import type { PersistedResultExplanationCode } from "@/modules/assessment/persisted-result/types";

export type PersistedResultCopy = Readonly<{
  metadataTitle: string;
  metadataDescription: string;
  eyebrow: string;
  heading: string;
  introduction: string;
  boundaryHeading: string;
  boundaries: readonly string[];
  consentRequiredHeading: string;
  consentRequiredBody: string;
  unavailableHeading: string;
  unavailableBody: string;
  notGeneratedHeading: string;
  notGeneratedBody: string;
  generateLabel: string;
  generatingLabel: string;
  generateError: string;
  assessedHeading: string;
  assessedBody: string;
  rawEvidenceTemplate: string;
  evidenceCountTemplate: string;
  unassessedHeading: string;
  unassessedBody: string;
  multipliersHeading: string;
  multipliersBody: string;
  singleScenarioLabel: string;
  priorityHeading: string;
  priorityUniqueLabel: string;
  priorityUniqueBody: string;
  noPriorityHeading: string;
  noPriorityBody: string;
  prototypeLessonLabel: string;
  prototypeLessonBoundary: string;
  practiceUnavailableLabel: string;
  practiceUnavailableBody: string;
  limitationsHeading: string;
  homeLabel: string;
  attemptLabel: string;
}>;

export const persistedResultCopy = {
  th: {
    metadataTitle: "ผลลัพธ์สังเคราะห์แบบบันทึก | Rise Pals",
    metadataDescription: "ผลลัพธ์อัลฟาสังเคราะห์จากคำตอบที่ส่งแล้ว โดยมีขอบเขตและที่มาอธิบายได้",
    eyebrow: "ผลลัพธ์อัลฟาสังเคราะห์",
    heading: "สัญญาณทักษะจาก 6 สถานการณ์จำลอง",
    introduction:
      "หน้านี้คำนวณซ้ำได้จากคำตอบสังเคราะห์ที่คุณส่งแล้ว แสดงหลักฐานดิบเพียง 2 ทักษะหลัก และไม่ใช่ภาพรวมความสามารถของคุณ",
    boundaryHeading: "อ่านผลนี้อย่างไร",
    boundaries: [
      "แสดงคะแนนดิบจากหลักฐาน 2 ใน 8 ทักษะหลักเท่านั้น โดยไม่ใช้ค่าน้ำหนักของกรอบทักษะ",
      "Ownership Thinking และ Sense of Urgency เป็นเพียงข้อสังเกตด้านละหนึ่งสถานการณ์ และไม่เปลี่ยนคะแนนหรือลำดับทักษะหลัก",
      "ลำดับฝึกต่อไปเป็นข้อเสนอชั่วคราวภายในสองทักษะที่มีหลักฐานครบ ไม่ใช่ช่องว่างทักษะที่ใหญ่ที่สุดของบุคคล",
      "ผลนี้ไม่ใช่แบบประเมินที่ผ่านการตรวจสอบ ไม่ใช่ระดับความสามารถ และห้ามใช้ตัดสินเรื่องงานหรือการจ้างงาน",
    ],
    consentRequiredHeading: "ต้องมีความยินยอมฉบับปัจจุบัน",
    consentRequiredBody:
      "ระบบไม่สร้างหรือแสดงผลลัพธ์เมื่อไม่มีความยินยอมข้อมูลบริการฉบับปัจจุบัน และการถอนความยินยอมไม่ใช่การลบข้อมูล",
    unavailableHeading: "ยังไม่มีเซสชันที่พร้อมสร้างผลลัพธ์",
    unavailableBody:
      "ต้องส่งคำตอบสังเคราะห์ครบทั้งหกข้อในเส้นทางแบบบันทึกก่อน หน้านี้จะไม่สร้างผลลัพธ์จากการเปิดหน้าเพียงอย่างเดียว",
    notGeneratedHeading: "พร้อมสร้างผลลัพธ์อย่างชัดเจน",
    notGeneratedBody:
      "กดปุ่มเพื่อสร้างผลลัพธ์จากเซสชันที่ส่งแล้ว การเปิดหรือรีเฟรชหน้านี้จะไม่สร้างรอบคำนวณใหม่เอง",
    generateLabel: "สร้างผลลัพธ์สังเคราะห์",
    generatingLabel: "กำลังสร้างผลลัพธ์…",
    generateError: "ไม่สามารถสร้างผลลัพธ์ได้อย่างปลอดภัย โปรดลองใหม่โดยไม่เปลี่ยนคำตอบ",
    assessedHeading: "สัญญาณทักษะหลักที่มีหลักฐาน",
    assessedBody: "เศษส่วนต่อไปนี้คือคะแนนดิบจากตัวเลือกที่ส่งแล้ว ไม่ใช่เปอร์เซ็นต์ความสามารถ",
    rawEvidenceTemplate: "ได้ {earned} จาก {available} คะแนนหลักฐาน",
    evidenceCountTemplate: "อ้างอิง {count} สถานการณ์",
    unassessedHeading: "ทักษะหลักที่ยังไม่ได้ประเมิน",
    unassessedBody: "หกทักษะต่อไปนี้ไม่มีแถวคะแนนและไม่เป็นตัวเลือกในการจัดลำดับ",
    multipliersHeading: "ข้อสังเกตตัวคูณพฤติกรรมที่แยกต่างหาก",
    multipliersBody:
      "ข้อสังเกตเหล่านี้ไม่ใช่คะแนนตัวคูณ ไม่ใช่รูปแบบพฤติกรรม และไม่มีผลต่อคะแนนหรือลำดับทักษะหลัก",
    singleScenarioLabel: "หลักฐาน 1 สถานการณ์",
    priorityHeading: "ตัวอย่างลำดับฝึกต่อไปแบบชั่วคราว",
    priorityUniqueLabel: "สัญญาณต่ำสุดที่แตกต่างกันภายใน 2 ทักษะที่ประเมิน",
    priorityUniqueBody:
      "ระบบเปรียบเทียบเศษส่วนคะแนนดิบอย่างแม่นยำโดยไม่ใช้ค่าน้ำหนัก โปรไฟล์ หรือข้อสังเกตตัวคูณ",
    noPriorityHeading: "ยังไม่มีลำดับที่แตกต่างกัน",
    noPriorityBody:
      "สัญญาณทักษะหลักสองด้านเท่ากัน ระบบจึงไม่ฝืนเลือกลำดับด้วยค่าน้ำหนัก ลำดับในกรอบ โปรไฟล์ หรือข้อสังเกตตัวคูณ",
    prototypeLessonLabel: "เปิดบทเรียนต้นแบบการตรวจสอบแหล่งข้อมูล",
    prototypeLessonBoundary:
      "บทเรียนนี้ยังเป็นต้นแบบ และลิงก์นี้เป็นเพียงการฝึกต่อจากลำดับชั่วคราวของข้อมูลสังเคราะห์",
    practiceUnavailableLabel: "ยังไม่มีแบบฝึก Systematic Thinking ที่ตรงกับรุ่นนี้",
    practiceUnavailableBody:
      "Rise Pals จะไม่สร้างลิงก์บทเรียนที่ยังไม่มีอยู่จริงหรืออ้างว่าคำแนะนำนี้ผ่านการตรวจสอบแล้ว",
    limitationsHeading: "ข้อจำกัดที่ต้องเห็นพร้อมผลลัพธ์",
    homeLabel: "กลับหน้าหลัก",
    attemptLabel: "กลับไปยังเซสชันแบบบันทึก",
  },
  en: {
    metadataTitle: "Persisted synthetic result | Rise Pals",
    metadataDescription:
      "A reproducible synthetic-alpha result from submitted responses, with explicit provenance and limitations.",
    eyebrow: "Synthetic-alpha result",
    heading: "Skill signals from six synthetic scenarios",
    introduction:
      "This page is reproducible from your submitted synthetic responses. It shows raw evidence for only two core competencies and is not a complete profile.",
    boundaryHeading: "How to read this result",
    boundaries: [
      "It shows raw evidence for only 2 of 8 core competencies and does not use framework weights.",
      "Ownership Thinking and Sense of Urgency are separate one-scenario observations that never change core scores or priority.",
      "The next-practice priority is provisional within two fully evidenced cores; it is not the person's largest overall skill gap.",
      "This is not a validated assessment or proficiency level and must not be used for employment decisions.",
    ],
    consentRequiredHeading: "Current consent is required",
    consentRequiredBody:
      "The service does not generate or reveal a result without current service-data consent. Withdrawal is not presented as deletion.",
    unavailableHeading: "No submitted session is ready",
    unavailableBody:
      "Submit all six synthetic responses in the persisted path first. Merely opening this page never creates a result.",
    notGeneratedHeading: "Explicitly generate the result",
    notGeneratedBody:
      "Use the button to derive a result from the submitted session. Opening or refreshing this page does not create another scoring run.",
    generateLabel: "Generate synthetic result",
    generatingLabel: "Generating result…",
    generateError: "The result could not be generated safely. Retry without changing responses.",
    assessedHeading: "Core signals with evidence",
    assessedBody:
      "These fractions are raw rubric evidence from submitted choices, not proficiency percentages.",
    rawEvidenceTemplate: "{earned} of {available} evidence points",
    evidenceCountTemplate: "Supported by {count} scenarios",
    unassessedHeading: "Unassessed core competencies",
    unassessedBody: "These six competencies have no score row and are not priority candidates.",
    multipliersHeading: "Separate behavioral-multiplier observations",
    multipliersBody:
      "These are not multiplier scores or behavioral patterns and do not affect core scores or priority.",
    singleScenarioLabel: "1 scenario of evidence",
    priorityHeading: "Provisional example next-practice priority",
    priorityUniqueLabel: "Unique lowest signal within the 2 assessed cores",
    priorityUniqueBody:
      "The service compares exact raw-score fractions without framework weights, profile data, or multiplier observations.",
    noPriorityHeading: "No distinct priority",
    noPriorityBody:
      "The two core signals are tied, so the service does not break the tie by weight, framework order, profile, or multiplier.",
    prototypeLessonLabel: "Open the source-verification prototype lesson",
    prototypeLessonBoundary:
      "This lesson remains a prototype. The link is only a next practice from a provisional synthetic-data priority.",
    practiceUnavailableLabel: "A matching Systematic Thinking practice is unavailable",
    practiceUnavailableBody:
      "Rise Pals does not invent a lesson link or imply that this recommendation has been validated.",
    limitationsHeading: "Limitations shown with the result",
    homeLabel: "Return home",
    attemptLabel: "Return to the persisted attempt",
  },
} as const satisfies Record<Locale, PersistedResultCopy>;

export const persistedResultExplanationCopy = {
  "synthetic-partial-result-limitation": {
    th: "ผลนี้มาจากข้อมูลอัลฟาสังเคราะห์ 6 สถานการณ์ ครอบคลุมทักษะหลักเพียง 2 จาก 8 ด้าน",
    en: "This result comes from six synthetic-alpha scenarios and covers only 2 of 8 core competencies.",
  },
  "assessed-core-raw-signal": {
    th: "สัญญาณนี้อธิบายคะแนนดิบจากสถานการณ์ที่ระบุเท่านั้น และไม่ใช่ระดับความสามารถ",
    en: "This signal explains raw points from the identified scenarios and is not a proficiency level.",
  },
  "single-scenario-multiplier-observation": {
    th: "หนึ่งสถานการณ์ไม่เพียงพอที่จะสรุปรูปแบบพฤติกรรม",
    en: "One scenario cannot establish a behavioral pattern.",
  },
  "unique-lowest-assessed-core-signal": {
    th: "ลำดับนี้มาจากสัดส่วนคะแนนดิบที่ต่ำกว่าอย่างแตกต่างกันภายในสองทักษะที่ประเมินเท่านั้น",
    en: "This priority comes only from the uniquely lower raw-score ratio within the two assessed cores.",
  },
  "no-distinct-priority": {
    th: "สัดส่วนคะแนนดิบเท่ากัน จึงไม่มีการบังคับเลือกลำดับฝึกต่อไป",
    en: "The raw-score ratios are tied, so no next-practice priority is forced.",
  },
} as const satisfies Readonly<
  Record<PersistedResultExplanationCode, Readonly<Record<Locale, string>>>
>;
