import { notFound } from "next/navigation";
import { PublicNarrative } from "@/components/public-narrative";
import { getPublishedEvidence } from "@/lib/evidence/records";
import { getCatalogForSegment } from "@/lib/i18n/server";

type PublicNarrativePageProps = Readonly<{
  params: Promise<{ locale: string }>;
}>;

export default async function PublicNarrativePage({ params }: PublicNarrativePageProps) {
  const { locale: localeSegment } = await params;
  const resolved = getCatalogForSegment(localeSegment);

  if (resolved === null) {
    notFound();
  }

  const evidence = getPublishedEvidence(resolved.locale);

  return (
    <PublicNarrative
      evidence={evidence}
      locale={resolved.locale}
      messages={resolved.catalog.landing}
    />
  );
}
