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
    eyebrow: "ผลงานของคุณ",
    indexHeading: "บันทึกส่วนตัว",
    indexIntroduction: "ดูบันทึกจำลองของคุณ ยังแชร์หรือเผยแพร่ไม่ได้",
    artifactHeading: "บันทึกการตรวจสอบแหล่งข้อมูล",
    artifactIntroduction: "เลือกข้อมูลสมมติที่เตรียมไว้จากกรณีทีมปฏิบัติการไบรต์ริเวอร์",
    privateLabel: "เฉพาะคุณเท่านั้น",
    prototypeLabel: "เดโม · ยังใช้รับรองทักษะหรือผลการเรียนรู้ไม่ได้",
    syntheticBoundary:
      "ใช้เฉพาะกรณีสมมติที่ให้ไว้ ห้ามใส่ข้อมูลจริงของคน ที่ทำงาน ลูกค้า โครงการ หรือข้อมูลลับ",
    noSharing: "ยังแชร์ ส่งออก ดาวน์โหลด หรือให้คนนอกตรวจไม่ได้",
    boundariesHeading: "ก่อนใช้บันทึกนี้",
    boundaries: [
      "เก็บเฉพาะตัวเลือก ไม่มีช่องพิมพ์ ลิงก์ ไฟล์ หรืออัปโหลด",
      "สถานะพร้อมแปลว่าข้อมูลครบ ไม่ใช่ใบรับรองทักษะหรือความพร้อมทำงาน",
      "ถอนบันทึกแล้วจะอ่านได้อย่างเดียว ข้อมูลยังไม่ถูกลบ",
      "ไม่มี XP คะแนน คำแนะนำเฉพาะคุณ หรือการเปลี่ยนระดับทักษะ",
    ],
    unavailableHeading: "ยังสร้างบันทึกไม่ได้",
    unavailableBody: "ฝึกบทเรียนแบบบันทึกผลให้ผ่านครบทุกข้อก่อนนะ",
    consentHeading: "ยินยอมใช้ข้อมูลก่อน",
    consentBody: "ไปที่การเริ่มต้นใช้งานเพื่อทบทวนและให้ความยินยอมก่อนอ่านหรือแก้ไขหลักฐานส่วนตัว",
    signInHeading: "เข้าสู่ระบบก่อนนะ",
    notStarted: "ยังไม่ได้เริ่ม",
    draft: "ฉบับร่าง",
    ready: "พร้อมตามโครงสร้างจำลอง",
    withdrawn: "ถอนออกจากการใช้งานแล้ว",
    openArtifact: "เปิดบันทึกหลักฐานส่วนตัว",
    learningEvidenceLink: "สร้างบันทึกจากการฝึก",
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
    readyLabel: "ตรวจความครบถ้วน",
    withdrawLabel: "ถอนหลักฐานจากการใช้งาน",
    saved: "บันทึกฉบับร่างบนเซิร์ฟเวอร์แล้ว",
    readyMessage: "บันทึกครบตามโครงสร้างจำลองและเปลี่ยนเป็นอ่านอย่างเดียวแล้ว",
    withdrawnMessage: "ถอนหลักฐานแล้ว บันทึกยังคงอยู่แบบอ่านอย่างเดียวและไม่ได้ถูกลบ",
    conflict: "มีฉบับใหม่กว่าหรือรหัสคำสั่งขัดแย้ง โปรดโหลดหน้าใหม่ก่อนดำเนินการต่อ",
    failed: "ดำเนินการไม่สำเร็จ โปรดลองใหม่โดยไม่ส่งซ้ำอย่างรวดเร็ว",
    notReady: "ยังไม่ครบ ลองดูผลตรวจแต่ละส่วนนะ",
    feedbackHeading: "ผลตรวจบันทึก",
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
    eyebrow: "YOUR WORK",
    indexHeading: "Private records",
    indexIntroduction: "Your fictional practice records. Sharing isn’t available yet.",
    artifactHeading: "Source verification note",
    artifactIntroduction:
      "Build a note from Bright River Operations using only the controlled synthetic values provided by Rise Pals.",
    privateLabel: "Private to this account",
    prototypeLabel: "Demo · not a validated skill or learning outcome",
    syntheticBoundary:
      "Use the provided fictional case only. No real personal, employer, client, project or confidential data.",
    noSharing: "No sharing, exports, downloads or external review yet.",
    boundariesHeading: "About these records",
    boundaries: [
      "Only selected options are saved. No text, links, files or uploads.",
      "Ready means the record is complete, not a skill certificate or hiring signal.",
      "Withdrawal makes a record read-only. It does not delete data.",
      "No XP, scores, personal advice or skill-level changes.",
    ],
    unavailableHeading: "You can’t create a record yet",
    unavailableBody: "Meet all criteria in the saved practice first.",
    consentHeading: "Current service-data consent is required",
    consentBody:
      "Open onboarding to review and grant current consent before reading or changing private evidence.",
    signInHeading: "Sign in required",
    notStarted: "Not started",
    draft: "Draft",
    ready: "Ready under the synthetic checklist",
    withdrawn: "Withdrawn from use",
    openArtifact: "Open the private evidence note",
    learningEvidenceLink: "Create a practice record",
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
    readyLabel: "Check completeness",
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
