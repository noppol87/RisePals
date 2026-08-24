"use server";

import { revalidatePath } from "next/cache";
import { isLocale, persistedLessonAttemptPath, type Locale } from "@/lib/i18n/config";
import type { PersistedLessonMutationInput } from "@/modules/lesson/persistence/contract";
import { mutatePersistedLesson, startPersistedLesson } from "@/modules/lesson/persistence/dal";
import {
  captureSuccessfulProductAction,
  reportControlledErrorOccurrence,
} from "@/modules/measurement/server";

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
  const operationCode =
    input.intent === "save"
      ? ("lesson_practice_saved" as const)
      : input.intent === "evaluate"
        ? ("lesson_practice_evaluated" as const)
        : ("lesson_practice_retry_started" as const);
  let result: Awaited<ReturnType<typeof mutatePersistedLesson>>;
  try {
    result = await mutatePersistedLesson({ ...input, locale });
  } catch (error) {
    await reportControlledErrorOccurrence({
      surface: "lesson_practice",
      operationCode,
      locale,
      category: "unexpected_domain",
      retryable: true,
      clientMutationId: input.clientMutationId,
    });
    throw error;
  }
  if (
    result.state === "saved" ||
    result.state === "needs-retry" ||
    result.state === "demonstrated"
  ) {
    await captureSuccessfulProductAction({
      surface: "lesson_practice",
      operationCode,
      locale,
      clientMutationId: input.clientMutationId,
    });
  }
  revalidatePath(persistedLessonAttemptPath(locale));
  return result;
}
