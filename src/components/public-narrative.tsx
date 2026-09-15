import { EvidenceSection } from "@/components/evidence-section";
import { ArrowIcon, SkillIcon } from "@/components/brand-mark";
import { FirstVisitJourney } from "@/components/first-visit-journey";
import { Stack } from "@/components/primitives/stack";
import { TextLink } from "@/components/primitives/text-link";
import type { PublishedEvidence } from "@/lib/evidence/model";
import {
  coreCompetencies,
  multipliers,
  productLoopSteps,
  type LandingCatalog,
} from "@/lib/i18n/catalogs";
import { sourceVerificationLessonPath, type Locale } from "@/lib/i18n/config";

type PublicNarrativeProps = Readonly<{
  evidence: readonly PublishedEvidence[];
  locale: Locale;
  messages: LandingCatalog;
}>;

export function PublicNarrative({ evidence, locale, messages }: PublicNarrativeProps) {
  return (
    <Stack className="landing-page">
      <FirstVisitJourney locale={locale} />

      <section
        id="how-rise-pals-works"
        className="narrative-section response-section"
        aria-labelledby="response-heading"
        data-reveal
      >
        <header className="section-heading">
          <p className="section-heading__eyebrow">{messages.response.eyebrow}</p>
          <h2 id="response-heading">{messages.response.heading}</h2>
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
        data-reveal
      >
        <details className="experience-disclosure">
          <summary>
            <span>
              <span className="section-heading__eyebrow">{messages.framework.eyebrow}</span>
              <h2 id="framework-heading">{messages.framework.heading}</h2>
            </span>
            <span className="disclosure-plus" aria-hidden="true">
              +
            </span>
          </summary>
          <p>{messages.framework.introduction}</p>
          <div className="framework-group" aria-labelledby="core-heading">
            <div className="framework-group__heading">
              <h3 id="core-heading">{messages.framework.coreHeading}</h3>
              <p>{messages.framework.coreIntroduction}</p>
            </div>
            <ul className="competency-grid">
              {coreCompetencies.map((competency, index) => (
                <li key={competency}>
                  <div className="competency-icon">
                    <SkillIcon index={index} />
                    <span>{String(index + 1).padStart(2, "0")}</span>
                  </div>
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
        </details>
      </section>
      <EvidenceSection evidence={evidence} messages={messages.evidence} />
      <section className="closing-invitation" aria-labelledby="closing-heading" data-reveal>
        <h2 id="closing-heading">
          {locale === "th" ? "พร้อมลองก้าวแรกไหม?" : "Ready for a small first step?"}
        </h2>
        <TextLink href={sourceVerificationLessonPath(locale)} className="narrative-cta">
          {messages.hero.ctaLabel}
          <ArrowIcon />
        </TextLink>
      </section>
    </Stack>
  );
}
