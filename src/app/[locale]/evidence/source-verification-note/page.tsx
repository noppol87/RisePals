import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";
import {
  PrivateEvidenceArtifact,
  StartEvidenceArtifact,
} from "@/components/private-evidence-artifact";
import { TextLink } from "@/components/primitives/text-link";
import {
  evidencePath,
  isLocale,
  onboardingPath,
  sourceVerificationEvidencePath,
} from "@/lib/i18n/config";
import { evidenceCopy } from "@/modules/evidence/copy";
import { loadEvidencePageState } from "@/modules/evidence/dal";
import { createEvidenceArtifactView } from "@/modules/evidence/view";

export const dynamic = "force-dynamic";

type ArtifactPageProps = Readonly<{ params: Promise<{ locale: string }> }>;

export async function generateMetadata({ params }: ArtifactPageProps): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = evidenceCopy[locale];
  return {
    title: copy.metadataTitle,
    description: copy.metadataDescription,
    robots: "noindex, noarchive",
    alternates: {
      languages: {
        th: sourceVerificationEvidencePath("th"),
        en: sourceVerificationEvidencePath("en"),
      },
    },
  };
}

export default async function SourceVerificationEvidencePage({ params }: ArtifactPageProps) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = evidenceCopy[locale];
  const state = await loadEvidencePageState(locale);
  if (state.state === "denied" && ["absent", "invalid", "expired"].includes(state.reason)) {
    redirect(`/${locale}/sign-in?returnTo=${sourceVerificationEvidencePath(locale)}`);
  }
  if (state.state === "consent-required") {
    return (
      <section className="assessment-storage-notice">
        <h1>{copy.consentHeading}</h1>
        <p>{copy.consentBody}</p>
        <TextLink href={onboardingPath(locale)} prefetch={false}>
          {copy.consentHeading}
        </TextLink>
      </section>
    );
  }
  if (state.state === "unavailable" || state.state === "denied") {
    return (
      <section className="assessment-storage-notice">
        <h1>{copy.unavailableHeading}</h1>
        <p>{copy.unavailableBody}</p>
      </section>
    );
  }
  return (
    <main className="lesson-page">
      <header className="lesson-hero">
        <p className="section-heading__eyebrow">{copy.eyebrow}</p>
        <h1>{copy.artifactHeading}</h1>
        <p>{copy.artifactIntroduction}</p>
        <p>
          <strong>{copy.privateLabel}</strong>
        </p>
        <p>{copy.prototypeLabel}</p>
        <p>{copy.syntheticBoundary}</p>
        <p>{copy.noSharing}</p>
      </header>
      {state.state === "not-started" ? <StartEvidenceArtifact copy={copy} locale={locale} /> : null}
      {state.state === "artifact" ? (
        <PrivateEvidenceArtifact
          copy={copy}
          initialArtifact={state.artifact}
          locale={locale}
          view={createEvidenceArtifactView(locale)}
        />
      ) : null}
      <TextLink href={evidencePath(locale)} prefetch={false}>
        {copy.backToEvidence}
      </TextLink>
    </main>
  );
}
