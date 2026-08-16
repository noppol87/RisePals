import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { PersistedAssessmentResult } from "@/components/persisted-assessment-result";
import { persistedResultCopy } from "@/modules/assessment/persisted-result/copy";
import type { PersistedResultView } from "@/modules/assessment/persisted-result/dal";

const baseView = {
  coreScores: [
    {
      name: "Critical Thinking & Fact-Checking",
      earnedPoints: 1,
      availablePoints: 4,
      evidenceCount: 2,
      explanation: "A raw evidence signal.",
    },
    {
      name: "Systematic Thinking",
      earnedPoints: 3,
      availablePoints: 4,
      evidenceCount: 2,
      explanation: "A raw evidence signal.",
    },
  ],
  unassessedCoreNames: [
    "Adaptability",
    "Communication",
    "Collaboration",
    "Creativity",
    "Digital Fluency",
    "Self-Development",
  ],
  multiplierObservations: [
    { name: "Ownership Thinking", evidenceCount: 1, explanation: "One scenario only." },
    { name: "Sense of Urgency", evidenceCount: 1, explanation: "One scenario only." },
  ],
  limitations: ["Not a validated assessment.", "Not an employment decision."],
  priority: {
    state: "unique",
    competencyName: "Critical Thinking & Fact-Checking",
    explanation: "The uniquely lower raw-score ratio.",
    nextAction: "prototype-lesson",
  },
} as const satisfies PersistedResultView;

function renderResult(view: PersistedResultView = baseView) {
  return render(
    <PersistedAssessmentResult
      attemptHref="/en/assessment/attempt"
      copy={persistedResultCopy.en}
      homeHref="/en"
      lessonHref="/en/learn/source-verification"
      view={view}
    />,
  );
}

describe("persisted synthetic result", () => {
  it("renders two raw core signals, six explicit unassessed cores and separate multiplier observations", () => {
    const { container } = renderResult();

    expect(screen.getByText("1 of 4 evidence points")).toBeVisible();
    expect(screen.getByText("3 of 4 evidence points")).toBeVisible();
    expect(screen.getAllByText("Supported by 2 scenarios")).toHaveLength(2);
    for (const name of baseView.unassessedCoreNames) expect(screen.getByText(name)).toBeVisible();
    expect(screen.getAllByText("1 scenario of evidence")).toHaveLength(2);
    expect(container.innerHTML).not.toMatch(
      /sessionId|userId|providerUserId|inputDigest|outputDigest/,
    );
  });

  it("links only the exact Critical Thinking prototype-lesson action", () => {
    renderResult();
    expect(
      screen.getByRole("link", { name: "Open the source-verification prototype lesson" }),
    ).toHaveAttribute("href", "/en/learn/source-verification");
  });

  it("renders an unavailable practice without inventing a lesson link for Systematic Thinking", () => {
    renderResult({
      ...baseView,
      priority: {
        state: "unique",
        competencyName: "Systematic Thinking",
        explanation: "The uniquely lower raw-score ratio.",
        nextAction: "practice-unavailable",
      },
    });

    expect(screen.getByText(/matching Systematic Thinking practice is unavailable/)).toBeVisible();
    expect(
      screen.queryByRole("link", { name: /source-verification prototype lesson/i }),
    ).toBeNull();
  });

  it("shows no recommendation or lesson link when assessed-core ratios tie", () => {
    renderResult({
      ...baseView,
      priority: { state: "none", explanation: "The exact raw-score ratios are tied." },
    });

    expect(screen.getByRole("heading", { name: "No distinct priority" })).toBeVisible();
    expect(
      screen.queryByRole("link", { name: /source-verification prototype lesson/i }),
    ).toBeNull();
  });
});
