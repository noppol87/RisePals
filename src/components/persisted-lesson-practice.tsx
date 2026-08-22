"use client";

import { useEffect, useRef, useState, useTransition, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import {
  mutatePersistedLessonAction,
  startPersistedLessonAction,
} from "@/app/[locale]/lessons/source-verification-practice/attempt/actions";
import type { Locale } from "@/lib/i18n/config";
import type { PersistedLessonCopy } from "@/modules/lesson/persistence/copy";
import type {
  ClientSafePracticeView,
  PersistedPracticeSelection,
} from "@/modules/lesson/persistence/contract";
import type {
  PersistedCriterionResult,
  PersistedLessonPageState,
} from "@/modules/lesson/persistence/dal";

type ActiveState = Extract<
  PersistedLessonPageState,
  { state: "in-progress" | "needs-retry" | "demonstrated" }
>;

function formatRevision(template: string, revision: number) {
  return template.replace("{revision}", String(revision));
}

export function StartPersistedLesson({
  copy,
  locale,
}: {
  copy: PersistedLessonCopy;
  locale: Locale;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [failed, setFailed] = useState(false);
  return (
    <div className="lesson-practice__actions">
      <button
        className="player-button player-button--primary"
        disabled={pending}
        type="button"
        onClick={() =>
          startTransition(async () => {
            const result = await startPersistedLessonAction(locale, crypto.randomUUID());
            setFailed(result.state === "denied" || result.state === "not-ready");
            if (result.state !== "denied" && result.state !== "not-ready") router.refresh();
          })
        }
      >
        {copy.startLabel}
      </button>
      {failed ? <p role="alert">{copy.failed}</p> : null}
    </div>
  );
}

export function PersistedLessonPractice({
  copy,
  initialState,
  locale,
}: {
  copy: PersistedLessonCopy;
  initialState: ActiveState;
  locale: Locale;
}) {
  const [phase, setPhase] = useState(initialState.state);
  const [revision, setRevision] = useState(initialState.revision);
  const [selections, setSelections] = useState<readonly PersistedPracticeSelection[]>(
    initialState.selections,
  );
  const [results, setResults] = useState<readonly PersistedCriterionResult[] | null>(
    initialState.results,
  );
  const [message, setMessage] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const feedbackRef = useRef<HTMLHeadingElement>(null);
  const view: ClientSafePracticeView = initialState.view;

  useEffect(() => {
    if (results) feedbackRef.current?.focus();
  }, [results]);

  function select(criterionId: PersistedPracticeSelection["criterionId"], optionId: string) {
    setSelections((current) => {
      const byCriterion = new Map(current.map((selection) => [selection.criterionId, selection]));
      byCriterion.set(criterionId, { criterionId, optionId });
      return view.criteria.flatMap((criterion) => {
        const selection = byCriterion.get(criterion.id);
        return selection ? [selection] : [];
      });
    });
    setMessage(null);
  }

  function applyResult(result: Awaited<ReturnType<typeof mutatePersistedLessonAction>>) {
    if (result.state === "conflict") {
      setMessage(copy.conflict);
      return;
    }
    if (result.state === "not-ready" || result.state === "denied") {
      setMessage(copy.failed);
      return;
    }
    if (!("revision" in result)) {
      setMessage(copy.failed);
      return;
    }
    setRevision(result.revision);
    setSelections(result.selections);
    setResults(result.results);
    setPhase(result.state === "saved" ? "in-progress" : result.state);
    setMessage(result.state === "saved" ? copy.saved : null);
  }

  function save(event: FormEvent) {
    event.preventDefault();
    startTransition(async () => {
      try {
        applyResult(
          await mutatePersistedLessonAction({
            locale,
            intent: "save",
            selections,
            expectedRevision: revision,
            clientMutationId: crypto.randomUUID(),
          }),
        );
      } catch {
        setMessage(copy.failed);
      }
    });
  }

  function evaluate() {
    if (selections.length !== view.criteria.length) {
      setMessage(copy.incomplete);
      return;
    }
    startTransition(async () => {
      try {
        applyResult(
          await mutatePersistedLessonAction({
            locale,
            intent: "evaluate",
            selections,
            expectedRevision: revision,
            clientMutationId: crypto.randomUUID(),
          }),
        );
      } catch {
        setMessage(copy.failed);
      }
    });
  }

  function retry() {
    startTransition(async () => {
      try {
        applyResult(
          await mutatePersistedLessonAction({
            locale,
            intent: "retry",
            expectedRevision: revision,
            clientMutationId: crypto.randomUUID(),
          }),
        );
      } catch {
        setMessage(copy.failed);
      }
    });
  }

  return (
    <section className="lesson-panel lesson-practice" aria-labelledby="persisted-practice-heading">
      <header className="lesson-section-heading">
        <h2 id="persisted-practice-heading">{view.heading}</h2>
        <p>{view.introduction}</p>
        <p className="lesson-practice__instruction">{view.instruction}</p>
        <p>{formatRevision(copy.revisionTemplate, revision)}</p>
      </header>
      <form className="lesson-practice__form" noValidate onSubmit={save}>
        {view.criteria.map((criterion) => {
          const selected = selections.find((selection) => selection.criterionId === criterion.id);
          return (
            <fieldset key={criterion.id} disabled={pending || phase === "demonstrated"}>
              <legend>
                <span>{criterion.label}</span>
                {criterion.prompt}
              </legend>
              <div className="lesson-practice__options">
                {criterion.options.map((option) => (
                  <label className="lesson-practice__option" key={option.id}>
                    <input
                      checked={selected?.optionId === option.id}
                      name={`persisted-practice-${criterion.id}`}
                      type="radio"
                      value={option.id}
                      onChange={() => select(criterion.id, option.id)}
                    />
                    <span>{option.label}</span>
                  </label>
                ))}
              </div>
            </fieldset>
          );
        })}
        {message ? <p role="status">{message}</p> : null}
        {phase !== "demonstrated" ? (
          <div className="lesson-practice__actions">
            {phase === "needs-retry" ? (
              <button
                className="player-button player-button--secondary"
                disabled={pending}
                type="button"
                onClick={retry}
              >
                {copy.retryLabel}
              </button>
            ) : (
              <>
                <button
                  className="player-button player-button--secondary"
                  disabled={pending}
                  type="submit"
                >
                  {copy.saveLabel}
                </button>
                <button
                  className="player-button player-button--primary"
                  disabled={pending}
                  type="button"
                  onClick={evaluate}
                >
                  {copy.evaluateLabel}
                </button>
              </>
            )}
          </div>
        ) : null}
      </form>
      {results ? (
        <section className="lesson-feedback" aria-labelledby="persisted-feedback-heading">
          <h3 id="persisted-feedback-heading" ref={feedbackRef} tabIndex={-1}>
            {phase === "demonstrated" ? copy.demonstratedHeading : copy.retryHeading}
          </h3>
          <p>{copy.feedbackHeading}</p>
          <ul>
            {results.map((result) => {
              const criterion = view.criteria.find(
                (candidate) => candidate.id === result.criterionId,
              )!;
              return (
                <li key={result.criterionId}>
                  <strong>
                    {criterion.label}: {result.status === "met" ? copy.met : copy.notMet}
                  </strong>
                </li>
              );
            })}
          </ul>
          <p className="lesson-feedback__boundary">{copy.noXp}</p>
        </section>
      ) : null}
    </section>
  );
}
