import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { SyntheticExampleResult } from "@/components/synthetic-example-result";
import {
  assessmentExampleResultPath,
  assessmentPath,
  localePath,
  sourceVerificationLessonPath,
} from "@/lib/i18n/config";
import { getCatalogForSegment } from "@/lib/i18n/server";
import { createSyntheticExampleResultView } from "@/modules/assessment/result/view";

type ExampleResultPageProps = Readonly<{
  params: Promise<{ locale: string }>;
}>;

export async function generateMetadata({ params }: ExampleResultPageProps): Promise<Metadata> {
  const { locale: localeSegment } = await params;
  const resolved = getCatalogForSegment(localeSegment);

  if (resolved === null) {
    notFound();
  }

  return {
    title: resolved.catalog.exampleResult.metadata.title,
    description: resolved.catalog.exampleResult.metadata.description,
    robots: "noindex, noarchive",
    alternates: {
      languages: {
        th: assessmentExampleResultPath("th"),
        en: assessmentExampleResultPath("en"),
      },
    },
  };
}

export default async function ExampleResultPage({ params }: ExampleResultPageProps) {
  const { locale: localeSegment } = await params;
  const resolved = getCatalogForSegment(localeSegment);

  if (resolved === null) {
    notFound();
  }

  return (
    <SyntheticExampleResult
      assessmentHref={assessmentPath(resolved.locale)}
      homeHref={localePath(resolved.locale)}
      lessonHref={sourceVerificationLessonPath(resolved.locale)}
      messages={resolved.catalog.exampleResult}
      view={createSyntheticExampleResultView(resolved.locale)}
    />
  );
}
