import { FRAMEWORK_VERSION_ID } from "@/modules/assessment/framework";
import type {
  AssessmentDefinition,
  AssessmentItem,
  ScoringModelDefinition,
} from "@/modules/assessment/types";

export const ASSESSMENT_ID = "assessment-workplace-scenarios-fixture-v1";
export const SCORING_MODEL_ID = "scoring-integer-rubric-fixture-v1";

export const assessmentItems = [
  {
    key: "verify-ai-summary-source",
    type: "scenario-choice",
    required: true,
    displayOrder: 1,
    prompt: {
      th: "คุณได้รับสรุปจากเครื่องมือ AI ซึ่งมีตัวเลขสำคัญไม่ตรงกับรายงานต้นฉบับ คุณจะทำอย่างไรต่อ",
      en: "You receive an AI-generated summary whose key figures differ from the original report. What do you do next?",
    },
    options: [
      {
        id: "verify-ai-summary-source-use-draft",
        label: {
          th: "ใช้สรุปนั้นต่อเพราะรูปแบบอ่านง่ายและส่งงานได้เร็ว",
          en: "Use the summary because it is easy to read and keeps the work moving.",
        },
        rubricPoints: 0,
      },
      {
        id: "verify-ai-summary-source-check-claims",
        label: {
          th: "เทียบข้ออ้างกับรายงานต้นฉบับ บันทึกจุดต่าง และแก้เฉพาะส่วนที่ตรวจสอบได้",
          en: "Compare the claims with the original report, record discrepancies, and correct only what can be verified.",
        },
        rubricPoints: 2,
      },
      {
        id: "verify-ai-summary-source-discard-all",
        label: {
          th: "ยกเลิกการใช้สรุปทั้งหมดทันทีโดยยังไม่ตรวจว่ามีส่วนใดถูกต้อง",
          en: "Discard the whole summary immediately without checking whether any parts are accurate.",
        },
        rubricPoints: 1,
      },
    ],
    rubric: {
      targetKind: "core",
      targetId: "critical-thinking-fact-checking",
      availablePoints: 2,
    },
  },
  {
    key: "test-process-assumption",
    type: "scenario-choice",
    required: true,
    displayOrder: 2,
    prompt: {
      th: "ทีมหนึ่งรายงานว่าวิธีทำงานใหม่ช่วยลดเวลาได้จากการทดลองครั้งเดียว คุณต้องตัดสินใจว่าจะขยายผลหรือไม่",
      en: "One team reports that a new workflow saved time in a single trial. You must decide whether to expand it.",
    },
    options: [
      {
        id: "test-process-assumption-roll-out",
        label: {
          th: "ขยายผลทันทีเพราะผลครั้งแรกเป็นบวก",
          en: "Roll it out immediately because the first result was positive.",
        },
        rubricPoints: 0,
      },
      {
        id: "test-process-assumption-define-evidence",
        label: {
          th: "กำหนดตัวชี้วัดและข้อสมมติ ทดลองเพิ่มในขอบเขตเล็ก และตรวจหาหลักฐานที่อาจหักล้างผล",
          en: "Define measures and assumptions, run another bounded trial, and look for evidence that could challenge the result.",
        },
        rubricPoints: 2,
      },
      {
        id: "test-process-assumption-wait-perfect",
        label: {
          th: "หยุดพิจารณาจนกว่าจะมีข้อมูลที่สมบูรณ์ทุกด้าน",
          en: "Pause consideration until complete information is available in every area.",
        },
        rubricPoints: 1,
      },
    ],
    rubric: {
      targetKind: "core",
      targetId: "critical-thinking-fact-checking",
      availablePoints: 2,
    },
  },
  {
    key: "map-downstream-impact",
    type: "scenario-choice",
    required: true,
    displayOrder: 3,
    prompt: {
      th: "ทีมของคุณต้องการเปลี่ยนแบบฟอร์มรับงานเพื่อให้กรอกเร็วขึ้น แต่ข้อมูลบางช่องถูกใช้โดยทีมปลายทางหลายทีม",
      en: "Your team wants to simplify an intake form, but several downstream teams use some of its fields.",
    },
    options: [
      {
        id: "map-downstream-impact-change-local",
        label: {
          th: "เปลี่ยนเฉพาะตามความต้องการของทีมคุณแล้วให้ทีมอื่นปรับตาม",
          en: "Change it for your team's needs and ask other teams to adapt afterward.",
        },
        rubricPoints: 0,
      },
      {
        id: "map-downstream-impact-map-test",
        label: {
          th: "ทำแผนที่ผู้ใช้ข้อมูลและข้อจำกัดต้นน้ำ-ปลายน้ำ แล้วทดลองการเปลี่ยนแปลงกับกลุ่มเล็กก่อน",
          en: "Map upstream and downstream users and constraints, then test the change with a small group first.",
        },
        rubricPoints: 2,
      },
      {
        id: "map-downstream-impact-ask-separately",
        label: {
          th: "ถามความเห็นแต่ละทีมแยกกันโดยยังไม่เชื่อมผลกระทบเป็นภาพรวม",
          en: "Ask each team separately without yet connecting the impacts into one system view.",
        },
        rubricPoints: 1,
      },
    ],
    rubric: {
      targetKind: "core",
      targetId: "systematic-thinking",
      availablePoints: 2,
    },
  },
  {
    key: "trace-recurring-bottleneck",
    type: "scenario-choice",
    required: true,
    displayOrder: 4,
    prompt: {
      th: "งานสำคัญล่าช้าซ้ำ ๆ ที่จุดส่งมอบสุดท้าย แม้ทีมปลายทางจะเพิ่มความพยายามแล้ว",
      en: "Important work is repeatedly delayed at the final handoff even after the downstream team increases its effort.",
    },
    options: [
      {
        id: "trace-recurring-bottleneck-remind-final-team",
        label: {
          th: "ย้ำให้ทีมปลายทางทำงานเร็วขึ้นเพราะเป็นจุดที่เห็นความล่าช้า",
          en: "Remind the downstream team to work faster because that is where the delay is visible.",
        },
        rubricPoints: 0,
      },
      {
        id: "trace-recurring-bottleneck-trace-flow",
        label: {
          th: "ติดตามข้อมูล การตัดสินใจ และความรับผิดชอบตลอด workflow เพื่อหาข้อจำกัดที่สร้างความล่าช้าจริง",
          en: "Trace information, decisions, and ownership across the workflow to locate the constraint creating the delay.",
        },
        rubricPoints: 2,
      },
      {
        id: "trace-recurring-bottleneck-add-status",
        label: {
          th: "เพิ่มการประชุมรายงานสถานะเพื่อให้ทุกคนเห็นความล่าช้าบ่อยขึ้น",
          en: "Add status meetings so everyone sees the delay more often.",
        },
        rubricPoints: 1,
      },
    ],
    rubric: {
      targetKind: "core",
      targetId: "systematic-thinking",
      availablePoints: 2,
    },
  },
  {
    key: "own-shared-outcome",
    type: "scenario-choice",
    required: true,
    displayOrder: 5,
    prompt: {
      th: "คุณส่งรายงานตามหน้าที่ได้ตรงเวลา แต่ปัญหาข้อมูลที่เกิดซ้ำทำให้หลายทีมตัดสินใจช้าลง",
      en: "You deliver your assigned report on time, but a recurring data issue slows decisions across several teams.",
    },
    options: [
      {
        id: "own-shared-outcome-complete-task",
        label: {
          th: "ส่งรายงานตามขอบเขตเดิมต่อไปเพราะงานส่วนของคุณเสร็จแล้ว",
          en: "Continue delivering within the original scope because your part is complete.",
        },
        rubricPoints: 0,
      },
      {
        id: "own-shared-outcome-coordinate-fix",
        label: {
          th: "ชี้ผลกระทบต่อผลลัพธ์ร่วม ชวนผู้เกี่ยวข้องหาเจ้าของปัญหา และช่วยประสานทางแก้ที่วัดผลได้",
          en: "Connect the issue to the shared outcome, establish ownership with the relevant people, and help coordinate a measurable fix.",
        },
        rubricPoints: 2,
      },
      {
        id: "own-shared-outcome-fix-own-copy",
        label: {
          th: "แก้ข้อมูลในไฟล์ของคุณเงียบ ๆ เพื่อให้รายงานรอบนี้ใช้งานได้",
          en: "Quietly correct your own copy so this reporting cycle can proceed.",
        },
        rubricPoints: 1,
      },
    ],
    rubric: {
      targetKind: "multiplier",
      targetId: "ownership-thinking",
      availablePoints: 2,
    },
  },
  {
    key: "move-with-safe-urgency",
    type: "scenario-choice",
    required: true,
    displayOrder: 6,
    prompt: {
      th: "กำหนดส่งถูกเลื่อนให้เร็วขึ้น ขณะที่ยังมีข้อมูลบางส่วนไม่แน่นอนและการเปลี่ยนแปลงอาจกระทบคุณภาพ",
      en: "A deadline moves forward while some information remains uncertain and the change could affect quality.",
    },
    options: [
      {
        id: "move-with-safe-urgency-rush-all",
        label: {
          th: "เร่งเปลี่ยนทุกอย่างทันทีและข้ามการตรวจสอบเพื่อให้ทันเวลา",
          en: "Rush the full change immediately and skip review to meet the date.",
        },
        rubricPoints: 0,
      },
      {
        id: "move-with-safe-urgency-small-step",
        label: {
          th: "เลือกการทดลองเล็กที่ย้อนกลับได้ กำหนด guardrail และเวลาตรวจผล เพื่อเดินหน้าโดยยังรักษาคุณภาพ",
          en: "Choose a small reversible experiment, set guardrails and a review point, and move while protecting quality.",
        },
        rubricPoints: 2,
      },
      {
        id: "move-with-safe-urgency-wait-certainty",
        label: {
          th: "หยุดทุกขั้นตอนจนกว่าความไม่แน่นอนทั้งหมดจะหมดไป",
          en: "Stop all action until every uncertainty is resolved.",
        },
        rubricPoints: 1,
      },
    ],
    rubric: {
      targetKind: "multiplier",
      targetId: "sense-of-urgency",
      availablePoints: 2,
    },
  },
] as const satisfies readonly AssessmentItem[];

export const assessmentDefinition = {
  id: ASSESSMENT_ID,
  assessmentKey: "workplace-scenarios-fixture",
  version: "1.0.0",
  frameworkVersionId: FRAMEWORK_VERSION_ID,
  items: assessmentItems,
} as const satisfies AssessmentDefinition;

export const scoringModelDefinition = {
  id: SCORING_MODEL_ID,
  scoringKey: "integer-rubric-fixture",
  version: "1.0.0",
  assessmentId: ASSESSMENT_ID,
  frameworkVersionId: FRAMEWORK_VERSION_ID,
  method: "deterministic-integer-rubric",
  pointScale: {
    minimum: 0,
    maximum: 2,
    step: 1,
  },
} as const satisfies ScoringModelDefinition;
