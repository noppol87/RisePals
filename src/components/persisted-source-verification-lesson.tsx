import { TextLink } from "@/components/primitives/text-link";
import {
  PersistedLessonPractice,
  StartPersistedLesson,
} from "@/components/persisted-lesson-practice";
import type { Locale } from "@/lib/i18n/config";
import type { PersistedLessonCopy } from "@/modules/lesson/persistence/copy";
import type { PersistedLessonPageState } from "@/modules/lesson/persistence/dal";
import type { SourceVerificationLessonView } from "@/modules/lesson/source-verification/types";

export function PersistedSourceVerificationLesson({
  copy,
  learningHref,
  locale,
  state,
  view,
}: {
  copy: PersistedLessonCopy;
  learningHref: string;
  locale: Locale;
  state: Exclude<PersistedLessonPageState, { state: "denied" | "consent-required" }>;
  view: SourceVerificationLessonView;
}) {
  return (
    <article className="lesson-prototype" aria-labelledby="persisted-lesson-heading">
      <header className="lesson-hero">
        <p className="section-heading__eyebrow">{view.hero.eyebrow}</p>
        <h1 id="persisted-lesson-heading">{view.hero.heading}</h1>
        <p className="lesson-hero__lead">{view.hero.introduction}</p>
        <p className="lesson-prototype__badge">{view.hero.prototypeLabel}</p>
        <p className="lesson-prototype__boundary">{view.hero.boundary}</p>
      </header>
      <section className="lesson-panel" aria-labelledby="persisted-overview-heading">
        <h2 id="persisted-overview-heading">{view.overview.heading}</h2>
        <dl className="lesson-overview">
          <div>
            <dt>{view.overview.targetLabel}</dt>
            <dd>Critical Thinking &amp; Fact-Checking</dd>
          </div>
          <div>
            <dt>{view.overview.stageLabel}</dt>
            <dd>{view.lesson.targetWorkingStage}</dd>
          </div>
          <div>
            <dt>{view.overview.roiLabel}</dt>
            <dd>{view.lesson.primaryRoiPillar}</dd>
          </div>
          <div>
            <dt>{view.overview.timeLabel}</dt>
            <dd>{view.overview.timeValue}</dd>
          </div>
        </dl>
      </section>
      <section
        className="lesson-panel lesson-scenario"
        aria-labelledby="persisted-scenario-heading"
      >
        <h2 id="persisted-scenario-heading">{view.scenario.heading}</h2>
        <p>{view.scenario.introduction}</p>
        <p className="lesson-synthetic-label">{view.scenario.syntheticLabel}</p>
        <blockquote className="lesson-ai-summary">
          <p>{view.scenario.aiSummary}</p>
        </blockquote>
        <div className="lesson-source-grid">
          {view.scenario.sourceRecords.map((record) => (
            <article key={record.id}>
              <h3>{record.label}</h3>
              <p>{record.detail}</p>
            </article>
          ))}
        </div>
      </section>
      <section className="lesson-panel" aria-labelledby="persisted-concepts-heading">
        <h2 id="persisted-concepts-heading">{view.concepts.heading}</h2>
        <p>{view.concepts.introduction}</p>
        <ol className="lesson-concept-list">
          {view.concepts.items.map((item) => (
            <li key={item.id}>
              <h3>{item.heading}</h3>
              <p>{item.body}</p>
            </li>
          ))}
        </ol>
      </section>
      {state.state === "not-started" ? (
        <StartPersistedLesson copy={copy} locale={locale} />
      ) : (
        <PersistedLessonPractice copy={copy} initialState={state} locale={locale} />
      )}
      <section className="lesson-panel lesson-proof" aria-labelledby="persisted-proof-heading">
        <h2 id="persisted-proof-heading">{view.proof.heading}</h2>
        <p>{view.proof.introduction}</p>
        <p>{view.proof.boundary}</p>
      </section>
      <section className="lesson-panel" aria-labelledby="persisted-reflection-heading">
        <h2 id="persisted-reflection-heading">{view.reflection.heading}</h2>
        <p>{view.reflection.prompt}</p>
        <p>{view.reflection.boundary}</p>
      </section>
      <TextLink href={learningHref} prefetch={false}>
        {copy.backLabel}
      </TextLink>
    </article>
  );
}
