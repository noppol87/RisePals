"use client";

import { useRef, useState, useTransition, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import {
  mutateEvidenceLifecycleAction,
  saveEvidenceArtifactAction,
  startEvidenceArtifactAction,
} from "@/app/[locale]/evidence/source-verification-note/actions";
import type { Locale } from "@/lib/i18n/config";
import type { EvidenceCopy } from "@/modules/evidence/copy";
import type { EvidenceArtifactClientState } from "@/modules/evidence/dal";
import type {
  EvidenceArtifactPayload,
  EvidenceArtifactView,
  EvidenceFieldFeedback,
} from "@/modules/evidence/types";

export function StartEvidenceArtifact({ copy, locale }: { copy: EvidenceCopy; locale: Locale }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<string | null>(null);
  return (
    <div className="lesson-practice__actions">
      <button
        className="player-button player-button--primary"
        disabled={pending}
        type="button"
        onClick={() =>
          startTransition(async () => {
            try {
              const result = await startEvidenceArtifactAction(locale, crypto.randomUUID());
              if (result.state === "saved" || result.state === "ready") router.refresh();
              else setMessage(result.state === "conflict" ? copy.conflict : copy.failed);
            } catch {
              setMessage(copy.failed);
            }
          })
        }
      >
        {copy.startLabel}
      </button>
      {message ? <p role="alert">{message}</p> : null}
    </div>
  );
}

function revisionLabel(template: string, revision: number) {
  return template.replace("{revision}", String(revision));
}

function feedbackMessage(
  feedback: readonly EvidenceFieldFeedback[],
  fieldId: EvidenceFieldFeedback["fieldId"],
) {
  return feedback.find((entry) => entry.fieldId === fieldId)?.message;
}

export function PrivateEvidenceArtifact({
  copy,
  initialArtifact,
  locale,
  view,
}: {
  copy: EvidenceCopy;
  initialArtifact: EvidenceArtifactClientState;
  locale: Locale;
  view: EvidenceArtifactView;
}) {
  const [artifact, setArtifact] = useState(initialArtifact);
  const [payload, setPayload] = useState<EvidenceArtifactPayload>(initialArtifact.payload);
  const [message, setMessage] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const statusRef = useRef<HTMLHeadingElement>(null);
  const readOnly = artifact.status !== "draft";

  function apply(result: Awaited<ReturnType<typeof saveEvidenceArtifactAction>>) {
    if (result.state === "conflict") {
      setMessage(copy.conflict);
      return false;
    }
    if (result.state === "not-ready" || result.state === "denied") {
      setMessage(result.state === "not-ready" ? copy.notReady : copy.failed);
      return false;
    }
    if (!("artifact" in result)) {
      setMessage(copy.failed);
      return false;
    }
    setArtifact(result.artifact);
    setPayload(result.artifact.payload);
    setMessage(
      result.state === "ready"
        ? copy.readyMessage
        : result.state === "withdrawn"
          ? copy.withdrawnMessage
          : copy.saved,
    );
    queueMicrotask(() => statusRef.current?.focus());
    return true;
  }

  function save(event: FormEvent) {
    event.preventDefault();
    startTransition(async () => {
      try {
        apply(
          await saveEvidenceArtifactAction({
            locale,
            intent: "save",
            payload,
            expectedRevision: artifact.revision,
            clientMutationId: crypto.randomUUID(),
          }),
        );
      } catch {
        setMessage(copy.failed);
      }
    });
  }

  function markReady() {
    startTransition(async () => {
      try {
        const saved = await saveEvidenceArtifactAction({
          locale,
          intent: "save",
          payload,
          expectedRevision: artifact.revision,
          clientMutationId: crypto.randomUUID(),
        });
        if (!apply(saved) || !("artifact" in saved)) return;
        apply(
          await mutateEvidenceLifecycleAction({
            locale,
            intent: "ready",
            expectedRevision: saved.artifact.revision,
            clientMutationId: crypto.randomUUID(),
          }),
        );
      } catch {
        setMessage(copy.failed);
      }
    });
  }

  function withdraw() {
    startTransition(async () => {
      try {
        apply(
          await mutateEvidenceLifecycleAction({
            locale,
            intent: "withdraw",
            expectedRevision: artifact.revision,
            clientMutationId: crypto.randomUUID(),
          }),
        );
      } catch {
        setMessage(copy.failed);
      }
    });
  }

  function toggleSource(id: EvidenceArtifactView["sourceReferences"][number]["id"]) {
    const selected = new Set(payload.sourceReferenceIds);
    if (selected.has(id)) selected.delete(id);
    else selected.add(id);
    setPayload({
      ...payload,
      sourceReferenceIds: view.sourceReferences.flatMap(({ id: candidate }) =>
        selected.has(candidate) ? [candidate] : [],
      ),
    });
    setMessage(null);
  }

  const feedback = artifact.feedback;

  return (
    <section className="lesson-panel lesson-practice" aria-labelledby="evidence-form-heading">
      <header className="lesson-section-heading">
        <h2 id="evidence-form-heading">{copy.formHeading}</h2>
        <p>{copy.formInstruction}</p>
        <p>{revisionLabel(copy.revisionTemplate, artifact.revision)}</p>
      </header>
      <form className="lesson-practice__form" noValidate onSubmit={save}>
        <fieldset disabled={pending || readOnly}>
          <legend>{copy.claimHeading}</legend>
          <p>{copy.claimInstruction}</p>
          <label className="lesson-practice__option">
            <input
              checked={payload.claimId === view.claim.id}
              name="evidence-claim"
              type="radio"
              value={view.claim.id}
              onChange={() => setPayload({ ...payload, claimId: view.claim.id })}
            />
            <span>
              <strong>{view.claim.label}</strong> {view.claim.value}
            </span>
          </label>
          <p>{feedbackMessage(feedback, "claim")}</p>
        </fieldset>
        <fieldset disabled={pending || readOnly}>
          <legend>{copy.sourceHeading}</legend>
          <p>{copy.sourceInstruction}</p>
          <div className="lesson-practice__options">
            {view.sourceReferences.map((source) => (
              <label className="lesson-practice__option" key={source.id}>
                <input
                  checked={payload.sourceReferenceIds.includes(source.id)}
                  type="checkbox"
                  value={source.id}
                  onChange={() => toggleSource(source.id)}
                />
                <span>
                  <strong>{source.label}</strong> {source.detail}
                </span>
              </label>
            ))}
          </div>
          <p>{feedbackMessage(feedback, "source-reference")}</p>
        </fieldset>
        <EvidenceRadioField
          disabled={pending || readOnly}
          heading={copy.fitHeading}
          instruction={copy.fitInstruction}
          name="evidence-fit"
          options={view.fitChecks}
          selected={payload.fitCheckId}
          feedback={feedbackMessage(feedback, "fit-check")}
          onSelect={(fitCheckId) => setPayload({ ...payload, fitCheckId })}
        />
        <EvidenceRadioField
          disabled={pending || readOnly}
          heading={copy.correctedHeading}
          instruction={copy.correctedInstruction}
          name="evidence-correction"
          options={view.correctedWordingOptions}
          selected={payload.correctedWordingOptionId}
          feedback={feedbackMessage(feedback, "corrected-wording")}
          onSelect={(correctedWordingOptionId) =>
            setPayload({ ...payload, correctedWordingOptionId })
          }
        />
        <EvidenceRadioField
          disabled={pending || readOnly}
          heading={copy.safeHeading}
          instruction={copy.safeInstruction}
          name="evidence-safe-action"
          options={view.safeNextActionOptions}
          selected={payload.safeNextActionOptionId}
          feedback={feedbackMessage(feedback, "safe-next-action")}
          onSelect={(safeNextActionOptionId) => setPayload({ ...payload, safeNextActionOptionId })}
        />
        <section aria-labelledby="evidence-feedback-heading">
          <h3 id="evidence-feedback-heading">{copy.feedbackHeading}</h3>
          <ul>
            {artifact.feedback.map((entry) => (
              <li key={entry.fieldId}>{entry.message}</li>
            ))}
          </ul>
        </section>
        <h3 ref={statusRef} tabIndex={-1}>
          {copy.statusHeading}
        </h3>
        <p role="status" aria-live="polite">
          {message ?? copy[artifact.status]}
        </p>
        {readOnly ? (
          <div className="assessment-storage-notice">
            <h3>{copy.readOnlyHeading}</h3>
            <p>{copy.readOnlyBody}</p>
          </div>
        ) : null}
        <div className="lesson-practice__actions">
          {!readOnly ? (
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
                onClick={markReady}
              >
                {copy.readyLabel}
              </button>
            </>
          ) : null}
          {artifact.status !== "withdrawn" ? (
            <button
              className="player-button player-button--secondary"
              disabled={pending}
              type="button"
              onClick={withdraw}
            >
              {copy.withdrawLabel}
            </button>
          ) : null}
        </div>
      </form>
    </section>
  );
}

function EvidenceRadioField<T extends string>({
  disabled,
  feedback,
  heading,
  instruction,
  name,
  onSelect,
  options,
  selected,
}: {
  disabled: boolean;
  feedback: string | undefined;
  heading: string;
  instruction: string;
  name: string;
  onSelect: (id: T) => void;
  options: readonly Readonly<{ id: T; label: string }>[];
  selected: T | null;
}) {
  return (
    <fieldset disabled={disabled}>
      <legend>{heading}</legend>
      <p>{instruction}</p>
      <div className="lesson-practice__options">
        {options.map((option) => (
          <label className="lesson-practice__option" key={option.id}>
            <input
              checked={selected === option.id}
              name={name}
              type="radio"
              value={option.id}
              onChange={() => onSelect(option.id)}
            />
            <span>{option.label}</span>
          </label>
        ))}
      </div>
      {feedback ? <p>{feedback}</p> : null}
    </fieldset>
  );
}
