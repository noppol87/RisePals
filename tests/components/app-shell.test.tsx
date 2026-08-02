import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { AppShell } from "@/components/app-shell";
import { catalogs } from "@/lib/i18n/catalogs";

describe("localized application shell", () => {
  it("renders semantic Thai navigation, a skip target, and real locale links", () => {
    render(
      <AppShell locale="th" messages={catalogs.th.shell}>
        <h1>{catalogs.th.landing.hero.heading}</h1>
      </AppShell>,
    );

    expect(screen.getByRole("link", { name: catalogs.th.shell.skipToContent })).toHaveAttribute(
      "href",
      "#main-content",
    );
    expect(screen.getByRole("banner")).toBeInTheDocument();
    expect(screen.getByRole("main")).toHaveAttribute("id", "main-content");
    expect(screen.getByRole("main")).toHaveAttribute("tabindex", "-1");
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      catalogs.th.landing.hero.heading,
    );

    const primaryNavigation = screen.getByRole("navigation", {
      name: catalogs.th.shell.navigationLabel,
    });
    expect(within(primaryNavigation).getByRole("link", { name: "หน้าหลัก" })).toHaveAttribute(
      "aria-current",
      "page",
    );

    const languageNavigation = screen.getByRole("navigation", {
      name: catalogs.th.shell.languageSwitcherLabel,
    });
    expect(within(languageNavigation).getByRole("link", { name: "ไทย" })).toHaveAttribute(
      "aria-current",
      "page",
    );
    expect(within(languageNavigation).getByRole("link", { name: "English" })).toHaveAttribute(
      "href",
      "/en",
    );
    expect(screen.getByText(/ภาษาปัจจุบัน/)).toBeVisible();
  });

  it("renders the same shell contract with intentional English labels", () => {
    render(
      <AppShell locale="en" messages={catalogs.en.shell}>
        <h1>{catalogs.en.landing.hero.heading}</h1>
      </AppShell>,
    );

    expect(screen.getByRole("navigation", { name: "Primary navigation" })).toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Choose language" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: /Work is changing/ })).toBeVisible();
  });
});
