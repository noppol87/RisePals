import type { EvidenceRecord, PublishedEvidence } from "@/lib/evidence/model";
import { validateEvidenceRecords } from "@/lib/evidence/validate";
import type { Locale } from "@/lib/i18n/config";

export const evidenceRecords = [
  {
    id: "ilo-nask-genai-exposure-2025",
    localized: {
      th: {
        claim:
          "ทั่วโลก คนทำงานประมาณ 1 ใน 4 อยู่ในอาชีพที่มีภารกิจบางส่วนซึ่งอาจได้รับอิทธิพลจาก GenAI",
        interpretation:
          "ILO–NASK ชี้ว่าการเปลี่ยนรูปของงานมีแนวโน้มมากกว่าการแทนที่ทั้งอาชีพ เพราะงานส่วนใหญ่ยังมีภารกิจที่ต้องใช้มนุษย์",
        action:
          "เริ่มแยกว่างานใดควรให้เทคโนโลยีช่วย และงานใดยังต้องใช้วิจารณญาณ การตรวจสอบ และความรับผิดชอบของคุณ",
        geography: "ประมาณการระดับโลก ไม่ใช่ตัวเลขเฉพาะประเทศไทย",
        context:
          "ดัชนีระดับภารกิจในอาชีพ ผสานข้อมูลการจำแนกงาน ความเห็นของคนทำงาน การทบทวนโดยผู้เชี่ยวชาญนานาชาติ การให้คะแนนด้วย AI และข้อมูลการจ้างงานที่ ILO ปรับให้เทียบกันได้",
        doesNotProve:
          "การสัมผัสกับศักยภาพของ GenAI ไม่ได้แปลว่างานนั้นถูกแทนที่ และไม่ใช่คำทำนายว่าบุคคลใดจะตกงาน",
      },
      en: {
        claim:
          "Globally, about one in four workers are in occupations with some degree of GenAI exposure.",
        interpretation:
          "ILO–NASK finds that job transformation is more likely than replacement because most occupations still include tasks that require human input.",
        action:
          "Start separating work that technology can assist from work that still needs your judgment, verification, and accountability.",
        geography: "A global estimate, not a Thailand-specific figure.",
        context:
          "A task-level occupational index combining classification data, worker input, international expert review, AI-assisted scoring, and ILO-harmonized employment data.",
        doesNotProve:
          "GenAI exposure does not mean an occupation will be replaced and does not predict that any individual will lose their job.",
      },
    },
    source: {
      title: "Generative AI and Jobs: A Refined Global Index of Occupational Exposure",
      url: "https://www.ilo.org/publications/generative-ai-and-jobs-refined-global-index-occupational-exposure",
      publisher: "International Labour Organization (ILO) and NASK",
      publicationDate: "2025-05-20",
    },
    dateLastVerified: "2026-08-02",
    reviewDate: "2027-02-02",
  },
  {
    id: "wef-core-skills-change-2030",
    localized: {
      th: {
        claim: "นายจ้างที่ตอบแบบสำรวจคาดว่า 39% ของทักษะหลักที่คนทำงานใช้จะเปลี่ยนไปภายในปี 2030",
        interpretation:
          "สัญญาณนี้สะท้อนว่าการพัฒนาทักษะอย่างต่อเนื่องเป็นเรื่องที่ควรวางแผน ไม่ใช่รอให้บทบาทงานเปลี่ยนแล้วจึงเริ่ม",
        action:
          "เลือกทักษะที่เชื่อมกับงานจริงหนึ่งด้าน แล้วฝึกผ่านโจทย์ รับ feedback และเก็บหลักฐานว่าคุณนำไปใช้ได้",
        geography:
          "แบบสำรวจครอบคลุม 55 เขตเศรษฐกิจและ 22 กลุ่มอุตสาหกรรม รวมประเทศไทย แต่ไม่ใช่ค่าคาดการณ์เฉพาะบุคคลหรือเฉพาะประเทศไทย",
        context:
          "ข้อมูลมาจากคำตอบของบริษัททั่วโลก 1,043 ราย ซึ่งมีพนักงานรวมกันมากกว่า 14.1 ล้านคน โดยเน้นบริษัทชั้นนำที่มีพนักงานตั้งแต่ 500 คน และเก็บข้อมูลช่วงพฤษภาคม–กันยายน 2024",
        doesNotProve:
          "นี่คือความคาดหวังที่นายจ้างรายงานเอง ไม่ใช่ความแน่นอนหรือคำพยากรณ์ของคนใดคนหนึ่ง และไม่ได้ครอบคลุมธุรกิจขนาดเล็กหรือภาคแรงงานนอกระบบ",
      },
      en: {
        claim: "Surveyed employers expect 39% of workers’ core skills to change by 2030.",
        interpretation:
          "The signal makes continuous skill development worth planning now instead of waiting for a role to change first.",
        action:
          "Choose one skill connected to real work, practise it through a task, use feedback, and keep proof that you can apply it.",
        geography:
          "The survey covers 55 economies and 22 industry clusters, including Thailand; it is not an individual or Thailand-specific forecast.",
        context:
          "The dataset contains 1,043 unique responses from global companies representing more than 14.1 million employees, focused on leading employers with at least 500 employees and collected from May to September 2024.",
        doesNotProve:
          "This is a self-reported employer-expectation survey, not a certainty or individual prediction, and it does not represent small enterprises or the informal sector.",
      },
    },
    source: {
      title: "The Future of Jobs Report 2025 — 3. Skills outlook",
      url: "https://www.weforum.org/publications/the-future-of-jobs-report-2025/in-full/3-skills-outlook/",
      publisher: "World Economic Forum",
      publicationDate: "2025-01-07",
    },
    dateLastVerified: "2026-08-02",
    reviewDate: "2027-02-02",
  },
] as const satisfies readonly EvidenceRecord[];

function currentUtcDate(): string {
  return new Date().toISOString().slice(0, 10);
}

export function getPublishedEvidence(
  locale: Locale,
  publicationDate = currentUtcDate(),
): readonly PublishedEvidence[] {
  return validateEvidenceRecords(evidenceRecords, { publicationDate }).map((record) => ({
    ...record,
    content: record.localized[locale],
  }));
}
