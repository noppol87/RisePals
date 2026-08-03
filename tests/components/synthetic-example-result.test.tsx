import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { SyntheticExampleResult } from "@/components/synthetic-example-result";
import { catalogs } from "@/lib/i18n/catalogs";
import { createSyntheticExampleResultView } from "@/modules/assessment/result/view";

function renderExample(locale: "th" | "en") {
  const view = createSyntheticExampleResultView(locale);
  const messages = catalogs[locale].exampleResult;
  const { container } = render(
    <SyntheticExampleResult
      assessmentHref={`/${locale}/assessment`}
      homeHref={`/${locale}`}
      messages={messages}
      view={view}
    />,
  );
  return { container, messages, view };
}

describe("synthetic example result", () => {
  it.each(["th", "en"] as const)("renders the complete %s example-only boundary", (locale) => {
    const { messages, view } = renderExample(locale);

    expect(screen.getByRole("heading", { level: 1, name: messages.heading })).toBeVisible();
    expect(screen.getByText(messages.exampleOnlyLabel)).toBeVisible();
    expect(screen.getByText(messages.userChoicesBoundary)).toBeVisible();
    expect(screen.getAllByText(view.result.fixtureId)).toHaveLength(2);
    expect(screen.getByText(view.result.contractVersionId)).toBeVisible();
    expect(screen.getByRole("link", { name: messages.backToAssessmentLabel })).toHaveAttribute(
      "href",
      `/${locale}/assessment`,
    );
  });

  it("renders exact text-equivalent raw signals with code-native segments", () => {
    const { container, messages } = renderExample("en");
    const figures = screen.getAllByRole("figure");

    expect(figures).toHaveLength(2);
    expect(
      within(figures[0]!).getByText(
        "1 of 4 possible raw evidence points in this synthetic fixture",
      ),
    ).toBeVisible();
    expect(
      within(figures[1]!).getByText(
        "3 of 4 possible raw evidence points in this synthetic fixture",
      ),
    ).toBeVisible();
    expect(within(figures[0]!).getByText("Supported by 2 synthetic scenarios")).toBeVisible();
    expect(container.querySelectorAll(".example-signal__segment")).toHaveLength(8);
    expect(container.querySelectorAll(".example-signal__segment--filled")).toHaveLength(4);
    expect(screen.getAllByText(messages.supportingItemsLabel).length).toBeGreaterThanOrEqual(4);
    expect(container.querySelector("output, [data-score], [data-result]")).toBeNull();
  });

  it("shows all six unassessed cores and keeps both multipliers separate", () => {
    const { messages, view } = renderExample("en");
    const unassessedSection = screen
      .getByRole("heading", { name: messages.unassessedHeading })
      .closest("section")!;
    const multiplierSection = screen
      .getByRole("heading", { name: messages.multipliersHeading })
      .closest("section")!;

    expect(within(unassessedSection).getAllByRole("listitem")).toHaveLength(6);
    for (const competency of view.unassessedCoreCompetencies) {
      expect(within(unassessedSection).getByText(competency.name)).toBeVisible();
    }
    expect(within(multiplierSection).getAllByRole("article")).toHaveLength(2);
    expect(within(multiplierSection).getAllByText(messages.singleScenarioLabel)).toHaveLength(2);
    expect(within(multiplierSection).getByText("Ownership Thinking")).toBeVisible();
    expect(within(multiplierSection).getByText("Sense of Urgency")).toBeVisible();
  });

  it("renders one example practice with the exact planned and unavailable trace", () => {
    const { messages, view } = renderExample("en");
    const practice = screen
      .getByRole("heading", { name: messages.practiceHeading })
      .closest("section")!;

    expect(within(practice).getByText(messages.practiceBody)).toBeVisible();
    expect(within(practice).getByText(messages.practiceAction)).toBeVisible();
    expect(
      within(practice).getByText(
        `${view.exampleNextPractice.definitionId}@${view.exampleNextPractice.definitionVersion}`,
      ),
    ).toBeVisible();
    expect(
      within(practice).getByText(
        `${view.exampleNextPractice.scoringModelVersionId}@${view.exampleNextPractice.scoringModelVersion}`,
      ),
    ).toBeVisible();
    expect(
      within(practice).getByText(view.exampleNextPractice.plannedLesson.lessonVersionId),
    ).toBeVisible();
    expect(within(practice).getByText(messages.lessonUnavailableLabel)).toBeVisible();
  });

  it.each(["th", "en"] as const)("shows the complete accepted limitation set in %s", (locale) => {
    const { messages, view } = renderExample(locale);
    const limitations = screen
      .getByRole("heading", { name: messages.limitationsHeading })
      .closest("section")!;

    expect(view.limitations).toHaveLength(7);
    expect(within(limitations).getAllByRole("listitem")).toHaveLength(7);
    for (const limitation of view.limitations) {
      expect(within(limitations).getByText(limitation.body)).toBeVisible();
    }
  });
});
