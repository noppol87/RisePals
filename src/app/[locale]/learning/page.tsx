import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";
import { TextLink } from "@/components/primitives/text-link";
import {
  evidencePath,
  isLocale,
  learningPath,
  onboardingPath,
  persistedLessonAttemptPath,
} from "@/lib/i18n/config";
import { evidenceCopy } from "@/modules/evidence/copy";
import { persistedLessonCopy } from "@/modules/lesson/persistence/copy";
import { loadPersistedLessonPageState } from "@/modules/lesson/persistence/dal";

export const dynamic = "force-dynamic";

type LearningPageProps = Readonly<{ params: Promise<{ locale: string }> }>;

export async function generateMetadata({ params }: LearningPageProps): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = persistedLessonCopy[locale];
  return {
    title: copy.metadataTitle,
    description: copy.metadataDescription,
    robots: "noindex, noarchive",
    alternates: { languages: { th: learningPath("th"), en: learningPath("en") } },
  };
}

export default async function LearningPage({ params }: LearningPageProps) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = persistedLessonCopy[locale];
  const privateEvidenceCopy = evidenceCopy[locale];
  const state = await loadPersistedLessonPageState(locale);
  if (state.state === "denied" && ["absent", "invalid", "expired"].includes(state.reason)) {
    redirect(`/${locale}/sign-in?returnTo=${learningPath(locale)}`);
  }
  const status =
    state.state === "not-started"
      ? copy.notStarted
      : state.state === "in-progress"
        ? copy.inProgress
        : state.state === "needs-retry"
          ? copy.needsRetry
          : state.state === "demonstrated"
            ? copy.demonstrated
            : null;
  return (
    <section className="persisted-result" aria-labelledby="learning-heading">
      <p className="section-heading__eyebrow">{copy.learningEyebrow}</p>
      <h1 id="learning-heading">{copy.learningHeading}</h1>
      <p>{copy.learningIntroduction}</p>
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
          <h2>{copy.consentHeading}</h2>
          <p>{copy.consentBody}</p>
          <TextLink href={onboardingPath(locale)} prefetch={false}>
            {copy.consentHeading}
          </TextLink>
        </div>
      ) : null}
      {state.state === "denied" ? (
        <div className="assessment-storage-notice">
          <h2>{copy.unavailableHeading}</h2>
        </div>
      ) : null}
      {status ? (
        <article className="persisted-result__card">
          <h2>{copy.lessonLink}</h2>
          <p>{status}</p>
          <TextLink href={persistedLessonAttemptPath(locale)} prefetch={false}>
            {copy.lessonLink}
          </TextLink>
        </article>
      ) : null}
      {state.state === "demonstrated" ? (
        <article className="persisted-result__card">
          <h2>{privateEvidenceCopy.artifactHeading}</h2>
          <p>{privateEvidenceCopy.privateLabel}</p>
          <TextLink href={evidencePath(locale)} prefetch={false}>
            {privateEvidenceCopy.learningEvidenceLink}
          </TextLink>
        </article>
      ) : null}
    </section>
  );
}
