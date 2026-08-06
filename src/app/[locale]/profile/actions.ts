"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { isLocale, type Locale } from "@/lib/i18n/config";
import { isConsentDecision } from "@/modules/consent/notice";
import { appendConsentReceipt, saveProfile } from "@/modules/profile/dal";

function readLocale(formData: FormData): Locale {
  const locale = formData.get("preferredLocale");
  if (typeof locale !== "string" || !isLocale(locale)) {
    throw new Error("Unsupported locale.");
  }
  return locale;
}

function ensureAuthorized(result: Awaited<ReturnType<typeof appendConsentReceipt>>) {
  if (result.state !== "authorized") {
    throw new Error("The profile operation is not authorized.");
  }
}

export async function recordConsentAction(formData: FormData) {
  const locale = readLocale(formData);
  const decision = formData.get("decision");
  if (!isConsentDecision(decision)) {
    throw new Error("Unsupported consent decision.");
  }

  ensureAuthorized(await appendConsentReceipt(decision, locale));
  revalidatePath(`/${locale}/onboarding`);
  revalidatePath(`/${locale}/profile`);
  redirect(`/${locale}/onboarding`);
}

export async function saveProfileAction(formData: FormData) {
  const locale = readLocale(formData);
  const result = await saveProfile(formData);
  if (result.state !== "authorized") {
    throw new Error("The profile operation is not authorized.");
  }

  revalidatePath(`/${locale}/onboarding`);
  revalidatePath(`/${locale}/profile`);
  redirect(`/${locale}/profile`);
}
