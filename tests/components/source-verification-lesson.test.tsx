import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { SourceVerificationLesson } from "@/components/source-verification-lesson";
import { sourceVerificationLessonDefinition } from "@/modules/lesson/publication/registry";
import { createSourceVerificationLessonView } from "@/modules/lesson/source-verification";
import {
  evaluateMission,
  sourceVerificationMission,
} from "@/modules/lesson/source-verification/mission-v2";

vi.mock("server-only", () => ({}));
const cases = sourceVerificationMission.cases;
function renderLesson(locale: "th" | "en" = "en") {
  return render(
    <SourceVerificationLesson
      homeHref={`/${locale}`}
      exampleResultHref={`/${locale}/assessment/example-result`}
      view={createSourceVerificationLessonView(locale, sourceVerificationLessonDefinition)}
    />,
  );
}
function begin() {
  fireEvent.click(screen.getByRole("button", { name: /Find what needs checking|Try it yourself/ }));
}
function finishCoached() {
  begin();
  for (const [i, question] of cases[0]!.questions.entries()) {
    fireEvent.click(
      screen.getByRole("radio", { name: question.options.find((o) => o.correct)!.label.en }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Check this answer" }));
    fireEvent.click(screen.getByRole("button", { name: i === 3 ? "See my summary" : "Continue" }));
  }
}
describe("versioned visual mission", () => {
  it.each(["th", "en"] as const)(
    "offers one clear %s start and keeps prototype boundaries visible",
    (locale) => {
      renderLesson(locale);
      expect(
        screen.getByRole("button", {
          name: locale === "th" ? "ลองหาจุดที่ต้องเช็ก" : "Find what needs checking",
        }),
      ).toBeVisible();
      expect(
        screen.getByRole("heading", {
          name:
            locale === "th"
              ? "AI ทำร่างแรกให้แล้ว ก่อนส่งต่อ คุณจะเช็กอะไร?"
              : "AI made the first draft. What would you check before passing it on?",
        }),
      ).toBeVisible();
      expect(
        screen.getByText(
          locale === "th" ? "ทุกทีมจึงเร็วขึ้น 30%" : "So every team was 30% faster.",
        ),
      ).toBeVisible();
      expect(screen.queryByRole("radio")).not.toBeInTheDocument();
      expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
      fireEvent.click(
        screen.getByText(locale === "th" ? "เกี่ยวกับแบบฝึกนี้" : "About this practice"),
      );
      expect(screen.getByText(/2.1.0/)).toBeVisible();
    },
  );
  it("focuses missing-answer errors, gives specific coaching, and keeps a wrong answer on the same step", async () => {
    renderLesson();
    begin();
    fireEvent.click(screen.getByRole("button", { name: "Check this answer" }));
    await waitFor(() => expect(screen.getByRole("alert")).toHaveFocus());
    fireEvent.click(screen.getAllByRole("radio")[0]!);
    expect(screen.queryByRole("status")).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Check this answer" }));
    expect(screen.getByRole("status")).toHaveTextContent(
      cases[0]!.questions[0]!.options[0]!.reason.en,
    );
    expect(screen.queryByRole("button", { name: "Continue" })).not.toBeInTheDocument();
    fireEvent.click(screen.getAllByRole("radio")[2]!);
    expect(screen.queryByRole("status")).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Check this answer" }));
    fireEvent.click(screen.getByRole("button", { name: "Continue" }));
    fireEvent.click(screen.getByRole("button", { name: /^Back$/ }));
    expect(screen.getAllByRole("radio")[2]).toBeChecked();
  });
  it("builds a before/after artifact, labels coaching honestly, and starts a clean independent case", () => {
    renderLesson();
    finishCoached();
    expect(
      screen.getByRole("heading", {
        name: "This summary is safer to use in a decision",
      }),
    ).toBeVisible();
    expect(screen.getByText(/decided what comes next/)).toBeVisible();
    expect(screen.getByText(/Team C’s result is still unknown/)).toBeVisible();
    expect(screen.queryByText(/XP/)).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Use this in another situation" }));
    begin();
    expect(screen.getAllByRole("radio").every((r) => !(r as HTMLInputElement).checked)).toBe(true);
    for (const [i] of cases[1]!.questions.entries()) {
      fireEvent.click(screen.getAllByRole("radio")[0]!);
      expect(screen.queryByRole("status")).not.toBeInTheDocument();
      fireEvent.click(
        screen.getByRole("button", { name: i === 3 ? "See my summary" : "Continue" }),
      );
    }
    expect(screen.getByRole("heading", { name: "A few things need another look" })).toBeVisible();
    expect(
      screen.queryByRole("heading", {
        name: "This summary is safer to use in a decision",
      }),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Try this case again" }));
    begin();
    expect(screen.getAllByRole("radio").every((r) => !(r as HTMLInputElement).checked)).toBe(true);
  });
});
describe("mission evaluation integrity", () => {
  it.each(cases)(
    "rejects missing/unknown responses and same-position guessing in $id",
    (mission) => {
      expect(evaluateMission(mission, {}).complete).toBe(false);
      expect(evaluateMission(mission, { claim: "not-an-option" }).complete).toBe(false);
      for (let i = 0; i < 3; i++) {
        const answers = Object.fromEntries(mission.questions.map((q) => [q.id, q.options[i]!.id]));
        expect(evaluateMission(mission, answers).complete).toBe(true);
        expect(evaluateMission(mission, answers).allCorrect).toBe(false);
      }
      const correct = Object.fromEntries(
        mission.questions.map((q) => [q.id, q.options.find((o) => o.correct)!.id]),
      );
      expect(evaluateMission(mission, correct).allCorrect).toBe(true);
      for (const q of mission.questions) {
        expect(q.options.filter((o) => o.correct)).toHaveLength(1);
        for (const o of q.options) {
          expect(o.label.th.length).toBeGreaterThan(0);
          expect(o.label.en.length).toBeGreaterThan(0);
          expect(o.reason.th.length).toBeGreaterThan(0);
          expect(o.reason.en.length).toBeGreaterThan(0);
        }
      }
    },
  );
  it("keeps legacy published identity and its source figures intact", () => {
    expect(sourceVerificationLessonDefinition.lesson.version).toBe("1.0.0");
    expect(sourceVerificationMission.sourceIdentity).toBe("source-verification-practice@1.0.0");
    expect(cases[0]!.facts.map((f) => f.amount)).toEqual([30, 8, null]);
    expect(cases[1]!.facts.map((f) => f.amount)).toEqual([12, 8, 80]);
    const source = createSourceVerificationLessonView("en", sourceVerificationLessonDefinition)
      .scenario.sourceRecords.map((r) => r.detail)
      .join(" ");
    for (const number of ["30%", "8%", "12", "40", "60", "2"]) expect(source).toContain(number);
  });
});
