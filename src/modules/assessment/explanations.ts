import type {
  ExplanationCode,
  ExplanationCopy,
  LimitationCode,
  LimitationCopy,
  ProvisionalScoringOutput,
  ScoreExplanationRecord,
} from "@/modules/assessment/types";

export const explanationCopy = {
  "fixture-slice-observation": {
    heading: { th: "สัญญาณจากชุดข้อมูลจำลอง", en: "Signal from a synthetic fixture" },
    body: {
      th: "ผลนี้แสดงเพียงว่าตัวเลือกที่กำหนดไว้เชื่อมกับ rubric อย่างไร เพื่อให้ทีมตรวจสอบ contract ก่อนสร้างแบบประเมินจริง",
      en: "This result only shows how the defined choices map to the rubric so the team can review the contract before building a real assessment.",
    },
  },
  "core-signal-observation": {
    heading: { th: "หลักฐานใน competency นี้", en: "Evidence in this competency" },
    body: {
      th: "ตรวจสอบสถานการณ์และตัวเลือกที่อ้างอิงเพื่อดูว่าคะแนนจำลองเกิดจากการตัดสินใจใด โดยยังไม่ตีความเป็นระดับความสามารถ",
      en: "Review the referenced scenarios and choices to see which decisions produced this fixture signal without treating it as a proficiency level.",
    },
  },
  "multiplier-single-scenario-observation": {
    heading: {
      th: "ข้อสังเกตพฤติกรรมจากหนึ่งสถานการณ์",
      en: "One-scenario behavioral observation",
    },
    body: {
      th: "ใช้ผลนี้เพื่อทบทวนเหตุผลของตัวเลือกเท่านั้น การประเมิน pattern ต้องอาศัยหลักฐานหลายบริบทและการตรวจสอบเพิ่มเติม",
      en: "Use this result only to review the reasoning behind the choice; establishing a pattern requires evidence across contexts and further review.",
    },
  },
} as const satisfies Readonly<Record<ExplanationCode, ExplanationCopy>>;

export const limitationCopy = {
  "not-validated-assessment": {
    body: {
      th: "ชุดสถานการณ์ขนาดเล็กนี้เป็น fixture สำหรับทดสอบระบบ ไม่ใช่แบบประเมินที่ผ่านการตรวจสอบความเที่ยงตรงหรือการสอบเทียบ",
      en: "This small scenario set is a system fixture, not a validated or calibrated assessment.",
    },
  },
  "partial-core-slice": {
    body: {
      th: "ชุดนี้มีหลักฐานต่อ core competencies เพียง 2 จาก 8 ด้าน จึงไม่ใช่ภาพรวมทักษะหรือคะแนน 8+2",
      en: "This slice contains evidence for only 2 of 8 core competencies, so it is not a full skill profile or an 8+2 score.",
    },
  },
  "single-scenario-not-behavior-pattern": {
    body: {
      th: "หนึ่งสถานการณ์ไม่เพียงพอที่จะสรุป pattern ของ Ownership Thinking หรือ Sense of Urgency",
      en: "One scenario cannot establish a pattern for Ownership Thinking or Sense of Urgency.",
    },
  },
  "cannot-predict-job-loss": {
    body: {
      th: "ผลจำลองนี้ไม่สามารถทำนายว่าบุคคลใดจะตกงาน",
      en: "This fixture result cannot predict whether anyone will lose a job.",
    },
  },
  "cannot-predict-job-performance": {
    body: {
      th: "ผลจำลองนี้ไม่สามารถทำนายผลการปฏิบัติงานจริง",
      en: "This fixture result cannot predict real job performance.",
    },
  },
  "cannot-determine-employability": {
    body: {
      th: "ผลจำลองนี้ไม่สามารถตัดสินความสามารถในการได้งานหรือรักษางาน",
      en: "This fixture result cannot determine employability.",
    },
  },
  "cannot-determine-hiring-eligibility": {
    body: {
      th: "ห้ามใช้ผลจำลองนี้ตัดสินคุณสมบัติหรือสิทธิ์ในการจ้างงาน",
      en: "This fixture result must not determine hiring eligibility.",
    },
  },
} as const satisfies Readonly<Record<LimitationCode, LimitationCopy>>;

const runLimitationCodes = [
  "not-validated-assessment",
  "partial-core-slice",
  "cannot-predict-job-loss",
  "cannot-predict-job-performance",
  "cannot-determine-employability",
  "cannot-determine-hiring-eligibility",
] as const satisfies readonly LimitationCode[];

export function deriveExplanationRecords(
  score: ProvisionalScoringOutput,
): readonly ScoreExplanationRecord[] {
  const allSupportingItemKeys = [
    ...score.coreSkillSignals.flatMap((signal) => signal.supportingItemKeys),
    ...score.multiplierObservations.flatMap((observation) => observation.supportingItemKeys),
  ];

  return [
    {
      id: `explanation-${score.assessmentId}`,
      explanationCode: "fixture-slice-observation",
      target: { kind: "assessment", id: score.assessmentId },
      supportingItemKeys: allSupportingItemKeys,
      limitationCodes: runLimitationCodes,
    },
    ...score.coreSkillSignals.map((signal): ScoreExplanationRecord => ({
      id: `explanation-${signal.competencyId}`,
      explanationCode: "core-signal-observation",
      target: { kind: "core", id: signal.competencyId },
      supportingItemKeys: [...signal.supportingItemKeys],
      limitationCodes: ["not-validated-assessment", "partial-core-slice"],
    })),
    ...score.multiplierObservations.map((observation): ScoreExplanationRecord => ({
      id: `explanation-${observation.multiplierId}`,
      explanationCode: "multiplier-single-scenario-observation",
      target: { kind: "multiplier", id: observation.multiplierId },
      supportingItemKeys: [...observation.supportingItemKeys],
      limitationCodes: ["not-validated-assessment", "single-scenario-not-behavior-pattern"],
    })),
  ];
}
