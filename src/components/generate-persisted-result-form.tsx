"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import {
  generatePersistedResultAction,
  type GenerateResultActionState,
} from "@/app/[locale]/assessment/result/actions";
import type { Locale } from "@/lib/i18n/config";
import type { PersistedResultCopy } from "@/modules/assessment/persisted-result/copy";

type GeneratePersistedResultFormProps = Readonly<{
  locale: Locale;
  mutationId: string;
  copy: PersistedResultCopy;
}>;

const initialState: GenerateResultActionState = { state: "idle" };

export function GeneratePersistedResultForm({
  locale,
  mutationId,
  copy,
}: GeneratePersistedResultFormProps) {
  const [state, action] = useActionState(generatePersistedResultAction, initialState);
  return (
    <form action={action} className="persisted-result__generate-form">
      <input name="locale" type="hidden" value={locale} />
      <input name="mutationId" type="hidden" value={mutationId} />
      <GenerateButton copy={copy} />
      {state.state === "failed" ? <p role="alert">{copy.generateError}</p> : null}
    </form>
  );
}

function GenerateButton({ copy }: Readonly<{ copy: PersistedResultCopy }>) {
  const { pending } = useFormStatus();
  return (
    <button className="player-button player-button--primary" disabled={pending} type="submit">
      {pending ? copy.generatingLabel : copy.generateLabel}
    </button>
  );
}
