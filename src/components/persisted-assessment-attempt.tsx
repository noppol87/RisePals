"use client";

import { useEffect, useMemo, useRef, useState, useTransition, type FormEvent } from "react";
import type { Locale } from "@/lib/i18n/config";
import { TextLink } from "@/components/primitives/text-link";
import type { PersistedAssessmentCopy } from "@/modules/assessment/persistence/copy";
import type {
  PersistedAssessmentPageState,
  PersistedSelection,
} from "@/modules/assessment/persistence/dal";
import {
  savePersistedAssessmentResponseAction,
  submitPersistedAssessmentAction,
} from "@/app/[locale]/assessment/attempt/actions";

type InProgressState = Extract<PersistedAssessmentPageState, { state: "in-progress" }>;
type AttemptPhase = "questions" | "review" | "submitted";

type PersistedAssessmentAttemptProps = Readonly<{
  copy: PersistedAssessmentCopy;
  initialState: InProgressState;
  locale: Locale;
  resultHref: string;
}>;

function formatTemplate(
  template: string,
  values: Readonly<Record<string, string | number>>,
): string {
  return Object.entries(values).reduce(
    (result, [key, value]) => result.replaceAll(`{${key}}`, String(value)),
    template,
  );
}

export function PersistedAssessmentAttempt({
  copy,
  initialState,
  locale,
  resultHref,
}: PersistedAssessmentAttemptProps) {
  const initialIndex = Math.max(
    0,
    initialState.view.items.findIndex((item) => item.key === initialState.currentItemKey),
  );
  const [selections, setSelections] = useState<readonly PersistedSelection[]>(
    initialState.selections,
  );
  const [currentIndex, setCurrentIndex] = useState(initialIndex);
  const [phase, setPhase] = useState<AttemptPhase>(
    initialState.selections.length === initialState.view.items.length ? "review" : "questions",
  );
  const [selectedOptionId, setSelectedOptionId] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const headingRef = useRef<HTMLHeadingElement>(null);
  const messageRef = useRef<HTMLParagraphElement>(null);
  const items = initialState.view.items;
  const currentItem = items[currentIndex]!;
  const savedSelection = selections.find((selection) => selection.itemKey === currentItem.key);
  const answeredCount = selections.length;
  const selectedValue = selectedOptionId ?? savedSelection?.selectedOptionId ?? "";
  const selectionByItem = useMemo(
    () => new Map(selections.map((selection) => [selection.itemKey, selection])),
    [selections],
  );

  useEffect(() => {
    headingRef.current?.focus();
  }, [currentIndex, phase]);

  useEffect(() => {
    if (message) messageRef.current?.focus();
  }, [message]);

  function goToItem(index: number): void {
    setMessage(null);
    setSelectedOptionId(null);
    setCurrentIndex(index);
    setPhase("questions");
  }

  function handleSave(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault();
    if (!selectedValue) {
      setMessage(copy.answerRequired);
      return;
    }
    setMessage(null);
    const expectedRevision = savedSelection?.revision ?? 0;
    startTransition(async () => {
      try {
        const result = await savePersistedAssessmentResponseAction({
          locale,
          itemKey: currentItem.key,
          selectedOptionId: selectedValue,
          expectedRevision,
          clientMutationId: crypto.randomUUID(),
        });
        if (result.state === "conflict") {
          setSelections((current) => {
            const withoutItem = current.filter((entry) => entry.itemKey !== currentItem.key);
            return result.selection ? [...withoutItem, result.selection] : withoutItem;
          });
          setSelectedOptionId(result.selection?.selectedOptionId ?? null);
          setMessage(copy.saveConflict);
          return;
        }
        if (result.state !== "saved") {
          setMessage(copy.saveFailed);
          return;
        }
        setSelections((current) => [
          ...current.filter((entry) => entry.itemKey !== currentItem.key),
          result.selection,
        ]);
        setSelectedOptionId(null);
        setMessage(copy.savedStatus);
        if (currentIndex === items.length - 1) setPhase("review");
        else setCurrentIndex((index) => index + 1);
      } catch {
        setMessage(copy.saveFailed);
      }
    });
  }

  function handleSubmit(): void {
    setMessage(null);
    startTransition(async () => {
      try {
        const result = await submitPersistedAssessmentAction(locale);
        if (result.state === "submitted") setPhase("submitted");
        else setMessage(copy.submitFailed);
      } catch {
        setMessage(copy.submitFailed);
      }
    });
  }

  if (phase === "submitted") {
    return (
      <div className="assessment-player__completion">
        <p className="section-heading__eyebrow">{copy.completionEyebrow}</p>
        <h2 ref={headingRef} tabIndex={-1}>
          {copy.completionHeading}
        </h2>
        <p>{copy.completionBody}</p>
        <p className="assessment-completion-boundary">{copy.completionBoundary}</p>
        <p>{copy.resultActionBoundary}</p>
        <TextLink href={resultHref}>{copy.resultActionLabel}</TextLink>
      </div>
    );
  }

  if (phase === "review") {
    return (
      <div className="assessment-player__completion">
        <h2 ref={headingRef} tabIndex={-1}>
          {copy.reviewHeading}
        </h2>
        <p>{copy.reviewBody}</p>
        <p>
          {formatTemplate(copy.answeredTemplate, { answered: answeredCount, total: items.length })}
        </p>
        <ol className="assessment-review-list">
          {items.map((item, index) => {
            const selection = selectionByItem.get(item.key);
            const label = item.options.find(
              (option) => option.id === selection?.selectedOptionId,
            )?.label;
            return (
              <li key={item.key}>
                <p>
                  <strong>{item.prompt}</strong>
                </p>
                <p>{label}</p>
                <button
                  className="player-button player-button--quiet"
                  type="button"
                  onClick={() => goToItem(index)}
                >
                  {copy.editLabel}
                </button>
              </li>
            );
          })}
        </ol>
        {message ? (
          <p ref={messageRef} role="alert" tabIndex={-1}>
            {message}
          </p>
        ) : null}
        <button
          className="player-button player-button--primary"
          disabled={isPending || answeredCount !== items.length}
          type="button"
          onClick={handleSubmit}
        >
          {copy.submitLabel}
        </button>
      </div>
    );
  }

  return (
    <div className="assessment-player__question">
      <header className="assessment-player__step-heading">
        <h2 ref={headingRef} tabIndex={-1}>
          {formatTemplate(copy.positionTemplate, {
            current: currentIndex + 1,
            total: items.length,
          })}
        </h2>
        <p>
          {formatTemplate(copy.answeredTemplate, { answered: answeredCount, total: items.length })}
        </p>
      </header>
      <form className="assessment-question-form" noValidate onSubmit={handleSave}>
        <fieldset
          aria-describedby={`persisted-option-hint${message ? " persisted-save-message" : ""}`}
        >
          <legend>{currentItem.prompt}</legend>
          <p id="persisted-option-hint" className="assessment-question-form__hint">
            {copy.optionHint}
          </p>
          <div className="assessment-options">
            {currentItem.options.map((option) => (
              <label className="assessment-option" key={option.id}>
                <input
                  checked={selectedValue === option.id}
                  name={`persisted-response-${currentItem.key}`}
                  type="radio"
                  value={option.id}
                  onChange={() => {
                    setSelectedOptionId(option.id);
                    setMessage(null);
                  }}
                />
                <span>{option.label}</span>
              </label>
            ))}
          </div>
        </fieldset>
        {message ? (
          <p id="persisted-save-message" ref={messageRef} role="status" tabIndex={-1}>
            {message}
          </p>
        ) : null}
        <div className="assessment-player__actions assessment-player__actions--question">
          <button
            className="player-button player-button--secondary"
            disabled={isPending || currentIndex === 0}
            type="button"
            onClick={() => goToItem(currentIndex - 1)}
          >
            {copy.backLabel}
          </button>
          <button
            className="player-button player-button--primary"
            disabled={isPending}
            type="submit"
          >
            {currentIndex === items.length - 1 ? copy.saveAndReviewLabel : copy.saveLabel}
          </button>
        </div>
      </form>
    </div>
  );
}
