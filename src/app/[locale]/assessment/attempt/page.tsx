import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";
import { PersistedAssessmentAttempt } from "@/components/persisted-assessment-attempt";
import { TextLink } from "@/components/primitives/text-link";
import {
  assessmentPath,
  isLocale,
  localePath,
  onboardingPath,
  persistedAssessmentPath,
} from "@/lib/i18n/config";
import { persistedAssessmentCopy } from "@/modules/assessment/persistence/copy";
import { loadPersistedAssessmentPageState } from "@/modules/assessment/persistence/dal";
import { startPersistedAssessmentAction } from "./actions";

export const dynamic = "force-dynamic";

type AttemptPageProps = Readonly<{ params: Promise<{ locale: string }> }>;

export async function generateMetadata({ params }: AttemptPageProps): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = persistedAssessmentCopy[locale];
  return {
    title: copy.metadataTitle,
    description: copy.metadataDescription,
    robots: "noindex, noarchive",
    alternates: {
      languages: { th: persistedAssessmentPath("th"), en: persistedAssessmentPath("en") },
    },
  };
}

export default async function PersistedAssessmentAttemptPage({ params }: AttemptPageProps) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = persistedAssessmentCopy[locale];
  const state = await loadPersistedAssessmentPageState(locale);

  if (
    state.state === "denied" &&
    (state.reason === "absent" || state.reason === "invalid" || state.reason === "expired")
  ) {
    redirect(`/${locale}/sign-in?returnTo=${persistedAssessmentPath(locale)}`);
  }

  return (
    <section className="assessment-player" aria-labelledby="persisted-assessment-heading">
      <p className="section-heading__eyebrow">{copy.eyebrow}</p>
      <h1 id="persisted-assessment-heading">{copy.heading}</h1>
      <p className="assessment-player__lead">{copy.introduction}</p>
      <div className="assessment-boundary" aria-labelledby="persisted-boundary-heading">
        <h2 id="persisted-boundary-heading">{copy.boundaryHeading}</h2>
        <ul>
          {copy.boundaries.map((boundary) => (
            <li key={boundary}>{boundary}</li>
          ))}
        </ul>
      </div>

      {state.state === "consent-required" ? (
        <div className="assessment-storage-notice">
          <h2>{copy.consentRequiredHeading}</h2>
          <p>{copy.consentRequiredBody}</p>
          <TextLink href={onboardingPath(locale)} prefetch={false}>
            {copy.consentLink}
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
        <div className="assessment-player__intro">
          <h2>{copy.startHeading}</h2>
          <p>{copy.startBody}</p>
          <form action={startPersistedAssessmentAction}>
            <input name="locale" type="hidden" value={locale} />
            <button className="player-button player-button--primary" type="submit">
              {copy.startLabel}
            </button>
          </form>
          <TextLink href={assessmentPath(locale)}>{copy.localPrototypeLink}</TextLink>
        </div>
      ) : null}

      {state.state === "in-progress" ? (
        <PersistedAssessmentAttempt copy={copy} initialState={state} locale={locale} />
      ) : null}

      {state.state === "submitted" ? (
        <div className="assessment-player__completion">
          <p className="section-heading__eyebrow">{copy.completionEyebrow}</p>
          <h2>{copy.completionHeading}</h2>
          <p>{copy.completionBody}</p>
          <p className="assessment-completion-boundary">{copy.completionBoundary}</p>
          <p>
            {copy.answeredTemplate
              .replace("{answered}", String(state.answeredCount))
              .replace("{total}", String(state.totalItems))}
          </p>
          <TextLink href={localePath(locale)}>{copy.homeLabel}</TextLink>
        </div>
      ) : null}
    </section>
  );
}
