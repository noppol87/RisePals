import { notFound } from "next/navigation";
import { getCatalogForSegment } from "@/lib/i18n/server";

type FoundationPageProps = Readonly<{
  params: Promise<{ locale: string }>;
}>;

export default async function FoundationPage({ params }: FoundationPageProps) {
  const { locale: localeSegment } = await params;
  const resolved = getCatalogForSegment(localeSegment);

  if (resolved === null) {
    notFound();
  }

  return (
    <section className="foundation-panel" aria-labelledby="foundation-heading">
      <p className="foundation-panel__eyebrow">{resolved.catalog.foundation.eyebrow}</p>
      <h1 id="foundation-heading">{resolved.catalog.foundation.heading}</h1>
      <p className="foundation-panel__description">{resolved.catalog.foundation.description}</p>
    </section>
  );
}
