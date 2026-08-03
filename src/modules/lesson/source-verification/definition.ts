import { FRAMEWORK_VERSION_ID } from "@/modules/assessment/framework";
import {
  LESSON_CONTENT_CONTRACT_VERSION_ID,
  SOURCE_VERIFICATION_LESSON_KEY,
  SOURCE_VERIFICATION_LESSON_VERSION,
  SOURCE_VERIFICATION_LESSON_VERSION_ID,
  SOURCE_VERIFICATION_PRACTICE_ID,
  SOURCE_VERIFICATION_PROOF_ID,
  SOURCE_VERIFICATION_RUBRIC_VERSION_ID,
  sourceVerificationCriterionIds,
  sourceVerificationProofFieldIds,
  type SourceVerificationLessonDefinition,
} from "@/modules/lesson/source-verification/types";

export const sourceVerificationLessonDefinition = {
  contractVersionId: LESSON_CONTENT_CONTRACT_VERSION_ID,
  lesson: {
    key: SOURCE_VERIFICATION_LESSON_KEY,
    versionId: SOURCE_VERIFICATION_LESSON_VERSION_ID,
    version: SOURCE_VERIFICATION_LESSON_VERSION,
    status: "prototype",
    frameworkVersionId: FRAMEWORK_VERSION_ID,
    targetCompetencyId: "critical-thinking-fact-checking",
    targetWorkingStage: "Practicing",
    primaryRoiPillar: "Intelligent Risk & Governance",
    estimatedActiveMinutes: 8,
    provenance: "git-versioned-local-prototype",
    locales: ["th", "en"],
    practiceId: SOURCE_VERIFICATION_PRACTICE_ID,
    rubricVersionId: SOURCE_VERIFICATION_RUBRIC_VERSION_ID,
    proofId: SOURCE_VERIFICATION_PROOF_ID,
  },
  practice: {
    id: SOURCE_VERIFICATION_PRACTICE_ID,
    version: "1.0.0",
    rubricVersionId: SOURCE_VERIFICATION_RUBRIC_VERSION_ID,
    criterionIds: sourceVerificationCriterionIds,
    options: [
      {
        id: "trace-claim-to-source-map",
        criterionId: "evidence-traceability",
        meetsCriterion: true,
      },
      {
        id: "trace-trust-ai-link-list",
        criterionId: "evidence-traceability",
        meetsCriterion: false,
      },
      {
        id: "trace-remove-source-notes",
        criterionId: "evidence-traceability",
        meetsCriterion: false,
      },
      {
        id: "fit-narrow-to-supported-teams",
        criterionId: "claim-source-fit",
        meetsCriterion: true,
      },
      {
        id: "fit-keep-all-team-claim",
        criterionId: "claim-source-fit",
        meetsCriterion: false,
      },
      {
        id: "fit-convert-to-broad-average",
        criterionId: "claim-source-fit",
        meetsCriterion: false,
      },
      {
        id: "safe-hold-and-resolve-gaps",
        criterionId: "safe-next-action",
        meetsCriterion: true,
      },
      {
        id: "safe-publish-with-small-note",
        criterionId: "safe-next-action",
        meetsCriterion: false,
      },
      {
        id: "safe-ask-ai-for-confidence",
        criterionId: "safe-next-action",
        meetsCriterion: false,
      },
    ],
  },
  rubric: {
    versionId: SOURCE_VERIFICATION_RUBRIC_VERSION_ID,
    version: "1.0.0",
    practiceId: SOURCE_VERIFICATION_PRACTICE_ID,
    demonstratedRequires: "all-criteria-met",
    criteria: [
      {
        id: "rubric-evidence-traceability",
        practiceCriterionId: "evidence-traceability",
      },
      {
        id: "rubric-claim-source-fit",
        practiceCriterionId: "claim-source-fit",
      },
      {
        id: "rubric-safe-next-action",
        practiceCriterionId: "safe-next-action",
      },
    ],
  },
  proof: {
    id: SOURCE_VERIFICATION_PROOF_ID,
    version: "1.0.0",
    status: "placeholder",
    artifactType: "source-verification-note",
    fieldIds: sourceVerificationProofFieldIds,
    capturesInput: false,
  },
  xpRule: {
    versionId: "source-verification-xp-preview-v1",
    viewingPreviewXp: 0,
    incompletePreviewXp: 0,
    demonstratedPreviewXp: 20,
    accumulation: "replace-not-add",
    persisted: false,
  },
  content: {
    th: {
      locale: "th",
      metadata: {
        title: "ต้นแบบบทเรียนตรวจสอบแหล่งข้อมูล | Rise Pals",
        description:
          "บทเรียนและแบบฝึกจำลองเพื่อฝึกเชื่อมข้ออ้างจากสรุปของ AI กับแหล่งข้อมูล โดยไม่เก็บคำตอบหรือความก้าวหน้า",
      },
      hero: {
        eyebrow: "Learn → Practice → Feedback → Proof placeholder",
        heading: "ตรวจข้ออ้างจากสรุปของ AI ก่อนนำไปใช้ตัดสินใจ",
        introduction:
          "บทเรียนสั้นนี้สาธิตการเปลี่ยนจากการอ่านเนื้อหาไปสู่การตัดสินใจ ตรวจด้วยเกณฑ์ที่เปิดเผย และเห็นรูปแบบหลักฐานที่อาจสร้างในอนาคต",
        prototypeLabel:
          "ต้นแบบเนื้อหาใน repository — ยังไม่เผยแพร่และยังไม่ผ่านการตรวจสอบผลการเรียนรู้",
        boundary:
          "สถานการณ์ องค์กร เอกสาร และตัวเลขทั้งหมดเป็นข้อมูลสมมติ บทเรียนไม่อ่านคำตอบจากแบบประเมิน และลิงก์นี้ไม่ใช่คำแนะนำเฉพาะบุคคล",
      },
      overview: {
        heading: "ขอบเขตของบทเรียนต้นแบบ",
        targetLabel: "ทักษะเป้าหมาย",
        stageLabel: "ระดับฝึกใช้งานที่ตั้งใจ",
        roiLabel: "เสาหลัก R.O.I.",
        timeLabel: "เวลาลงมือโดยประมาณ",
        timeValue: "ประมาณ 8 นาที",
      },
      scenario: {
        heading: "สถานการณ์สมมติ: สรุปผลโครงการที่กว้างกว่าหลักฐาน",
        introduction:
          "ทีมของคุณได้รับร่างสรุปจาก AI เพื่อใช้ในการประชุมผู้บริหาร คุณต้องตัดสินใจก่อนว่าข้อความใดใช้ได้และต้องทำอะไรต่อ",
        syntheticLabel: "ข้อมูลทั้งหมดในกรณีนี้สร้างขึ้นเพื่อการทดสอบต้นแบบเท่านั้น",
        organizationLabel: "องค์กรสมมติ",
        organization: "Bright River Operations",
        documentLabel: "เอกสารสมมติ",
        document: "ร่างทบทวนโครงการบริการ รุ่น 0.3",
        aiSummaryLabel: "ข้อความจากสรุปของ AI",
        aiSummary: "“ทั้งสามทีมลดเวลาปิดงานได้ 30% และโครงการไม่พบความเสี่ยงด้านการยกระดับปัญหา”",
        sourceHeading: "ข้อมูลในชุดเอกสารต้นฉบับสมมติ",
        sourceRecords: [
          {
            id: "pilot-table",
            label: "ตารางผลโครงการ",
            detail:
              "ทีม A เร็วขึ้น 30% จากกรณีจำลอง 12 รายการ; ทีม B เร็วขึ้น 8% จาก 40 รายการ; ทีม C ไม่มีข้อมูลเพราะการส่งออกข้อมูลไม่สมบูรณ์",
          },
          {
            id: "scope-note",
            label: "หมายเหตุขอบเขต",
            detail: "ร่างนี้ครอบคลุมช่วงทดลอง 60 วัน และระบุว่าไม่ควรสรุปผลเกินกลุ่มทดลอง",
          },
          {
            id: "risk-log",
            label: "บันทึกความเสี่ยง",
            detail: "มีปัญหาเร่งด่วนของทีม C ที่ยังไม่ปิดอยู่ 2 รายการ",
          },
        ],
      },
      concepts: {
        heading: "แนวคิดที่จำเป็นก่อนตัดสินใจ",
        introduction: "ใช้เพียงสามคำถามเพื่อหยุดข้ออ้างที่หลักฐานยังรองรับไม่พอ",
        items: [
          {
            id: "evidence-traceability",
            heading: "1. ตามรอยหลักฐานได้หรือไม่",
            body: "แยกข้ออ้างสำคัญ แล้วชี้ไปยังตาราง หมายเหตุ หรือบันทึกที่รองรับแต่ละข้ออย่างชัดเจน",
          },
          {
            id: "claim-source-fit",
            heading: "2. ความแรงและขอบเขตของข้ออ้างพอดีกับแหล่งข้อมูลหรือไม่",
            body: "อย่าขยายผลจากหนึ่งทีมไปทุกทีม และอย่าเปลี่ยนข้อมูลที่หายไปให้กลายเป็นผลลัพธ์เชิงบวก",
          },
          {
            id: "safe-next-action",
            heading: "3. ก้าวถัดไปลดความเสี่ยงได้จริงหรือไม่",
            body: "ชะลอข้อความที่ยังยืนยันไม่ได้ ขอข้อมูลที่ขาด และแก้ข้ออ้างก่อนนำไปใช้ในการตัดสินใจ",
          },
        ],
      },
      practice: {
        eyebrow: "Structured decision practice",
        heading: "เลือกการตรวจสอบที่ปลอดภัยที่สุด",
        introduction:
          "ตอบทั้งสามส่วน ระบบจะเทียบตัวเลือกกับเกณฑ์ที่แสดงไว้โดยตรง ไม่มี AI หรือผู้ประเมินภายนอกเข้ามาตัดสิน",
        instruction: "เลือกหนึ่งตัวเลือกต่อเกณฑ์ แล้วกดดู feedback",
        criteria: [
          {
            id: "evidence-traceability",
            label: "การตามรอยหลักฐาน",
            prompt: "คุณควรสร้างร่องรอยการตรวจสอบแบบใดก่อน",
            options: [
              {
                id: "trace-claim-to-source-map",
                label: "ทำตารางเชื่อมแต่ละข้ออ้างกับส่วนของแหล่งข้อมูล และระบุจุดที่ข้อมูลขาด",
              },
              {
                id: "trace-trust-ai-link-list",
                label: "ใช้รายชื่อลิงก์ที่ AI ให้มาโดยไม่เปิดตรวจเนื้อหาแต่ละแหล่ง",
              },
              {
                id: "trace-remove-source-notes",
                label: "ลบหมายเหตุแหล่งข้อมูลเพื่อให้สรุปอ่านง่ายขึ้น",
              },
            ],
          },
          {
            id: "claim-source-fit",
            label: "ความพอดีระหว่างข้ออ้างกับแหล่งข้อมูล",
            prompt: "ข้อความใดแทนสรุปเดิมได้ตรงกับหลักฐานมากที่สุด",
            options: [
              {
                id: "fit-narrow-to-supported-teams",
                label:
                  "ทีม A เร็วขึ้น 30% และทีม B เร็วขึ้น 8% ในข้อมูลทดลอง ส่วนทีม C ยังสรุปไม่ได้เพราะข้อมูลไม่ครบ",
              },
              {
                id: "fit-keep-all-team-claim",
                label: "ทั้งสามทีมเร็วขึ้นประมาณ 30% เพราะแนวโน้มโดยรวมเป็นบวก",
              },
              {
                id: "fit-convert-to-broad-average",
                label: "โครงการลดเวลาปิดงานได้มาก โดยไม่ต้องแยกทีมและขนาดตัวอย่าง",
              },
            ],
          },
          {
            id: "safe-next-action",
            label: "ก้าวถัดไปที่ปลอดภัย",
            prompt: "ทีมควรทำอะไรก่อนส่งสรุปให้ผู้บริหาร",
            options: [
              {
                id: "safe-hold-and-resolve-gaps",
                label:
                  "พักข้ออ้างรวม ขอข้อมูลทีม C ตรวจปัญหาเร่งด่วน และส่งเฉพาะข้อความที่ตามรอยหลักฐานได้",
              },
              {
                id: "safe-publish-with-small-note",
                label: "ส่งสรุปเดิมพร้อมหมายเหตุสั้น ๆ ว่าตัวเลขอาจเปลี่ยนภายหลัง",
              },
              {
                id: "safe-ask-ai-for-confidence",
                label: "ขอให้ AI เพิ่มค่าความมั่นใจ แล้วใช้สรุปเดิมหากค่าดูสูงพอ",
              },
            ],
          },
        ],
      },
      rubric: {
        heading: "เกณฑ์การให้ feedback ที่เปิดเผย",
        introduction:
          "แต่ละเกณฑ์มีเพียง ผ่านเกณฑ์ หรือ ยังไม่ผ่านเกณฑ์ ไม่มีคะแนนร้อยละหรือระดับความสามารถ",
        demonstratedRule:
          "ผ่านครบทั้งสามเกณฑ์จึงแสดงตัวอย่าง 20 XP หากยังไม่ครบจะเป็น 0 XP โดยไม่บันทึกหรือสะสม",
        criteria: [
          {
            id: "evidence-traceability",
            label: "การตามรอยหลักฐาน",
            metDescription: "เชื่อมข้ออ้างกับแหล่งข้อมูลเฉพาะและระบุข้อมูลที่ขาด",
            notMetDescription: "ยังไม่มีร่องรอยที่ตรวจย้อนกลับจากข้ออ้างไปยังหลักฐานจริง",
          },
          {
            id: "claim-source-fit",
            label: "ความพอดีระหว่างข้ออ้างกับแหล่งข้อมูล",
            metDescription: "จำกัดข้อความตามทีม ขนาดตัวอย่าง และข้อมูลที่มีอยู่จริง",
            notMetDescription: "ข้อความยังกว้างหรือแรงกว่าขอบเขตที่แหล่งข้อมูลรองรับ",
          },
          {
            id: "safe-next-action",
            label: "ก้าวถัดไปที่ปลอดภัย",
            metDescription: "ชะลอข้ออ้างที่ยังไม่ยืนยันและแก้ช่องว่างก่อนนำไปใช้",
            notMetDescription: "ก้าวถัดไปยังปล่อยให้ข้ออ้างที่ไม่ครบถ้วนถูกนำไปใช้ตัดสินใจ",
          },
        ],
      },
      feedback: {
        incompleteError: "เลือกคำตอบให้ครบทั้งสามเกณฑ์ก่อนดู feedback",
        heading: "Feedback จากเกณฑ์ที่เปิดเผย",
        demonstratedHeading: "ผ่านครบทั้งสามเกณฑ์ในแบบฝึกจำลองนี้",
        partialHeading: "ยังมีเกณฑ์ที่ควรทบทวนก่อนใช้สรุป",
        demonstratedSummary:
          "ตัวเลือกชุดนี้แสดงการตามรอยหลักฐาน จำกัดข้ออ้างให้พอดี และเลือกก้าวถัดไปที่ลดความเสี่ยง",
        partialSummary:
          "ดูผลรายเกณฑ์ด้านล่าง แล้วลองปรับการตัดสินใจได้ แบบฝึกนี้ไม่ตีความเป็นระดับความสามารถของคุณ",
        metLabel: "ผ่านเกณฑ์",
        notMetLabel: "ยังไม่ผ่านเกณฑ์",
        previewXpTemplate: "ตัวอย่างกติกา XP: {xp} XP",
        unsavedXpBoundary:
          "XP เป็นเพียงตัวอย่างกติกาและไม่ได้ถูกบันทึก การประเมินซ้ำไม่สะสม XP เพิ่ม",
        evaluateLabel: "ดู feedback ตามเกณฑ์",
        retryLabel: "ปรับคำตอบแล้วลองอีกครั้ง",
        resetLabel: "ล้างตัวเลือกในหน้านี้",
        demonstratedAnnouncement: "ผ่านครบทั้งสามเกณฑ์ ได้ตัวอย่าง 20 XP ซึ่งไม่ได้ถูกบันทึก",
        partialAnnouncement: "ยังไม่ผ่านครบทั้งสามเกณฑ์ ตัวอย่าง XP เท่ากับ 0 และไม่ได้ถูกบันทึก",
      },
      proof: {
        eyebrow: "Proof placeholder",
        heading: "หลักฐานในอนาคต: บันทึกการตรวจสอบแหล่งข้อมูล",
        introduction:
          "ในผลิตภัณฑ์อนาคต การฝึกนี้อาจนำไปสู่บันทึกที่ตรวจสอบย้อนกลับได้ แต่ต้นแบบนี้แสดงเฉพาะโครงสร้างเท่านั้น",
        placeholderLabel: "ตัวอย่างโครงสร้างหลักฐาน — ยังสร้างหรือบันทึกไม่ได้",
        fieldsHeading: "ช่องข้อมูลที่คาดว่าจะมี",
        fields: [
          { id: "claim", label: "ข้ออ้างที่ตรวจ" },
          { id: "source-reference", label: "แหล่งและตำแหน่งอ้างอิง" },
          { id: "fit-check", label: "ผลตรวจความพอดีของข้ออ้าง" },
          { id: "corrected-wording", label: "ข้อความที่แก้ตามหลักฐาน" },
          { id: "safe-next-action", label: "ก้าวถัดไปที่ปลอดภัย" },
        ],
        boundary: "ไม่มีช่องข้อความ การอัปโหลด การสร้างไฟล์ หรือการจัดเก็บหลักฐานใน RP-TURN-009",
      },
      reflection: {
        heading: "ทบทวนกับตนเองโดยไม่ส่งคำตอบ",
        prompt: "ในงานของคุณ จุดตรวจใดควรเกิดขึ้นก่อนนำสรุปจาก AI ไปใช้ตัดสินใจ",
        boundary:
          "คิดหรือจดไว้กับตนเองเท่านั้น หน้านี้ไม่มีช่องให้กรอกและไม่เก็บหรือส่ง reflection",
      },
      actions: {
        backToExampleLabel: "กลับไปดูผลลัพธ์ตัวอย่างคงที่",
        homeLabel: "กลับหน้าหลัก",
      },
    },
    en: {
      locale: "en",
      metadata: {
        title: "Source-verification lesson prototype | Rise Pals",
        description:
          "A synthetic lesson and practice for tracing AI-summary claims to sources without saving responses or progress.",
      },
      hero: {
        eyebrow: "Learn → Practice → Feedback → Proof placeholder",
        heading: "Verify claims in an AI summary before using them in a decision",
        introduction:
          "This micro-lesson demonstrates a path from concise content to an active decision, transparent feedback, and the shape of future evidence.",
        prototypeLabel:
          "Repository-local content prototype — not published or externally validated for learning outcomes",
        boundary:
          "Every organization, document, person, and value in this scenario is synthetic. The lesson reads no assessment response, and this link is not a personalized recommendation.",
      },
      overview: {
        heading: "Prototype lesson boundary",
        targetLabel: "Target competency",
        stageLabel: "Intended working stage",
        roiLabel: "R.O.I. pillar",
        timeLabel: "Estimated active time",
        timeValue: "About 8 minutes",
      },
      scenario: {
        heading: "Synthetic situation: a project summary that overreaches its sources",
        introduction:
          "Your team receives an AI-generated draft for an executive review. You must decide what the evidence supports and what should happen before circulation.",
        syntheticLabel: "All details in this case were invented only for prototype review",
        organizationLabel: "Synthetic organization",
        organization: "Bright River Operations",
        documentLabel: "Synthetic document",
        document: "Service pilot review, draft 0.3",
        aiSummaryLabel: "AI-summary claim",
        aiSummary:
          "“All three teams reduced resolution time by 30%, and the pilot found no escalation risk.”",
        sourceHeading: "What the synthetic source pack actually says",
        sourceRecords: [
          {
            id: "pilot-table",
            label: "Pilot outcome table",
            detail:
              "Team A was 30% faster across 12 synthetic cases; Team B was 8% faster across 40; Team C has no result because its export is incomplete.",
          },
          {
            id: "scope-note",
            label: "Scope note",
            detail:
              "The draft covers a 60-day pilot and says findings should not be generalized beyond the pilot group.",
          },
          {
            id: "risk-log",
            label: "Risk log",
            detail: "Two priority escalations for Team C remain unresolved.",
          },
        ],
      },
      concepts: {
        heading: "The concepts needed for this decision",
        introduction: "Use three checks to stop a claim when its evidence is not ready.",
        items: [
          {
            id: "evidence-traceability",
            heading: "1. Can you trace the evidence?",
            body: "Separate each material claim and point to the exact table, note, or record that supports it.",
          },
          {
            id: "claim-source-fit",
            heading: "2. Does the claim fit the source?",
            body: "Do not generalize one team's outcome to every team or turn missing data into a positive result.",
          },
          {
            id: "safe-next-action",
            heading: "3. Does the next action reduce risk?",
            body: "Hold unsupported wording, request missing evidence, and correct the claim before it informs a decision.",
          },
        ],
      },
      practice: {
        eyebrow: "Structured decision practice",
        heading: "Choose the safest verification response",
        introduction:
          "Answer all three parts. The prototype compares your choices directly with the visible rubric; no AI or external reviewer evaluates them.",
        instruction: "Choose one option for each criterion, then review the feedback.",
        criteria: [
          {
            id: "evidence-traceability",
            label: "Evidence traceability",
            prompt: "What verification record should you create first?",
            options: [
              {
                id: "trace-claim-to-source-map",
                label:
                  "Map every material claim to a specific source section and mark missing evidence.",
              },
              {
                id: "trace-trust-ai-link-list",
                label: "Trust the AI summary's list of links without opening each source.",
              },
              {
                id: "trace-remove-source-notes",
                label: "Remove source notes so the summary is easier to read.",
              },
            ],
          },
          {
            id: "claim-source-fit",
            label: "Claim-to-source fit",
            prompt: "Which replacement statement best fits the source pack?",
            options: [
              {
                id: "fit-narrow-to-supported-teams",
                label:
                  "Team A was 30% faster and Team B 8% faster in the pilot data; Team C cannot yet be summarized because its data is incomplete.",
              },
              {
                id: "fit-keep-all-team-claim",
                label:
                  "All three teams were about 30% faster because the overall trend is positive.",
              },
              {
                id: "fit-convert-to-broad-average",
                label:
                  "The pilot greatly reduced resolution time, without separating teams or sample sizes.",
              },
            ],
          },
          {
            id: "safe-next-action",
            label: "Safe next action",
            prompt: "What should the team do before sending the summary to executives?",
            options: [
              {
                id: "safe-hold-and-resolve-gaps",
                label:
                  "Hold the broad claim, obtain Team C data, resolve the escalations, and circulate only traceable wording.",
              },
              {
                id: "safe-publish-with-small-note",
                label: "Send the original summary with a short note that figures may change later.",
              },
              {
                id: "safe-ask-ai-for-confidence",
                label:
                  "Ask the AI for a confidence value and keep the claim if the value appears high.",
              },
            ],
          },
        ],
      },
      rubric: {
        heading: "Transparent feedback rubric",
        introduction:
          "Each criterion is only met or not met. There is no proficiency percentage or learner stage judgment.",
        demonstratedRule:
          "Meeting all three criteria previews 20 XP; any other outcome is 0 XP, with nothing saved or accumulated.",
        criteria: [
          {
            id: "evidence-traceability",
            label: "Evidence traceability",
            metDescription: "Links each claim to a specific source and names missing evidence.",
            notMetDescription:
              "Does not yet provide an auditable path from claim to source evidence.",
          },
          {
            id: "claim-source-fit",
            label: "Claim-to-source fit",
            metDescription:
              "Limits wording to the teams, sample sizes, and evidence actually available.",
            notMetDescription: "Keeps a claim broader or stronger than the source supports.",
          },
          {
            id: "safe-next-action",
            label: "Safe next action",
            metDescription: "Holds unsupported wording and closes evidence gaps before use.",
            notMetDescription: "Still allows incomplete claims to influence a decision.",
          },
        ],
      },
      feedback: {
        incompleteError: "Choose one response for all three criteria before reviewing feedback.",
        heading: "Feedback from the visible rubric",
        demonstratedHeading: "All three criteria are met in this synthetic practice",
        partialHeading: "Review at least one criterion before using the summary",
        demonstratedSummary:
          "These choices trace the evidence, keep claims within scope, and choose a next action that reduces risk.",
        partialSummary:
          "Review the criterion-level feedback and revise the decision. This prototype does not infer your proficiency.",
        metLabel: "Criterion met",
        notMetLabel: "Criterion not met",
        previewXpTemplate: "XP rule preview: {xp} XP",
        unsavedXpBoundary:
          "XP is a preview rule only and is not saved. Re-evaluating never accumulates additional XP.",
        evaluateLabel: "Review rubric feedback",
        retryLabel: "Revise choices and try again",
        resetLabel: "Clear choices on this page",
        demonstratedAnnouncement:
          "All three criteria are met. The preview is 20 XP, and nothing is saved.",
        partialAnnouncement:
          "Not all three criteria are met. The preview is 0 XP, and nothing is saved.",
      },
      proof: {
        eyebrow: "Proof placeholder",
        heading: "Future evidence: a source verification note",
        introduction:
          "A future product could turn this practice into a traceable note. This prototype displays only the expected structure.",
        placeholderLabel: "Evidence structure preview — creation and saving are unavailable",
        fieldsHeading: "Expected fields",
        fields: [
          { id: "claim", label: "Claim reviewed" },
          { id: "source-reference", label: "Source and location reference" },
          { id: "fit-check", label: "Claim-fit finding" },
          { id: "corrected-wording", label: "Evidence-supported correction" },
          { id: "safe-next-action", label: "Safe next action" },
        ],
        boundary: "RP-TURN-009 provides no text field, upload, artifact creation, or storage.",
      },
      reflection: {
        heading: "Reflect privately without submitting an answer",
        prompt:
          "Where should a verification checkpoint sit before an AI summary informs your work?",
        boundary:
          "Think or write privately. This page provides no input and does not collect or transmit a reflection.",
      },
      actions: {
        backToExampleLabel: "Return to the fixed synthetic result",
        homeLabel: "Return home",
      },
    },
  },
} as const satisfies SourceVerificationLessonDefinition;
