"use client";

import { useState } from "react";
import { ArrowIcon } from "@/components/brand-mark";
import { TextLink } from "@/components/primitives/text-link";
import { sourceVerificationLessonPath, type Locale } from "@/lib/i18n/config";

type GoalKey = "flow" | "change" | "opportunity" | "explore";

type Goal = Readonly<{
  icon: string;
  label: string;
  situations: readonly string[];
  path: string;
  reason: string;
  available: boolean;
}>;

const copy: Record<
  Locale,
  Readonly<{
    eyebrow: string;
    heading: string;
    lead: string;
    step: string;
    context: string;
    situationContextHeading: string;
    situationContextLead: string;
    situationHeading: string;
    situationLead: string;
    other: string;
    resultEyebrow: string;
    resultHeading: string;
    yourGoal: string;
    whatHappened: string;
    startWith: string;
    honestAvailable: string;
    honestComing: string;
    tryMission: string;
    tryNearby: string;
    back: string;
    reset: string;
    privacy: string;
    goals: Readonly<Record<GoalKey, Goal>>;
  }>
> = {
  th: {
    eyebrow: "เริ่มจากเรื่องของคุณ",
    heading: "อยากให้การทำงานดีขึ้นตรงไหน?",
    lead: "เลือกเรื่องที่ใกล้ตัวที่สุด เดี๋ยวเราช่วยหาจุดเริ่มให้",
    step: "จุดเริ่ม",
    context: "เลือก 1 เรื่อง",
    situationContextHeading: "มาดูกันว่างานติดตรงไหน",
    situationContextLead: "อีกหนึ่งคำตอบ แล้วเราจะช่วยชี้ทางเริ่มให้",
    situationHeading: "ช่วงนี้ เรื่องไหนกระทบงานคุณมากที่สุด?",
    situationLead: "เลือกเหตุการณ์ที่ใกล้เคียง ไม่ต้องตรงทุกคำ",
    other: "ยังไม่ตรงกับฉัน",
    resultEyebrow: "ทางเริ่มของคุณ",
    resultHeading: "เริ่มเล็ก ๆ จากเรื่องนี้ก่อน",
    yourGoal: "สิ่งที่คุณอยากให้ดีขึ้น",
    whatHappened: "เหตุการณ์ที่ใกล้ตัว",
    startWith: "ลองสำรวจ",
    honestAvailable: "มีภารกิจให้ลองแล้ว ใช้สถานการณ์จำลองและยังไม่บันทึกผล",
    honestComing:
      "ทางนี้ยังอยู่ระหว่างพัฒนา วันนี้ลองภารกิจใกล้เคียงเพื่อรู้จักวิธีฝึกของ Rise Pals ก่อนได้",
    tryMission: "เริ่มภารกิจแรก",
    tryNearby: "ลองภารกิจที่มีตอนนี้",
    back: "ย้อนกลับ",
    reset: "เปลี่ยนคำตอบก่อนหน้า",
    privacy: "สิ่งที่เลือกอยู่แค่ในหน้านี้ · ไม่ใช่ผลประเมิน",
    goals: {
      flow: {
        icon: "↗",
        label: "อยากให้งานราบรื่นขึ้น",
        situations: [
          "งานต้องกลับมาแก้หลายรอบ",
          "รอข้อมูลจนงานไปต่อไม่ได้",
          "หลายเรื่องชนกันจนเลือกไม่ถูก",
        ],
        path: "มองงานให้เป็นระบบ",
        reason: "แยกสิ่งที่ควบคุมได้ เห็นจุดติดขัด และเลือกแก้ตรงที่ส่งผลจริง",
        available: false,
      },
      change: {
        icon: "✦",
        label: "อยากรับมือวิธีทำงานใหม่",
        situations: [
          "ไม่แน่ใจว่าข้อมูลจาก AI เชื่อได้แค่ไหน",
          "เครื่องมือใหม่ทำให้ขั้นตอนเดิมเปลี่ยน",
          "อยากใช้เครื่องมือใหม่โดยไม่สร้างความเสี่ยง",
        ],
        path: "คิดก่อนเชื่อและใช้ข้อมูลให้ชัวร์",
        reason: "ฝึกแยกข้ออ้างออกจากหลักฐาน ก่อนนำคำตอบหรือเครื่องมือใหม่ไปใช้กับงานจริง",
        available: true,
      },
      opportunity: {
        icon: "◎",
        label: "อยากพร้อมสำหรับโอกาสถัดไป",
        situations: [
          "มีผลงานแต่เล่าให้คนอื่นเห็นคุณค่าไม่ชัด",
          "ยังไม่รู้ว่าควรพัฒนาอะไรก่อน",
          "อยากรับผิดชอบงานที่ใหญ่ขึ้น",
        ],
        path: "เล่าคุณค่าของงานให้เห็นภาพ",
        reason: "เริ่มจากเชื่อมสิ่งที่ทำกับผลที่เกิดขึ้น เพื่อให้คนอื่นเข้าใจคุณค่าของผลงาน",
        available: false,
      },
      explore: {
        icon: "~",
        label: "ยังไม่แน่ใจ ขอสำรวจก่อน",
        situations: [
          "งานเปลี่ยนไป แต่ยังบอกไม่ได้ว่าติดตรงไหน",
          "อยากรู้ว่าทักษะแบบไหนช่วยงานได้",
          "ยังไม่มีปัญหาชัด แต่อยากเตรียมตัว",
        ],
        path: "ลองตัดสินใจจากข้อมูล",
        reason:
          "ใช้ภารกิจสั้น ๆ เพื่อสังเกตวิธีคิดของตัวเอง โดยยังไม่รีบสรุปว่าเก่งหรืออ่อนด้านไหน",
        available: true,
      },
    },
  },
  en: {
    eyebrow: "START WITH YOUR WORLD",
    heading: "What would you like to improve at work?",
    lead: "Pick what feels closest. We’ll help you find a small first step.",
    step: "Starting point",
    context: "Choose one",
    situationContextHeading: "Let’s find what is getting in the way.",
    situationContextLead: "One more answer will help us suggest a starting path.",
    situationHeading: "What has affected your work most lately?",
    situationLead: "Choose the closest situation. It does not need to match perfectly.",
    other: "None of these fits",
    resultEyebrow: "YOUR STARTING PATH",
    resultHeading: "Start small with this.",
    yourGoal: "What you want to improve",
    whatHappened: "A situation close to yours",
    startWith: "Explore",
    honestAvailable:
      "A practice mission is ready. It uses a fictional case and does not save progress.",
    honestComing:
      "This path is still in development. You can try the closest available mission to see how Rise Pals practice works.",
    tryMission: "Start your first mission",
    tryNearby: "Try the available mission",
    back: "Back",
    reset: "Change earlier answers",
    privacy: "Your choices stay on this page · This is not an assessment result",
    goals: {
      flow: {
        icon: "↗",
        label: "Make work run more smoothly",
        situations: [
          "Work keeps coming back for revisions",
          "Missing information blocks progress",
          "Too many priorities compete at once",
        ],
        path: "See the system around the work",
        reason: "Separate what you can influence, spot the constraint and act where it matters.",
        available: false,
      },
      change: {
        icon: "✦",
        label: "Handle new tools and ways of working",
        situations: [
          "I am unsure whether an AI answer is reliable",
          "A new tool changed the old workflow",
          "I want to use new tools without creating risk",
        ],
        path: "Check the evidence before acting",
        reason: "Separate claims from evidence before using an answer or tool in real work.",
        available: true,
      },
      opportunity: {
        icon: "◎",
        label: "Prepare for my next opportunity",
        situations: [
          "I struggle to show the value of my work",
          "I do not know what to build first",
          "I want to take on broader responsibility",
        ],
        path: "Make the value of your work clear",
        reason: "Connect what you did to what changed, so others can understand its value.",
        available: false,
      },
      explore: {
        icon: "~",
        label: "I’m not sure yet",
        situations: [
          "Work is changing but I cannot name the problem",
          "I want to see which skills could help",
          "Nothing is urgent; I want to prepare",
        ],
        path: "Make a decision from evidence",
        reason:
          "Use a short mission to notice how you think, without rushing to label a strength or gap.",
        available: true,
      },
    },
  },
};

