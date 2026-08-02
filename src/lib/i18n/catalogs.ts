import type { Locale } from "@/lib/i18n/config";

export type ShellCatalog = Readonly<{
  brandName: string;
  skipToContent: string;
  navigationLabel: string;
  homeLabel: string;
  languageSwitcherLabel: string;
  currentLanguageLabel: string;
  languageNames: Readonly<Record<Locale, string>>;
}>;

export type AppCatalog = Readonly<{
  shell: ShellCatalog;
  foundation: Readonly<{
    eyebrow: string;
    heading: string;
    description: string;
  }>;
}>;

export const catalogs = {
  th: {
    shell: {
      brandName: "Rise Pals",
      skipToContent: "ข้ามไปยังเนื้อหาหลัก",
      navigationLabel: "การนำทางหลัก",
      homeLabel: "หน้าหลัก",
      languageSwitcherLabel: "เลือกภาษา",
      currentLanguageLabel: "ภาษาปัจจุบัน",
      languageNames: {
        th: "ไทย",
        en: "English",
      },
    },
    foundation: {
      eyebrow: "โครงสร้างแอป",
      heading: "พื้นฐานประสบการณ์ Rise Pals",
      description:
        "หน้านี้ใช้ตรวจสอบโครงสร้าง ภาษา การเข้าถึง และการจัดวางที่รองรับหน้าจอหลายขนาด ก่อนเริ่มสร้างประสบการณ์ผลิตภัณฑ์จริง",
    },
  },
  en: {
    shell: {
      brandName: "Rise Pals",
      skipToContent: "Skip to main content",
      navigationLabel: "Primary navigation",
      homeLabel: "Home",
      languageSwitcherLabel: "Choose language",
      currentLanguageLabel: "Current language",
      languageNames: {
        th: "ไทย",
        en: "English",
      },
    },
    foundation: {
      eyebrow: "Application structure",
      heading: "Rise Pals experience foundation",
      description:
        "This page verifies structure, language, accessibility, and responsive layout before product experiences are introduced.",
    },
  },
} as const satisfies Record<Locale, AppCatalog>;
