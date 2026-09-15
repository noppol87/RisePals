"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { ArrowIcon, SkillIcon } from "@/components/brand-mark";
import { TextLink } from "@/components/primitives/text-link";
import type { SourceVerificationLessonView } from "@/modules/lesson/source-verification/types";
import {
  evaluateMission,
  sourceVerificationMission,
  type MissionCase,
} from "@/modules/lesson/source-verification/mission-v2";
import type { Locale } from "@/lib/i18n/config";

type Props = Readonly<{
  exampleResultHref: string;
  homeHref: string;
  view: SourceVerificationLessonView;
}>;

export function SourceVerificationLesson({ exampleResultHref, homeHref, view }: Props) {
  const locale = view.lesson.locale;
  const th = locale === "th";
  const [caseIndex, setCaseIndex] = useState(0);
  const [step, setStep] = useState(-1);
  const [selections, setSelections] = useState<Record<string, string>>({});
  const [checked, setChecked] = useState(false);
  const [error, setError] = useState(false);
  const headingRef = useRef<HTMLHeadingElement>(null);
  const errorRef = useRef<HTMLParagraphElement>(null);
  const initial = useRef(true);
  const mission: MissionCase = sourceVerificationMission.cases[caseIndex]!;
  const independent = mission.mode === "independent";
  const question = mission.questions[step];
  const selected = question?.options.find((o) => o.id === selections[question.id]);
  const result = evaluateMission(mission, selections);
  const finished = step === mission.questions.length && result.complete;
  const summaryChoice = mission.questions[2]!.options.find((o) => o.id === selections.rewrite);
  const actionChoice = mission.questions[3]!.options.find((o) => o.id === selections.action);
  const copy = (thai: string, english: string) => (th ? thai : english);
  const stepLabels = th
    ? ["หาจุดเกินข้อมูล", "เลือกหลักฐาน", "เขียนให้ตรง", "เลือกก้าวต่อ"]
    : ["Find the overclaim", "Choose evidence", "Write accurately", "Choose next step"];

  useEffect(() => {
    if (initial.current) {
      initial.current = false;
      return;
    }
    headingRef.current?.focus();
    headingRef.current?.scrollIntoView?.({ block: "start" });
  }, [step, caseIndex]);
  useEffect(() => {
    if (error) errorRef.current?.focus();
  }, [error]);

  function advance(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selected) {
      setError(true);
      return;
    }
    if (!independent && (!checked || !selected.correct)) {
      setChecked(true);
      return;
    }
    setChecked(false);
    setError(false);
    setStep(step + 1);
  }
  function restart(index: number) {
    setCaseIndex(index);
    setSelections({});
    setChecked(false);
    setError(false);
    setStep(-1);
  }

  return (
    <article className="mission-workspace" aria-labelledby="mission-title">
      <header className="mission-topline">
        <TextLink href={homeHref}>{copy("← กลับหน้าหลัก", "← Home")}</TextLink>
        <span>
          {copy("คิดก่อนเชื่อ", "Think critically")} <span aria-hidden="true">/</span> 0
          {caseIndex + 1}
        </span>
      </header>
      <h1 id="mission-title">
        {copy("เช็กสรุปก่อนใช้ตัดสินใจ", "Check a summary before it informs a decision")}
      </h1>
      <p className="mission-boundary">
        {copy(
          "ข้อมูลสมมติ · ไม่บันทึกผล · ไม่ใช่การรับรองทักษะ",
          "Fictional data · not saved · no skill certification",
        )}
      </p>
      {step >= 0 && !finished ? (
        <ol className="mission-steps" aria-label={copy("ขั้นตอน", "Steps")}>
          {stepLabels.map((label, index) => (
            <li
              key={label}
              aria-current={step === index ? "step" : undefined}
              data-done={index < step}
            >
              <span aria-hidden="true">{index < step ? "✓" : index + 1}</span>
              <span>{label}</span>
            </li>
          ))}
        </ol>
      ) : null}

      {step === -1 ? (
        <section className="mission-intro">
          <div className="mission-intro__copy">
            <p className="mission-eyebrow">
              {independent
                ? copy("รอบนี้ลองเอง", "NOW TRY IT YOURSELF")
                : copy("ภารกิจแรก · มีคำใบ้ให้", "FIRST MISSION · WITH GUIDANCE")}
            </p>
            <h2 ref={headingRef} tabIndex={-1}>
              {mission.title[locale]}
            </h2>
            <p>{mission.context[locale]}</p>
            <button
              type="button"
              className="player-button player-button--primary"
              onClick={() => setStep(0)}
            >
              {copy("เริ่มช่วยทีมเช็กสรุป", "Start checking the summary")}
              <ArrowIcon />
            </button>
            <p className="mission-small">
              {independent
                ? copy("ดูเฉลยหลังตอบครบทั้ง 4 ขั้น", "Feedback comes after all 4 decisions.")
                : copy(
                    "หาจุดที่เกินข้อมูล → เลือกหลักฐาน → แก้สรุป → เลือกก้าวต่อ",
                    "Find the overclaim → choose evidence → fix the summary → decide what comes next",
                  )}
            </p>
          </div>
          <div className="mission-ai-note">
            <div className="mission-note-label">
              <SkillIcon index={7} />
              <span>{copy("ฉบับร่างจาก AI", "AI DRAFT")}</span>
              <span aria-hidden="true">✦</span>
            </div>
            <blockquote>{mission.before[locale]}</blockquote>
            <span className="mission-unverified">{copy("ยังไม่ได้ตรวจ", "Not yet checked")}</span>
            <div className="mission-note-lines" aria-hidden="true">
              <span />
              <span />
              <span />
            </div>
          </div>
        </section>
      ) : null}

      {question && !finished ? (
        <section className="mission-task" key={`${mission.id}-${step}`}>
          <div className="mission-task__purpose">
            <span>{copy("เป้าหมายของภารกิจ", "MISSION GOAL")}</span>
            <p>
              {caseIndex === 0
                ? copy(
                    "ช่วยให้หัวหน้าตัดสินใจจากข้อมูลที่ตรวจสอบได้ โดยไม่เหมารวมผลของทีมหนึ่งไปทุกทีม",
                    "Help the manager decide from checked evidence without generalizing one team’s result to every team.",
                  )
                : copy(
                    "ช่วยทีมเลือกเวลาอบรมโดยไม่ใช้คำตอบจากคนส่วนน้อยแทนพนักงานทุกคน",
                    "Help the team choose a training time without treating a minority of responses as everyone’s preference.",
                  )}
            </p>
          </div>
          <div className="mission-task__grid">
            <aside
              className="mission-evidence"
              aria-label={copy("หลักฐานที่ใช้เช็ก", "Evidence to check")}
            >
              <EvidenceStrip mission={mission} locale={locale} />
              {step < 2 ? (
                <div className="mission-quote-small">
                  <span>{copy("คำตอบ AI ที่กำลังตรวจ", "AI ANSWER BEING CHECKED")}</span>
                  <p>{mission.before[locale]}</p>
                </div>
              ) : (
                <div
                  className="mission-live-note"
                  aria-label={copy("สรุปที่กำลังแก้", "Your draft summary")}
                >
                  <span>{copy("สรุปของคุณ", "YOUR SUMMARY")}</span>
                  <p>{mission.summaryPrefix[locale]}</p>
                  <p className={summaryChoice ? "mission-inserted" : "mission-blank"}>
                    {summaryChoice?.label[locale] ??
                      copy("เติมส่วนที่ยังขาด →", "Complete the missing part →")}
                  </p>
                </div>
              )}
              <details className="mission-source-details">
                <summary>{copy("ดูที่มาของข้อมูล", "Source details")}</summary>
                {caseIndex === 0 ? (
                  view.scenario.sourceRecords.map((record) => (
                    <div key={record.id}>
                      <strong>{record.label}</strong>
                      <p>{record.detail}</p>
                    </div>
                  ))
                ) : (
                  <p>
                    {copy(
                      "แบบสำรวจสมมติ: ถามพนักงาน 100 คน ตอบ 20 คน เลือกช่วงเย็น 12 คน เวลาอื่น 8 คน ไม่ตอบ 80 คน ไม่มีข้อมูลความต้องการของผู้ไม่ตอบ",
                      "Fictional survey: 100 staff invited, 20 responses. 12 chose evenings, 8 other times, 80 did not reply. No preference data is available for non-respondents.",
                    )}
                  </p>
                )}
              </details>
            </aside>
            <form noValidate onSubmit={advance} className="mission-decisions">
              <header className="mission-task__header">
                <p className="mission-eyebrow">
                  {independent
                    ? copy("รอบลองเอง", "YOUR TURN")
                    : copy("รอบฝึกไปด้วยกัน", "GUIDED ROUND")}{" "}
                  · {stepLabels[step]}
                </p>
                <h2 id="mission-question" ref={headingRef} tabIndex={-1}>
                  {question.prompt[locale]}
                </h2>
                <p className="mission-question-help">
                  {step === 0
                    ? copy(
                        "เทียบคำตอบ AI กับหลักฐานด้านซ้าย แล้วเลือก 1 ข้อที่ข้อมูลยังยืนยันไม่ได้",
                        "Compare the AI answer with the evidence, then choose one statement the data cannot confirm.",
                      )
                    : step === 1
                      ? copy(
                          "เลือกแหล่งที่ตอบคำถามนี้ได้โดยตรงและเห็นข้อมูลที่ขาดด้วย",
                          "Choose the source that answers this question directly and shows what is missing.",
                        )
                      : step === 2
                        ? copy(
                            "เลือกข้อความที่บอกเท่าที่รู้ และไม่เปลี่ยนข้อมูลที่ขาดให้เป็นผลลัพธ์",
                            "Choose wording that states only what is known and does not turn missing data into a result.",
                          )
                        : copy(
                            "เลือกสิ่งที่ช่วยปิดช่องว่างของข้อมูลก่อนนำสรุปไปใช้จริง",
                            "Choose the action that closes the evidence gap before the summary is used.",
                          )}
                </p>
              </header>
              <fieldset
                aria-labelledby="mission-question"
                aria-describedby={error ? "mission-error" : undefined}
                aria-invalid={error || undefined}
              >
                <legend className="mission-choice-label">
                  {copy("เลือกคำตอบ 1 ข้อ", "Choose one answer")}
                </legend>
                <div className={`mission-options mission-options--${question.id}`}>
                  {question.options.map((option, index) => (
                    <label
                      className="mission-option"
                      key={option.id}
                      data-selected={selected?.id === option.id}
                    >
                      <input
                        type="radio"
                        name={question.id}
                        value={option.id}
                        checked={selected?.id === option.id}
                        onChange={() => {
                          setSelections({ ...selections, [question.id]: option.id });
                          setChecked(false);
                          setError(false);
                        }}
                      />
                      <span className="mission-option__index" aria-hidden="true">
                        {question.id === "evidence" ? "▤" : String(index + 1).padStart(2, "0")}
                      </span>
                      <span>{option.label[locale]}</span>
                    </label>
                  ))}
                </div>
              </fieldset>
              {error ? (
                <p id="mission-error" role="alert" ref={errorRef} tabIndex={-1}>
                  {copy("เลือกสักข้อก่อนนะ", "Choose an answer first.")}
                </p>
              ) : null}
              {checked && selected && !independent ? (
                <div className="mission-hint" data-correct={selected.correct} role="status">
                  <strong>
                    {selected.correct
                      ? copy("ถูกต้อง เพราะอะไร", "Correct — here’s why")
                      : copy("ยังไม่ใช่ข้อนี้ เพราะอะไร", "Not this one — here’s why")}
                  </strong>
                  <p>{selected.reason[locale]}</p>
                </div>
              ) : null}
              <div className="mission-actions">
                <button
                  className="player-button player-button--secondary"
                  type="button"
                  onClick={() => {
                    setStep(step - 1);
                    setChecked(false);
                    setError(false);
                  }}
                >
                  {copy("ย้อนกลับ", "Back")}
                </button>
                <button className="player-button player-button--primary" type="submit">
                  {!independent && !(checked && selected?.correct)
                    ? copy("ตรวจคำตอบนี้", "Check this answer")
                    : step === 3
                      ? copy("ดูสรุปของฉัน", "See my summary")
                      : copy("ไปต่อ", "Continue")}
                  <ArrowIcon />
                </button>
              </div>
            </form>
          </div>
        </section>
      ) : null}

      {finished ? (
        <section className="mission-result">
          <div className="mission-result__heading">
            <span className="mission-result__symbol" aria-hidden="true">
              {result.allCorrect ? "✓" : "↺"}
            </span>
            <p className="mission-eyebrow">
              {copy("จากคำตอบในโจทย์นี้", "FROM YOUR CHOICES IN THIS CASE")}
            </p>
            <h2 ref={headingRef} tabIndex={-1}>
              {result.allCorrect
                ? copy(
                    "สรุปนี้พร้อมใช้ตัดสินใจมากขึ้น",
                    "This summary is safer to use in a decision",
                  )
                : copy("มีจุดที่น่าลองเช็กอีกที", "A few things need another look")}
            </h2>
            <p>
              {independent
                ? result.allCorrect
                  ? copy(
                      "รอบนี้คุณเลือกหลักฐานและสรุปได้ตรง โดยไม่มีคำใบ้ระหว่างตอบ",
                      "You matched the evidence and summary without hints during this round.",
                    )
                  : copy(
                      "ลองเทียบคำตอบกับหลักฐานด้านล่าง",
                      "Compare your choices with the evidence below.",
                    )
                : copy(
                    "คุณหาจุดที่เกินข้อมูล เลือกหลักฐาน แก้สรุป และเลือกก้าวต่อแล้ว",
                    "You found the overclaim, chose evidence, fixed the summary, and decided what comes next.",
                  )}
            </p>
          </div>
          <div className="mission-before-after">
            <div className="mission-before">
              <span>{copy("ก่อนเช็ก · ฉบับ AI", "BEFORE · AI DRAFT")}</span>
              <p>{mission.before[locale]}</p>
            </div>
            <div className="mission-after" data-correct={result.allCorrect}>
              <span>{copy("หลังเช็ก · สรุปของคุณ", "AFTER · YOUR SUMMARY")}</span>
              <p>
                {mission.summaryPrefix[locale]} {summaryChoice?.label[locale]}
              </p>
              <hr />
              <span>{copy("ก่อนนำไปใช้", "BEFORE USING IT")}</span>
              <p>{actionChoice?.label[locale]}</p>
            </div>
          </div>
          {!result.allCorrect ? (
            <div className="mission-review">
              <h3>{copy("จุดที่ควรทบทวน", "What to revisit")}</h3>
              {result.results
                .filter((r) => !r.correct)
                .map((r) => (
                  <div key={r.id}>
                    <strong>{stepLabels[mission.questions.findIndex((q) => q.id === r.id)]}</strong>
                    <p>{r.selected?.reason[locale]}</p>
                  </div>
                ))}
              <details>
                <summary>
                  {copy("ดูตัวอย่างสรุปที่ตรงกับข้อมูล", "See a supported summary")}
                </summary>
                <p>
                  {mission.summaryPrefix[locale]}{" "}
                  {mission.questions[2]!.options.find((o) => o.correct)!.label[locale]}
                </p>
                <p>{mission.questions[3]!.options.find((o) => o.correct)!.label[locale]}</p>
              </details>
            </div>
          ) : (
            <p className="mission-takeaway">
              {copy(
                "จำไว้ใช้กับงาน: เช็กที่มา · สรุปเท่าที่รู้ · บอกสิ่งที่ยังขาด",
                "Take this to work: check the source · stay within the evidence · name the gaps",
              )}
            </p>
          )}
          <div className="mission-actions mission-result__actions">
            {caseIndex === 0 ? (
              <button
                type="button"
                className="player-button player-button--primary"
                onClick={() => restart(1)}
              >
                {copy("ลองใช้กับอีกสถานการณ์", "Use this in another situation")}
                <ArrowIcon />
              </button>
            ) : (
              <TextLink
                className="player-button player-button--primary"
                href={`${homeHref}#skill-framework`}
              >
                {copy("กลับไปดูทักษะอื่น", "Explore other skills")}
                <ArrowIcon />
              </TextLink>
            )}
            <button
              className="player-button player-button--secondary"
              type="button"
              onClick={() => restart(caseIndex)}
            >
              {copy("ลองโจทย์นี้ใหม่", "Try this case again")}
            </button>
          </div>
        </section>
      ) : null}
      <details className="mission-about">
        <summary>{copy("เกี่ยวกับแบบฝึกนี้", "About this practice")}</summary>
        <p>
          {copy(
            "รอบแรกมีคำแนะนำ รอบถัดไปใช้สถานการณ์ใหม่และเฉลยหลังตอบครบ ตรวจตามคำตอบที่กำหนดไว้ ไม่ใช้ AI ให้คะแนน ไม่บันทึกคำตอบ และยังไม่ได้ทดสอบผลการเรียนรู้กับผู้ใช้จริง",
            "The first round is coached; the second uses a new case with feedback at the end. Checks use authored answers, not AI scoring. Responses are not saved and learning outcomes have not been validated with users.",
          )}
        </p>
        <p>
          {copy("แบบฝึกเวอร์ชัน", "Practice version")} {sourceVerificationMission.version} ·{" "}
          {copy("ต้นแบบในเครื่อง", "local prototype")}
        </p>
        <p>
          {copy(
            "ข้อมูลกรณีแรกมาจากบทเรียนสมมติ",
            "First-case data comes from the fictional lesson",
          )}{" "}
          {sourceVerificationMission.sourceIdentity}
        </p>
        <TextLink href={exampleResultHref}>
          {copy("ดูตัวอย่างผลประเมิน", "View the example assessment result")}
        </TextLink>
      </details>
      <noscript>
        {copy(
          "เปิด JavaScript เพื่อทำแบบฝึกแบบโต้ตอบนี้",
          "Enable JavaScript to use this interactive practice.",
        )}
      </noscript>
    </article>
  );
}

function EvidenceStrip({ mission, locale }: Readonly<{ mission: MissionCase; locale: Locale }>) {
  const max = Math.max(...mission.facts.map((fact) => fact.amount ?? 0));
  return (
    <figure className="mission-facts">
      <figcaption>{locale === "th" ? "หลักฐานที่ใช้เช็ก" : "EVIDENCE TO CHECK"}</figcaption>
      <div className="mission-facts__grid">
        {mission.facts.map((fact) => (
          <div key={fact.id} data-missing={fact.amount === null}>
            <span>{fact.label[locale]}</span>
            <strong>{fact.value}</strong>
            <svg viewBox="0 0 100 8" aria-hidden="true">
              <rect width="100" height="8" rx="4" fill="currentColor" opacity=".12" />
              {fact.amount !== null ? (
                <rect
                  className="mission-fact-bar"
                  width={max ? (fact.amount / max) * 100 : 0}
                  height="8"
                  rx="4"
                  fill="currentColor"
                />
              ) : (
                <path d="M0 4H100" stroke="currentColor" strokeDasharray="4 4" />
              )}
            </svg>
            <small>{fact.detail[locale]}</small>
          </div>
        ))}
      </div>
      <p>{mission.scope[locale]}</p>
    </figure>
  );
}
