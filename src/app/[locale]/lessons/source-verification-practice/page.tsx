import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { SourceVerificationLesson } from "@/components/source-verification-lesson";
import {
  assessmentExampleResultPath,
  localePath,
  sourceVerificationLessonPath,
} from "@/lib/i18n/config";
import { getCatalogForSegment } from "@/lib/i18n/server";
import { sourceVerificationLessonDefinition } from "@/modules/lesson/publication/registry";
import { createSourceVerificationLessonView } from "@/modules/lesson/source-verification/view";

type SourceVerificationLessonPageProps = Readonly<{
  params: Promise<{ locale: string }>;
}>;

export async function generateMetadata({
  params,
}: SourceVerificationLessonPageProps): Promise<Metadata> {
  const { locale: localeSegment } = await params;
  const resolved = getCatalogForSegment(localeSegment);

  if (resolved === null) {
    notFound();
  }

  const view = createSourceVerificationLessonView(
    resolved.locale,
    sourceVerificationLessonDefinition,
  );
  return {
    title: view.metadata.title,
    description: view.metadata.description,
    robots: "noindex, noarchive",
    alternates: {
      languages: {
        th: sourceVerificationLessonPath("th"),
        en: sourceVerificationLessonPath("en"),
      },
    },
  };
}

export default async function SourceVerificationLessonPage({
  params,
}: SourceVerificationLessonPageProps) {
  const { locale: localeSegment } = await params;
  const resolved = getCatalogForSegment(localeSegment);

  if (resolved === null) {
    notFound();
  }

  return (
    <SourceVerificationLesson
      exampleResultHref={assessmentExampleResultPath(resolved.locale)}
      homeHref={localePath(resolved.locale)}
      view={createSourceVerificationLessonView(resolved.locale, sourceVerificationLessonDefinition)}
    />
  );
}
