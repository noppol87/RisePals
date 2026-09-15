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
            <TextLink className="narrative-cta" href={assessmentPath(locale)}>
              {messages.hero.ctaLabel}
              <ArrowIcon />
            </TextLink>
            <a className="hero-secondary-link" href="#how-rise-pals-works">
              {locale === "th" ? "รู้จักเส้นทางของคุณ" : "See how it works"}
              <span aria-hidden="true">↘</span>
            </a>
          </div>
          <div className="hero-reassurance">
            <span>
              <span aria-hidden="true">✓</span>
              {locale === "th" ? "เริ่มได้โดยไม่สมัคร" : "No sign-up to explore"}
            </span>
            <span>
              <span aria-hidden="true">✓</span>
              {locale === "th" ? "เรียนรู้ผ่านการลงมือทำ" : "Learn by doing"}
            </span>
          </div>
          <p className="landing-hero__supporting">{messages.hero.supporting}</p>
        </div>
        <SkillOrbit locale={locale} framework={messages.framework} />
      </section>

      <div
        className="landing-baseline"
        aria-label={locale === "th" ? "ภาพรวมประสบการณ์" : "The experience at a glance"}
      >
        <div>
          <strong>
            8<span>+2</span>
          </strong>
          <span>
            {locale === "th" ? "ทักษะและพฤติกรรมที่ต่อยอดได้" : "Skills and behaviours to build on"}
          </span>
        </div>
        <div>
          <strong>06</strong>
          <span>
            {locale === "th" ? "สถานการณ์ให้ลองตัดสินใจ" : "Scenarios to explore your thinking"}
          </span>
        </div>
        <div>
          <strong>01</strong>
          <span>
            {locale === "th" ? "ภารกิจแรกให้ลองลงมือทำ" : "First practice mission to try"}
          </span>
        </div>
      </div>

      <aside className="landing-availability">
        <span className="edition-label">EXPLORATION EDITION</span>
        <p>{messages.hero.availability}</p>
      </aside>

      <section className="first-mission" aria-labelledby="first-mission-heading" data-reveal>
        <div className="first-mission__visual" aria-hidden="true">
          <span className="mission-visual__index">MISSION / 001</span>
          <div className="source-stack source-stack--back">
            <span />
            <span />
            <span />
          </div>
          <div className="source-stack source-stack--front">
            <span className="source-stack__tag">SOURCE CHECK</span>
            <div className="source-stack__headline">
              Look closer.
              <br />
              Think clearer.
            </div>
            <div className="source-stack__lines">
              <span />
              <span />
            </div>
            <div className="source-stack__check">
              <SkillIcon index={0} />
            </div>
          </div>
          <span className="mission-visual__caption">CRITICAL THINKING ↗</span>
        </div>
        <div className="first-mission__copy">
          <p className="section-heading__eyebrow">
            {locale === "th"
              ? "ก้าวเล็ก ๆ ที่เริ่มได้วันนี้"
              : "A small step starts something bigger"}
          </p>
          <h2 id="first-mission-heading">
            {locale === "th" ? (
              <>
                อย่าเพิ่งเชื่อ AI
                <br />
                ลองเป็นคนตรวจคำตอบ
              </>
            ) : (
              <>
                Before you trust AI,
                <br />
                put the answer to the test.
              </>
            )}
          </h2>
          <p>
            {locale === "th"
              ? "ทดลองตรวจแหล่งข้อมูล แยกข้อเท็จจริงจากคำกล่าวอ้าง แล้วรับ feedback จากสิ่งที่คุณเลือกในภารกิจแรก"
              : "Check the source. Separate the evidence from the claim. Get feedback on your choices in your first practice mission."}
          </p>
          <div className="mission-tags">
            <span>{locale === "th" ? "ฝึกคิดอย่างมีวิจารณญาณ" : "Critical thinking"}</span>
            <span>{locale === "th" ? "มี feedback" : "With feedback"}</span>
          </div>
          <TextLink href={sourceVerificationLessonPath(locale)} className="mission-link">
            {locale === "th" ? "ลองภารกิจตรวจสอบข้อมูล" : "Try the source-checking mission"}
            <ArrowIcon />
          </TextLink>
          <small>
            {locale === "th"
              ? "ภารกิจตัวอย่าง · ไม่บันทึกผลการฝึก"
              : "Practice prototype · progress is not saved"}
          </small>
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

      <EvidenceSection evidence={evidence} messages={messages.evidence} />

      <section
        id="skill-framework"
        className="narrative-section framework-section"
        aria-labelledby="framework-heading"
        data-reveal
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
      </section>
      <section className="closing-invitation" aria-labelledby="closing-heading" data-reveal>
        <p className="section-heading__eyebrow">YOUR NEXT CHAPTER STARTS HERE</p>
        <h2 id="closing-heading">
          {locale === "th" ? (
            <>
              ก้าวต่อไปของคุณ
              <br />
              <em>เริ่มได้จากก้าวเล็ก ๆ</em>
            </>
          ) : (
            <>
              Big possibilities.
              <br />
              <em>One small next step.</em>
            </>
          )}
        </h2>
        <TextLink href={assessmentPath(locale)} className="narrative-cta">
          {locale === "th" ? "เริ่มสำรวจทักษะของคุณ" : "Explore your next step"}
          <ArrowIcon />
        </TextLink>
        <p>
          {locale === "th"
            ? "เริ่มจากสถานการณ์จำลอง ไม่ต้องสมัครบัญชี"
            : "Start with a synthetic scenario. No account needed."}
        </p>
      </section>
    </Stack>
  );
}