export function FirstVisitJourney({ locale }: Readonly<{ locale: Locale }>) {
  const messages = copy[locale];
  const [goalKey, setGoalKey] = useState<GoalKey | null>(null);
  const [situation, setSituation] = useState<string | null>(null);
  const goal = goalKey === null ? null : messages.goals[goalKey];
  const stage = situation === null ? (goal === null ? 1 : 2) : 3;

  function reset() {
    setGoalKey(null);
    setSituation(null);
  }

  return (
    <section className="first-visit" aria-labelledby="first-visit-heading">
      <div className="first-visit__intro">
        <p className="section-heading__eyebrow">{messages.eyebrow}</p>
        <h1 id="first-visit-heading">
          {stage === 1
            ? messages.heading
            : stage === 2
              ? messages.situationContextHeading
              : messages.resultHeading}
        </h1>
        <p>
          {stage === 1 ? messages.lead : stage === 2 ? messages.situationContextLead : goal?.reason}
        </p>
        <div className="first-visit__trail" aria-label={`${messages.step} ${stage} / 3`}>
          {[1, 2, 3].map((item) => (
            <span key={item} className={item <= stage ? "is-active" : undefined} />
          ))}
          <small>{stage} / 3</small>
        </div>
      </div>

      <div className="first-visit__task" aria-live="polite">
        {stage === 1 ? (
          <>
            <p className="first-visit__prompt">{messages.context}</p>
            <div className="first-visit__choices">
              {(Object.keys(messages.goals) as GoalKey[]).map((key) => (
                <button key={key} type="button" onClick={() => setGoalKey(key)}>
                  <span aria-hidden="true">{messages.goals[key].icon}</span>
                  {messages.goals[key].label}
                  <b aria-hidden="true">→</b>
                </button>
              ))}
            </div>
          </>
        ) : stage === 2 && goal !== null ? (
          <>
            <p className="first-visit__selected">
              <small>{messages.yourGoal}</small>
              {goal.label}
            </p>
            <div className="first-visit__question">
              <h2>{messages.situationHeading}</h2>
              <p>{messages.situationLead}</p>
            </div>
            <div className="first-visit__choices first-visit__choices--situations">
              {goal.situations.map((item) => (
                <button key={item} type="button" onClick={() => setSituation(item)}>
                  {item}
                  <b aria-hidden="true">→</b>
                </button>
              ))}
              <button type="button" onClick={() => setSituation(messages.other)}>
                {messages.other}
                <b aria-hidden="true">→</b>
              </button>
            </div>
            <button className="first-visit__back" type="button" onClick={reset}>
              ← {messages.back}
            </button>
          </>
        ) : goal !== null && situation !== null ? (
          <div className="first-visit__result">
            <div className="first-visit__result-label">{messages.resultEyebrow}</div>
            <div className="first-visit__summary">
              <p>
                <small>{messages.yourGoal}</small>
                {goal.label}
              </p>
              <span aria-hidden="true">↓</span>
              <p>
                <small>{messages.whatHappened}</small>
                {situation}
              </p>
            </div>
            <div className="first-visit__path">
              <small>{messages.startWith}</small>
              <h2>{goal.path}</h2>
              <p>{goal.available ? messages.honestAvailable : messages.honestComing}</p>
            </div>
            <TextLink
              className="narrative-cta first-visit__primary-action"
              href={sourceVerificationLessonPath(locale)}
            >
              {goal.available ? messages.tryMission : messages.tryNearby}
              <ArrowIcon />
            </TextLink>
            <button className="first-visit__back" type="button" onClick={reset}>
              {messages.reset}
            </button>
          </div>
        ) : null}
      </div>
      <p className="first-visit__privacy">{messages.privacy}</p>
    </section>
  );
}
