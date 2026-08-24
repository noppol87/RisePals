import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { ProfileConsent } from "@/components/profile-consent";
import type { ProfilePageState } from "@/modules/profile/dal";

vi.mock("@/app/[locale]/profile/actions", () => ({
  recordConsentAction: vi.fn(),
  recordMeasurementConsentAction: vi.fn(),
  saveProfileAction: vi.fn(),
}));
vi.mock("@/modules/identity/providers/clerk/client-boundary", () => ({
  ClerkLogoutControl: ({ label }: { label: string }) => <button>{label}</button>,
}));

function state(status: "not-set" | "granted" | "declined" | "withdrawn" | "stale") {
  return {
    state: "ready",
    profile: null,
    consent: { decision: "granted", noticeVersion: "alpha-privacy-v1" },
    measurementConsent: {
      status,
      noticeVersion: "alpha-measurement-monitoring-v1",
    },
  } satisfies ProfilePageState;
}

describe("optional profile measurement consent", () => {
  it.each([
    ["th", "การวัดผลการใช้งานและเฝ้าระวังข้อผิดพลาดแบบไม่บังคับ", "ยังไม่ได้เลือก"],
    ["en", "Optional measurement and error monitoring", "Not selected"],
  ] as const)("renders complete %s copy with no preselected choice", (locale, heading, status) => {
    const { container } = render(
      <ProfileConsent locale={locale} mode="profile" state={state("not-set")} />,
    );
    expect(screen.getByRole("heading", { name: heading })).toBeVisible();
    expect(screen.getByText(new RegExp(status))).toBeVisible();
    expect(
      screen.getByRole("button", {
        name: locale === "th" ? "ยินยอมแบบไม่บังคับ" : "Grant optional consent",
      }),
    ).toBeVisible();
    expect(
      screen.getByRole("button", { name: locale === "th" ? "ปฏิเสธ" : "Decline" }),
    ).toBeVisible();
    expect(container.querySelectorAll('input[type="radio"], input[type="checkbox"]')).toHaveLength(
      5,
    );
    const html = container.innerHTML;
    for (const prohibited of [
      "measurement_subject_id",
      "correlation_id",
      "mutation_digest",
      "consent_record_id",
    ]) {
      expect(html).not.toContain(prohibited);
    }
  });

  it("shows withdrawal only for a current grant and keeps profile controls available", () => {
    render(<ProfileConsent locale="en" mode="profile" state={state("granted")} />);
    expect(screen.getByRole("button", { name: "Withdraw" })).toBeVisible();
    expect(screen.queryByRole("button", { name: "Decline" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Save profile" })).toBeVisible();
  });
});
