import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { PersistedAssessmentAttempt } from "@/components/persisted-assessment-attempt";
import { createPersistedAssessmentView } from "@/modules/assessment/persistence/contract";
import { persistedAssessmentCopy } from "@/modules/assessment/persistence/copy";
import {
  savePersistedAssessmentResponseAction,
  submitPersistedAssessmentAction,
} from "@/app/[locale]/assessment/attempt/actions";

vi.mock("@/app/[locale]/assessment/attempt/actions", () => ({
  savePersistedAssessmentResponseAction: vi.fn(),
  submitPersistedAssessmentAction: vi.fn(),
}));

const saveAction = vi.mocked(savePersistedAssessmentResponseAction);
const submitAction = vi.mocked(submitPersistedAssessmentAction);

function renderAttempt() {
  const view = createPersistedAssessmentView("en");
  const result = render(
    <PersistedAssessmentAttempt
      copy={persistedAssessmentCopy.en}
      initialState={{
        state: "in-progress",
        view,
        selections: [],
        currentItemKey: view.items[0]!.key,
      }}
      locale="en"
    />,
  );
  return { ...result, view };
}

describe("persisted assessment attempt client boundary", () => {
  beforeEach(() => {
    saveAction.mockReset();
    submitAction.mockReset();
    saveAction.mockImplementation(async (input) => ({
      state: "saved",
      selection: {
        itemKey: input.itemKey,
        selectedOptionId: input.selectedOptionId,
        revision: input.expectedRevision + 1,
      },
    }));
    submitAction.mockResolvedValue({ state: "submitted", answeredCount: 6, totalItems: 6 });
  });

  it("saves six controlled option IDs, reviews them, and submits without browser identifiers", async () => {
    const { container, view } = renderAttempt();
    for (const [index, item] of view.items.entries()) {
      const group = await screen.findByRole("group", { name: item.prompt });
      fireEvent.click(within(group).getAllByRole("radio")[1]!);
      fireEvent.click(
        screen.getByRole("button", {
          name: index === 5 ? "Save and review" : "Save and continue",
        }),
      );
      if (index < 5) await screen.findByRole("heading", { name: `Scenario ${index + 2} of 6` });
    }

    await screen.findByRole("heading", { name: "Review before submission" });
    expect(saveAction).toHaveBeenCalledTimes(6);
    for (const call of saveAction.mock.calls) {
      expect(Object.keys(call[0]).sort()).toEqual([
        "clientMutationId",
        "expectedRevision",
        "itemKey",
        "locale",
        "selectedOptionId",
      ]);
      expect(call[0]).not.toHaveProperty("sessionId");
      expect(call[0]).not.toHaveProperty("userId");
    }
    expect(container.innerHTML).not.toMatch(/assessmentVersionId|sessionId|userId/);

    fireEvent.click(screen.getByRole("button", { name: "Submit and lock raw responses" }));
    await screen.findByRole("heading", { name: "The session is locked" });
    expect(submitAction).toHaveBeenCalledWith("en");
  });

  it("surfaces a stale-revision conflict and replaces the local display with the server value", async () => {
    const { view } = renderAttempt();
    const first = view.items[0]!;
    saveAction.mockResolvedValueOnce({
      state: "conflict",
      selection: {
        itemKey: first.key,
        selectedOptionId: first.options[2]!.id,
        revision: 2,
      },
    });
    const group = await screen.findByRole("group", { name: first.prompt });
    fireEvent.click(within(group).getAllByRole("radio")[0]!);
    fireEvent.click(screen.getByRole("button", { name: "Save and continue" }));

    await screen.findByText(/changed in another window/);
    await waitFor(() => expect(within(group).getAllByRole("radio")[2]).toBeChecked());
  });
});
