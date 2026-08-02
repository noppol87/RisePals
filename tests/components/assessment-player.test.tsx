import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { beforeEach, describe, expect, it } from "vitest";
import { AssessmentPlayer } from "@/components/assessment-player";
import { catalogs } from "@/lib/i18n/catalogs";
import {
  ASSESSMENT_PLAYER_STORAGE_KEY,
  ASSESSMENT_PLAYER_STORAGE_SCHEMA_VERSION,
} from "@/modules/assessment/player/storage";
import { createAssessmentPlayerView } from "@/modules/assessment/player/view";

function renderPlayer(locale: "th" | "en") {
  const view = createAssessmentPlayerView(locale);
  render(
    <AssessmentPlayer homeHref={`/${locale}`} messages={catalogs[locale].assessment} view={view} />,
  );
  return view;
}

async function startPlayer(locale: "th" | "en" = "en") {
  const view = renderPlayer(locale);
  const startButton = screen.getByRole("button", {
    name: catalogs[locale].assessment.startLabel,
  });
  await waitFor(() => expect(startButton).toBeEnabled());
  fireEvent.click(startButton);
  await screen.findByRole("group", { name: view.items[0]!.prompt });
  return view;
}

async function completePlayer(locale: "th" | "en" = "en") {
  const view = await startPlayer(locale);
  for (const [index, item] of view.items.entries()) {
    const group = await screen.findByRole("group", { name: item.prompt });
    fireEvent.click(within(group).getAllByRole("radio")[0]!);
    fireEvent.click(
      screen.getByRole("button", {
        name:
          index === view.items.length - 1
            ? catalogs[locale].assessment.finishLabel
            : catalogs[locale].assessment.continueLabel,
      }),
    );
  }
  await screen.findByRole("heading", { name: catalogs[locale].assessment.completionHeading });
  return view;
}

describe("assessment player", () => {
  beforeEach(() => {
    window.sessionStorage.clear();
  });

  it.each(["th", "en"] as const)("renders complete %s introductory boundaries", (locale) => {
    renderPlayer(locale);

    expect(
      screen.getByRole("heading", { name: catalogs[locale].assessment.heading }),
    ).toBeVisible();
    for (const boundary of catalogs[locale].assessment.boundaries) {
      expect(screen.getByText(boundary)).toBeVisible();
    }
    expect(screen.getByText(catalogs[locale].assessment.storageBody)).toBeVisible();
    expect(screen.queryByRole("radio")).not.toBeInTheDocument();
    expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
  });

  it("uses a native required fieldset, legend, and radio group", async () => {
    const view = await startPlayer("en");
    const group = screen.getByRole("group", { name: view.items[0]!.prompt });
    const radios = within(group).getAllByRole("radio");

    expect(group.tagName).toBe("FIELDSET");
    expect(group.querySelector("legend")).toHaveTextContent(view.items[0]!.prompt);
    expect(radios).toHaveLength(3);
    for (const radio of radios) {
      expect(radio).toHaveAttribute("required");
    }
  });

  it("announces and focuses an inline error when an answer is missing", async () => {
    await startPlayer("en");
    fireEvent.click(screen.getByRole("button", { name: "Continue" }));

    const error = await screen.findByRole("alert");
    expect(error).toHaveTextContent(catalogs.en.assessment.answerRequired);
    await waitFor(() => expect(error).toHaveFocus());
    expect(screen.getByRole("group")).toHaveAttribute("aria-invalid", "true");
  });

  it("keeps current position separate from answered count and announces transitions", async () => {
    const view = await startPlayer("en");
    expect(screen.getByText("Scenario 1 of 6")).toBeVisible();
    expect(screen.getByText("Answered 0 of 6 scenarios")).toBeVisible();

    fireEvent.click(screen.getAllByRole("radio")[0]!);
    expect(screen.getByText("Answered 1 of 6 scenarios")).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Continue" }));

    await screen.findByRole("group", { name: view.items[1]!.prompt });
    expect(screen.getByText("Scenario 2 of 6")).toBeVisible();
    expect(screen.getByText("Opened scenario 2 of 6")).toBeInTheDocument();
    await waitFor(() => expect(screen.getByRole("heading", { name: "Scenario 2" })).toHaveFocus());
  });

  it("preserves earlier selections when moving backward", async () => {
    const view = await startPlayer("en");
    const firstOption = screen.getAllByRole("radio")[1]!;
    fireEvent.click(firstOption);
    fireEvent.click(screen.getByRole("button", { name: "Continue" }));
    await screen.findByRole("group", { name: view.items[1]!.prompt });

    fireEvent.click(screen.getAllByRole("radio")[2]!);
    fireEvent.click(screen.getByRole("button", { name: "Back" }));
    await screen.findByRole("group", { name: view.items[0]!.prompt });

    expect(screen.getAllByRole("radio")[1]).toBeChecked();
    expect(screen.getByText("Answered 2 of 6 scenarios")).toBeVisible();
  });

  it("completes without rendering a score, proficiency, or recommendation", async () => {
    await completePlayer("en");

    expect(screen.getByText(catalogs.en.assessment.completionBoundary)).toBeVisible();
    expect(screen.getByRole("button", { name: "Review responses" })).toBeVisible();
    expect(screen.getByRole("button", { name: "Clear and start again" })).toBeVisible();
    expect(screen.getByRole("link", { name: "Return home" })).toHaveAttribute("href", "/en");
    expect(screen.queryByText(/your score|your proficiency|recommended next step/i)).toBeNull();
    expect(document.querySelector("output, [data-score], [data-result]")).toBeNull();
  });

  it("clears stored state and returns to the intro", async () => {
    await startPlayer("en");
    fireEvent.click(screen.getAllByRole("radio")[0]!);
    await waitFor(() =>
      expect(window.sessionStorage.getItem(ASSESSMENT_PLAYER_STORAGE_KEY)).not.toBeNull(),
    );

    fireEvent.click(
      screen.getByRole("button", {
        name: catalogs.en.assessment.clearLabel,
      }),
    );

    expect(screen.getByRole("heading", { name: catalogs.en.assessment.heading })).toBeVisible();
    await waitFor(() =>
      expect(window.sessionStorage.getItem(ASSESSMENT_PLAYER_STORAGE_KEY)).toBeNull(),
    );
    expect(screen.getByText(catalogs.en.assessment.storageCleared)).toBeVisible();
  });

  it("restores a valid same-session step and selections", async () => {
    const view = createAssessmentPlayerView("en");
    window.sessionStorage.setItem(
      ASSESSMENT_PLAYER_STORAGE_KEY,
      JSON.stringify({
        schemaVersion: ASSESSMENT_PLAYER_STORAGE_SCHEMA_VERSION,
        assessmentVersionId: view.assessmentVersionId,
        phase: "question",
        currentItemKey: view.items[0]!.key,
        selections: [{ itemKey: view.items[0]!.key, optionId: view.items[0]!.options[2]!.id }],
      }),
    );

    renderPlayer("en");
    await screen.findByRole("group", { name: view.items[0]!.prompt });
    expect(screen.getAllByRole("radio")[2]).toBeChecked();
    expect(screen.getByText(catalogs.en.assessment.storageRestored)).toBeVisible();
  });
});
