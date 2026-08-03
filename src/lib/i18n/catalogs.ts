import type { Locale } from "@/lib/i18n/config";

export type ShellCatalog = Readonly<{
  brandName: string;
  skipToContent: string;
  navigationLabel: string;
  homeLabel: string;
  languageSwitcherLabel: string;
  currentLanguageLabel: string;
  languageNames: Readonly<Record<Locale, string>>;
}>;

export const productLoopSteps = [
  "diagnose",
  "prioritize",
  "learn",
  "practice",
  "prove",
  "opportunity",
] as const;

export const coreCompetencies = [
  "criticalThinking",
  "systematicThinking",
  "growthMindset",
  "emotionalIntelligence",
  "resilience",
  "curiosity",
  "ethicalJudgement",
  "strategicStorytelling",
] as const;

export const multipliers = ["ownershipThinking", "senseOfUrgency"] as const;

type NamedDescription = Readonly<{
  name: string;
  description: string;
}>;

export type LandingCatalog = Readonly<{
  hero: Readonly<{
    eyebrow: string;
    heading: string;
    introduction: string;
    supporting: string;
    ctaLabel: string;
    availability: string;
  }>;
  evidence: Readonly<{
    eyebrow: string;
    heading: string;
    introduction: string;
    signalLabel: string;
    interpretationLabel: string;
    actionLabel: string;
    geographyLabel: string;
    contextLabel: string;
    limitationLabel: string;
    sourceLabel: string;
    publishedLabel: string;
    verifiedLabel: string;
    reviewLabel: string;
  }>;
  response: Readonly<{
    eyebrow: string;
    heading: string;
    introduction: string;
    loopLabel: string;
    steps: Readonly<Record<(typeof productLoopSteps)[number], NamedDescription>>;
    practiceNote: string;
  }>;
  framework: Readonly<{
    eyebrow: string;
    heading: string;
    introduction: string;
    coreHeading: string;
    coreIntroduction: string;
    core: Readonly<Record<(typeof coreCompetencies)[number], NamedDescription>>;
    multipliersHeading: string;
    multipliersIntroduction: string;
    multiplierItems: Readonly<Record<(typeof multipliers)[number], NamedDescription>>;
    boundary: string;
  }>;
}>;

export type AssessmentPlayerCatalog = Readonly<{
  metadata: Readonly<{
    title: string;
    description: string;
  }>;
  eyebrow: string;
  heading: string;
  introduction: string;
  boundariesHeading: string;
  boundaries: readonly string[];
  storageHeading: string;
  storageBody: string;
  storageUnavailable: string;
  storageRestored: string;
  storageDiscarded: string;
  storageCleared: string;
  startLabel: string;
  questionHeadingTemplate: string;
  positionTemplate: string;
  answeredTemplate: string;
  optionGroupHint: string;
  answerRequired: string;
  assessmentIncomplete: string;
  backLabel: string;
  continueLabel: string;
  finishLabel: string;
  clearLabel: string;
  completionEyebrow: string;
  completionHeading: string;
  completionSummary: string;
  completionBoundary: string;
  exampleResultHeading: string;
  exampleResultBody: string;
  exampleResultLinkLabel: string;
  reviewLabel: string;
  restartLabel: string;
  homeLabel: string;
  stepAnnouncementTemplate: string;
  completionAnnouncement: string;
}>;

export type ExampleResultCatalog = Readonly<{
  metadata: Readonly<{
    title: string;
    description: string;
  }>;
  eyebrow: string;
  heading: string;
  introduction: string;
  exampleOnlyLabel: string;
  userChoicesBoundary: string;
  fixtureHeading: string;
  fixtureLabel: string;
  contractLabel: string;
  coverageHeading: string;
  coverageIntroduction: string;
  assessedHeading: string;
  assessedIntroduction: string;
  rawEvidenceTemplate: string;
  evidenceCountTemplate: string;
  supportingItemsLabel: string;
  unassessedHeading: string;
  unassessedIntroduction: string;
  multipliersHeading: string;
  multipliersIntroduction: string;
  singleScenarioLabel: string;
  practiceEyebrow: string;
  practiceHeading: string;
  practiceBody: string;
  practiceActionHeading: string;
  practiceAction: string;
  traceHeading: string;
  traceIntroduction: string;
  traceDefinitionLabel: string;
  traceFixtureLabel: string;
  traceTargetLabel: string;
  traceScoringModelLabel: string;
  traceItemsLabel: string;
  traceLessonLabel: string;
  lessonPrototypeLabel: string;
  lessonLinkBoundary: string;
  lessonLinkLabel: string;
  limitationsHeading: string;
  limitationsIntroduction: string;
  backToAssessmentLabel: string;
  homeLabel: string;
}>;

