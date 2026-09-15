"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
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

  function handleSubmit(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault();
    const result = submitSourceVerificationPractice(state, view);
    if (!result.ok) {
      setValidationError(view.feedback.incompleteError);
      return;
    }

    setValidationError(null);
    setState(result.state);
  }

  function handleRetry(): void {
    setValidationError(null);
    setState((current) => retrySourceVerificationPractice(current));
    queueMicrotask(() => practiceHeadingRef.current?.focus());
  }

  function handleReset(): void {
    setValidationError(null);
    setState(resetSourceVerificationPractice());
    queueMicrotask(() => practiceHeadingRef.current?.focus());
  }

  return (
    <article className="lesson-prototype" aria-labelledby="lesson-prototype-heading">
      <p className="visually-hidden" aria-live="polite" aria-atomic="true">
        {feedbackAnnouncement}
      </p>

      <header className="lesson-hero">
        <p className="section-heading__eyebrow">
          {th ? "ภารกิจ 01 · คิดก่อนเชื่อ" : "MISSION 01 · THINK CRITICALLY"}
        </p>
        <h1 id="lesson-prototype-heading">
          {th ? "AI บอกแบบนี้ เชื่อได้ไหม?" : "The AI said it. Is it true?"}
        </h1>
        <p className="lesson-hero__lead">
          {th
            ? "อ่านสรุป เช็กหลักฐาน แล้วลองตัดสินใจ 3 ข้อ"
            : "Read the summary. Check the evidence. Make 3 decisions."}
        </p>
        <p className="lesson-prototype__badge">
          {view.lesson.locale === "th"
            ? "เดโม · ยังไม่ผ่านการตรวจสอบผลการเรียนรู้"
            : "Demo · learning outcomes not externally validated"}
        </p>
        <p className="lesson-prototype__boundary">
          {th
            ? "ข้อมูลสมมติทั้งหมด ไม่ใช้คำตอบจากแบบประเมิน และไม่ใช่คำแนะนำเฉพาะคุณ"
            : "Fictional data. No assessment answers used. Not personal advice."}
        </p>
        <nav
          className="lesson-quick-nav"
          aria-label={view.lesson.locale === "th" ? "ส่วนต่าง ๆ ของบทเรียน" : "In this lesson"}
        >
          <a href="#lesson-scenario-heading">
            {view.lesson.locale === "th" ? "01 อ่านสถานการณ์" : "01 Read the scenario"}
          </a>
          <a href="#lesson-concepts-heading">
            {view.lesson.locale === "th" ? "02 เรียนรู้แนวคิด" : "02 Learn the approach"}
          </a>
          <a href="#lesson-practice-heading">
            {view.lesson.locale === "th" ? "03 ลงมือฝึก" : "03 Put it into practice"}
          </a>
        </nav>
      </header>

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

      <section className="lesson-panel lesson-scenario" aria-labelledby="lesson-scenario-heading">
        <header className="lesson-section-heading">
          <h2 id="lesson-scenario-heading">
            {th ? "สรุปนี้เกินหลักฐานไปไหม?" : "Does the evidence back this up?"}
          </h2>
          <p>
            {th
              ? "ก่อนส่งสรุปนี้ให้หัวหน้า ลองดูว่าตรงไหนใช้ได้ ตรงไหนต้องเช็กเพิ่ม"
              : "Before sending this summary, decide what holds up and what needs checking."}
          </p>
          <p className="lesson-synthetic-label">
            {th ? "สถานการณ์และตัวเลขสมมติ" : "Fictional scenario and figures"}
          </p>
        </header>
        <dl className="lesson-scenario__context">
          <div>
            <dt>{view.scenario.organizationLabel}</dt>
            <dd>{th ? "ทีมปฏิบัติการไบรต์ริเวอร์" : view.scenario.organization}</dd>
          </div>
          <div>
            <dt>{view.scenario.documentLabel}</dt>
            <dd>{view.scenario.document}</dd>
          </div>
        </dl>
        <blockquote className="lesson-ai-summary">
          <p className="lesson-ai-summary__label">{view.scenario.aiSummaryLabel}</p>
          <p>{view.scenario.aiSummary}</p>
        </blockquote>
        <section aria-labelledby="lesson-source-pack-heading">
          <h3 id="lesson-source-pack-heading">{view.scenario.sourceHeading}</h3>
          <div className="lesson-source-grid">
            {view.scenario.sourceRecords.map((record) => (
              <article key={record.id}>
                <h4>{record.label}</h4>
                <p>{record.detail}</p>
              </article>
            ))}
          </div>
        </section>
      </section>

      <section className="lesson-panel" aria-labelledby="lesson-concepts-heading">
        <header className="lesson-section-heading">
          <h2 id="lesson-concepts-heading">{th ? "ถามตัวเอง 3 ข้อ" : "Ask 3 questions"}</h2>
        </header>
        <ol className="lesson-concept-list">
          {view.concepts.items.map((item) => (
            <li key={item.id}>
              <h3>{item.heading}</h3>
              <p>{item.body}</p>
            </li>
          ))}
        </ol>
      </section>

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

      <section className="lesson-panel lesson-practice" aria-labelledby="lesson-practice-heading">
        <header className="lesson-section-heading">
          <p className="section-heading__eyebrow">{th ? "ตาคุณลองแล้ว" : "YOUR TURN"}</p>
          <h2 id="lesson-practice-heading" ref={practiceHeadingRef} tabIndex={-1}>
            {th ? "คุณจะเลือกทำยังไง?" : "What would you do?"}
          </h2>
          <p>
            {th
              ? "เทียบคำตอบกับเกณฑ์ที่กำหนด ไม่มี AI หรือผู้ประเมินมาตัดสิน"
              : "Feedback follows fixed criteria, with no AI or external assessor."}
          </p>
          <p className="lesson-practice__instruction" id="lesson-practice-instruction">
            {th ? "เลือกให้ครบ 3 ข้อ แล้วดูผล" : "Choose an answer for each of the 3 questions."}
          </p>
        </header>

        <form className="lesson-practice__form" noValidate onSubmit={handleSubmit}>
          {view.practice.criteria.map((criterion) => {
            const selection = state.selections.find(
              (candidate) => candidate.criterionId === criterion.id,
            );
            return (
              <fieldset
                aria-describedby={`lesson-practice-instruction${validationError ? " lesson-practice-error" : ""}`}
                aria-invalid={validationError && !selection ? "true" : undefined}
                key={criterion.id}
              >
                <legend>
                  <span>{criterion.label}</span>
                  {criterion.prompt}
                </legend>
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
                            selectSourceVerificationOption(current, view, criterion.id, option.id),
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

          <div className="lesson-practice__actions">
            <button className="player-button player-button--primary" type="submit">
              {th ? "ดูผลการฝึก" : "See how you did"}
            </button>
            {state.evaluation ? (
              <button
                className="player-button player-button--secondary"
                type="button"
                onClick={handleRetry}
              >
                {th ? "ลองอีกครั้ง" : "Try again"}
              </button>
            ) : null}
            <button
              className="player-button player-button--quiet"
              type="button"
              onClick={handleReset}
            >
              {th ? "ล้างคำตอบ" : "Clear answers"}
            </button>
          </div>
        </form>

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
      </section>

      <details className="lesson-panel lesson-proof experience-disclosure">
        <summary>
          <h2 id="lesson-proof-heading">{th ? "เก็บผลงานได้ไหม?" : "Can I save my work?"}</h2>
          <span className="disclosure-plus" aria-hidden="true">
            +
          </span>
        </summary>
        <p className="section-heading__eyebrow">{th ? "ยังอยู่ระหว่างพัฒนา" : "IN DEVELOPMENT"}</p>

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

      <nav className="lesson-actions" aria-label={view.hero.heading}>
        <TextLink href={exampleResultHref}>
          {th ? "กลับไปดูตัวอย่าง" : "Back to the example"}
        </TextLink>
        <TextLink href={homeHref}>{view.actions.homeLabel}</TextLink>
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
