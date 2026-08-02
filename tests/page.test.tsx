import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import HomePage from "@/app/page";

describe("Rise Pals scaffold page", () => {
  it("identifies the application foundation with semantic content", () => {
    render(<HomePage />);

    expect(screen.getByRole("main")).toBeInTheDocument();
    expect(screen.getByRole("heading", { level: 1, name: "Rise Pals" })).toBeVisible();
    expect(screen.getByText(/โครงแอปพลิเคชันพร้อม/)).toBeVisible();
  });
});
