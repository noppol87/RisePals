"use client";

import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { TextLink } from "@/components/primitives/text-link";
import type { AssessmentPlayerCatalog } from "@/lib/i18n/catalogs";
import { getBrowserSessionStorage } from "@/modules/assessment/player/browser-storage";
import {
  advancePlayer,
  createInitialPlayerState,
  getPlayerProgress,
  movePlayerBack,
  resetPlayer,
  reviewPlayerAnswers,
  selectPlayerOption,
  startPlayer,
  type AssessmentPlayerState,
} from "@/modules/assessment/player/state";
import {
  clearPlayerState,
  loadPlayerState,
  persistPlayerState,
  type SessionStorageLike,
} from "@/modules/assessment/player/storage";
import type { AssessmentPlayerView } from "@/modules/assessment/player/view";

type AssessmentPlayerProps = Readonly<{
  homeHref: string;
  messages: AssessmentPlayerCatalog;
  view: AssessmentPlayerView;
}>;

type StorageStatus = "empty" | "loaded" | "discarded" | "unavailable" | "cleared";

export function AssessmentPlayer({ homeHref, messages, view }: AssessmentPlayerProps) {
  const [state, setState] = useState<AssessmentPlayerState>(createInitialPlayerState);
  const [hydrated, setHydrated] = useState(false);
  const [storageStatus, setStorageStatus] = useState<StorageStatus>("empty");
  const [validationError, setValidationError] = useState<string | null>(null);
  const storageRef = useRef<SessionStorageLike | null>(null);
  const headingRef = useRef<HTMLHeadingElement>(null);
  const errorRef = useRef<HTMLParagraphElement>(null);
  const previousStepRef = useRef("intro:");

  const progress = useMemo(() => getPlayerProgress(state, view), [state, view]);
  const currentItem =
    state.phase === "question"
      ? view.items.find((item) => item.key === state.currentItemKey)
      : undefined;
  const currentSelection = currentItem
    ? state.selections.find((selection) => selection.itemKey === currentItem.key)?.optionId
    : undefined;
  const stepIdentity = `${state.phase}:${state.currentItemKey ?? ""}`;
  const announcement =
    state.phase === "question" && progress.currentPosition !== null
      ? formatTemplate(messages.stepAnnouncementTemplate, {
          current: progress.currentPosition,
          total: progress.totalItems,
        })
      : state.phase === "complete"
        ? messages.completionAnnouncement
        : "";

  useEffect(() => {
    let cancelled = false;
    const storage = getBrowserSessionStorage();
    storageRef.current = storage;
    const loaded = loadPlayerState(storage, view);
    queueMicrotask(() => {
      if (!cancelled) {
        setState(loaded.state);
        setStorageStatus(loaded.status);
        setHydrated(true);
      }
    });

    return () => {
      cancelled = true;
    };
  }, [view]);

  useEffect(() => {
    if (!hydrated) {
      return;
    }

    if (!persistPlayerState(storageRef.current, state, view)) {
      queueMicrotask(() => setStorageStatus("unavailable"));
    }
  }, [hydrated, state, view]);

  useEffect(() => {
    if (!hydrated || previousStepRef.current === stepIdentity) {
      return;
    }

    previousStepRef.current = stepIdentity;
    headingRef.current?.focus();
  }, [hydrated, stepIdentity]);

  useEffect(() => {
    if (validationError !== null) {
      errorRef.current?.focus();
    }
  }, [validationError]);

  function updateState(nextState: AssessmentPlayerState): void {
    setValidationError(null);
    setState(nextState);
  }

  function handleContinue(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault();
    const result = advancePlayer(state, view);
    if (!result.ok) {
      setValidationError(
        result.reason === "answer-required"
          ? messages.answerRequired
          : messages.assessmentIncomplete,
      );
      return;
    }

    updateState(result.state);
  }

  function handleClear(): void {
    const cleared = clearPlayerState(storageRef.current);
    setStorageStatus(cleared ? "cleared" : "unavailable");
    setValidationError(null);
    setState(resetPlayer());
  }

  const storageMessage = getStorageMessage(storageStatus, messages);

  return (
    <section className="assessment-player" aria-labelledby="assessment-player-heading">
      <p className="visually-hidden" aria-live="polite" aria-atomic="true">
        {announcement}
      </p>

      {state.phase === "intro" ? (
        <div className="assessment-player__intro">
          <p className="section-heading__eyebrow">{messages.eyebrow}</p>
          <h1 id="assessment-player-heading" ref={headingRef} tabIndex={-1}>
            {messages.heading}
          </h1>
          <p className="assessment-player__lead">{messages.introduction}</p>

          <div className="assessment-boundary" aria-labelledby="assessment-boundary-heading">
            <h2 id="assessment-boundary-heading">{messages.boundariesHeading}</h2>
            <ul>
              {messages.boundaries.map((boundary) => (
                <li key={boundary}>{boundary}</li>
              ))}
            </ul>
          </div>

          <div className="assessment-storage-notice" aria-labelledby="storage-notice-heading">
            <h2 id="storage-notice-heading">{messages.storageHeading}</h2>
            <p>{messages.storageBody}</p>
          </div>

          {storageMessage ? (
            <p className="assessment-player__status" role="status">
              {storageMessage}
            </p>
          ) : null}

          <div className="assessment-player__actions">
            <button
              className="player-button player-button--primary"
              disabled={!hydrated}
              type="button"
              onClick={() => updateState(startPlayer(state, view))}
            >
              {messages.startLabel}
            </button>
            {state.selections.length > 0 ? (
              <button
                className="player-button player-button--secondary"
                type="button"
                onClick={handleClear}
              >
                {messages.clearLabel}
              </button>
            ) : null}
            <TextLink href={homeHref}>{messages.homeLabel}</TextLink>
          </div>
        </div>
      ) : null}

      {state.phase === "question" && currentItem && progress.currentPosition !== null ? (
        <div className="assessment-player__question">
          <header className="assessment-player__step-heading">
            <p className="section-heading__eyebrow">{messages.eyebrow}</p>
            <h1 id="assessment-player-heading" ref={headingRef} tabIndex={-1}>
              {formatTemplate(messages.questionHeadingTemplate, {
                current: progress.currentPosition,
              })}
            </h1>
            <div
              className="assessment-progress"
              aria-label={formatTemplate(messages.positionTemplate, {
                current: progress.currentPosition,
                total: progress.totalItems,
              })}
            >
              <p>
                {formatTemplate(messages.positionTemplate, {
                  current: progress.currentPosition,
                  total: progress.totalItems,
                })}
              </p>
              <p>
                {formatTemplate(messages.answeredTemplate, {
                  answered: progress.answeredCount,
                  total: progress.totalItems,
                })}
              </p>
            </div>
          </header>

          <form className="assessment-question-form" noValidate onSubmit={handleContinue}>
            <fieldset
              aria-describedby={`assessment-option-hint${validationError ? " assessment-answer-error" : ""}`}
              aria-invalid={validationError ? "true" : undefined}
            >
              <legend>{currentItem.prompt}</legend>
              <p id="assessment-option-hint" className="assessment-question-form__hint">
                {messages.optionGroupHint}
              </p>
              <div className="assessment-options">
                {currentItem.options.map((option) => (
                  <label className="assessment-option" key={option.id}>
                    <input
                      checked={currentSelection === option.id}
                      name={`assessment-response-${currentItem.key}`}
                      required
                      type="radio"
                      value={option.id}
                      onChange={() => {
                        setValidationError(null);
                        setState(selectPlayerOption(state, view, option.id));
                      }}
                    />
                    <span>{option.label}</span>
                  </label>
                ))}
              </div>
            </fieldset>

            {validationError ? (
              <p
                id="assessment-answer-error"
                className="assessment-player__error"
                ref={errorRef}
                role="alert"
                tabIndex={-1}
              >
                {validationError}
              </p>
            ) : null}

            <div className="assessment-player__actions assessment-player__actions--question">
              <button
                className="player-button player-button--secondary"
                type="button"
                onClick={() => updateState(movePlayerBack(state, view))}
              >
                {messages.backLabel}
              </button>
              <button className="player-button player-button--primary" type="submit">
                {progress.currentPosition === progress.totalItems
                  ? messages.finishLabel
                  : messages.continueLabel}
              </button>
              <button
                className="player-button player-button--quiet"
                type="button"
                onClick={handleClear}
              >
                {messages.clearLabel}
              </button>
            </div>
          </form>

          {storageMessage ? (
            <p className="assessment-player__status" role="status">
              {storageMessage}
            </p>
          ) : null}
        </div>
      ) : null}

      {state.phase === "complete" ? (
        <div className="assessment-player__completion">
          <p className="section-heading__eyebrow">{messages.completionEyebrow}</p>
          <h1 id="assessment-player-heading" ref={headingRef} tabIndex={-1}>
            {messages.completionHeading}
          </h1>
          <p className="assessment-player__lead">{messages.completionSummary}</p>
          <p className="assessment-completion-boundary">{messages.completionBoundary}</p>
          <div className="assessment-progress assessment-progress--complete">
            <p>
              {formatTemplate(messages.answeredTemplate, {
                answered: progress.answeredCount,
                total: progress.totalItems,
              })}
            </p>
          </div>
          <div className="assessment-player__actions">
            <button
              className="player-button player-button--secondary"
              type="button"
              onClick={() => updateState(reviewPlayerAnswers(state, view))}
            >
              {messages.reviewLabel}
            </button>
            <button
              className="player-button player-button--primary"
              type="button"
              onClick={handleClear}
            >
              {messages.restartLabel}
            </button>
            <TextLink href={homeHref}>{messages.homeLabel}</TextLink>
          </div>
        </div>
      ) : null}
    </section>
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

function getStorageMessage(
  status: StorageStatus,
  messages: AssessmentPlayerCatalog,
): string | null {
  switch (status) {
    case "loaded":
      return messages.storageRestored;
    case "discarded":
      return messages.storageDiscarded;
    case "unavailable":
      return messages.storageUnavailable;
    case "cleared":
      return messages.storageCleared;
    case "empty":
      return null;
  }
}
