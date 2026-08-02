import { EvidenceSection } from "@/components/evidence-section";
import { Stack } from "@/components/primitives/stack";
import { TextLink } from "@/components/primitives/text-link";
import type { PublishedEvidence } from "@/lib/evidence/model";
import {
  coreCompetencies,
  multipliers,
  productLoopSteps,
  type LandingCatalog,
} from "@/lib/i18n/catalogs";
import { assessmentPath, type Locale } from "@/lib/i18n/config";

type PublicNarrativeProps = Readonly<{
  evidence: readonly PublishedEvidence[];
  locale: Locale;
  messages: LandingCatalog;
}>;

export function PublicNarrative({ evidence, locale, messages }: PublicNarrativeProps) {
  return (
    <Stack className="landing-page">
      <section className="landing-hero" aria-labelledby="landing-hero-heading">
        <p className="section-heading__eyebrow">{messages.hero.eyebrow}</p>
        <h1 id="landing-hero-heading">{messages.hero.heading}</h1>
        <p className="landing-hero__lead">{messages.hero.introduction}</p>
        <p className="landing-hero__supporting">{messages.hero.supporting}</p>
        <div className="landing-hero__action">
          <TextLink className="narrative-cta" href={assessmentPath(locale)}>
            {messages.hero.ctaLabel}
          </TextLink>
          <p>{messages.hero.availability}</p>
        </div>
      </section>

      <EvidenceSection evidence={evidence} messages={messages.evidence} />

      <section
        id="how-rise-pals-works"
        className="narrative-section response-section"
        aria-labelledby="response-heading"
      >
        <header className="section-heading">
          <p className="section-heading__eyebrow">{messages.response.eyebrow}</p>
          <h2 id="response-heading">{messages.response.heading}</h2>
          <p>{messages.response.introduction}</p>
        </header>
        <ol className="product-loop" aria-label={messages.response.loopLabel}>
          {productLoopSteps.map((step, index) => (
            <li key={step}>
              <span className="product-loop__number" aria-hidden="true">
                {String(index + 1).padStart(2, "0")}
              </span>
              <div>
                <h3>{messages.response.steps[step].name}</h3>
                <p>{messages.response.steps[step].description}</p>
              </div>
            </li>
          ))}
        </ol>
        <p className="practice-note">{messages.response.practiceNote}</p>
      </section>

      <section
        id="skill-framework"
        className="narrative-section framework-section"
        aria-labelledby="framework-heading"
      >
        <header className="section-heading">
          <p className="section-heading__eyebrow">{messages.framework.eyebrow}</p>
          <h2 id="framework-heading">{messages.framework.heading}</h2>
          <p>{messages.framework.introduction}</p>
        </header>

        <div className="framework-group" aria-labelledby="core-heading">
          <div className="framework-group__heading">
            <h3 id="core-heading">{messages.framework.coreHeading}</h3>
            <p>{messages.framework.coreIntroduction}</p>
          </div>
          <ul className="competency-grid">
            {coreCompetencies.map((competency) => (
              <li key={competency}>
                <h4>{messages.framework.core[competency].name}</h4>
                <p>{messages.framework.core[competency].description}</p>
              </li>
            ))}
          </ul>
        </div>

        <div className="framework-group multiplier-group" aria-labelledby="multipliers-heading">
          <div className="framework-group__heading">
            <h3 id="multipliers-heading">{messages.framework.multipliersHeading}</h3>
            <p>{messages.framework.multipliersIntroduction}</p>
          </div>
          <ul className="multiplier-grid">
            {multipliers.map((multiplier) => (
              <li key={multiplier}>
                <h4>{messages.framework.multiplierItems[multiplier].name}</h4>
                <p>{messages.framework.multiplierItems[multiplier].description}</p>
              </li>
            ))}
          </ul>
        </div>

        <p className="framework-boundary">{messages.framework.boundary}</p>
      </section>
    </Stack>
  );
}
