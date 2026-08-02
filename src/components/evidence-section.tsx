import type { PublishedEvidence } from "@/lib/evidence/model";
import type { LandingCatalog } from "@/lib/i18n/catalogs";

type EvidenceSectionProps = Readonly<{
  evidence: readonly PublishedEvidence[];
  messages: LandingCatalog["evidence"];
}>;

export function EvidenceSection({ evidence, messages }: EvidenceSectionProps) {
  return (
    <section
      id="why-now"
      className="narrative-section evidence-section"
      aria-labelledby="why-now-heading"
    >
      <header className="section-heading">
        <p className="section-heading__eyebrow">{messages.eyebrow}</p>
        <h2 id="why-now-heading">{messages.heading}</h2>
        <p>{messages.introduction}</p>
      </header>
      <div className="evidence-grid">
        {evidence.map((item) => {
          const headingId = `evidence-${item.id}`;

          return (
            <article className="evidence-card" aria-labelledby={headingId} key={item.id}>
              <figure>
                <p className="evidence-card__label">{messages.signalLabel}</p>
                <h3 id={headingId}>{item.content.claim}</h3>
                <div className="evidence-card__response">
                  <div>
                    <p className="evidence-card__label">{messages.interpretationLabel}</p>
                    <p>{item.content.interpretation}</p>
                  </div>
                  <div className="evidence-card__action">
                    <p className="evidence-card__label">{messages.actionLabel}</p>
                    <p>{item.content.action}</p>
                  </div>
                </div>
                <dl className="evidence-card__provenance">
                  <div>
                    <dt>{messages.geographyLabel}</dt>
                    <dd>{item.content.geography}</dd>
                  </div>
                  <div>
                    <dt>{messages.contextLabel}</dt>
                    <dd>{item.content.context}</dd>
                  </div>
                  <div>
                    <dt>{messages.limitationLabel}</dt>
                    <dd>{item.content.doesNotProve}</dd>
                  </div>
                </dl>
                <figcaption className="evidence-card__citation">
                  <cite>{item.source.title}</cite>
                  <span>{item.source.publisher}</span>
                  <span>
                    {messages.publishedLabel}:{" "}
                    <time dateTime={item.source.publicationDate}>
                      {item.source.publicationDate}
                    </time>
                  </span>
                  <span>
                    {messages.verifiedLabel}:{" "}
                    <time dateTime={item.dateLastVerified}>{item.dateLastVerified}</time>
                  </span>
                  <span>
                    {messages.reviewLabel}:{" "}
                    <time dateTime={item.reviewDate}>{item.reviewDate}</time>
                  </span>
                  <a className="source-link" href={item.source.url}>
                    {messages.sourceLabel}
                  </a>
                </figcaption>
              </figure>
            </article>
          );
        })}
      </div>
    </section>
  );
}
