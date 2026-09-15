import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { PublicNarrative } from "@/components/public-narrative";
import { getPublishedEvidence } from "@/lib/evidence/records";
import { catalogs, coreCompetencies, multipliers, productLoopSteps } from "@/lib/i18n/catalogs";

describe("public narrative", () => {
  it("starts from the visitor's goal and explains an available first step without scoring", () => {
    render(
      <PublicNarrative
        evidence={getPublishedEvidence("th", "2026-08-02")}
        locale="th"
        messages={catalogs.th.landing}
      />,
    );

    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "อยากให้การทำงานดีขึ้นตรงไหน",
    );
    fireEvent.click(screen.getByRole("button", { name: /อยากรับมือวิธีทำงานใหม่/ }));
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "ช่วงนี้ เรื่องไหนกระทบคุณที่สุด",
    );
    fireEvent.click(screen.getByRole("button", { name: /ข้อมูลจาก AI เชื่อได้แค่ไหน/ }));
    expect(screen.getByRole("heading", { name: "คิดก่อนเชื่อและใช้ข้อมูลให้ชัวร์" })).toBeVisible();
    expect(screen.getByText(/ยังไม่บันทึกผล/)).toBeVisible();
    expect(screen.getByRole("link", { name: /เริ่มภารกิจแรก/ })).toHaveAttribute(
      "href",
      "/th/lessons/source-verification-practice",
    );
    expect(screen.queryByText(/คะแนน/)).toBeInTheDocument();
    expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
  });

  it("renders exactly two evidence items with visible qualifiers and direct sources", () => {
    render(
      <PublicNarrative
        evidence={getPublishedEvidence("en", "2026-08-02")}
        locale="en"
        messages={catalogs.en.landing}
      />,
    );

    expect(screen.getByText(/about one in four workers/)).not.toBeVisible();
    fireEvent.click(screen.getByText(catalogs.en.landing.evidence.heading));
    expect(screen.getAllByRole("article")).toHaveLength(2);
    expect(screen.getByText(/about one in four workers/)).toBeVisible();
    expect(screen.getByText(/39% of workers’ core skills/)).toBeVisible();
    expect(screen.getByText(/not a Thailand-specific figure/)).toBeVisible();
    expect(screen.getByText(/not a certainty or individual prediction/)).toBeVisible();

    const sourceLinks = screen.getAllByRole("link", {
      name: catalogs.en.landing.evidence.sourceLabel,
    });
    expect(sourceLinks).toHaveLength(2);
    expect(sourceLinks[0]).toHaveAttribute(
      "href",
      "https://www.ilo.org/publications/generative-ai-and-jobs-refined-global-index-occupational-exposure",
    );
    expect(sourceLinks[1]).toHaveAttribute(
      "href",
      "https://www.weforum.org/publications/the-future-of-jobs-report-2025/in-full/3-skills-outlook/",
    );
    expect(screen.getAllByText("2026-08-02")).toHaveLength(2);
    expect(screen.getAllByText("2027-02-02")).toHaveLength(2);
  });

  it("presents the complete loop and keeps eight core skills distinct from two multipliers", () => {
    render(
      <PublicNarrative
        evidence={getPublishedEvidence("en", "2026-08-02")}
        locale="en"
        messages={catalogs.en.landing}
      />,
    );

    const loop = screen.getByRole("list", { name: catalogs.en.landing.response.loopLabel });
    expect(within(loop).getAllByRole("listitem")).toHaveLength(productLoopSteps.length);
    for (const step of productLoopSteps) {
      expect(
        within(loop).getByRole("heading", { name: catalogs.en.landing.response.steps[step].name }),
      ).toBeVisible();
    }
    expect(screen.getByText(catalogs.en.landing.response.practiceNote)).toBeVisible();
    fireEvent.click(screen.getByText(catalogs.en.landing.framework.heading));

    expect(screen.getByRole("heading", { name: "8 core skills" })).toBeVisible();
    for (const competency of coreCompetencies) {
      expect(
        screen.getByRole("heading", {
          name: catalogs.en.landing.framework.core[competency].name,
        }),
      ).toBeVisible();
    }
    expect(screen.getByRole("heading", { name: "2 habits that help" })).toBeVisible();
    for (const multiplier of multipliers) {
      expect(
        screen.getByRole("heading", {
          name: catalogs.en.landing.framework.multiplierItems[multiplier].name,
        }),
      ).toBeVisible();
    }
    expect(screen.getByText(catalogs.en.landing.framework.multipliersIntroduction)).toBeVisible();
    expect(screen.getByText(catalogs.en.landing.framework.boundary)).toBeVisible();
  });
});
