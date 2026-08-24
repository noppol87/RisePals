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
import {
  captureSuccessfulProductAction,
  reportControlledErrorOccurrence,
} from "@/modules/measurement/server";

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
  let result: Awaited<ReturnType<typeof saveEvidenceArtifact>>;
  try {
    result = await saveEvidenceArtifact({ ...input, locale });
  } catch (error) {
    await reportControlledErrorOccurrence({
      surface: "private_evidence",
      operationCode: "private_evidence_saved",
      locale,
      category: "unexpected_domain",
      retryable: true,
      clientMutationId: input.clientMutationId,
    });
    throw error;
  }
  if (result.state === "saved" || result.state === "ready" || result.state === "withdrawn") {
    await captureSuccessfulProductAction({
      surface: "private_evidence",
      operationCode: "private_evidence_saved",
      locale,
      clientMutationId: input.clientMutationId,
    });
  }
  revalidateEvidence(locale);
  return result;
}

export async function mutateEvidenceLifecycleAction(input: EvidenceLifecycleInput) {
  const locale = localeValue(input.locale);
  const operationCode =
    input.intent === "ready"
      ? ("private_evidence_marked_ready" as const)
      : ("private_evidence_withdrawn" as const);
  let result: Awaited<ReturnType<typeof mutateEvidenceLifecycle>>;
  try {
    result = await mutateEvidenceLifecycle({ ...input, locale });
  } catch (error) {
    await reportControlledErrorOccurrence({
      surface: "private_evidence",
      operationCode,
      locale,
      category: "unexpected_domain",
      retryable: true,
      clientMutationId: input.clientMutationId,
    });
    throw error;
  }
  if (result.state === "ready" || result.state === "withdrawn") {
    await captureSuccessfulProductAction({
      surface: "private_evidence",
      operationCode,
      locale,
      clientMutationId: input.clientMutationId,
    });
  }
  revalidateEvidence(locale);
  return result;
}
