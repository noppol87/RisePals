"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { LessonEvidenceVisual, sourceCaseVisual } from "@/components/lesson-evidence-visual";
import { SkillIcon, ArrowIcon } from "@/components/brand-mark";
import { TextLink } from "@/components/primitives/text-link";
import type { SourceVerificationLessonView } from "@/modules/lesson/source-verification/types";
import {
  createInitialSourceVerificationPracticeState,
  getSourceVerificationPracticeOutcome,
  resetSourceVerificationPractice,
  retrySourceVerificationPractice,
  selectSourceVerificationOption,
  submitSourceVerificationPractice,
} from "@/modules/lesson/source-verification/state";

type SourceVerificationLessonProps = Readonly<{
  exampleResultHref: string;
  homeHref: string;
  view: SourceVerificationLessonView;
}>;

export function SourceVerificationLesson({
  exampleResultHref,
  homeHref,
  view,
}: SourceVerificationLessonProps) {
  const th = view.lesson.locale === "th";
  const [state, setState] = useState(createInitialSourceVerificationPracticeState);
  const [stage, setStage] = useState(0);
  const [questionIndex, setQuestionIndex] = useState(0);
  const scenarioHeadingRef = useRef<HTMLHeadingElement>(null);
  const sourcesHeadingRef = useRef<HTMLHeadingElement>(null);
  const lastPositionRef = useRef("0:0");
  const [validationError, setValidationError] = useState<string | null>(null);
  const practiceHeadingRef = useRef<HTMLHeadingElement>(null);
  const feedbackHeadingRef = useRef<HTMLHeadingElement>(null);
  const errorRef = useRef<HTMLParagraphElement>(null);
  const outcome = getSourceVerificationPracticeOutcome(state);
  const feedbackAnnouncement = state.evaluation
    ? state.evaluation.demonstrated
      ? view.feedback.demonstratedAnnouncement
      : view.feedback.partialAnnouncement
    : "";

  useEffect(() => {
    if (validationError !== null) {
      errorRef.current?.focus();
    }
  }, [validationError]);

  useEffect(() => {
    if (state.phase === "feedback") {
      feedbackHeadingRef.current?.focus();
    }
  }, [state.phase]);

  useEffect(() => {
    const position = `${stage}:${questionIndex}`;
    if (lastPositionRef.current === position) return;
    lastPositionRef.current = position;
    const heading =
      stage === 0
        ? scenarioHeadingRef.current
        : stage === 1
          ? sourcesHeadingRef.current
          : practiceHeadingRef.current;
    heading?.focus();
    heading?.scrollIntoView?.({ block: "start" });
  }, [stage, questionIndex]);

  function goToStage(next: number) {
    setValidationError(null);
    setStage(next);
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault();
    const criterion = view.practice.criteria[questionIndex];
    if (!criterion) {
      setValidationError(view.feedback.incompleteError);
      return;
    }
    if (!state.selections.some((selection) => selection.criterionId === criterion.id)) {
      setValidationError(th ? "เลือกสักข้อก่อนนะ" : "Choose an answer first.");
      return;
    }
    if (questionIndex < view.practice.criteria.length - 1) {
      setValidationError(null);
      setQuestionIndex(questionIndex + 1);
      return;
    }
    const result = submitSourceVerificationPractice(state, view);
    if (!result.ok) {
      setValidationError(view.feedback.incompleteError);
      return;
    }

    setValidationError(null);
    setState(result.state);
  }

  function handleRetry(): void {
    setQuestionIndex(0);
    setValidationError(null);
    setState((current) => retrySourceVerificationPractice(current));
    queueMicrotask(() => practiceHeadingRef.current?.focus());
  }

  function handleReset(): void {
    setQuestionIndex(0);
    setValidationError(null);
    setState(resetSourceVerificationPractice());
    queueMicrotask(() => practiceHeadingRef.current?.focus());
  }

  return (
    <article className="lesson-prototype lesson-guided" aria-labelledby="lesson-prototype-heading">
      <p className="visually-hidden" aria-live="polite" aria-atomic="true">
        {feedbackAnnouncement}
      </p>
      <header className="guided-header">
        <p className="section-heading__eyebrow">
          {th ? "ภารกิจ 01 · คิดก่อนเชื่อ" : "MISSION 01 · THINK CRITICALLY"}
        </p>
        <h1 id="lesson-prototype-heading">
          {th ? "AI บอกแบบนี้ เชื่อได้ไหม?" : "The AI said it. Is it true?"}
        </h1>
        <p>
          {th
            ? "ดูภาพ เช็กข้อมูล แล้วลองตอบทีละข้อ"
            : "See the story. Check the evidence. Try one question at a time."}
        </p>
        <p className="guided-demo-note">
          {th
            ? "ข้อมูลสมมติ · ผลฝึกไม่บันทึก · ยังไม่ใช่การรับรองทักษะ"
            : "Fictional data · progress isn’t saved · no validated skill result"}
        </p>
      </header>
      <nav className="guided-steps" aria-label={th ? "ขั้นตอนบทเรียน" : "Lesson steps"}>
        {(th
          ? ["ดูเรื่องนี้", "เช็กหลักฐาน", "ลองตอบ"]
          : ["See the story", "Check evidence", "Try it"]
        ).map((label, index) => (
          <button
            key={index}
            type="button"
            aria-current={stage === index ? "step" : undefined}
            onClick={() => goToStage(index)}
          >
            <span aria-hidden="true">{index + 1}</span>
            {label}
          </button>
        ))}
      </nav>
      <section
        className="guided-panel guided-story"
        hidden={stage !== 0}
        aria-labelledby="lesson-scenario-heading"
      >
        <div className="guided-story__copy">
          <p className="section-heading__eyebrow">{th ? "เริ่มตรงนี้" : "START HERE"}</p>
          <h2 id="lesson-scenario-heading" ref={scenarioHeadingRef} tabIndex={-1}>
            {th ? "ก่อนส่งสรุปให้หัวหน้า…" : "Before you send this summary…"}
          </h2>
          <p>
            {th
              ? "AI สรุปผลให้แล้ว แต่ข้อมูลตรงกันจริงไหม?"
              : "AI wrote the summary. Does the evidence agree?"}
          </p>
          <button
            className="player-button player-button--primary"
            type="button"
            onClick={() => goToStage(1)}
          >
            {th ? "เริ่มเช็กสรุปนี้" : "Check this summary"}
            <ArrowIcon />
          </button>
        </div>
        <div className="claim-illustration">
          <div className="claim-illustration__top">
            <SkillIcon index={7} />
            <span>{th ? "สรุปจาก AI" : "AI SUMMARY"}</span>
            <span aria-hidden="true">✦</span>
          </div>
          <blockquote>
            <p>{view.scenario.aiSummary}</p>
          </blockquote>
          <div
            className="claim-illustration__teams"
            aria-hidden="true"
            hidden={
              view.lesson.versionId !== sourceCaseVisual.lessonVersionId ||
              view.lesson.version !== sourceCaseVisual.version
            }
          >
            {["A", "B", "C"].map((team) => (
              <div key={team}>
                <span>
                  {th ? "ทีม" : "TEAM"} {team}
                </span>
                <svg viewBox="0 0 60 60">
                  <path
                    d="M12 44V28M30 44V20M48 44V10"
                    stroke="currentColor"
                    strokeWidth="8"
                    strokeLinecap="round"
                  />
                </svg>
                <strong>30%</strong>
              </div>
            ))}
          </div>
          <p className="claim-illustration__caption">
            {th ? "คำกล่าวอ้างของ AI · ยังไม่ได้ตรวจ" : "The AI’s claim · not yet checked"}
          </p>
        </div>
      </section>
      <section
        className="guided-panel guided-sources"
        hidden={stage !== 1}
        aria-labelledby="lesson-source-pack-heading"
      >
        <header>
          <p className="section-heading__eyebrow">
            {th ? "เปิดหลักฐานดู" : "LOOK AT THE EVIDENCE"}
          </p>
          <h2 id="lesson-source-pack-heading" ref={sourcesHeadingRef} tabIndex={-1}>
            {th ? "ทั้ง 3 ทีม ได้ผลเท่ากันจริงไหม?" : "Did all 3 teams get the same result?"}
          </h2>
        </header>
        <LessonEvidenceVisual view={view} />
        <details className="lesson-source-original">
          <summary>{th ? "มีวิธีเช็กยังไง?" : "How should I check?"}</summary>
          <ol className="lesson-concept-list">
            {view.concepts.items.map((item) => (
              <li key={item.id}>
                <h3>{item.heading}</h3>
                <p>{item.body}</p>
              </li>
            ))}
          </ol>
        </details>
        <div className="guided-actions">
          <button
            type="button"
            className="player-button player-button--secondary"
            onClick={() => goToStage(0)}
          >
            {th ? "กลับไปดูสรุป" : "Back to the summary"}
          </button>
          <button
            type="button"
            className="player-button player-button--primary"
            onClick={() => goToStage(2)}
          >
            {th ? "ลองตอบจากที่เห็น" : "Try a question"}
            <ArrowIcon />
          </button>
        </div>
      </section>
      <section
        className="guided-panel lesson-practice"
        hidden={stage !== 2}
        aria-labelledby="lesson-practice-heading"
      >
        <h2 id="lesson-practice-heading" ref={practiceHeadingRef} tabIndex={-1}>
          {th ? "คุณจะเลือกทำยังไง?" : "What would you do?"}
        </h2>
        {!state.evaluation ? (
          <>
            <div className="guided-question-progress">
              <p>{th ? `ข้อ ${questionIndex + 1} จาก 3` : `Question ${questionIndex + 1} of 3`}</p>
              <div aria-hidden="true">
                {view.practice.criteria.map((item, index) => (
                  <span
                    key={item.id}
                    data-current={index === questionIndex}
                    data-complete={state.selections.some((s) => s.criterionId === item.id)}
                  />
                ))}
              </div>
            </div>
            <details className="lesson-source-original guided-recall">
              <summary>{th ? "ดูหลักฐานอีกครั้ง" : "Peek at the evidence"}</summary>
              <LessonEvidenceVisual view={view} />
            </details>
            <form className="lesson-practice__form" noValidate onSubmit={handleSubmit}>
              <p id="lesson-practice-instruction">
                {th ? "เลือกข้อที่คุณจะทำ" : "Choose what you would do."}
              </p>
              {view.practice.criteria.map((criterion, index) => {
                const selection = state.selections.find((s) => s.criterionId === criterion.id);
                return (
                  <fieldset
                    key={criterion.id}
                    hidden={index !== questionIndex}
                    aria-describedby={`lesson-practice-instruction${validationError ? " lesson-practice-error" : ""}`}
                    aria-invalid={validationError && !selection ? "true" : undefined}
                  >
                    <legend>{criterion.prompt}</legend>
                    <div className="lesson-practice__options">
                      {criterion.options.map((option) => (
                        <label className="lesson-practice__option" key={option.id}>
                          <input
                            checked={selection?.optionId === option.id}
                            name={`lesson-practice-${criterion.id}`}
                            required
                            type="radio"
                            value={option.id}
                            onChange={() => {
                              setValidationError(null);
                              setState((current) =>
                                selectSourceVerificationOption(
                                  current,
                                  view,
                                  criterion.id,
                                  option.id,
                                ),
                              );
                            }}
                          />
                          <span>{option.label}</span>
                        </label>
                      ))}
                    </div>
                  </fieldset>
                );
              })}
              {validationError ? (
                <p
                  className="lesson-practice__error"
                  id="lesson-practice-error"
                  ref={errorRef}
                  role="alert"
                  tabIndex={-1}
                >
                  {validationError}
                </p>
              ) : null}
              <div className="guided-actions">
                <button
                  className="player-button player-button--secondary"
                  type="button"
                  onClick={() => {
                    setValidationError(null);
                    if (questionIndex > 0) setQuestionIndex(questionIndex - 1);
                    else goToStage(1);
                  }}
                >
                  {th ? "ย้อนกลับ" : "Back"}
                </button>
                <button className="player-button player-button--primary" type="submit">
                  {questionIndex === 2
                    ? th
                      ? "ดูผลการฝึก"
                      : "See how you did"
                    : th
                      ? "ข้อต่อไป"
                      : "Next question"}
                  <ArrowIcon />
                </button>
              </div>
            </form>
          </>
        ) : null}
        {state.evaluation ? (
          <section
            className={
              state.evaluation.demonstrated
                ? "lesson-feedback lesson-feedback--demonstrated"
                : "lesson-feedback"
            }
            aria-labelledby="lesson-feedback-heading"
          >
            <h3 id="lesson-feedback-heading" ref={feedbackHeadingRef} tabIndex={-1}>
              {state.evaluation.demonstrated
                ? view.feedback.demonstratedHeading
                : view.feedback.partialHeading}
            </h3>
            <p>
              {state.evaluation.demonstrated
                ? view.feedback.demonstratedSummary
                : view.feedback.partialSummary}
            </p>
            <ul>
              {state.evaluation.criterionResults.map((result) => {
                const criterion = view.practice.criteria.find(
                  (candidate) => candidate.id === result.criterionId,
                )!;
                const met = result.status === "met";
                return (
                  <li key={result.criterionId}>
                    <h4>{criterion.rubric.label}</h4>
                    <strong>{met ? view.feedback.metLabel : view.feedback.notMetLabel}</strong>
                    <p>
                      {met ? criterion.rubric.metDescription : criterion.rubric.notMetDescription}
                    </p>
                  </li>
                );
              })}
            </ul>
            <p className="lesson-feedback__xp">
              {formatTemplate(view.feedback.previewXpTemplate, { xp: outcome.previewXp })}
            </p>
            <p className="lesson-feedback__boundary">{view.feedback.unsavedXpBoundary}</p>
          </section>
        ) : null}

        {state.evaluation ? (
          <div className="guided-actions">
            <button
              className="player-button player-button--primary"
              type="button"
              onClick={handleRetry}
            >
              {th ? "ลองอีกครั้ง" : "Try again"}
            </button>
            <button
              className="player-button player-button--secondary"
              type="button"
              onClick={handleReset}
            >
              {th ? "ล้างคำตอบ" : "Clear answers"}
            </button>
          </div>
        ) : null}
      </section>
      <details className="guided-extras lesson-source-original">
        <summary>
          {th ? "เกี่ยวกับเดโมและเกณฑ์การฝึก" : "About the demo and feedback criteria"}
        </summary>
        <p>
          {th
            ? "ข้อมูลสมมติทั้งหมด ไม่ใช้คำตอบจากแบบประเมิน และไม่ใช่คำแนะนำเฉพาะคุณ"
            : "Fictional data. No assessment answers used. Not personal advice."}
        </p>
        <details className="lesson-panel experience-disclosure">
          <summary>
            <h2 id="lesson-overview-heading">{th ? "เกี่ยวกับบทเรียนนี้" : "About this lesson"}</h2>
            <span className="disclosure-plus" aria-hidden="true">
              +
            </span>
          </summary>

          <dl className="lesson-overview">
            <div>
              <dt>{view.overview.targetLabel}</dt>
              <dd>
                <strong>{th ? "คิดก่อนเชื่อ" : "Think critically"}</strong>
                <code>{view.lesson.targetCompetencyId}</code>
              </dd>
            </div>
            <div>
              <dt>{view.overview.stageLabel}</dt>
              <dd>{th ? "ลองใช้จริง" : "Practising"}</dd>
            </div>
            <div>
              <dt>{view.overview.roiLabel}</dt>
              <dd>{th ? "รู้ทันความเสี่ยงและรับผิดชอบ" : "Risk and responsibility"}</dd>
            </div>
            <div>
              <dt>{view.overview.timeLabel}</dt>
              <dd>{view.overview.timeValue}</dd>
            </div>
          </dl>
          <p className="lesson-version-line">
            <code>{view.lesson.versionId}</code> · <code>{view.lesson.version}</code> ·{" "}
            <code>{view.lesson.status}</code> · <code>{view.lesson.validationStatus}</code>
          </p>
        </details>

        <details className="lesson-panel lesson-rubric experience-disclosure">
          <summary>
            <h2 id="lesson-rubric-heading">{th ? "ดูเกณฑ์การฝึก" : "How feedback works"}</h2>
            <span className="disclosure-plus" aria-hidden="true">
              +
            </span>
          </summary>
          <header className="lesson-section-heading">
            <p>{view.rubric.introduction}</p>
            <p className="lesson-rubric__rule">{view.rubric.demonstratedRule}</p>
          </header>
          <ul className="lesson-rubric__criteria">
            {view.practice.criteria.map((criterion) => (
              <li key={criterion.id}>
                <h3>{criterion.rubric.label}</h3>
                <p>{criterion.rubric.metDescription}</p>
              </li>
            ))}
          </ul>
        </details>

        <details className="lesson-panel lesson-proof experience-disclosure">
          <summary>
            <h2 id="lesson-proof-heading">{th ? "เก็บผลงานได้ไหม?" : "Can I save my work?"}</h2>
            <span className="disclosure-plus" aria-hidden="true">
              +
            </span>
          </summary>
          <p className="section-heading__eyebrow">
            {th ? "ยังอยู่ระหว่างพัฒนา" : "IN DEVELOPMENT"}
          </p>

          <p>
            {th
              ? "ตอนนี้ดูได้แค่ตัวอย่างบันทึก ยังสร้างหรือบันทึกผลงานไม่ได้"
              : "This is a sample record. Creating and saving proof isn’t available yet."}
          </p>
          <p className="lesson-proof__label">{view.proof.placeholderLabel}</p>
          <h3>{view.proof.fieldsHeading}</h3>
          <ul>
            {view.proof.fields.map((field) => (
              <li key={field.id}>{field.label}</li>
            ))}
          </ul>
          <p className="lesson-proof__boundary">
            {th
              ? "ยังพิมพ์ข้อความ อัปโหลด หรือบันทึกไฟล์ไม่ได้"
              : "No text entry, uploads or saved files."}
          </p>
        </details>

        <aside className="lesson-reflection" aria-labelledby="lesson-reflection-heading">
          <h2 id="lesson-reflection-heading">
            {th ? "ลองนึกถึงงานของคุณ" : "Think about your work"}
          </h2>
          <p>{view.reflection.prompt}</p>
          <p>
            {th
              ? "คิดหรือจดไว้เองได้เลย หน้านี้ไม่เก็บคำตอบ"
              : "Keep your thoughts to yourself. Nothing is collected here."}
          </p>
        </aside>
      </details>
      <noscript>
        <p>
          {th
            ? "เปิด JavaScript เพื่อเช็กหลักฐานและลองตอบทีละขั้น"
            : "Enable JavaScript to check the evidence and try each step."}
        </p>
      </noscript>
      <nav className="lesson-actions" aria-label={view.hero.heading}>
        <TextLink href={homeHref}>{view.actions.homeLabel}</TextLink>
        <TextLink href={exampleResultHref}>
          {th ? "กลับไปดูตัวอย่าง" : "Back to the example"}
        </TextLink>
      </nav>
    </article>
  );
}

function formatTemplate(
  template: string,
  values: Readonly<Record<string, string | number>>,
): string {
  return Object.entries(values).reduce(
    (formatted, [key, value]) => formatted.replaceAll(`{${key}}`, String(value)),
    template,
  );
}