export type AppCatalog = Readonly<{
  shell: ShellCatalog;
  landing: LandingCatalog;
  assessment: AssessmentPlayerCatalog;
  exampleResult: ExampleResultCatalog;
}>;

export const catalogs = {
  th: {
    shell: {
      brandName: "Rise Pals",
      skipToContent: "ข้ามไปยังเนื้อหาหลัก",
      navigationLabel: "การนำทางหลัก",
      homeLabel: "หน้าหลัก",
      languageSwitcherLabel: "เลือกภาษา",
      currentLanguageLabel: "ภาษาปัจจุบัน",
      languageNames: {
        th: "ไทย",
        en: "English",
      },
    },
    landing: {
      hero: {
        eyebrow: "พร้อมเติบโตไปกับโลกงานที่เปลี่ยน",
        heading: "งานกำลังเปลี่ยน แต่คุณยังเตรียมตัวและสร้างคุณค่าใหม่ได้",
        introduction:
          "Rise Pals ช่วยให้คนทำงานมองการเปลี่ยนแปลงอย่างมีหลักฐาน เห็นทักษะที่ควรพัฒนา และเปลี่ยนความกังวลให้เป็นการลงมือทำทีละขั้น",
        supporting:
          "เราไม่ทำนายว่าใครจะตกงาน และไม่รับประกันการจ้างงาน เป้าหมายคือช่วยให้คุณฝึกวิจารณญาณ เชื่อมงานกับผลลัพธ์ และพิสูจน์สิ่งที่ทำได้จริง",
        ctaLabel: "ทดลอง 6 สถานการณ์จำลอง",
        availability:
          "เปิดให้ทดลองตอบ 6 สถานการณ์จำลองแล้ว แต่ยังไม่ใช่แบบประเมินที่ผ่านการตรวจสอบและยังไม่มีผลลัพธ์หรือคำแนะนำ หน้าหลักนี้ไม่เก็บข้อมูล ส่วนต้นแบบจะเก็บเฉพาะรหัสตัวเลือกชั่วคราวในแท็บเบราว์เซอร์",
      },
      evidence: {
        eyebrow: "Why now · เหตุผลที่ควรเริ่มเตรียมตัว",
        heading: "เห็นสัญญาณให้ชัด แล้วเลือกการตอบสนองที่ทำได้จริง",
        introduction:
          "ข้อมูลต่อไปนี้บอกถึงการเปลี่ยนแปลงในระดับงานและนายจ้าง ไม่ใช่คำตัดสินอนาคตของบุคคล ทุกสัญญาณจึงมาพร้อมขอบเขตและก้าวถัดไปที่สร้างสรรค์",
        signalLabel: "สัญญาณ",
        interpretationLabel: "ความหมายที่ใช้ได้",
        actionLabel: "ก้าวถัดไป",
        geographyLabel: "ขอบเขตพื้นที่",
        contextLabel: "ตัวอย่างและวิธีศึกษา",
        limitationLabel: "ข้อมูลนี้ไม่ได้พิสูจน์ว่า",
        sourceLabel: "อ่านแหล่งข้อมูลต้นฉบับ",
        publishedLabel: "เผยแพร่",
        verifiedLabel: "ตรวจสอบล่าสุด",
        reviewLabel: "ทบทวนภายใน",
      },
      response: {
        eyebrow: "Rise Pals response",
        heading: "จากความไม่แน่นอน สู่เส้นทางพัฒนาที่มีหลักฐาน",
        introduction:
          "Rise Pals ไม่ได้จบที่การสอนใช้ AI หรือเขียน prompt แต่เชื่อมการเข้าใจตนเอง การเลือกสิ่งสำคัญ การฝึก และโอกาสให้เป็นวงจรเดียว",
        loopLabel: "วงจรการพัฒนาของ Rise Pals",
        steps: {
          diagnose: {
            name: "Diagnose",
            description: "ทำความเข้าใจบริบทงานและทักษะที่มีอยู่ โดยไม่สร้างคะแนนเสี่ยงเกินหลักฐาน",
          },
          prioritize: {
            name: "Prioritize",
            description: "เลือกช่องว่างที่มีความหมายก่อน แทนการพยายามเรียนทุกอย่างพร้อมกัน",
          },
          learn: {
            name: "Learn",
            description: "เรียนแนวคิดที่จำเป็นและเชื่อมกับสถานการณ์งานจริง",
          },
          practice: {
            name: "Practice",
            description: "ลงมือผ่านโจทย์ การตัดสินใจ และสถานการณ์จำลอง",
          },
          prove: {
            name: "Prove",
            description: "รับ feedback และสร้างหลักฐานที่แสดงว่าคุณนำทักษะไปใช้ได้",
          },
          opportunity: {
            name: "Opportunity",
            description: "ต่อยอดหลักฐานสู่การเรียนรู้ mentorship และโอกาสที่เหมาะสมในอนาคต",
          },
        },
        practiceNote:
          "การดูเนื้อหาจบไม่เท่ากับมีทักษะ ความก้าวหน้าที่มีความหมายต้องมีการลงมือทำ feedback และหลักฐาน—ไม่ใช่เพียง completion",
      },
      framework: {
        eyebrow: "8+2 framework preview",
        heading: "ทักษะมนุษย์ที่ช่วยกำกับ เชื่อมโยง และสร้างผลลัพธ์",
        introduction:
          "กรอบ 8+2 มองความพร้อมกว้างกว่าความคล่องแคล่วด้านเครื่องมือ โดยแยกทักษะหลักแปดด้านออกจากพฤติกรรมตัวคูณสองด้านอย่างชัดเจน",
        coreHeading: "8 ทักษะหลัก",
        coreIntroduction:
          "ทักษะหลักช่วยให้คุณตรวจสอบข้อมูล ออกแบบระบบ ทำงานกับคน และเชื่อมความซับซ้อนกับการตัดสินใจ",
        core: {
          criticalThinking: {
            name: "Critical Thinking & Fact-Checking",
            description: "ตรวจสมมติฐาน แหล่งข้อมูล hallucination และ bias ก่อนเชื่อหรือลงมือ",
          },
          systematicThinking: {
            name: "Systematic Thinking",
            description: "มองระบบ เชื่อม silo และเห็นผลกระทบตั้งแต่ต้นน้ำถึงปลายน้ำ",
          },
          growthMindset: {
            name: "Growth Mindset",
            description: "ยอมเรียนรู้ใหม่ ทดลอง และปรับวิธีทำงานเมื่อหลักฐานเปลี่ยน",
          },
          emotionalIntelligence: {
            name: "Emotional Intelligence / EQ",
            description: "เข้าใจคน สื่อสาร เจรจา และทำงานข้ามทีมกับความแตกต่าง",
          },
          resilience: {
            name: "Resilience & Adaptability",
            description: "รับมือความไม่แน่นอนและ iteration โดยไม่ถอยกลับสู่วิธีเดิมอัตโนมัติ",
          },
          curiosity: {
            name: "Curiosity",
            description: "ตั้งคำถามและสมมติฐานที่เปิดทางให้เกิด insight ใหม่",
          },
          ethicalJudgement: {
            name: "Ethical Judgement & Governance",
            description: "ดูแล privacy ความเป็นธรรม compliance และความรับผิดชอบ",
          },
          strategicStorytelling: {
            name: "Strategic Storytelling & Framing",
            description: "เปลี่ยนความซับซ้อนเป็นกรอบเรื่องที่ช่วยให้คนตัดสินใจและลงมือ",
          },
        },
        multipliersHeading: "+2 ตัวคูณเชิงพฤติกรรม",
        multipliersIntroduction:
          "สองด้านนี้ไม่ใช่ทักษะหลักลำดับที่เก้าหรือสิบ แต่เป็น pattern ที่ช่วยเปลี่ยนทักษะให้เกิดผลลัพธ์",
        multiplierItems: {
          ownershipThinking: {
            name: "Ownership Thinking",
            description:
              "มองผลลัพธ์รวม เชื่อมงานกับคุณค่าธุรกิจ และรับผิดชอบการแก้ปัญหาเหมือนเจ้าของ",
          },
          senseOfUrgency: {
            name: "Sense of Urgency",
            description: "เปลี่ยนแรงกดดันเป็นความเร็วที่มีกลยุทธ์ โดยไม่ทิ้งคุณภาพหรือ governance",
          },
        },
        boundary:
          "ต้นแบบสถานการณ์จำลองพร้อมให้ทดลองเพื่อทดสอบการใช้งาน แต่ยังไม่มีคะแนน น้ำหนักที่แสดงต่อผู้ใช้ ระดับความเสี่ยงส่วนบุคคล ผลประเมิน หรือคำแนะนำเฉพาะบุคคล",
      },
    },
    assessment: {
      metadata: {
        title: "ต้นแบบสถานการณ์ประเมิน | Rise Pals",
        description:
          "ต้นแบบการใช้งาน 6 สถานการณ์จำลองที่ไม่ผ่านการตรวจสอบความเที่ยงตรงและไม่มีผลลัพธ์หรือคำแนะนำ",
      },
      eyebrow: "ต้นแบบการตอบสถานการณ์",
      heading: "ทดลองตอบ 6 สถานการณ์จำลองอย่างเป็นขั้นตอน",
      introduction:
        "ประสบการณ์นี้ใช้สถานการณ์ในที่ทำงานที่สร้างขึ้นเพื่อทดสอบขั้นตอนการใช้งานเท่านั้น ไม่ใช่แบบประเมินจริง",
      boundariesHeading: "ขอบเขตที่ควรรู้ก่อนเริ่ม",
      boundaries: [
        "สถานการณ์ทั้งหกเป็นข้อมูลจำลอง และชุดนี้ยังไม่ผ่านการตรวจสอบความเที่ยงตรงหรือการสอบเทียบ",
        "คำตอบไม่สามารถทำนายการตกงาน ผลการปฏิบัติงาน ความสามารถในการได้งานหรือรักษางาน หรือคุณสมบัติในการจ้างงาน",
        "RP-TURN-007 ไม่มีผลคะแนน ระดับความสามารถ ช่องว่างที่ควรพัฒนา หรือคำแนะนำ",
        "ระบบไม่ขอชื่อ อีเมล นายจ้าง ประสบการณ์ เป้าหมาย โปรไฟล์ความยินยอม หรือข้อความอิสระ",
        "การกดเริ่มเป็นเพียงการเริ่มต้นแบบ ไม่ใช่การให้ความยินยอมทางกฎหมายหรือใบรับความยินยอม",
      ],
      storageHeading: "การเก็บคำตอบชั่วคราวในแท็บนี้",
      storageBody:
        "ต้นแบบนี้เก็บเฉพาะรหัสสถานการณ์และรหัสตัวเลือกไว้ชั่วคราวใน sessionStorage ของแท็บเบราว์เซอร์นี้ เพื่อกลับมาขั้นเดิมหลังรีเฟรช ข้อมูลไม่ถูกส่งไปยังเซิร์ฟเวอร์ ไม่ใช่การบันทึกถาวร และอาจหายได้เมื่อปิดแท็บหรือเมื่อเบราว์เซอร์จำกัดพื้นที่เก็บข้อมูล คุณล้างข้อมูลนี้ได้ทุกเมื่อ",
      storageUnavailable:
        "เบราว์เซอร์ไม่อนุญาตพื้นที่เก็บข้อมูลชั่วคราว คุณยังทดลองต่อได้ แต่การรีเฟรชอาจทำให้คำตอบหาย",
      storageRestored: "กู้คืนขั้นและตัวเลือกที่บันทึกชั่วคราวในแท็บนี้แล้ว",
      storageDiscarded: "ข้อมูลชั่วคราวเดิมไม่เข้ากับต้นแบบปัจจุบัน จึงถูกล้างอย่างปลอดภัย",
      storageCleared: "ล้างคำตอบชั่วคราวแล้ว",
      startLabel: "เริ่มต้นแบบ 6 สถานการณ์",
      questionHeadingTemplate: "สถานการณ์ที่ {current}",
      positionTemplate: "สถานการณ์ {current} จาก {total}",
      answeredTemplate: "ตอบแล้ว {answered} จาก {total} สถานการณ์",
      optionGroupHint: "เลือกหนึ่งคำตอบก่อนดำเนินการต่อ",
      answerRequired: "โปรดเลือกหนึ่งคำตอบก่อนดำเนินการต่อ",
      assessmentIncomplete: "โปรดตอบสถานการณ์ให้ครบทั้งหกก่อนจบต้นแบบ",
      backLabel: "ย้อนกลับ",
      continueLabel: "ดำเนินการต่อ",
      finishLabel: "จบต้นแบบ",
      clearLabel: "ล้างคำตอบและกลับไปเริ่มต้น",
      completionEyebrow: "ครบทั้ง 6 สถานการณ์",
      completionHeading: "คุณตอบสถานการณ์จำลองครบแล้ว",
      completionSummary:
        "ขอบคุณที่ทดลองขั้นตอนทั้งหมด คำตอบยังคงเป็นข้อมูลชั่วคราวในแท็บนี้จนกว่าคุณจะล้างหรือปิดแท็บ",
      completionBoundary:
        "RP-TURN-007 ไม่คำนวณหรือแสดงคะแนน ระดับความสามารถ ความมั่นใจ รูปแบบพฤติกรรม ช่องว่างที่ควรพัฒนา หรือคำแนะนำใด ๆ",
      exampleResultHeading: "ดูตัวอย่างผลลัพธ์ที่แยกจากคำตอบของคุณ",
      exampleResultBody:
        "ตัวอย่างถัดไปใช้ชุดคำตอบจำลองที่ทีมกำหนดไว้ล่วงหน้า ระบบไม่อ่าน ไม่ให้คะแนน และไม่นำตัวเลือกที่คุณตอบในแท็บนี้ไปใช้",
      exampleResultLinkLabel: "ดูตัวอย่างผลลัพธ์จำลอง (ไม่ใช้คำตอบของคุณ)",
      reviewLabel: "ทบทวนคำตอบ",
      restartLabel: "ล้างและเริ่มใหม่",
      homeLabel: "กลับหน้าหลัก",
      stepAnnouncementTemplate: "เปิดสถานการณ์ {current} จาก {total}",
      completionAnnouncement: "ตอบสถานการณ์จำลองครบทั้งหกแล้ว ไม่มีผลลัพธ์ในต้นแบบนี้",
    },
    exampleResult: {
      metadata: {
        title: "ตัวอย่างแผนที่สัญญาณทักษะ | Rise Pals",
        description:
          "ตัวอย่างผลลัพธ์สองทักษะจากชุดคำตอบจำลองที่กำหนดไว้ โดยไม่ใช้คำตอบของผู้เข้าชม",
      },
      eyebrow: "ตัวอย่างผลลัพธ์จากข้อมูลจำลอง",
      heading: "ดูแผนที่สัญญาณทักษะจากกรณีตัวอย่างหนึ่งชุด",
      introduction:
        "หน้านี้สาธิตวิธีอธิบายหลักฐานที่ครอบคลุม ข้อจำกัด และตัวอย่างการฝึกขั้นถัดไป โดยใช้ชุดคำตอบจำลองที่ทีมตรวจทานแล้วหนึ่งชุด",
      exampleOnlyLabel: "ตัวอย่างเท่านั้น — ไม่ใช่ผลของคุณ",
      userChoicesBoundary:
        "ระบบไม่อ่าน ไม่ให้คะแนน และไม่นำตัวเลือกชั่วคราวจากการตอบ 6 สถานการณ์ของคุณมาใช้ ผลด้านล่างจะเหมือนเดิมไม่ว่าคุณเลือกคำตอบใด",
      fixtureHeading: "ที่มาของตัวอย่าง",
      fixtureLabel: "รหัสชุดคำตอบจำลอง",
      contractLabel: "รุ่นโครงสร้างผลลัพธ์",
      coverageHeading: "หลักฐานในตัวอย่างครอบคลุมอะไร",
      coverageIntroduction:
        "สถานการณ์จำลองหกข้อให้สัญญาณดิบต่อทักษะหลักเพียง 2 จาก 8 ด้าน และข้อสังเกตแยกสำหรับทักษะเสริมด้านละหนึ่งสถานการณ์",
      assessedHeading: "สัญญาณดิบของ 2 ทักษะที่มีหลักฐาน",
      assessedIntroduction:
        "ช่องสีแสดงแต้มหลักฐานดิบจากตัวเลือกที่กำหนดไว้ในชุดจำลอง ไม่ใช่ร้อยละความสามารถ ระดับทักษะ หรือคะแนนรวม",
      rawEvidenceTemplate: "แต้มหลักฐานดิบ {earned} จาก {available} แต้มที่เป็นไปได้ในชุดจำลองนี้",
      evidenceCountTemplate: "อ้างอิง {count} สถานการณ์จำลอง",
      supportingItemsLabel: "รหัสสถานการณ์ที่รองรับ",
      unassessedHeading: "ทักษะหลักอีก 6 ด้านที่ยังไม่มีหลักฐาน",
      unassessedIntroduction:
        "ชุดจำลองนี้ไม่มีสถานการณ์ที่ผูกกับทักษะเหล่านี้ จึงไม่แสดงคะแนนและไม่อนุมานความสามารถ",
      multipliersHeading: "ข้อสังเกต +2 แยกจากทักษะหลัก",
      multipliersIntroduction:
        "Ownership Thinking และ Sense of Urgency ไม่ถูกนำไปคูณหรือรวมกับสัญญาณหลัก แต่ละด้านมีหลักฐานเพียงหนึ่งสถานการณ์ จึงยังไม่ใช่รูปแบบพฤติกรรม",
      singleScenarioLabel: "ข้อสังเกตจาก 1 สถานการณ์จำลองเท่านั้น",
      practiceEyebrow: "ตัวอย่างการฝึกขั้นถัดไป",
      practiceHeading: "ฝึกตรวจข้ออ้างของสรุปจาก AI เทียบกับแหล่งต้นฉบับ",
      practiceBody:
        "นี่คือตัวอย่างคงที่เพื่อสาธิตเส้นทางอ้างอิง ไม่ใช่การเลือกทักษะเร่งด่วนหรือคำแนะนำเฉพาะบุคคลจากคำตอบของคุณ",
      practiceActionHeading: "วิธีทดลองฝึก",
      practiceAction:
        "เลือกสรุปจาก AI หนึ่งชิ้น เทียบข้ออ้างสำคัญกับแหล่งต้นฉบับ บันทึกจุดที่ตรงและไม่ตรง แล้วแก้เฉพาะส่วนที่ตรวจสอบหลักฐานได้",
      traceHeading: "ที่มาของตัวอย่างการฝึก",
      traceIntroduction:
        "ข้อมูลอ้างอิงนี้ทำให้ทีมตรวจได้ว่าตัวอย่างเชื่อมกับรุ่นการให้คะแนน สถานการณ์ ทักษะ และบทเรียนต้นแบบใด",
      traceDefinitionLabel: "รุ่นตัวอย่างการฝึก",
      traceFixtureLabel: "ชุดคำตอบจำลอง",
      traceTargetLabel: "ทักษะเป้าหมายของตัวอย่าง",
      traceScoringModelLabel: "รุ่นวิธีให้คะแนนจำลอง",
      traceItemsLabel: "รหัสสถานการณ์ที่รองรับ",
      traceLessonLabel: "รหัสรุ่นบทเรียนต้นแบบ",
      lessonPrototypeLabel:
        "ต้นแบบพร้อมให้ทดลอง — ยังไม่ใช่เนื้อหาที่เผยแพร่หรือผ่านการตรวจสอบผลการเรียนรู้",
      lessonLinkBoundary:
        "ผลลัพธ์ด้านบนยังเป็นตัวอย่างคงที่จากข้อมูลจำลอง บทเรียนนี้เป็นต้นแบบ และลิงก์ไม่ได้เกิดจากคำแนะนำเฉพาะบุคคล",
      lessonLinkLabel: "เปิดบทเรียนต้นแบบการตรวจสอบแหล่งข้อมูล",
      limitationsHeading: "ข้อจำกัดของหลักฐานและการใช้งาน",
      limitationsIntroduction:
        "อ่านข้อจำกัดทั้งหมดก่อนตีความภาพตัวอย่างนี้ ไม่มีข้อมูลส่วนใดใช้ตัดสินบุคคล การจ้างงาน หรือความพร้อมในการทำงาน",
      backToAssessmentLabel: "กลับไปต้นแบบ 6 สถานการณ์",
      homeLabel: "กลับหน้าหลัก",
    },
  },
  en: {
    shell: {
      brandName: "Rise Pals",
      skipToContent: "Skip to main content",
      navigationLabel: "Primary navigation",
      homeLabel: "Home",
      languageSwitcherLabel: "Choose language",
      currentLanguageLabel: "Current language",
      languageNames: {
        th: "ไทย",
        en: "English",
      },
    },
    landing: {
      hero: {
        eyebrow: "Grow with a changing world of work",
        heading: "Work is changing. You can still prepare, grow, and create new value.",
        introduction:
          "Rise Pals helps people look at change through evidence, see which capabilities matter, and turn uncertainty into practical development one step at a time.",
        supporting:
          "We do not predict who will lose a job or guarantee employment. The goal is to help you practise judgment, connect work to outcomes, and prove what you can do.",
        ctaLabel: "Try six synthetic scenarios",
        availability:
          "A six-scenario player prototype is available, but it is not a validated assessment and provides no result or recommendation. This landing page collects nothing; the player temporarily stores only selected IDs in the browser tab.",
      },
      evidence: {
        eyebrow: "Why now",
        heading: "Read the signals clearly, then choose a constructive response",
        introduction:
          "These sources describe changes at occupation and employer level, not an individual destiny. Every signal is shown with its scope, limitations, and a useful next action.",
        signalLabel: "Signal",
        interpretationLabel: "Useful interpretation",
        actionLabel: "Next action",
        geographyLabel: "Geographic scope",
        contextLabel: "Sample and method",
        limitationLabel: "What this does not prove",
        sourceLabel: "Read the original source",
        publishedLabel: "Published",
        verifiedLabel: "Last verified",
        reviewLabel: "Review by",
      },
      response: {
        eyebrow: "The Rise Pals response",
        heading: "Turn uncertainty into an evidence-building development path",
        introduction:
          "Rise Pals goes beyond AI tools and prompt training. It connects self-understanding, prioritization, practice, and opportunity in one complete loop.",
        loopLabel: "The Rise Pals development loop",
        steps: {
          diagnose: {
            name: "Diagnose",
            description:
              "Understand your work context and current capabilities without inventing a risk score.",
          },
          prioritize: {
            name: "Prioritize",
            description:
              "Choose a meaningful gap first instead of trying to learn everything at once.",
          },
          learn: {
            name: "Learn",
            description: "Learn only the concepts needed for a realistic work situation.",
          },
          practice: {
            name: "Practice",
            description: "Act through tasks, decisions, and realistic scenarios.",
          },
          prove: {
            name: "Prove",
            description: "Use feedback and create evidence that shows you can apply the skill.",
          },
          opportunity: {
            name: "Opportunity",
            description:
              "In time, connect proof to learning, mentorship, and opportunities that fit.",
          },
        },
        practiceNote:
          "Finishing content is not the same as building a skill. Meaningful progress needs action, feedback, and proof—not passive completion.",
      },
      framework: {
        eyebrow: "8+2 framework preview",
        heading: "Human capabilities for directing, connecting, and delivering outcomes",
        introduction:
          "The 8+2 framework looks beyond tool fluency and keeps eight core competencies distinct from two behavioural multipliers.",
        coreHeading: "8 core competencies",
        coreIntroduction:
          "The core competencies help you verify information, design systems, work with people, and frame complexity for decisions.",
        core: {
          criticalThinking: {
            name: "Critical Thinking & Fact-Checking",
            description: "Check assumptions, sources, hallucinations, and bias before acting.",
          },
          systematicThinking: {
            name: "Systematic Thinking",
            description:
              "See the system, connect silos, and trace upstream and downstream effects.",
          },
          growthMindset: {
            name: "Growth Mindset",
            description: "Learn again, experiment, and change a workflow when evidence changes.",
          },
          emotionalIntelligence: {
            name: "Emotional Intelligence / EQ",
            description: "Understand people, communicate, negotiate, and work across differences.",
          },
          resilience: {
            name: "Resilience & Adaptability",
            description:
              "Navigate uncertainty and iteration without defaulting to the old workflow.",
          },
          curiosity: {
            name: "Curiosity",
            description: "Ask questions and form hypotheses that open up new insight.",
          },
          ethicalJudgement: {
            name: "Ethical Judgement & Governance",
            description: "Protect privacy, fairness, compliance, and accountability.",
          },
          strategicStorytelling: {
            name: "Strategic Storytelling & Framing",
            description: "Frame complexity so people can make a decision and act.",
          },
        },
        multipliersHeading: "+2 behavioural multipliers",
        multipliersIntroduction:
          "These are not ninth and tenth core skills. They are patterns that help turn capability into outcomes.",
        multiplierItems: {
          ownershipThinking: {
            name: "Ownership Thinking",
            description:
              "See the whole outcome, connect work to business value, and take responsibility for solving the problem.",
          },
          senseOfUrgency: {
            name: "Sense of Urgency",
            description:
              "Turn pressure into strategic speed without abandoning quality or governance.",
          },
        },
        boundary:
          "The synthetic-scenario player is available for usability review, but it exposes no score or weights and provides no personal risk level, assessment result, or personalized recommendation.",
      },
    },
    assessment: {
      metadata: {
        title: "Assessment scenario prototype | Rise Pals",
        description:
          "A six-scenario usability prototype that is not validated or calibrated and provides no result or recommendation.",
      },
      eyebrow: "Assessment player prototype",
      heading: "Try six synthetic workplace scenarios, one step at a time",
      introduction:
        "This experience uses invented workplace scenarios to review the player interaction only. It is not a real assessment.",
      boundariesHeading: "What to know before you begin",
      boundaries: [
        "All six scenarios are synthetic, and this set has not been validated or calibrated.",
        "Your choices cannot predict job loss, job performance, employability, or hiring eligibility.",
        "RP-TURN-007 provides no score, proficiency level, priority gap, result, or recommendation.",
        "The player asks for no name, email, employer, experience, goals, consent profile, or free text.",
        "Starting the prototype begins only this interaction; it is not legal consent or a consent receipt.",
      ],
      storageHeading: "Temporary answer storage in this tab",
      storageBody:
        "The player keeps only scenario and selected-option IDs in this tab's sessionStorage so a refresh can return to the same step. Nothing is sent to the server, this is not durable persistence, and the data may disappear when you close the tab or when browser storage is restricted. You can clear it at any time.",
      storageUnavailable:
        "Browser session storage is unavailable. You can continue, but refreshing may remove your selections.",
      storageRestored: "The step and selections saved temporarily in this tab were restored.",
      storageDiscarded:
        "Earlier temporary state was incompatible with this prototype and was cleared safely.",
      storageCleared: "Temporary selections were cleared.",
      startLabel: "Start the six-scenario prototype",
      questionHeadingTemplate: "Scenario {current}",
      positionTemplate: "Scenario {current} of {total}",
      answeredTemplate: "Answered {answered} of {total} scenarios",
      optionGroupHint: "Choose one response before continuing.",
      answerRequired: "Choose one response before continuing.",
      assessmentIncomplete: "Answer all six scenarios before completing the prototype.",
      backLabel: "Back",
      continueLabel: "Continue",
      finishLabel: "Finish prototype",
      clearLabel: "Clear responses and return to the start",
      completionEyebrow: "All 6 scenarios answered",
      completionHeading: "You completed the synthetic scenarios",
      completionSummary:
        "Thank you for reviewing the full flow. Your choices remain temporary in this tab until you clear them or close the tab.",
      completionBoundary:
        "RP-TURN-007 calculates and displays no score, proficiency, confidence, behavioural pattern, priority gap, result, or recommendation.",
      exampleResultHeading: "View an example result that is separate from your choices",
      exampleResultBody:
        "The next page uses a predefined synthetic response fixture. It does not read, score, or use the choices you made in this tab.",
      exampleResultLinkLabel: "View a synthetic example result (your choices are not used)",
      reviewLabel: "Review responses",
      restartLabel: "Clear and start again",
      homeLabel: "Return home",
      stepAnnouncementTemplate: "Opened scenario {current} of {total}",
      completionAnnouncement:
        "All six synthetic scenarios are answered. This prototype has no result.",
    },
    exampleResult: {
      metadata: {
        title: "Synthetic skill-signal map example | Rise Pals",
        description:
          "A two-competency result example derived from a predefined synthetic fixture, never from the visitor's choices.",
      },
      eyebrow: "Synthetic result example",
      heading: "Explore a skill-signal map from one example fixture",
      introduction:
        "This page demonstrates how evidence coverage, limitations, and an example next practice could be explained using one reviewed synthetic response fixture.",
      exampleOnlyLabel: "Example only — this is not your result",
      userChoicesBoundary:
        "The page does not read, score, or use your temporary choices from the six-scenario player. The example below stays the same whatever you selected.",
      fixtureHeading: "Example provenance",
      fixtureLabel: "Synthetic response fixture ID",
      contractLabel: "Result contract version",
      coverageHeading: "What evidence this example covers",
      coverageIntroduction:
        "The six synthetic scenarios provide raw signals for only 2 of 8 core competencies and one separate single-scenario observation for each multiplier.",
      assessedHeading: "Raw signals for the 2 covered competencies",
      assessedIntroduction:
        "Filled segments represent raw fixture evidence points. They are not percentage proficiency, a skill stage, or an overall score.",
      rawEvidenceTemplate:
        "{earned} of {available} possible raw evidence points in this synthetic fixture",
      evidenceCountTemplate: "Supported by {count} synthetic scenarios",
      supportingItemsLabel: "Supporting scenario keys",
      unassessedHeading: "6 core competencies with no evidence in this fixture",
      unassessedIntroduction:
        "No fixture scenario maps to these competencies, so the example gives them no score and makes no capability inference.",
      multipliersHeading: "+2 observations kept separate from core signals",
      multipliersIntroduction:
        "Ownership Thinking and Sense of Urgency are not multiplied into or aggregated with the core signals. Each has evidence from only one scenario, which cannot establish a behavioural pattern.",
      singleScenarioLabel: "Observation from 1 synthetic scenario only",
      practiceEyebrow: "Example next practice",
      practiceHeading: "Practise checking claims in an AI summary against the original source",
      practiceBody:
        "This fixed example demonstrates a trace. It is not a selected priority gap or a personalized recommendation based on your choices.",
      practiceActionHeading: "Try the practice",
      practiceAction:
        "Choose one AI-generated summary, compare its important claims with the original source, record matches and discrepancies, then correct only what the evidence supports.",
      traceHeading: "Why this example practice is traceable",
      traceIntroduction:
        "These references let reviewers verify the scoring-model version, scenarios, target competency, and exact prototype lesson.",
      traceDefinitionLabel: "Example-practice definition",
      traceFixtureLabel: "Synthetic fixture",
      traceTargetLabel: "Example target competency",
      traceScoringModelLabel: "Synthetic scoring-model version",
      traceItemsLabel: "Supporting scenario keys",
      traceLessonLabel: "Prototype lesson-version reference",
      lessonPrototypeLabel:
        "Prototype available — not published or externally validated learning content",
      lessonLinkBoundary:
        "The result above remains a fixed synthetic example. This lesson is a prototype, and the link is not a personalized recommendation.",
      lessonLinkLabel: "Open the source-verification lesson prototype",
      limitationsHeading: "Evidence and use limitations",
      limitationsIntroduction:
        "Read every limitation before interpreting this example. Nothing here may be used to judge a person, hiring, or work readiness.",
      backToAssessmentLabel: "Return to the six-scenario prototype",
      homeLabel: "Return home",
    },
  },
} as const satisfies Record<Locale, AppCatalog>;
