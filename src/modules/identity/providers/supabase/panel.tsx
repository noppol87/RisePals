"use client";
import Link from "next/link";
import { useActionState, useState } from "react";
import type { Locale } from "@/lib/i18n/config";
import { submitEmailCode, signOut, type EmailCodeState } from "./actions";

const copy = {
  th: {
    email: "อีเมลทดสอบ",
    send: "ส่งรหัสเข้าอีเมล",
    token: "รหัสยืนยันจากอีเมล",
    verify: "ยืนยันและเข้าสู่ระบบ",
    resend: "ส่งรหัสอีกครั้ง",
    sent: "หากอีเมลนี้ใช้กับระบบได้ คุณจะได้รับรหัสยืนยัน โปรดตรวจกล่องจดหมาย",
    error: "ยังดำเนินการไม่สำเร็จ ตรวจข้อมูลแล้วลองอีกครั้ง หรือขอรหัสใหม่",
    busy: "กำลังดำเนินการ…",
    signIn: "มีบัญชีแล้ว เข้าสู่ระบบ",
    signUp: "ยังไม่มีบัญชี สร้างบัญชี",
    logoutError: "ออกจากระบบไม่สำเร็จ โปรดลองอีกครั้ง",
  },
  en: {
    email: "Test email",
    send: "Send email code",
    token: "Email verification code",
    verify: "Verify and sign in",
    resend: "Send another code",
    sent: "If this email can be used here, a verification code will arrive in your inbox.",
    error:
      "We could not complete this step. Check your details and try again, or request a new code.",
    busy: "Working…",
    signIn: "Already have an account? Sign in",
    signUp: "Need an account? Sign up",
    logoutError: "Could not sign out. Please try again.",
  },
} as const;

export function EmailCodePanel({
  locale,
  returnPath,
  mode,
}: Readonly<{ locale: Locale; returnPath: string; mode: "sign-in" | "sign-up" }>) {
  const initial: EmailCodeState = { step: "email", status: "idle" };
  const [state, action, pending] = useActionState(
    submitEmailCode.bind(null, locale, mode, returnPath),
    initial,
  );
  const text = copy[locale];
  const [email, setEmail] = useState("");
  return (
    <div className="surface-card profile-panel">
      <form action={action} className="auth-code-form">
        <label htmlFor="auth-email">{text.email}</label>
        <input
          id="auth-email"
          name="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          type="email"
          autoComplete="email"
          maxLength={254}
          required
          readOnly={pending}
        />
        {state.step === "verify" && (
          <>
            <label htmlFor="auth-token">{text.token}</label>
            <input
              id="auth-token"
              name="token"
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              pattern="[0-9]{6,10}"
              minLength={6}
              maxLength={10}
              required
              readOnly={pending}
            />
          </>
        )}
        <p role={state.status === "error" ? "alert" : "status"} aria-live="polite">
          {state.status === "sent" ? text.sent : state.status === "error" ? text.error : ""}
        </p>
        <button
          className="player-button player-button--primary"
          name="intent"
          value={state.step === "verify" ? "verify" : "send"}
          disabled={pending}
        >
          {pending ? text.busy : state.step === "verify" ? text.verify : text.send}
        </button>
        {state.step === "verify" && (
          <button
            className="player-button player-button--quiet"
            name="intent"
            value="send"
            formNoValidate
            disabled={pending}
          >
            {text.resend}
          </button>
        )}
      </form>
      <Link
        href={`/${locale}/${mode === "sign-in" ? "sign-up" : "sign-in"}?returnTo=${encodeURIComponent(returnPath)}`}
      >
        {mode === "sign-in" ? text.signUp : text.signIn}
      </Link>
    </div>
  );
}

export function SupabaseSignInPanel(props: Readonly<{ locale: Locale; returnPath: string }>) {
  return <EmailCodePanel {...props} mode="sign-in" />;
}
export function SupabaseSignUpPanel(props: Readonly<{ locale: Locale; returnPath: string }>) {
  return <EmailCodePanel {...props} mode="sign-up" />;
}
export function SupabaseLogoutControl({
  label,
  locale,
}: Readonly<{ label: string; locale: Locale }>) {
  const [success, action, pending] = useActionState(signOut.bind(null, locale), true);
  return (
    <form action={action}>
      <button className="player-button player-button--quiet" disabled={pending}>
        {label}
      </button>
      {!success && <p role="alert">{copy[locale].logoutError}</p>}
    </form>
  );
}
