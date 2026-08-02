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
  reviewLabel: string;
  restartLabel: string;
  homeLabel: string;
  stepAnnouncementTemplate: string;
  completionAnnouncement: string;
}>;

export type AppCatalog = Readonly<{
  shell: ShellCatalog;
  landing: LandingCatalog;
  assessment: AssessmentPlayerCatalog;
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
      reviewLabel: "ทบทวนคำตอบ",
      restartLabel: "ล้างและเริ่มใหม่",
      homeLabel: "กลับหน้าหลัก",
      stepAnnouncementTemplate: "เปิดสถานการณ์ {current} จาก {total}",
      completionAnnouncement: "ตอบสถานการณ์จำลองครบทั้งหกแล้ว ไม่มีผลลัพธ์ในต้นแบบนี้",
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
      reviewLabel: "Review responses",
      restartLabel: "Clear and start again",
      homeLabel: "Return home",
      stepAnnouncementTemplate: "Opened scenario {current} of {total}",
      completionAnnouncement:
        "All six synthetic scenarios are answered. This prototype has no result.",
    },
  },
} as const satisfies Record<Locale, AppCatalog>;
