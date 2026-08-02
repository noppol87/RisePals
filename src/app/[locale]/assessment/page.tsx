import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { AssessmentPlayer } from "@/components/assessment-player";
import { assessmentPath, localePath } from "@/lib/i18n/config";
import { getCatalogForSegment } from "@/lib/i18n/server";
import { createAssessmentPlayerView } from "@/modules/assessment/player/view";

type AssessmentPlayerPageProps = Readonly<{
  params: Promise<{ locale: string }>;
}>;

export async function generateMetadata({ params }: AssessmentPlayerPageProps): Promise<Metadata> {
  const { locale: localeSegment } = await params;
  const resolved = getCatalogForSegment(localeSegment);

  if (resolved === null) {
    notFound();
  }

  return {
    title: resolved.catalog.assessment.metadata.title,
    description: resolved.catalog.assessment.metadata.description,
    robots: "noindex, noarchive",
    alternates: {
      languages: {
        th: assessmentPath("th"),
        en: assessmentPath("en"),
      },
    },
  };
}

export default async function AssessmentPlayerPage({ params }: AssessmentPlayerPageProps) {
  const { locale: localeSegment } = await params;
  const resolved = getCatalogForSegment(localeSegment);

  if (resolved === null) {
    notFound();
  }

  return (
    <AssessmentPlayer
      homeHref={localePath(resolved.locale)}
      messages={resolved.catalog.assessment}
      view={createAssessmentPlayerView(resolved.locale)}
    />
  );
}
