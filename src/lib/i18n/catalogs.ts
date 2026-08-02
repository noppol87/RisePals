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

export type AppCatalog = Readonly<{
  shell: ShellCatalog;
  landing: LandingCatalog;
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
        ctaLabel: "ดูหลักฐานว่าโลกงานกำลังเปลี่ยนอย่างไร",
        availability:
          "ขณะนี้เป็นต้นแบบคำอธิบายสาธารณะ แบบประเมินและ onboarding ยังไม่เปิด และหน้านี้ไม่เก็บข้อมูลของคุณ",
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
          "นี่เป็นเพียงตัวอย่างกรอบแนวคิด ยังไม่มีคำถามประเมิน คะแนน น้ำหนัก ระดับความเสี่ยงส่วนบุคคล หรือคำแนะนำเฉพาะบุคคลในต้นแบบนี้",
      },
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
        ctaLabel: "See the evidence behind the change",
        availability:
          "This is a public narrative prototype. Assessment and onboarding are not available, and this page does not collect your data.",
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
          "This is a framework preview only. This prototype contains no assessment questions, scores, weights, personal risk levels, or personalized recommendations.",
      },
    },
  },
} as const satisfies Record<Locale, AppCatalog>;
