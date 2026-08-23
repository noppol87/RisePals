import type { Locale } from "@/lib/i18n/config";
import type { EvidenceFieldId, EvidenceFitCheckId } from "@/modules/evidence/types";

type FeedbackCopy = Readonly<
  Record<
    EvidenceFieldId,
    Readonly<{
      complete: string;
      incomplete: string;
      needsReview: string;
    }>
  >
>;

export type EvidenceCopy = Readonly<{
  metadataTitle: string;
  metadataDescription: string;
  eyebrow: string;
  indexHeading: string;
  indexIntroduction: string;
  artifactHeading: string;
  artifactIntroduction: string;
  privateLabel: string;
  prototypeLabel: string;
  syntheticBoundary: string;
  noSharing: string;
  boundariesHeading: string;
  boundaries: readonly string[];
  unavailableHeading: string;
  unavailableBody: string;
  consentHeading: string;
  consentBody: string;
  signInHeading: string;
  notStarted: string;
  draft: string;
  ready: string;
  withdrawn: string;
  openArtifact: string;
  learningEvidenceLink: string;
  startLabel: string;
  formHeading: string;
  formInstruction: string;
  claimHeading: string;
  claimInstruction: string;
  sourceHeading: string;
  sourceInstruction: string;
  fitHeading: string;
  fitInstruction: string;
  fitLabels: Readonly<Record<EvidenceFitCheckId, string>>;
  correctedHeading: string;
  correctedInstruction: string;
  safeHeading: string;
  safeInstruction: string;
  saveLabel: string;
  readyLabel: string;
  withdrawLabel: string;
  saved: string;
  readyMessage: string;
  withdrawnMessage: string;
  conflict: string;
  failed: string;
  notReady: string;
  feedbackHeading: string;
  revisionTemplate: string;
  backToEvidence: string;
  statusHeading: string;
  readOnlyHeading: string;
  readOnlyBody: string;
  feedback: FeedbackCopy;
}>;

