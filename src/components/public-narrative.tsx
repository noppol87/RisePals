import { EvidenceSection } from "@/components/evidence-section";
import { ArrowIcon, SkillIcon } from "@/components/brand-mark";
import { SkillOrbit } from "@/components/skill-orbit";
import { Stack } from "@/components/primitives/stack";
import { TextLink } from "@/components/primitives/text-link";
import type { PublishedEvidence } from "@/lib/evidence/model";
import {
  coreCompetencies,
  multipliers,
  productLoopSteps,
  type LandingCatalog,
} from "@/lib/i18n/catalogs";
import { assessmentPath, sourceVerificationLessonPath, type Locale } from "@/lib/i18n/config";

type PublicNarrativeProps = Readonly<{
  evidence: readonly PublishedEvidence[];
  locale: Locale;
  messages: LandingCatalog;
}>;

export function PublicNarrative({ evidence, locale, messages }: PublicNarrativeProps) {
  return (
    <Stack className="landing-page">
      <section className="landing-hero" aria-labelledby="landing-hero-heading">
        <div className="landing-hero__copy">
          <p className="section-heading__eyebrow">{messages.hero.eyebrow}</p>
          <h1 id="landing-hero-heading">
            {messages.hero.heading}
            <br />
            <span>{messages.hero.headingAccent}</span>
          </h1>
          <p className="landing-hero__lead">{messages.hero.introduction}</p>
          <div className="landing-hero__action">
            <TextLink className="narrative-cta" href={sourceVerificationLessonPath(locale)}>
              {messages.hero.ctaLabel}
              <ArrowIcon />
            </TextLink>
            <TextLink className="hero-secondary-link" href={assessmentPath(locale)}>
              {locale === "th" ? "ลองตอบ 6 ข้อ" : "Try 6 scenarios"}
              <span aria-hidden="true">↘</span>
            </TextLink>
          </div>
          <p className="landing-hero__supporting">
            {messages.hero.supporting} · {messages.hero.availability}
          </p>
        </div>
        <SkillOrbit locale={locale} framework={messages.framework} />
      </section>

      <section className="first-mission" aria-labelledby="first-mission-heading" data-reveal>
        <div className="first-mission__visual" aria-hidden="true">
          <span className="mission-visual__index">
            {locale === "th" ? "ภารกิจ / 01" : "MISSION / 01"}
          </span>
          <div className="source-stack source-stack--back">
            <span />
            <span />
            <span />
          </div>
          <div className="source-stack source-stack--front">
            <span className="source-stack__tag">
              {locale === "th" ? "เช็กก่อนเชื่อ" : "SOURCE CHECK"}
            </span>
            <div className="source-stack__headline">
              {locale === "th" ? "จริงแค่ไหน" : "Is it true?"}
              <br />
              {locale === "th" ? "ลองเช็กดู" : "Let’s check."}
            </div>
            <div className="source-stack__lines">
              <span />
              <span />
            </div>
            <div className="source-stack__check">
              <SkillIcon index={0} />
            </div>
          </div>
          <span className="mission-visual__caption">
            {locale === "th" ? "คิดก่อนเชื่อ ↗" : "THINK CRITICALLY ↗"}
          </span>
        </div>
        <div className="first-mission__copy">
          <p className="section-heading__eyebrow">
            {locale === "th" ? "ลองภารกิจแรก" : "YOUR FIRST MISSION"}
          </p>
          <h2 id="first-mission-heading">
            {locale === "th" ? (
              <>
                อย่าเพิ่งเชื่อ AI
                <br />
                ลองเช็กคำตอบ
              </>
            ) : (
              <>
                Trust the AI?
                <br />
                Check it first.
              </>
            )}
          </h2>
          <p>
            {locale === "th"
              ? "หาหลักฐานให้เจอ แล้วดูว่าคำตอบของคุณมีจุดไหนที่ทำได้ดี"
              : "Find the evidence. Make your call. See how you did."}
          </p>
          <TextLink href={sourceVerificationLessonPath(locale)} className="mission-link">
            {locale === "th" ? "ลองภารกิจนี้" : "Try this mission"}
            <ArrowIcon />
          </TextLink>
          <small>{locale === "th" ? "เดโม · ไม่บันทึกผล" : "Demo · progress isn’t saved"}</small>
        </div>
      </section>

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
