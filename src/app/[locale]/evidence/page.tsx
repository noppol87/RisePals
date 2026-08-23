import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";
import { StartEvidenceArtifact } from "@/components/private-evidence-artifact";
import { TextLink } from "@/components/primitives/text-link";
import {
  evidencePath,
  isLocale,
  onboardingPath,
  sourceVerificationEvidencePath,
} from "@/lib/i18n/config";
import { evidenceCopy } from "@/modules/evidence/copy";
import { loadEvidencePageState } from "@/modules/evidence/dal";

export const dynamic = "force-dynamic";

type EvidencePageProps = Readonly<{ params: Promise<{ locale: string }> }>;

export async function generateMetadata({ params }: EvidencePageProps): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = evidenceCopy[locale];
  return {
    title: copy.metadataTitle,
    description: copy.metadataDescription,
    robots: "noindex, noarchive",
    alternates: { languages: { th: evidencePath("th"), en: evidencePath("en") } },
  };
}

export default async function EvidencePage({ params }: EvidencePageProps) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = evidenceCopy[locale];
  const state = await loadEvidencePageState(locale);
  if (state.state === "denied" && ["absent", "invalid", "expired"].includes(state.reason)) {
    redirect(`/${locale}/sign-in?returnTo=${evidencePath(locale)}`);
  }
  return (
    <section className="persisted-result" aria-labelledby="evidence-index-heading">
      <p className="section-heading__eyebrow">{copy.eyebrow}</p>
      <h1 id="evidence-index-heading">{copy.indexHeading}</h1>
      <p>{copy.indexIntroduction}</p>
      <EvidenceBoundaries copy={copy} />
      {state.state === "consent-required" ? (
        <div className="assessment-storage-notice">
          <h2>{copy.consentHeading}</h2>
          <p>{copy.consentBody}</p>
          <TextLink href={onboardingPath(locale)} prefetch={false}>
            {copy.consentHeading}
          </TextLink>
        </div>
      ) : null}
      {state.state === "unavailable" || state.state === "denied" ? (
        <div className="assessment-storage-notice">
          <h2>{copy.unavailableHeading}</h2>
          <p>{copy.unavailableBody}</p>
        </div>
      ) : null}
      {state.state === "not-started" ? (
        <article className="persisted-result__card">
          <h2>{copy.artifactHeading}</h2>
          <p>{copy.notStarted}</p>
          <StartEvidenceArtifact copy={copy} locale={locale} />
        </article>
      ) : null}
      {state.state === "artifact" ? (
        <article className="persisted-result__card">
          <h2>{copy.artifactHeading}</h2>
          <p>{copy[state.artifact.status]}</p>
          <TextLink href={sourceVerificationEvidencePath(locale)} prefetch={false}>
            {copy.openArtifact}
          </TextLink>
        </article>
      ) : null}
    </section>
  );
}

function EvidenceBoundaries({ copy }: { copy: (typeof evidenceCopy)["th" | "en"] }) {
  return (
    <aside className="assessment-boundary" aria-labelledby="evidence-boundary-heading">
      <h2 id="evidence-boundary-heading">{copy.boundariesHeading}</h2>
      <p>
        <strong>{copy.privateLabel}</strong>
      </p>
      <p>{copy.prototypeLabel}</p>
      <p>{copy.syntheticBoundary}</p>
      <p>{copy.noSharing}</p>
      <ul>
        {copy.boundaries.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </aside>
  );
}
