import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { SourceVerificationLesson } from "@/components/source-verification-lesson";
import { LessonEvidenceVisual, sourceCaseVisual } from "@/components/lesson-evidence-visual";
import { sourceVerificationLessonDefinition } from "@/modules/lesson/publication/registry";
import { createSourceVerificationLessonView } from "@/modules/lesson/source-verification";

vi.mock("server-only", () => ({}));

function renderLesson(locale: "th" | "en" = "en") {
  const view = createSourceVerificationLessonView(locale, sourceVerificationLessonDefinition);
  return {
    view,
    ...render(
      <SourceVerificationLesson
        exampleResultHref={`/${locale}/assessment/example-result`}
        homeHref={`/${locale}`}
        view={view}
      />,
    ),
  };
}
function enterPractice(container: HTMLElement) {
  fireEvent.click(container.querySelectorAll(".guided-steps button")[2]!);
}
function chooseResponses(
  view: ReturnType<typeof createSourceVerificationLessonView>,
  meets: (index: number) => boolean,
) {
  for (const [index, criterion] of view.practice.criteria.entries()) {
    const group = screen.getByRole("group", { name: criterion.prompt });
    const option = criterion.options.find(
      (candidate) => candidate.meetsCriterion === meets(index),
    )!;
    fireEvent.click(within(group).getByRole("radio", { name: option.label }));
    if (index < 2) fireEvent.click(screen.getByRole("button", { name: "Next question" }));
  }
}

describe("guided source-verification lesson", () => {
  it.each(["th", "en"] as const)(
    "starts %s with one story and keeps complete method details available",
    (locale) => {
      const { container, view } = renderLesson(locale);
      expect(screen.getByRole("heading", { level: 1 })).toBeVisible();
      expect(
        screen.getByRole("button", {
          name: locale === "th" ? "เริ่มเช็กสรุปนี้" : "Check this summary",
        }),
      ).toBeVisible();
      expect(screen.queryByRole("radio")).not.toBeInTheDocument();
      expect(screen.getByText(view.scenario.aiSummary)).toBeVisible();
      const extras = container.querySelector(".guided-extras")!;
      for (const summary of extras.querySelectorAll("summary")) fireEvent.click(summary);
      expect(screen.getByText(view.lesson.versionId)).toBeVisible();
      expect(screen.getByText(view.rubric.demonstratedRule)).toBeVisible();
      expect(screen.getByText(view.proof.placeholderLabel)).toBeVisible();
      expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
      expect(container.querySelector('input[type="file"]')).toBeNull();
    },
  );
  it("shows only one question, focuses a missing-answer error and preserves answers on Back", async () => {
    const { container, view } = renderLesson();
    enterPractice(container);
    expect(screen.getAllByRole("radio")).toHaveLength(3);
    fireEvent.click(screen.getByRole("button", { name: "Next question" }));
    const error = await screen.findByRole("alert");
    await waitFor(() => expect(error).toHaveFocus());
    expect(error).toHaveTextContent("Choose an answer first.");
    fireEvent.click(screen.getAllByRole("radio")[1]!);
    fireEvent.click(screen.getByRole("button", { name: "Next question" }));
    expect(screen.getByRole("group", { name: view.practice.criteria[1]!.prompt })).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: /^Back$/ }));
    expect(screen.getAllByRole("radio")[1]).toBeChecked();
    expect(screen.queryByText("XP rule preview: 20 XP")).not.toBeInTheDocument();
  });
  it("gives criterion-level partial feedback without awarding preview XP", async () => {
    const { container, view } = renderLesson();
    enterPractice(container);
    chooseResponses(view, (index) => index !== 1);
    fireEvent.click(screen.getByRole("button", { name: "See how you did" }));
    const heading = await screen.findByRole("heading", { name: view.feedback.partialHeading });
    await waitFor(() => expect(heading).toHaveFocus());
    expect(screen.getAllByText(view.feedback.metLabel)).toHaveLength(2);
    expect(screen.getByText(view.feedback.notMetLabel)).toBeVisible();
    expect(screen.getByText("XP rule preview: 0 XP")).toBeVisible();
    expect(screen.getByText(view.feedback.unsavedXpBoundary)).toBeVisible();
    expect(screen.queryByRole("radio")).not.toBeInTheDocument();
  });
  it("requires all criteria, never accumulates XP, and clears all three answers on reset", async () => {
    const { container, view } = renderLesson();
    enterPractice(container);
    chooseResponses(view, () => true);
    fireEvent.click(screen.getByRole("button", { name: "See how you did" }));
    expect(
      await screen.findByRole("heading", { name: view.feedback.demonstratedHeading }),
    ).toBeVisible();
    expect(screen.getByText("XP rule preview: 20 XP")).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Try again" }));
    await waitFor(() =>
      expect(screen.getByRole("heading", { name: "What would you do?" })).toHaveFocus(),
    );
    expect(screen.queryByText("XP rule preview: 20 XP")).not.toBeInTheDocument();
    chooseResponses(view, () => true);
    fireEvent.click(screen.getByRole("button", { name: "See how you did" }));
    expect(await screen.findByText("XP rule preview: 20 XP")).toBeVisible();
    expect(screen.queryByText(/40 XP/)).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Clear answers" }));
    expect(
      [...container.querySelectorAll<HTMLInputElement>('input[type="radio"]')].every(
        (r) => !r.checked,
      ),
    ).toBe(true);
  });
});

describe("fictional case illustration", () => {
  it("matches the published source figures and renders missing data without a zero-valued bar", () => {
    const view = createSourceVerificationLessonView("en", sourceVerificationLessonDefinition);
    const records = view.scenario.sourceRecords.map((r) => r.detail).join(" ");
    for (const team of sourceCaseVisual.teams) {
      if (team.improvement !== null) {
        expect(records).toContain(`${team.improvement}%`);
        expect(records).toContain(String(team.cases));
      }
    }
    expect(records).toContain(String(sourceCaseVisual.days));
    expect(records).toContain(String(sourceCaseVisual.unresolved));
    const { container } = render(<LessonEvidenceVisual view={view} />);
    expect(screen.getByText("Unknown")).toBeVisible();
    expect(container.querySelector('[data-missing="true"] .team-chart__bar')).toBeNull();
    expect(screen.getByText("Missing data ≠ zero improvement")).toBeVisible();
  });
  it("does not reuse the v1 chart for an unknown version", () => {
    const original = createSourceVerificationLessonView("en", sourceVerificationLessonDefinition);
    const view = { ...original, lesson: { ...original.lesson } };
    Object.defineProperty(view.lesson, "version", { value: "2.0.0" });
    const { container } = render(<LessonEvidenceVisual view={view} />);
    expect(container.querySelector(".team-comparison")).toBeNull();
    fireEvent.click(screen.getByText("Read the fictional source records"));
    expect(screen.getByText(view.scenario.sourceRecords[0]!.detail)).toBeVisible();
  });
});
