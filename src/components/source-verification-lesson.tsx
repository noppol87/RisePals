"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { TextLink } from "@/components/primitives/text-link";
import {
  createInitialSourceVerificationPracticeState,
  getSourceVerificationPracticeOutcome,
  resetSourceVerificationPractice,
  retrySourceVerificationPractice,
  selectSourceVerificationOption,
  submitSourceVerificationPractice,
  type SourceVerificationLessonView,
} from "@/modules/lesson/source-verification";

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
        <p className="section-heading__eyebrow">{view.hero.eyebrow}</p>
        <h1 id="lesson-prototype-heading">{view.hero.heading}</h1>
        <p className="lesson-hero__lead">{view.hero.introduction}</p>
        <p className="lesson-prototype__badge">{view.hero.prototypeLabel}</p>
        <p className="lesson-prototype__boundary">{view.hero.boundary}</p>
      </header>

      <section className="lesson-panel" aria-labelledby="lesson-overview-heading">
        <h2 id="lesson-overview-heading">{view.overview.heading}</h2>
        <dl className="lesson-overview">
          <div>
            <dt>{view.overview.targetLabel}</dt>
            <dd>
              <strong>Critical Thinking &amp; Fact-Checking</strong>
              <code>{view.lesson.targetCompetencyId}</code>
            </dd>
          </div>
          <div>
            <dt>{view.overview.stageLabel}</dt>
            <dd>{view.lesson.targetWorkingStage}</dd>
          </div>
          <div>
            <dt>{view.overview.roiLabel}</dt>
            <dd>{view.lesson.primaryRoiPillar}</dd>
          </div>
          <div>
            <dt>{view.overview.timeLabel}</dt>
            <dd>{view.overview.timeValue}</dd>
          </div>
        </dl>
        <p className="lesson-version-line">
          <code>{view.lesson.versionId}</code> · <code>{view.lesson.version}</code> ·{" "}
          <code>{view.lesson.status}</code>
        </p>
      </section>

      <section className="lesson-panel lesson-scenario" aria-labelledby="lesson-scenario-heading">
        <header className="lesson-section-heading">
          <h2 id="lesson-scenario-heading">{view.scenario.heading}</h2>
          <p>{view.scenario.introduction}</p>
          <p className="lesson-synthetic-label">{view.scenario.syntheticLabel}</p>
        </header>
        <dl className="lesson-scenario__context">
          <div>
            <dt>{view.scenario.organizationLabel}</dt>
            <dd>{view.scenario.organization}</dd>
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
          <h2 id="lesson-concepts-heading">{view.concepts.heading}</h2>
          <p>{view.concepts.introduction}</p>
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

      <section className="lesson-panel lesson-rubric" aria-labelledby="lesson-rubric-heading">
        <header className="lesson-section-heading">
          <h2 id="lesson-rubric-heading">{view.rubric.heading}</h2>
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
      </section>

      <section className="lesson-panel lesson-practice" aria-labelledby="lesson-practice-heading">
        <header className="lesson-section-heading">
          <p className="section-heading__eyebrow">{view.practice.eyebrow}</p>
          <h2 id="lesson-practice-heading" ref={practiceHeadingRef} tabIndex={-1}>
            {view.practice.heading}
          </h2>
          <p>{view.practice.introduction}</p>
          <p className="lesson-practice__instruction" id="lesson-practice-instruction">
            {view.practice.instruction}
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
              {view.feedback.evaluateLabel}
            </button>
            {state.evaluation ? (
              <button
                className="player-button player-button--secondary"
                type="button"
                onClick={handleRetry}
              >
                {view.feedback.retryLabel}
              </button>
            ) : null}
            <button
              className="player-button player-button--quiet"
              type="button"
              onClick={handleReset}
            >
              {view.feedback.resetLabel}
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

      <section className="lesson-panel lesson-proof" aria-labelledby="lesson-proof-heading">
        <p className="section-heading__eyebrow">{view.proof.eyebrow}</p>
        <h2 id="lesson-proof-heading">{view.proof.heading}</h2>
        <p>{view.proof.introduction}</p>
        <p className="lesson-proof__label">{view.proof.placeholderLabel}</p>
        <h3>{view.proof.fieldsHeading}</h3>
        <ul>
          {view.proof.fields.map((field) => (
            <li key={field.id}>{field.label}</li>
          ))}
        </ul>
        <p className="lesson-proof__boundary">{view.proof.boundary}</p>
      </section>

      <aside className="lesson-reflection" aria-labelledby="lesson-reflection-heading">
        <h2 id="lesson-reflection-heading">{view.reflection.heading}</h2>
        <p>{view.reflection.prompt}</p>
        <p>{view.reflection.boundary}</p>
      </aside>

      <nav className="lesson-actions" aria-label={view.hero.heading}>
        <TextLink href={exampleResultHref}>{view.actions.backToExampleLabel}</TextLink>
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
