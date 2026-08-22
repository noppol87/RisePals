import { randomUUID } from "node:crypto";
import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";
import { GeneratePersistedResultForm } from "@/components/generate-persisted-result-form";
import { PersistedAssessmentResult } from "@/components/persisted-assessment-result";
import { TextLink } from "@/components/primitives/text-link";
import {
  isLocale,
  localePath,
  onboardingPath,
  persistedAssessmentPath,
  persistedAssessmentResultPath,
  persistedLessonAttemptPath,
} from "@/lib/i18n/config";
import { persistedResultCopy } from "@/modules/assessment/persisted-result/copy";
import { loadPersistedResultPageState } from "@/modules/assessment/persisted-result/dal";

export const dynamic = "force-dynamic";

type ResultPageProps = Readonly<{ params: Promise<{ locale: string }> }>;

export async function generateMetadata({ params }: ResultPageProps): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = persistedResultCopy[locale];
  return {
    title: copy.metadataTitle,
    description: copy.metadataDescription,
    robots: "noindex, noarchive",
    alternates: {
      languages: {
        th: persistedAssessmentResultPath("th"),
        en: persistedAssessmentResultPath("en"),
      },
    },
  };
}

export default async function PersistedAssessmentResultPage({ params }: ResultPageProps) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = persistedResultCopy[locale];
  const state = await loadPersistedResultPageState(locale);

  if (
    state.state === "denied" &&
    (state.reason === "absent" || state.reason === "invalid" || state.reason === "expired")
  ) {
    redirect(`/${locale}/sign-in?returnTo=${persistedAssessmentResultPath(locale)}`);
  }

  if (state.state === "ready") {
    return (
      <PersistedAssessmentResult
        attemptHref={persistedAssessmentPath(locale)}
        copy={copy}
        homeHref={localePath(locale)}
        lessonHref={persistedLessonAttemptPath(locale)}
        view={state.view}
      />
    );
  }

  return (
    <section className="persisted-result" aria-labelledby="persisted-result-heading">
      <p className="section-heading__eyebrow">{copy.eyebrow}</p>
      <h1 id="persisted-result-heading">{copy.heading}</h1>
      <p>{copy.introduction}</p>
      <div className="assessment-boundary">
        <h2>{copy.boundaryHeading}</h2>
        <ul>
          {copy.boundaries.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      </div>
      {state.state === "consent-required" ? (
        <div className="assessment-storage-notice">
          <h2>{copy.consentRequiredHeading}</h2>
          <p>{copy.consentRequiredBody}</p>
          <TextLink href={onboardingPath(locale)} prefetch={false}>
            {copy.attemptLabel}
          </TextLink>
        </div>
      ) : null}
      {state.state === "unavailable" || state.state === "denied" ? (
        <div className="assessment-storage-notice">
          <h2>{copy.unavailableHeading}</h2>
          <p>{copy.unavailableBody}</p>
          <TextLink href={persistedAssessmentPath(locale)}>{copy.attemptLabel}</TextLink>
        </div>
      ) : null}
      {state.state === "not-generated" ? (
        <div className="assessment-storage-notice">
          <h2>{copy.notGeneratedHeading}</h2>
          <p>{copy.notGeneratedBody}</p>
          <GeneratePersistedResultForm copy={copy} locale={locale} mutationId={randomUUID()} />
        </div>
      ) : null}
    </section>
  );
}
