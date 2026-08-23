import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";
import { PersistedSourceVerificationLesson } from "@/components/persisted-source-verification-lesson";
import { TextLink } from "@/components/primitives/text-link";
import {
  isLocale,
  learningPath,
  onboardingPath,
  persistedLessonAttemptPath,
} from "@/lib/i18n/config";
import { persistedLessonCopy } from "@/modules/lesson/persistence/copy";
import { loadPersistedLessonPageState } from "@/modules/lesson/persistence/dal";
import { sourceVerificationLessonDefinition } from "@/modules/lesson/publication/registry";
import { createSourceVerificationLessonView } from "@/modules/lesson/source-verification/view";

export const dynamic = "force-dynamic";

type AttemptPageProps = Readonly<{ params: Promise<{ locale: string }> }>;

export async function generateMetadata({ params }: AttemptPageProps): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = persistedLessonCopy[locale];
  return {
    title: copy.metadataTitle,
    description: copy.metadataDescription,
    robots: "noindex, noarchive",
    alternates: {
      languages: { th: persistedLessonAttemptPath("th"), en: persistedLessonAttemptPath("en") },
    },
  };
}

export default async function PersistedLessonAttemptPage({ params }: AttemptPageProps) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = persistedLessonCopy[locale];
  const state = await loadPersistedLessonPageState(locale);
  if (state.state === "denied" && ["absent", "invalid", "expired"].includes(state.reason)) {
    redirect(`/${locale}/sign-in?returnTo=${persistedLessonAttemptPath(locale)}`);
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
  if (state.state === "denied") {
    return (
      <section className="assessment-storage-notice">
        <h1>{copy.unavailableHeading}</h1>
      </section>
    );
  }
  return (
    <PersistedSourceVerificationLesson
      copy={copy}
      learningHref={learningPath(locale)}
      locale={locale}
      state={state}
      view={createSourceVerificationLessonView(locale, sourceVerificationLessonDefinition)}
    />
  );
}
