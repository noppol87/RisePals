import type { Locale } from "@/lib/i18n/config";

export const localizedEvidenceFields = [
  "claim",
  "interpretation",
  "action",
  "geography",
  "context",
  "doesNotProve",
] as const;

export type EvidenceLocaleContent = Readonly<
  Record<(typeof localizedEvidenceFields)[number], string>
>;

export type EvidenceRecord = Readonly<{
  id: string;
  localized: Readonly<Record<Locale, EvidenceLocaleContent>>;
  source: Readonly<{
    title: string;
    url: string;
    publisher: string;
    publicationDate: string;
  }>;
  dateLastVerified: string;
  reviewDate: string;
}>;

export type PublishedEvidence = EvidenceRecord &
  Readonly<{
    content: EvidenceLocaleContent;
  }>;
