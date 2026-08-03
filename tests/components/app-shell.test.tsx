import { render, screen, within } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { AppShell } from "@/components/app-shell";
import { catalogs } from "@/lib/i18n/catalogs";

const navigation = vi.hoisted(() => ({ pathname: "/th" }));

vi.mock("next/navigation", () => ({
  usePathname: () => navigation.pathname,
}));

describe("localized application shell", () => {
  beforeEach(() => {
    navigation.pathname = "/th";
  });
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
    navigation.pathname = "/en";
    render(
      <AppShell locale="en" messages={catalogs.en.shell}>
        <h1>{catalogs.en.landing.hero.heading}</h1>
      </AppShell>,
    );

    expect(screen.getByRole("navigation", { name: "Primary navigation" })).toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Choose language" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: /Work is changing/ })).toBeVisible();
  });

  it("preserves the assessment route while switching locale", () => {
    navigation.pathname = "/th/assessment";
    render(
      <AppShell locale="th" messages={catalogs.th.shell}>
        <h1>{catalogs.th.assessment.heading}</h1>
      </AppShell>,
    );

    expect(screen.getByRole("link", { name: "English" })).toHaveAttribute("href", "/en/assessment");
    expect(screen.getByRole("link", { name: "หน้าหลัก" })).not.toHaveAttribute("aria-current");
  });

  it("preserves the synthetic example-result route while switching locale", () => {
    navigation.pathname = "/th/assessment/example-result";
    render(
      <AppShell locale="th" messages={catalogs.th.shell}>
        <h1>{catalogs.th.exampleResult.heading}</h1>
      </AppShell>,
    );

    expect(screen.getByRole("link", { name: "English" })).toHaveAttribute(
      "href",
      "/en/assessment/example-result",
    );
    expect(screen.getByRole("link", { name: "หน้าหลัก" })).not.toHaveAttribute("aria-current");
  });

  it("preserves the source-verification lesson route while switching locale", () => {
    navigation.pathname = "/th/lessons/source-verification-practice";
    render(
      <AppShell locale="th" messages={catalogs.th.shell}>
        <h1>ต้นแบบบทเรียนตรวจสอบแหล่งข้อมูล</h1>
      </AppShell>,
    );

    expect(screen.getByRole("link", { name: "English" })).toHaveAttribute(
      "href",
      "/en/lessons/source-verification-practice",
    );
    expect(screen.getByRole("link", { name: "หน้าหลัก" })).not.toHaveAttribute("aria-current");
  });
});
