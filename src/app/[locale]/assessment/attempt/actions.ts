"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { isLocale, persistedAssessmentPath, type Locale } from "@/lib/i18n/config";
import {
  savePersistedAssessmentResponse,
  startPersistedAssessment,
  submitPersistedAssessment,
} from "@/modules/assessment/persistence/dal";
import type { SavePersistedResponseInput } from "@/modules/assessment/persistence/contract";
import {
  captureSuccessfulProductAction,
  reportControlledErrorOccurrence,
} from "@/modules/measurement/server";

function readLocale(value: unknown): Locale {
  if (typeof value !== "string" || !isLocale(value)) throw new Error("Unsupported locale.");
  return value;
}

export async function startPersistedAssessmentAction(formData: FormData) {
  const locale = readLocale(formData.get("locale"));
  const result = await startPersistedAssessment(locale);
  if (result.state === "denied") throw new Error("The assessment operation is not authorized.");
  revalidatePath(persistedAssessmentPath(locale));
  redirect(persistedAssessmentPath(locale));
}

export async function savePersistedAssessmentResponseAction(input: SavePersistedResponseInput) {
  const locale = readLocale(input.locale);
  let result: Awaited<ReturnType<typeof savePersistedAssessmentResponse>>;
  try {
    result = await savePersistedAssessmentResponse({ ...input, locale });
  } catch (error) {
    await reportControlledErrorOccurrence({
      surface: "assessment",
      operationCode: "assessment_response_saved",
      locale,
      category: "unexpected_domain",
      retryable: true,
      clientMutationId: input.clientMutationId,
    });
    throw error;
  }
  if (result.state === "saved") {
    await captureSuccessfulProductAction({
      surface: "assessment",
      operationCode: "assessment_response_saved",
      locale,
      clientMutationId: input.clientMutationId,
    });
  }
  revalidatePath(persistedAssessmentPath(locale));
  return result;
}

export async function submitPersistedAssessmentAction(localeValue: string) {
  const locale = readLocale(localeValue);
  const result = await submitPersistedAssessment(locale);
  revalidatePath(persistedAssessmentPath(locale));
  return result;
}
