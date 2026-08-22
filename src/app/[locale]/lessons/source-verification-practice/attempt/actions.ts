"use server";

import { revalidatePath } from "next/cache";
import { isLocale, persistedLessonAttemptPath, type Locale } from "@/lib/i18n/config";
import type { PersistedLessonMutationInput } from "@/modules/lesson/persistence/contract";
import { mutatePersistedLesson, startPersistedLesson } from "@/modules/lesson/persistence/dal";

function readLocale(value: unknown): Locale {
  if (typeof value !== "string" || !isLocale(value)) throw new Error("Unsupported locale.");
  return value;
}

export async function startPersistedLessonAction(localeValue: string, mutationId: string) {
  const locale = readLocale(localeValue);
  const result = await startPersistedLesson(locale, mutationId);
  revalidatePath(persistedLessonAttemptPath(locale));
  return result;
}

export async function mutatePersistedLessonAction(input: PersistedLessonMutationInput) {
  const locale = readLocale(input.locale);
  const result = await mutatePersistedLesson({ ...input, locale });
  revalidatePath(persistedLessonAttemptPath(locale));
  return result;
}
