import { act, fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
const actions = vi.hoisted(() => ({ submitEmailCode: vi.fn(), signOut: vi.fn() }));
vi.mock("@/modules/identity/providers/supabase/actions", () => actions);
import { EmailCodePanel } from "@/modules/identity/providers/supabase/panel";

beforeEach(() => {
  vi.resetAllMocks();
});
describe("localized email-code form", () => {
  it.each(["th", "en"] as const)("keeps the email while moving to OTP in %s", async (locale) => {
    actions.submitEmailCode.mockResolvedValue({ step: "verify", status: "sent" });
    render(<EmailCodePanel locale={locale} mode="sign-in" returnPath={`/${locale}/profile`} />);
    const email = screen.getByLabelText(locale === "th" ? "อีเมลทดสอบ" : "Test email");
    fireEvent.change(email, { target: { value: "synthetic@example.invalid" } });
    await act(async () => {
      fireEvent.click(
        screen.getByRole("button", {
          name: locale === "th" ? "ส่งรหัสเข้าอีเมล" : "Send email code",
        }),
      );
    });
    expect(email).toHaveValue("synthetic@example.invalid");
    expect(
      screen.getByLabelText(locale === "th" ? "รหัสยืนยันจากอีเมล" : "Email verification code"),
    ).toHaveAttribute("autocomplete", "one-time-code");
    expect(screen.getByRole("status")).not.toBeEmptyDOMElement();
    expect(screen.getByRole("link")).toHaveAttribute(
      "href",
      `/${locale}/sign-up?returnTo=${encodeURIComponent(`/${locale}/profile`)}`,
    );
  });
  it("announces verification failure and allows another code", async () => {
    actions.submitEmailCode.mockResolvedValue({ step: "verify", status: "error" });
    render(<EmailCodePanel locale="en" mode="sign-up" returnPath="/en/onboarding" />);
    fireEvent.change(screen.getByLabelText("Test email"), {
      target: { value: "synthetic@example.invalid" },
    });
    await act(async () => {
      fireEvent.click(screen.getByRole("button", { name: "Send email code" }));
    });
    expect(screen.getByRole("alert")).toHaveTextContent("could not complete");
    expect(screen.getByRole("button", { name: "Send another code" })).toHaveAttribute(
      "formnovalidate",
    );
  });
});