export const evidenceCopy = {
  th: {
    metadataTitle: "หลักฐานส่วนตัวแบบมีโครงสร้าง | Rise Pals",
    metadataDescription:
      "พื้นที่อัลฟาสังเคราะห์สำหรับบันทึกการตรวจสอบแหล่งข้อมูลด้วยตัวเลือกควบคุมเท่านั้น",
    eyebrow: "Private structured evidence",
    indexHeading: "พื้นที่หลักฐานส่วนตัว",
    indexIntroduction: "พื้นที่นี้แสดงหลักฐานจำลองของบัญชีคุณเท่านั้น และไม่เปิดให้แชร์หรือเผยแพร่",
    artifactHeading: "บันทึกการตรวจสอบแหล่งข้อมูล",
    artifactIntroduction:
      "สร้างบันทึกจากกรณี Bright River Operations โดยเลือกเฉพาะข้อมูลสมมติที่ระบบเตรียมไว้",
    privateLabel: "ส่วนตัวสำหรับบัญชีนี้เท่านั้น",
    prototypeLabel: "อัลฟาสังเคราะห์ — ยังไม่ผ่านการตรวจสอบความสามารถหรือผลการเรียนรู้",
    syntheticBoundary:
      "ใช้เฉพาะกรณี Bright River Operations ที่สมมติขึ้น ห้ามนำข้อมูลจริงของบุคคล นายจ้าง ลูกค้า โครงการ หรือข้อมูลลับมาใช้",
    noSharing: "หลักฐานนี้แชร์ ส่งออก ดาวน์โหลด หรือให้บุคคลภายนอกตรวจสอบไม่ได้",
    boundariesHeading: "ขอบเขตข้อมูลและความหมาย",
    boundaries: [
      "ระบบเก็บเฉพาะรหัสตัวเลือกที่ควบคุมไว้ ไม่มีข้อความอิสระ ลิงก์ ไฟล์ หรือการอัปโหลด",
      "สถานะพร้อมหมายถึงโครงสร้างจำลองครบตามเกณฑ์เท่านั้น ไม่ใช่ใบรับรอง ระดับทักษะ หรือสัญญาณการจ้างงาน",
      "การถอนหลักฐานทำให้บันทึกอ่านอย่างเดียว แต่ไม่ใช่การลบหรือการใช้สิทธิ์ลบข้อมูล",
      "ไม่มี XP คะแนนแบบประเมิน คำแนะนำเฉพาะบุคคล หรือการเปลี่ยนระดับความสามารถจากหลักฐานนี้",
    ],
    unavailableHeading: "ยังสร้างหลักฐานนี้ไม่ได้",
    unavailableBody: "ต้องผ่านแบบฝึกตรวจสอบแหล่งข้อมูลฉบับบันทึกความคืบหน้าครบทุกเกณฑ์ก่อน",
    consentHeading: "ต้องให้ความยินยอมข้อมูลบริการเวอร์ชันปัจจุบัน",
    consentBody: "ไปที่การเริ่มต้นใช้งานเพื่อทบทวนและให้ความยินยอมก่อนอ่านหรือแก้ไขหลักฐานส่วนตัว",
    signInHeading: "ต้องลงชื่อเข้าใช้",
    notStarted: "ยังไม่ได้เริ่ม",
    draft: "ฉบับร่าง",
    ready: "พร้อมตามโครงสร้างจำลอง",
    withdrawn: "ถอนออกจากการใช้งานแล้ว",
    openArtifact: "เปิดบันทึกหลักฐานส่วนตัว",
    learningEvidenceLink: "สร้างหลักฐานส่วนตัวจากแบบฝึกที่ผ่านครบแล้ว",
    startLabel: "เริ่มฉบับร่างส่วนตัว",
    formHeading: "เลือกข้อมูลสมมติสำหรับบันทึก",
    formInstruction:
      "ฉบับร่างบันทึกได้แม้ยังไม่ครบ แต่ต้องผ่านรายการตรวจทั้งห้าส่วนจึงทำเครื่องหมายว่าพร้อมได้",
    claimHeading: "1. ข้ออ้างที่ตรวจ",
    claimInstruction: "เลือกข้ออ้างคงที่จากสรุป AI ในกรณีสมมติ",
    sourceHeading: "2. แหล่งอ้างอิง",
    sourceInstruction: "เลือกแหล่งที่จำเป็นเพื่อเห็นผล ขอบเขต และความเสี่ยงที่ยังไม่ปิดตามลำดับ",
    fitHeading: "3. ผลตรวจความพอดี",
    fitInstruction: "ข้ออ้างนี้พอดีกับหลักฐานเพียงใด",
    fitLabels: {
      supported: "หลักฐานรองรับครบตามข้อความ",
      "partially-supported-overgeneralized": "มีหลักฐานบางส่วน แต่ข้อความขยายผลเกินขอบเขต",
      unsupported: "หลักฐานไม่รองรับข้ออ้าง",
    },
    correctedHeading: "4. ข้อความที่แก้ตามหลักฐาน",
    correctedInstruction: "เลือกข้อความจากแบบฝึกที่ตรงกับข้อมูลสมมติมากที่สุด",
    safeHeading: "5. ก้าวถัดไปที่ปลอดภัย",
    safeInstruction: "เลือกการดำเนินการก่อนนำสรุปไปใช้ตัดสินใจ",
    saveLabel: "บันทึกฉบับร่าง",
    readyLabel: "ตรวจและทำเครื่องหมายว่าพร้อม",
    withdrawLabel: "ถอนหลักฐานจากการใช้งาน",
    saved: "บันทึกฉบับร่างบนเซิร์ฟเวอร์แล้ว",
    readyMessage: "บันทึกครบตามโครงสร้างจำลองและเปลี่ยนเป็นอ่านอย่างเดียวแล้ว",
    withdrawnMessage: "ถอนหลักฐานแล้ว บันทึกยังคงอยู่แบบอ่านอย่างเดียวและไม่ได้ถูกลบ",
    conflict: "มีฉบับใหม่กว่าหรือรหัสคำสั่งขัดแย้ง โปรดโหลดหน้าใหม่ก่อนดำเนินการต่อ",
    failed: "ดำเนินการไม่สำเร็จ โปรดลองใหม่โดยไม่ส่งซ้ำอย่างรวดเร็ว",
    notReady: "บันทึกยังไม่ครบตามรายการตรวจ โปรดดู feedback รายส่วน",
    feedbackHeading: "ผลตรวจโครงสร้างที่เปิดเผย",
    revisionTemplate: "ฉบับแก้ไข {revision}",
    backToEvidence: "กลับพื้นที่หลักฐานส่วนตัว",
    statusHeading: "สถานะหลักฐาน",
    readOnlyHeading: "บันทึกนี้อ่านอย่างเดียว",
    readOnlyBody:
      "บันทึกที่พร้อมแล้วแก้ไขไม่ได้ และบันทึกที่ถอนแล้วเปิดใหม่หรือทำให้พร้อมอีกครั้งไม่ได้",
    feedback: {
      claim: {
        complete: "เลือกข้ออ้างสมมติที่กำหนดแล้ว",
        incomplete: "ยังไม่ได้เลือกข้ออ้าง",
        needsReview: "ข้ออ้างไม่ตรงกับกรณีที่อนุมัติ",
      },
      "source-reference": {
        complete: "ครอบคลุมผล ขอบเขต และความเสี่ยงครบแล้ว",
        incomplete: "ยังไม่ได้เลือกแหล่งอ้างอิง",
        needsReview: "ยังขาดแหล่งที่จำเป็นต่อการตรวจสอบครบถ้วน",
      },
      "fit-check": {
        complete: "ระบุการขยายผลเกินหลักฐานได้ถูกต้อง",
        incomplete: "ยังไม่ได้เลือกผลตรวจความพอดี",
        needsReview: "ผลตรวจยังไม่ตรงกับหลักฐานในกรณีสมมติ",
      },
      "corrected-wording": {
        complete: "ข้อความแก้ไขจำกัดขอบเขตตามหลักฐาน",
        incomplete: "ยังไม่ได้เลือกข้อความแก้ไข",
        needsReview: "ข้อความยังแรงหรือกว้างกว่าหลักฐาน",
      },
      "safe-next-action": {
        complete: "ก้าวถัดไปชะลอข้ออ้างและปิดช่องว่าง",
        incomplete: "ยังไม่ได้เลือกก้าวถัดไป",
        needsReview: "ก้าวถัดไปยังปล่อยให้ข้ออ้างไม่ครบถูกนำไปใช้",
      },
    },
  },
  en: {
    metadataTitle: "Private structured evidence | Rise Pals",
    metadataDescription:
      "A synthetic-alpha source-verification note using controlled selections only.",
    eyebrow: "Private structured evidence",
    indexHeading: "Private evidence area",
    indexIntroduction:
      "This area shows only the current account's synthetic evidence and provides no sharing or publication.",
    artifactHeading: "Source verification note",
    artifactIntroduction:
      "Build a note from Bright River Operations using only the controlled synthetic values provided by Rise Pals.",
    privateLabel: "Private to this account",
    prototypeLabel: "Synthetic alpha — not validated proficiency or learning efficacy",
    syntheticBoundary:
      "Use only the fictional Bright River Operations case. Never add real personal, employer, client, project, or confidential information.",
    noSharing:
      "This artifact cannot be shared, exported, downloaded, or verified by an external party.",
    boundariesHeading: "Data and meaning boundary",
    boundaries: [
      "Only controlled option IDs are stored. There is no free text, URL, file, or upload.",
      "Ready means only that the synthetic structure meets its checklist; it is not a credential, skill level, or hiring signal.",
      "Withdrawal makes the record read-only. It is not deletion or an erasure request.",
      "This artifact changes no XP, assessment score, recommendation, or proficiency stage.",
    ],
    unavailableHeading: "This artifact is not available yet",
    unavailableBody:
      "First demonstrate every criterion in the persisted source-verification practice.",
    consentHeading: "Current service-data consent is required",
    consentBody:
      "Open onboarding to review and grant current consent before reading or changing private evidence.",
    signInHeading: "Sign in required",
    notStarted: "Not started",
    draft: "Draft",
    ready: "Ready under the synthetic checklist",
    withdrawn: "Withdrawn from use",
    openArtifact: "Open the private evidence note",
    learningEvidenceLink: "Create private evidence from the demonstrated practice",
    startLabel: "Start a private draft",
    formHeading: "Choose synthetic evidence values",
    formInstruction:
      "A draft may be partial. All five checklist sections must pass before it can be marked ready.",
    claimHeading: "1. Claim reviewed",
    claimInstruction: "Select the fixed AI-summary claim from the synthetic case.",
    sourceHeading: "2. Source references",
    sourceInstruction:
      "Select the sources needed to trace performance, scope, and unresolved risk in canonical order.",
    fitHeading: "3. Claim-fit finding",
    fitInstruction: "How well does this claim fit the evidence?",
    fitLabels: {
      supported: "The wording is fully supported",
      "partially-supported-overgeneralized":
        "Some evidence exists, but the wording overgeneralizes it",
      unsupported: "The evidence does not support the claim",
    },
    correctedHeading: "4. Evidence-supported correction",
    correctedInstruction:
      "Choose the accepted practice wording that best fits the synthetic evidence.",
    safeHeading: "5. Safe next action",
    safeInstruction: "Choose what should happen before the summary informs a decision.",
    saveLabel: "Save draft",
    readyLabel: "Check and mark ready",
    withdrawLabel: "Withdraw artifact from use",
    saved: "The draft was saved on the server.",
    readyMessage: "The note meets the synthetic checklist and is now read-only.",
    withdrawnMessage: "The artifact is withdrawn and remains read-only; it was not deleted.",
    conflict: "A newer revision or conflicting mutation exists. Reload before continuing.",
    failed: "The action failed. Try again without rapidly resubmitting.",
    notReady: "The note does not yet meet the checklist. Review the field feedback.",
    feedbackHeading: "Transparent structure feedback",
    revisionTemplate: "Revision {revision}",
    backToEvidence: "Back to private evidence",
    statusHeading: "Artifact status",
    readOnlyHeading: "This artifact is read-only",
    readOnlyBody:
      "Ready content cannot be edited, and a withdrawn artifact cannot reopen or become ready again.",
    feedback: {
      claim: {
        complete: "The fixed synthetic claim is selected.",
        incomplete: "No claim has been selected.",
        needsReview: "The claim does not match the accepted case.",
      },
      "source-reference": {
        complete: "Performance, scope, and unresolved risk are all traced.",
        incomplete: "No source reference is selected.",
        needsReview: "At least one required source is still missing.",
      },
      "fit-check": {
        complete: "The overgeneralization is identified correctly.",
        incomplete: "No claim-fit finding is selected.",
        needsReview: "The finding does not match the synthetic evidence.",
      },
      "corrected-wording": {
        complete: "The correction stays within the evidence.",
        incomplete: "No corrected wording is selected.",
        needsReview: "The wording remains broader or stronger than the source.",
      },
      "safe-next-action": {
        complete: "The action holds the claim and closes evidence gaps.",
        incomplete: "No safe next action is selected.",
        needsReview: "The action still allows incomplete evidence to influence a decision.",
      },
    },
  },
} as const satisfies Record<Locale, EvidenceCopy>;
