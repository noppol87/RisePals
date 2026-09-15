"use server";
import { redirect } from "next/navigation";
import { isLocale } from "@/lib/i18n/config";
import { safeLocaleReturnPath } from "../../redirects";
import { createSupabaseServerClient } from "./client";

export type EmailCodeState = Readonly<{
  step: "email" | "verify";
  status: "idle" | "sent" | "error";
}>;
export async function submitEmailCode(
  locale: string,
  mode: string,
  returnPath: string,
  _previous: EmailCodeState,
  form: FormData,
): Promise<EmailCodeState> {
  if (!isLocale(locale) || (mode !== "sign-in" && mode !== "sign-up"))
    return { step: "email", status: "error" };
  const intent = form.get("intent");
  const email = form.get("email");
  const token = form.get("token");
  const step = intent === "verify" ? "verify" : "email";
  if (
    typeof email !== "string" ||
    email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
    (intent !== "send" && intent !== "verify") ||
    (intent === "verify" && (typeof token !== "string" || !/^\d{6,10}$/.test(token)))
  ) {
    return { step, status: "error" };
  }
  try {
    const client = await createSupabaseServerClient(true);
    if (!client) return { step, status: "error" };
    if (intent === "send") {
      await client.auth.signInWithOtp({ email, options: { shouldCreateUser: mode === "sign-up" } });
      // A uniform result avoids disclosing whether the email has an account.
      return { step: "verify", status: "sent" };
    }
    const { data, error } = await client.auth.verifyOtp({
      email,
      token: token as string,
      type: "email",
    });
    if (
      error ||
      !data.user ||
      !data.session ||
      data.user.is_anonymous ||
      !data.user.email_confirmed_at
    ) {
      return { step: "verify", status: "error" };
    }
  } catch {
    return { step, status: "error" };
  }
  redirect(safeLocaleReturnPath(returnPath, locale));
}

export async function signOut(locale: string, _previous: boolean): Promise<boolean> {
  void _previous;
  if (!isLocale(locale)) return false;
  try {
    const client = await createSupabaseServerClient(true);
    if (!client) return false;
    const { error } = await client.auth.signOut({ scope: "local" });
    if (error) return false;
  } catch {
    return false;
  }
  redirect(`/${locale}`);
}
