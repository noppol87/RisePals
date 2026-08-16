"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { isLocale, persistedAssessmentResultPath, type Locale } from "@/lib/i18n/config";
import { generatePersistedResult } from "@/modules/assessment/persisted-result/dal";

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
  const result = await generatePersistedResult(locale, mutationId);
  if (result.state !== "ready") return { state: "failed" };
  revalidatePath(persistedAssessmentResultPath(locale));
  redirect(persistedAssessmentResultPath(locale));
}
