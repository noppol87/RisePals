import type { Locale } from "@/lib/i18n/config";

export type ShellCatalog = Readonly<{
  brandName: string;
  skipToContent: string;
  navigationLabel: string;
  homeLabel: string;
  profileLabel: string;
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
    headingAccent: string;
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
  persistedAttemptHeading: string;
  persistedAttemptBody: string;
  persistedAttemptLinkLabel: string;
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
      profileLabel: "บัญชีทดลอง",
      languageSwitcherLabel: "เลือกภาษา",
      currentLanguageLabel: "ภาษาปัจจุบัน",
      languageNames: {
        th: "ไทย",
        en: "English",
      },
    },
    landing: {
      hero: {
        eyebrow: "ค่อย ๆ เก่งขึ้น ในแบบคุณ",
        heading: "ไม่ต้องเก่งทุกอย่าง",
        headingAccent: "เริ่มแค่อย่างเดียว",
        introduction: "ลองคิด ลองทำ แล้วค่อย ๆ เพิ่มทักษะที่ใช้ได้จริง",
        supporting: "ไม่ต้องสมัคร",
        ctaLabel: "ลองเช็กคำตอบ AI",
        availability: "เดโมสถานการณ์จำลอง ยังไม่ให้คะแนน",
      },
      evidence: {
        eyebrow: "อยากรู้ที่มา?",
        heading: "ทำไมต้องฝึกทักษะเหล่านี้",
        introduction: "ข้อมูลภาพรวมของงาน ไม่ใช่คำทำนายว่าใครจะตกงาน",
        signalLabel: "ข้อมูลที่พบ",
        interpretationLabel: "หมายความว่า",
        actionLabel: "ลองเริ่มจาก",
        geographyLabel: "ขอบเขตพื้นที่",
        contextLabel: "ศึกษาจากอะไร",
        limitationLabel: "อ่านควบคู่กัน",
        sourceLabel: "อ่านต้นฉบับ",
        publishedLabel: "เผยแพร่",
        verifiedLabel: "ตรวจสอบล่าสุด",
        reviewLabel: "ทบทวนภายใน",
      },
      response: {
        eyebrow: "ค่อยเป็นค่อยไป",
        heading: "จากลองทำ สู่ทำได้จริง",
        introduction: "เลือกจุดเริ่ม แล้วค่อยไปต่อ",
        loopLabel: "วงจรการพัฒนาของ Rise Pals",
        steps: {
          diagnose: {
            name: "รู้จักตัวเอง",
            description: "ลองตัดสินใจในโจทย์ใกล้ตัว",
          },
          prioritize: {
            name: "เลือกจุดเริ่ม",
            description: "ฝึกทีละเรื่อง ไม่ต้องรีบ",
          },
          learn: {
            name: "เรียนให้เข้าใจ",
            description: "จับหลักที่ใช้กับงานได้",
          },
          practice: {
            name: "ลองใช้จริง",
            description: "ลองผิดได้ แล้วค่อยปรับ",
          },
          prove: {
            name: "เก็บผลงาน",
            description: "ให้สิ่งที่ทำเล่าแทนคุณ",
          },
          opportunity: {
            name: "ต่อยอดโอกาส",
            description: "ใช้ทักษะเปิดทางใหม่",
          },
        },
        practiceNote: "ตอนนี้ลองตอบโจทย์และฝึกได้ ส่วนการต่อยอดสู่งานยังอยู่ระหว่างพัฒนา",
      },
      framework: {
        eyebrow: "ทักษะที่เราชวนฝึก",
        heading: "8 ทักษะ + 2 นิสัย",
        introduction: "ไม่ต้องฝึกครบทุกด้าน เริ่มจากเรื่องที่อยากลอง",
        coreHeading: "8 ทักษะหลัก",
        coreIntroduction: "เลือกฝึกทีละทักษะ",
        core: {
          criticalThinking: {
            name: "คิดก่อนเชื่อ",
            description: "เช็กข้อมูลและเหตุผลก่อนตัดสินใจ",
          },
          systematicThinking: {
            name: "มองภาพรวม",
            description: "เห็นว่างานแต่ละส่วนเชื่อมกันยังไง",
          },
          growthMindset: {
            name: "กล้าลองใหม่",
            description: "เปิดรับวิธีใหม่ แล้วลองปรับใช้",
          },
          emotionalIntelligence: {
            name: "เข้าใจคน",
            description: "ฟังให้เข้าใจ และทำงานร่วมกัน",
          },
          resilience: {
            name: "ปรับตัวได้",
            description: "ตั้งหลักแล้วไปต่อเมื่อแผนเปลี่ยน",
          },
          curiosity: {
            name: "ช่างสงสัย",
            description: "ถามต่อ เพื่อเห็นสิ่งที่ยังไม่รู้",
          },
          ethicalJudgement: {
            name: "ใช้ข้อมูลอย่างรับผิดชอบ",
            description: "เคารพความเป็นส่วนตัว กติกา และความเป็นธรรม",
          },
          strategicStorytelling: {
            name: "เล่าเรื่องให้เข้าใจ",
            description: "ย่อยเรื่องยากให้คนเข้าใจและนำไปใช้",
          },
        },
        multipliersHeading: "2 นิสัยที่ช่วยให้ไปต่อ",
        multipliersIntroduction: "สองข้อนี้ช่วยเสริมทักษะ ไม่ใช่ทักษะที่ 9 และ 10",
        multiplierItems: {
          ownershipThinking: {
            name: "รับผิดชอบจนจบ",
            description: "มองผลลัพธ์รวม ไม่หยุดแค่ทำงานของตัวเองให้ครบ",
          },
          senseOfUrgency: {
            name: "เริ่มให้ไว ใส่ใจคุณภาพ",
            description: "แยกเรื่องสำคัญ แล้วลงมือโดยไม่ทิ้งคุณภาพ",
          },
        },
        boundary: "กรอบนี้ใช้ชวนฝึก ไม่ใช่ผลประเมินของคุณ",
      },
    },
    assessment: {
      metadata: {
        title: "ต้นแบบสถานการณ์ประเมิน | Rise Pals",
        description:
          "ต้นแบบการใช้งาน 6 สถานการณ์จำลองที่ไม่ผ่านการตรวจสอบความเที่ยงตรงและไม่มีผลลัพธ์หรือคำแนะนำ",
      },
      eyebrow: "ลองสำรวจตัวเอง",
      heading: "ถ้าเจอแบบนี้ คุณจะทำยังไง?",
      introduction: "ลองตอบ 6 สถานการณ์ในที่ทำงาน ไม่มีคะแนน และไม่ต้องสมัคร",
      boundariesHeading: "รู้ไว้ก่อนลอง",
      boundaries: [
        "โจทย์สมมติ ยังไม่ใช่แบบประเมินที่ผ่านการตรวจสอบ",
        "ไม่ทำนายอนาคตการทำงาน และไม่ใช้ตัดสินการจ้างงาน",
        "ไม่ให้คะแนน ระดับทักษะ หรือคำแนะนำเฉพาะตัว",
        "ไม่ขอชื่อ อีเมล หรือข้อมูลส่วนตัว",
        "กดเริ่มคือการลองเดโม ไม่ใช่การยินยอมใช้ข้อมูลส่วนตัว",
      ],
      storageHeading: "คำตอบเก็บไว้ตรงไหน?",
      storageBody:
        "เก็บชั่วคราวในแท็บนี้ รีเฟรชแล้วทำต่อได้ ไม่ส่งขึ้นเซิร์ฟเวอร์ ปิดแท็บแล้วอาจหาย และล้างได้ทุกเมื่อ",
      storageUnavailable: "ตอนนี้เก็บคำตอบในแท็บไม่ได้ รีเฟรชแล้วอาจต้องเริ่มใหม่",
      storageRestored: "กลับมาทำต่อจากข้อเดิมได้เลย",
      storageDiscarded: "เดโมเปลี่ยนไปแล้ว มาเริ่มกันใหม่นะ",
      storageCleared: "ล้างคำตอบชั่วคราวแล้ว",
      persistedAttemptHeading: "อยากลองแบบบันทึกคำตอบ?",
      persistedAttemptBody:
        "ต้องใช้บัญชีทดลองและยินยอมใช้ข้อมูลก่อน โดยจะเริ่มใหม่ ไม่ย้ายคำตอบจากหน้านี้",
      persistedAttemptLinkLabel: "ไปแบบบันทึกคำตอบ",
      startLabel: "เริ่มลองกัน",
      questionHeadingTemplate: "สถานการณ์ที่ {current}",
      positionTemplate: "สถานการณ์ {current} จาก {total}",
      answeredTemplate: "ตอบแล้ว {answered} จาก {total} สถานการณ์",
      optionGroupHint: "เลือกข้อที่ใกล้กับสิ่งที่คุณจะทำ",
      answerRequired: "เลือกสักข้อก่อนนะ",
      assessmentIncomplete: "ยังตอบไม่ครบ ลองดูข้อที่เหลือก่อนนะ",
      backLabel: "ย้อนกลับ",
      continueLabel: "ข้อต่อไป",
      finishLabel: "เสร็จแล้ว",
      clearLabel: "ล้างแล้วเริ่มใหม่",
      completionEyebrow: "ครบทั้ง 6 สถานการณ์",
      completionHeading: "ครบแล้ว เก่งมากที่ลองจนจบ",
      completionSummary: "คำตอบอยู่ชั่วคราวในแท็บนี้ ล้างหรือปิดแท็บได้เมื่อพร้อม",
      completionBoundary: "เดโมนี้ยังไม่คำนวณคะแนนหรือแนะนำทักษะเฉพาะตัว",
      exampleResultHeading: "อยากเห็นหน้าผลลัพธ์?",
      exampleResultBody: "ดูตัวอย่างจากคำตอบที่ทีมเตรียมไว้ ไม่ใช่ผลจากคำตอบของคุณ",
      exampleResultLinkLabel: "ดูผลลัพธ์ตัวอย่าง",
      reviewLabel: "ทบทวนคำตอบ",
      restartLabel: "ล้างและเริ่มใหม่",
      homeLabel: "กลับหน้าหลัก",
      stepAnnouncementTemplate: "เปิดสถานการณ์ {current} จาก {total}",
      completionAnnouncement: "ตอบครบ 6 ข้อแล้ว เดโมนี้ยังไม่มีผลคะแนน",
    },
    exampleResult: {
      metadata: {
        title: "ตัวอย่างแผนที่สัญญาณทักษะ | Rise Pals",
        description:
          "ตัวอย่างผลลัพธ์สองทักษะจากชุดคำตอบจำลองที่กำหนดไว้ โดยไม่ใช้คำตอบของผู้เข้าชม",
      },
      eyebrow: "ลองดูหน้าผลลัพธ์",
      heading: "เห็นทักษะ แล้วลองฝึกต่อ",
      introduction: "นี่คือตัวอย่างจากคำตอบสมมติของทีม",
      exampleOnlyLabel: "ตัวอย่างเท่านั้น",
      userChoicesBoundary: "ไม่ใช่ผลจากคำตอบของคุณ",
      fixtureHeading: "ตัวอย่างนี้มาจากไหน?",
      fixtureLabel: "รหัสชุดคำตอบจำลอง",
      contractLabel: "รุ่นโครงสร้างผลลัพธ์",
      coverageHeading: "โจทย์ชุดนี้ดูอะไรบ้าง",
      coverageIntroduction: "ดูได้บางทักษะเท่านั้น ยังสรุปภาพรวมไม่ได้",
      assessedHeading: "ทักษะที่มีข้อมูล",
      assessedIntroduction: "ดูคะแนนพร้อมเหตุผลจากแต่ละโจทย์",
      rawEvidenceTemplate: "แต้มหลักฐานดิบ {earned} จาก {available} แต้มที่เป็นไปได้ในชุดจำลองนี้",
      evidenceCountTemplate: "อ้างอิง {count} สถานการณ์จำลอง",
      supportingItemsLabel: "รหัสสถานการณ์ที่รองรับ",
      unassessedHeading: "ทักษะที่ยังไม่ได้ดู",
      unassessedIntroduction: "ไม่มีข้อมูล ไม่ได้แปลว่าทำไม่ได้",
      multipliersHeading: "นิสัยที่สังเกตได้",
      multipliersIntroduction: "เห็นจากโจทย์เดียว ยังสรุปว่าเป็นนิสัยประจำไม่ได้",
      singleScenarioLabel: "จากสถานการณ์เดียว",
      practiceEyebrow: "ลองฝึกต่อ",
      practiceHeading: "เริ่มจากเช็กข้อมูลให้ชัวร์",
      practiceBody: "ลองตรวจคำตอบของ AI ก่อนนำไปใช้",
      practiceActionHeading: "วิธีทดลองฝึก",
      practiceAction:
        "เลือกสรุปจาก AI หนึ่งชิ้น เทียบข้ออ้างสำคัญกับแหล่งต้นฉบับ บันทึกจุดที่ตรงและไม่ตรง แล้วแก้เฉพาะส่วนที่ตรวจสอบหลักฐานได้",
      traceHeading: "ที่มาของตัวอย่าง",
      traceIntroduction: "รายละเอียดสำหรับตรวจสอบวิธีให้คะแนน",
      traceDefinitionLabel: "รุ่นตัวอย่างการฝึก",
      traceFixtureLabel: "ชุดคำตอบจำลอง",
      traceTargetLabel: "ทักษะเป้าหมายของตัวอย่าง",
      traceScoringModelLabel: "รุ่นวิธีให้คะแนนจำลอง",
      traceItemsLabel: "รหัสสถานการณ์ที่รองรับ",
      traceLessonLabel: "รหัสรุ่นบทเรียนต้นแบบ",
      lessonPrototypeLabel: "บทเรียนเดโม · ยังไม่ผ่านการตรวจสอบผลการเรียนรู้",
      lessonLinkBoundary: "บทเรียนตัวอย่าง ไม่ใช่คำแนะนำจากคำตอบของคุณ",
      lessonLinkLabel: "ลองบทเรียนนี้",
      limitationsHeading: "ข้อจำกัดที่ควรรู้",
      limitationsIntroduction: "ไม่ใช้ผลตัวอย่างนี้ตัดสินความสามารถหรือการจ้างงาน",
      backToAssessmentLabel: "กลับไปลองตอบ",
      homeLabel: "กลับหน้าหลัก",
    },
  },
  en: {
    shell: {
      brandName: "Rise Pals",
      skipToContent: "Skip to main content",
      navigationLabel: "Primary navigation",
      homeLabel: "Home",
      profileLabel: "Test account",
      languageSwitcherLabel: "Choose language",
      currentLanguageLabel: "Current language",
      languageNames: {
        th: "ไทย",
        en: "English",
      },
    },
    landing: {
      hero: {
        eyebrow: "SMALL STEPS. REAL PRACTICE.",
        heading: "You don’t need it all.",
        headingAccent: "Just a place to start.",
        introduction: "Try a scenario. Practise a skill. Take your next step.",
        supporting: "No sign-up needed",
        ctaLabel: "Try checking an AI answer",
        availability: "Synthetic demo. No assessment score.",
      },
      evidence: {
        eyebrow: "THE EVIDENCE",
        heading: "Why build these skills?",
        introduction: "Workforce trends, not predictions about you.",
        signalLabel: "Finding",
        interpretationLabel: "What it means",
        actionLabel: "A next step",
        geographyLabel: "Geographic scope",
        contextLabel: "Study context",
        limitationLabel: "Keep in mind",
        sourceLabel: "Read the source",
        publishedLabel: "Published",
        verifiedLabel: "Last verified",
        reviewLabel: "Review by",
      },
      response: {
        eyebrow: "ONE STEP AT A TIME",
        heading: "From trying to doing.",
        introduction: "Pick a starting point. Keep going.",
        loopLabel: "The Rise Pals development loop",
        steps: {
          diagnose: {
            name: "Explore",
            description: "Try a workplace scenario.",
          },
          prioritize: {
            name: "Focus",
            description: "Pick one thing to build.",
          },
          learn: {
            name: "Learn",
            description: "Get the idea.",
          },
          practice: {
            name: "Practise",
            description: "Try, reflect, try again.",
          },
          prove: {
            name: "Show your work",
            description: "Build evidence of your skills.",
          },
          opportunity: {
            name: "Find opportunities",
            description: "Open doors over time.",
          },
        },
        practiceNote:
          "Scenarios and practice are available. Career opportunities are still in development.",
      },
      framework: {
        eyebrow: "WHAT YOU CAN BUILD",
        heading: "8 skills. 2 habits.",
        introduction: "Start with one that interests you.",
        coreHeading: "8 core skills",
        coreIntroduction: "Build one skill at a time.",
        core: {
          criticalThinking: {
            name: "Think critically",
            description: "Check the evidence before acting.",
          },
          systematicThinking: {
            name: "See the system",
            description: "Connect the parts and their effects.",
          },
          growthMindset: {
            name: "Keep learning",
            description: "Try new ideas and adjust.",
          },
          emotionalIntelligence: {
            name: "Understand people",
            description: "Listen, communicate and collaborate.",
          },
          resilience: {
            name: "Adapt and recover",
            description: "Find your next step when plans change.",
          },
          curiosity: {
            name: "Stay curious",
            description: "Ask questions that open up ideas.",
          },
          ethicalJudgement: {
            name: "Act responsibly",
            description: "Protect privacy, fairness and accountability.",
          },
          strategicStorytelling: {
            name: "Tell a clear story",
            description: "Make complex ideas useful.",
          },
        },
        multipliersHeading: "2 habits that help",
        multipliersIntroduction: "These support the skills; they are not a ninth and tenth skill.",
        multiplierItems: {
          ownershipThinking: {
            name: "Take ownership",
            description: "Care about the whole outcome.",
          },
          senseOfUrgency: {
            name: "Act with purpose",
            description: "Move promptly without cutting corners.",
          },
        },
        boundary: "A practice framework, not your assessment result.",
      },
    },
    assessment: {
      metadata: {
        title: "Assessment scenario prototype | Rise Pals",
        description:
          "A six-scenario usability prototype that is not validated or calibrated and provides no result or recommendation.",
      },
      eyebrow: "A LITTLE SELF-EXPLORATION",
      heading: "What would you do?",
      introduction: "Try 6 workplace scenarios. No score. No sign-up.",
      boundariesHeading: "Before you try",
      boundaries: [
        "Fictional scenarios, not a validated assessment.",
        "No predictions about work or hiring.",
        "No score, skill rating or personal recommendation.",
        "No name, email or personal details requested.",
        "Starting the demo does not grant data consent.",
      ],
      storageHeading: "Where do answers go?",
      storageBody:
        "Only in this browser tab, so you can refresh and resume. Nothing is sent to the server. Closing the tab may clear them. You can clear them any time.",
      storageUnavailable: "Answers cannot be saved in this tab. A refresh may reset them.",
      storageRestored: "Welcome back. Pick up where you left off.",
      storageDiscarded: "The demo has changed. Start fresh.",
      storageCleared: "Temporary selections were cleared.",
      persistedAttemptHeading: "Want to try saved responses?",
      persistedAttemptBody:
        "Use a test account and agree to data use first. This starts fresh; your tab answers are not copied.",
      persistedAttemptLinkLabel: "Try saved responses",
      startLabel: "Let’s try it",
      questionHeadingTemplate: "Scenario {current}",
      positionTemplate: "Scenario {current} of {total}",
      answeredTemplate: "Answered {answered} of {total} scenarios",
      optionGroupHint: "Choose one response before continuing.",
      answerRequired: "Choose one response before continuing.",
      assessmentIncomplete: "Answer all six scenarios before completing the prototype.",
      backLabel: "Back",
      continueLabel: "Continue",
      finishLabel: "Finish prototype",
      clearLabel: "Clear and restart",
      completionEyebrow: "All 6 scenarios answered",
      completionHeading: "You made it through.",
      completionSummary: "Your choices stay in this tab until cleared or closed.",
      completionBoundary: "This demo calculates no score or personal recommendation.",
      exampleResultHeading: "Curious about the results page?",
      exampleResultBody: "View an example from prepared answers. It does not use your choices.",
      exampleResultLinkLabel: "See an example result",
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
      eyebrow: "A LOOK AT RESULTS",
      heading: "See the skills. Try a next step.",
      introduction: "An example built from prepared answers.",
      exampleOnlyLabel: "Example only",
      userChoicesBoundary: "Not a result from your choices.",
      fixtureHeading: "Where this example comes from",
      fixtureLabel: "Synthetic response fixture ID",
      contractLabel: "Result contract version",
      coverageHeading: "What these scenarios cover",
      coverageIntroduction: "A few skills, not a full picture.",
      assessedHeading: "Skills with evidence",
      assessedIntroduction: "Read the evidence alongside each signal.",
      rawEvidenceTemplate:
        "{earned} of {available} possible raw evidence points in this synthetic fixture",
      evidenceCountTemplate: "Supported by {count} synthetic scenarios",
      supportingItemsLabel: "Supporting scenario keys",
      unassessedHeading: "Skills not covered",
      unassessedIntroduction: "Missing evidence does not mean missing ability.",
      multipliersHeading: "Habits to notice",
      multipliersIntroduction: "One scenario cannot establish a lasting habit.",
      singleScenarioLabel: "One scenario only",
      practiceEyebrow: "TRY A NEXT STEP",
      practiceHeading: "Check before you trust.",
      practiceBody: "Try verifying an AI-generated claim.",
      practiceActionHeading: "Try the practice",
      practiceAction:
        "Choose one AI-generated summary, compare its important claims with the original source, record matches and discrepancies, then correct only what the evidence supports.",
      traceHeading: "Example references",
      traceIntroduction: "Details for checking the scoring method.",
      traceDefinitionLabel: "Example-practice definition",
      traceFixtureLabel: "Synthetic fixture",
      traceTargetLabel: "Example target competency",
      traceScoringModelLabel: "Synthetic scoring-model version",
      traceItemsLabel: "Supporting scenario keys",
      traceLessonLabel: "Prototype lesson-version reference",
      lessonPrototypeLabel: "Lesson demo · learning outcomes not externally validated",
      lessonLinkBoundary: "An example lesson, not a recommendation based on your choices.",
      lessonLinkLabel: "Try this lesson",
      limitationsHeading: "Know the limits",
      limitationsIntroduction: "Do not use this example to judge ability or hiring.",
      backToAssessmentLabel: "Back to the scenarios",
      homeLabel: "Return home",
    },
  },
} as const satisfies Record<Locale, AppCatalog>;
