"use server";

import { revalidatePath } from "next/cache";
import {
  evidencePath,
  isLocale,
  sourceVerificationEvidencePath,
  type Locale,
} from "@/lib/i18n/config";
import type { EvidenceLifecycleInput, EvidenceSaveInput } from "@/modules/evidence/types";
import {
  mutateEvidenceLifecycle,
  saveEvidenceArtifact,
  startEvidenceArtifact,
} from "@/modules/evidence/dal";

function localeValue(value: unknown): Locale {
  if (typeof value !== "string" || !isLocale(value)) throw new Error("Unsupported locale.");
  return value;
}

function revalidateEvidence(locale: Locale) {
  revalidatePath(evidencePath(locale));
  revalidatePath(sourceVerificationEvidencePath(locale));
}

export async function startEvidenceArtifactAction(localeInput: string, clientMutationId: string) {
  const locale = localeValue(localeInput);
  const result = await startEvidenceArtifact({ locale, clientMutationId });
  revalidateEvidence(locale);
  return result;
}

export async function saveEvidenceArtifactAction(input: EvidenceSaveInput) {
  const locale = localeValue(input.locale);
  const result = await saveEvidenceArtifact({ ...input, locale });
  revalidateEvidence(locale);
  return result;
}

export async function mutateEvidenceLifecycleAction(input: EvidenceLifecycleInput) {
  const locale = localeValue(input.locale);
  const result = await mutateEvidenceLifecycle({ ...input, locale });
  revalidateEvidence(locale);
  return result;
}
