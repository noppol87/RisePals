import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { SourceVerificationLesson } from "@/components/source-verification-lesson";
import { sourceVerificationLessonDefinition } from "@/modules/lesson/publication/registry";
import { createSourceVerificationLessonView } from "@/modules/lesson/source-verification";

vi.mock("server-only", () => ({}));

function renderLesson(locale: "th" | "en" = "en") {
  const view = createSourceVerificationLessonView(locale, sourceVerificationLessonDefinition);
  const rendered = render(
    <SourceVerificationLesson
      exampleResultHref={`/${locale}/assessment/example-result`}
      homeHref={`/${locale}`}
      view={view}
    />,
  );
  for (const summary of rendered.container.querySelectorAll("details > summary"))
    fireEvent.click(summary);
  return { view, ...rendered };
}

function chooseResponses(
  view: ReturnType<typeof createSourceVerificationLessonView>,
  meetsCriterion: (index: number) => boolean,
) {
  for (const [index, criterion] of view.practice.criteria.entries()) {
    const group = screen.getByRole("group", { name: new RegExp(criterion.prompt) });
    const option = criterion.options.find(
      (candidate) => candidate.meetsCriterion === meetsCriterion(index),
    )!;
    fireEvent.click(within(group).getByRole("radio", { name: option.label }));
  }
}

describe("source-verification lesson prototype", () => {
  it.each(["th", "en"] as const)(
    "renders the complete %s lesson, transparent rubric, and non-collecting proof boundary",
    (locale) => {
      const { container, view } = renderLesson(locale);

      expect(
        screen.getByRole("heading", {
          level: 1,
          name: locale === "th" ? "AI บอกแบบนี้ เชื่อได้ไหม?" : "The AI said it. Is it true?",
        }),
      ).toBeVisible();
      expect(screen.getByText("lesson-source-verification-practice-v1")).toBeVisible();
      expect(screen.getByText("published", { exact: true })).toBeVisible();
      expect(screen.getByText("prototype-unvalidated", { exact: true })).toBeVisible();
      expect(screen.getByText(locale === "th" ? "ลองใช้จริง" : "Practising")).toBeVisible();
      expect(
        screen.getByText(
          locale === "th" ? "รู้ทันความเสี่ยงและรับผิดชอบ" : "Risk and responsibility",
        ),
      ).toBeVisible();
      expect(screen.getAllByRole("radio")).toHaveLength(9);
      expect(container.querySelectorAll("fieldset")).toHaveLength(3);
      expect(screen.getByText(view.rubric.demonstratedRule)).toBeVisible();
      expect(screen.getByText(view.proof.placeholderLabel)).toBeVisible();
      expect(
        screen.getByText(
          locale === "th"
            ? "ยังพิมพ์ข้อความ อัปโหลด หรือบันทึกไฟล์ไม่ได้"
            : "No text entry, uploads or saved files.",
        ),
      ).toBeVisible();
      expect(
        screen.getByText(
          locale === "th"
            ? "คิดหรือจดไว้เองได้เลย หน้านี้ไม่เก็บคำตอบ"
            : "Keep your thoughts to yourself. Nothing is collected here.",
        ),
      ).toBeVisible();
      expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
      expect(container.querySelector('input[type="file"]')).toBeNull();
      expect(screen.queryByText(view.feedback.demonstratedHeading)).not.toBeInTheDocument();
      expect(screen.queryByText(/(?:XP rule preview|ตัวอย่างกติกา XP):/)).not.toBeInTheDocument();
      expect(
        screen.getByRole("link", {
          name: locale === "th" ? "กลับไปดูตัวอย่าง" : "Back to the example",
        }),
      ).toHaveAttribute("href", `/${locale}/assessment/example-result`);
    },
  );

  it("focuses an inline error and keeps passive or incomplete viewing at zero XP", async () => {
    const { view } = renderLesson("en");
    fireEvent.click(screen.getByRole("button", { name: "See how you did" }));

    const error = await screen.findByRole("alert");
    expect(error).toHaveTextContent(view.feedback.incompleteError);
    await waitFor(() => expect(error).toHaveFocus());
    expect(screen.queryByText("XP rule preview: 20 XP")).not.toBeInTheDocument();
    expect(screen.queryByText("XP rule preview: 0 XP")).not.toBeInTheDocument();
  });

  it("shows criterion-level partial feedback and zero preview XP", async () => {
    const { view } = renderLesson("en");
    chooseResponses(view, (index) => index !== 1);
    fireEvent.click(screen.getByRole("button", { name: "See how you did" }));

    const heading = await screen.findByRole("heading", { name: view.feedback.partialHeading });
    await waitFor(() => expect(heading).toHaveFocus());
    expect(screen.getAllByText(view.feedback.metLabel)).toHaveLength(2);
    expect(screen.getByText(view.feedback.notMetLabel)).toBeVisible();
    expect(screen.getByText("XP rule preview: 0 XP")).toBeVisible();
    expect(screen.getByText(view.feedback.unsavedXpBoundary)).toBeVisible();
  });

  it("requires all three criteria for demonstrated practice and replaces rather than accumulates XP", async () => {
    const { view } = renderLesson("en");
    chooseResponses(view, () => true);
    fireEvent.click(screen.getByRole("button", { name: "See how you did" }));

    expect(
      await screen.findByRole("heading", { name: view.feedback.demonstratedHeading }),
    ).toBeVisible();
    expect(screen.getAllByText(view.feedback.metLabel)).toHaveLength(3);
    expect(screen.getByText("XP rule preview: 20 XP")).toBeVisible();

    fireEvent.click(screen.getByRole("button", { name: "Try again" }));
    await waitFor(() =>
      expect(screen.getByRole("heading", { name: "What would you do?" })).toHaveFocus(),
    );
    expect(screen.queryByText("XP rule preview: 20 XP")).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "See how you did" }));
    expect(await screen.findByText("XP rule preview: 20 XP")).toBeVisible();
    expect(screen.queryByText(/40 XP/)).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Clear answers" }));
    await waitFor(() =>
      expect(screen.getByRole("heading", { name: "What would you do?" })).toHaveFocus(),
    );
    expect(
      screen.getAllByRole("radio").every((radio) => !(radio as HTMLInputElement).checked),
    ).toBe(true);
    expect(screen.queryByText("XP rule preview: 20 XP")).not.toBeInTheDocument();
  });
});
