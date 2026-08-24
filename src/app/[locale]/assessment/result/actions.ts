"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { isLocale, persistedAssessmentResultPath, type Locale } from "@/lib/i18n/config";
import { generatePersistedResultWithExecution } from "@/modules/assessment/persisted-result/dal";
import {
  captureSuccessfulProductAction,
  reportControlledErrorOccurrence,
} from "@/modules/measurement/server";

export type GenerateResultActionState = Readonly<{ state: "idle" | "failed" }>;

function readLocale(value: FormDataEntryValue | null): Locale {
  if (typeof value !== "string" || !isLocale(value)) throw new Error("Unsupported locale.");
  return value;
}

export async function generatePersistedResultAction(
  _previous: GenerateResultActionState,
  formData: FormData,
): Promise<GenerateResultActionState> {
  const locale = readLocale(formData.get("locale"));
  const mutationId = formData.get("mutationId");
  if (typeof mutationId !== "string") return { state: "failed" };
  const execution = await generatePersistedResultWithExecution(locale, mutationId);
  const result = execution.result;
  if (result.state !== "ready") {
    if (result.state === "failed") {
      try {
        await reportControlledErrorOccurrence({
          surface: "result",
          operationCode: "result_generated",
          locale,
          category: "unexpected_domain",
          retryable: true,
          clientMutationId: mutationId,
        });
      } catch {}
    }
    return { state: "failed" };
  }
  if (execution.disposition === "applied") {
    await captureSuccessfulProductAction({
      surface: "result",
      operationCode: "result_generated",
      locale,
      clientMutationId: mutationId,
    });
  }
  revalidatePath(persistedAssessmentResultPath(locale));
  redirect(persistedAssessmentResultPath(locale));
}
