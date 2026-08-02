import type {
  CoreCompetencyDefinition,
  CoreCompetencyId,
  FrameworkDefinition,
  MultiplierDefinition,
} from "@/modules/assessment/types";

export const FRAMEWORK_VERSION_ID = "framework-rise-pals-8-plus-2-v2";

export const canonicalCoreWeightBasisPoints = {
  "critical-thinking-fact-checking": 2_000,
  "systematic-thinking": 1_500,
  "growth-mindset": 1_500,
  "emotional-intelligence": 1_000,
  "resilience-adaptability": 1_000,
  curiosity: 1_000,
  "ethical-judgement-governance": 1_000,
  "strategic-storytelling-framing": 1_000,
} as const satisfies Readonly<Record<CoreCompetencyId, number>>;

export const coreCompetencies = [
  {
    id: "critical-thinking-fact-checking",
    kind: "core",
    weightBasisPoints: canonicalCoreWeightBasisPoints["critical-thinking-fact-checking"],
    displayOrder: 1,
    name: { th: "การคิดเชิงวิพากษ์และตรวจสอบข้อเท็จจริง", en: "Critical Thinking & Fact-Checking" },
  },
  {
    id: "systematic-thinking",
    kind: "core",
    weightBasisPoints: canonicalCoreWeightBasisPoints["systematic-thinking"],
    displayOrder: 2,
    name: { th: "การคิดอย่างเป็นระบบ", en: "Systematic Thinking" },
  },
  {
    id: "growth-mindset",
    kind: "core",
    weightBasisPoints: canonicalCoreWeightBasisPoints["growth-mindset"],
    displayOrder: 3,
    name: { th: "กรอบความคิดแบบเติบโต", en: "Growth Mindset" },
  },
  {
    id: "emotional-intelligence",
    kind: "core",
    weightBasisPoints: canonicalCoreWeightBasisPoints["emotional-intelligence"],
    displayOrder: 4,
    name: { th: "ความฉลาดทางอารมณ์", en: "Emotional Intelligence / EQ" },
  },
  {
    id: "resilience-adaptability",
    kind: "core",
    weightBasisPoints: canonicalCoreWeightBasisPoints["resilience-adaptability"],
    displayOrder: 5,
    name: { th: "ความยืดหยุ่นและการปรับตัว", en: "Resilience & Adaptability" },
  },
  {
    id: "curiosity",
    kind: "core",
    weightBasisPoints: canonicalCoreWeightBasisPoints.curiosity,
    displayOrder: 6,
    name: { th: "ความอยากรู้อยากเห็น", en: "Curiosity" },
  },
  {
    id: "ethical-judgement-governance",
    kind: "core",
    weightBasisPoints: canonicalCoreWeightBasisPoints["ethical-judgement-governance"],
    displayOrder: 7,
    name: { th: "วิจารณญาณด้านจริยธรรมและธรรมาภิบาล", en: "Ethical Judgement & Governance" },
  },
  {
    id: "strategic-storytelling-framing",
    kind: "core",
    weightBasisPoints: canonicalCoreWeightBasisPoints["strategic-storytelling-framing"],
    displayOrder: 8,
    name: { th: "การเล่าเรื่องและวางกรอบเชิงกลยุทธ์", en: "Strategic Storytelling & Framing" },
  },
] as const satisfies readonly CoreCompetencyDefinition[];

export const multiplierDefinitions = [
  {
    id: "ownership-thinking",
    kind: "multiplier",
    displayOrder: 1,
    name: { th: "การคิดแบบเจ้าของ", en: "Ownership Thinking" },
  },
  {
    id: "sense-of-urgency",
    kind: "multiplier",
    displayOrder: 2,
    name: { th: "การรับรู้และตอบสนองต่อความเร่งด่วน", en: "Sense of Urgency" },
  },
] as const satisfies readonly MultiplierDefinition[];

export const assessmentFramework = {
  id: FRAMEWORK_VERSION_ID,
  frameworkKey: "rise-pals-8-plus-2",
  version: "2.0",
  coreCompetencies,
  multipliers: multiplierDefinitions,
} as const satisfies FrameworkDefinition;
