import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { PersistedLessonPractice } from "@/components/persisted-lesson-practice";
import { persistedLessonCopy } from "@/modules/lesson/persistence/copy";
import type { ClientSafePracticeView } from "@/modules/lesson/persistence/contract";

const actions = vi.hoisted(() => ({
  mutate: vi.fn(),
  start: vi.fn(),
}));

vi.mock("@/app/[locale]/lessons/source-verification-practice/attempt/actions", () => ({
  mutatePersistedLessonAction: actions.mutate,
  startPersistedLessonAction: actions.start,
}));

const view: ClientSafePracticeView = {
  heading: "Persisted practice",
  introduction: "Synthetic practice",
  instruction: "Choose one option for each criterion.",
  criteria: [
    {
      id: "evidence-traceability",
      label: "Traceability",
      prompt: "Trace the claim?",
      options: [{ id: "trace-claim-to-source-map", label: "Map the claim" }],
    },
    {
      id: "claim-source-fit",
      label: "Fit",
      prompt: "Narrow the claim?",
      options: [{ id: "fit-narrow-to-supported-teams", label: "Narrow it" }],
    },
    {
      id: "safe-next-action",
      label: "Safety",
      prompt: "Choose a safe action?",
      options: [{ id: "safe-hold-and-resolve-gaps", label: "Hold publication" }],
    },
  ],
};

const initialState = {
  state: "in-progress" as const,
  view,
  revision: 0,
  selections: [],
  results: null,
};

describe("persisted lesson practice", () => {
  it("saves an ordered response snapshot and sends evaluation without evaluator fields", async () => {
    actions.mutate
      .mockResolvedValueOnce({
        state: "saved",
        revision: 1,
        selections: [
          { criterionId: "evidence-traceability", optionId: "trace-claim-to-source-map" },
          { criterionId: "claim-source-fit", optionId: "fit-narrow-to-supported-teams" },
          { criterionId: "safe-next-action", optionId: "safe-hold-and-resolve-gaps" },
        ],
        results: null,
      })
      .mockResolvedValueOnce({
        state: "demonstrated",
        revision: 2,
        selections: [
          { criterionId: "evidence-traceability", optionId: "trace-claim-to-source-map" },
          { criterionId: "claim-source-fit", optionId: "fit-narrow-to-supported-teams" },
          { criterionId: "safe-next-action", optionId: "safe-hold-and-resolve-gaps" },
        ],
        results: [
          {
            criterionId: "evidence-traceability",
            selectedOptionId: "trace-claim-to-source-map",
            status: "met",
          },
          {
            criterionId: "claim-source-fit",
            selectedOptionId: "fit-narrow-to-supported-teams",
            status: "met",
          },
          {
            criterionId: "safe-next-action",
            selectedOptionId: "safe-hold-and-resolve-gaps",
            status: "met",
          },
        ],
      });
    render(
      <PersistedLessonPractice
        copy={persistedLessonCopy.en}
        initialState={initialState}
        locale="en"
      />,
    );
    for (const criterion of view.criteria) {
      fireEvent.click(
        within(screen.getByRole("group", { name: new RegExp(criterion.prompt) })).getByRole(
          "radio",
        ),
      );
    }
    fireEvent.click(screen.getByRole("button", { name: persistedLessonCopy.en.saveLabel }));
    await waitFor(() => expect(actions.mutate).toHaveBeenCalledTimes(1));
    expect(actions.mutate.mock.calls[0]![0]).toMatchObject({
      intent: "save",
      locale: "en",
      expectedRevision: 0,
      selections: [
        { criterionId: "evidence-traceability", optionId: "trace-claim-to-source-map" },
        { criterionId: "claim-source-fit", optionId: "fit-narrow-to-supported-teams" },
        { criterionId: "safe-next-action", optionId: "safe-hold-and-resolve-gaps" },
      ],
    });
    const evaluateButton = screen.getByRole("button", {
      name: persistedLessonCopy.en.evaluateLabel,
    });
    await waitFor(() => expect(evaluateButton).toBeEnabled());
    fireEvent.click(evaluateButton);
    await waitFor(() => expect(actions.mutate).toHaveBeenCalledTimes(2));
    expect(actions.mutate.mock.calls[1]![0]).toMatchObject({
      intent: "evaluate",
      expectedRevision: 1,
    });
    expect(actions.mutate.mock.calls[1]![0]).toHaveProperty("selections", [
      { criterionId: "evidence-traceability", optionId: "trace-claim-to-source-map" },
      { criterionId: "claim-source-fit", optionId: "fit-narrow-to-supported-teams" },
      { criterionId: "safe-next-action", optionId: "safe-hold-and-resolve-gaps" },
    ]);
    expect(
      await screen.findByRole("heading", { name: persistedLessonCopy.en.demonstratedHeading }),
    ).toHaveFocus();
    expect(screen.getByText(persistedLessonCopy.en.noXp)).toBeVisible();
  });

  it("requires complete selections before requesting server evaluation", () => {
    actions.mutate.mockReset();
    render(
      <PersistedLessonPractice
        copy={persistedLessonCopy.en}
        initialState={initialState}
        locale="en"
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: persistedLessonCopy.en.evaluateLabel }));
    expect(screen.getByRole("status")).toHaveTextContent(persistedLessonCopy.en.incomplete);
    expect(actions.mutate).not.toHaveBeenCalled();
  });
});
