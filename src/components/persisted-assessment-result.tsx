import { TextLink } from "@/components/primitives/text-link";
import type { PersistedResultCopy } from "@/modules/assessment/persisted-result/copy";
import type { PersistedResultView } from "@/modules/assessment/persisted-result/dal";

type PersistedAssessmentResultProps = Readonly<{
  attemptHref: string;
  homeHref: string;
  lessonHref: string;
  copy: PersistedResultCopy;
  view: PersistedResultView;
}>;

export function PersistedAssessmentResult({
  attemptHref,
  homeHref,
  lessonHref,
  copy,
  view,
}: PersistedAssessmentResultProps) {
  return (
    <article className="persisted-result" aria-labelledby="persisted-result-heading">
      <header className="persisted-result__hero">
        <p className="section-heading__eyebrow">{copy.eyebrow}</p>
        <h1 id="persisted-result-heading">{copy.heading}</h1>
        <p>{copy.introduction}</p>
      </header>

      <section className="assessment-boundary" aria-labelledby="persisted-result-boundary">
        <h2 id="persisted-result-boundary">{copy.boundaryHeading}</h2>
        <ul>
          {copy.boundaries.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      </section>

      <section className="persisted-result__section" aria-labelledby="persisted-core-heading">
        <h2 id="persisted-core-heading">{copy.assessedHeading}</h2>
        <p>{copy.assessedBody}</p>
        <div className="persisted-result__grid">
          {view.coreScores.map((score) => (
            <article className="persisted-result__card" key={score.name}>
              <h3>{score.name}</h3>
              <p className="persisted-result__fraction">
                {formatTemplate(copy.rawEvidenceTemplate, {
                  earned: score.earnedPoints,
                  available: score.availablePoints,
                })}
              </p>
              <p>{formatTemplate(copy.evidenceCountTemplate, { count: score.evidenceCount })}</p>
              <p>{score.explanation}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="persisted-result__section" aria-labelledby="persisted-unassessed-heading">
        <h2 id="persisted-unassessed-heading">{copy.unassessedHeading}</h2>
        <p>{copy.unassessedBody}</p>
        <ul className="example-unassessed-list">
          {view.unassessedCoreNames.map((name) => (
            <li key={name}>{name}</li>
          ))}
        </ul>
      </section>

      <section className="persisted-result__section" aria-labelledby="persisted-multiplier-heading">
        <h2 id="persisted-multiplier-heading">{copy.multipliersHeading}</h2>
        <p>{copy.multipliersBody}</p>
        <div className="persisted-result__grid">
          {view.multiplierObservations.map((observation) => (
            <article className="persisted-result__card" key={observation.name}>
              <h3>{observation.name}</h3>
              <p className="example-multiplier__label">{copy.singleScenarioLabel}</p>
              <p>{observation.explanation}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="persisted-result__priority" aria-labelledby="persisted-priority-heading">
        <h2 id="persisted-priority-heading">{copy.priorityHeading}</h2>
        {view.priority.state === "none" ? (
          <>
            <h3>{copy.noPriorityHeading}</h3>
            <p>{copy.noPriorityBody}</p>
            <p>{view.priority.explanation}</p>
          </>
        ) : (
          <>
            <p className="section-heading__eyebrow">{copy.priorityUniqueLabel}</p>
            <h3>{view.priority.competencyName}</h3>
            <p>{copy.priorityUniqueBody}</p>
            <p>{view.priority.explanation}</p>
            {view.priority.nextAction === "prototype-lesson" ? (
              <div>
                <p>{copy.prototypeLessonBoundary}</p>
                <TextLink href={lessonHref}>{copy.prototypeLessonLabel}</TextLink>
              </div>
            ) : (
              <div>
                <h4>{copy.practiceUnavailableLabel}</h4>
                <p>{copy.practiceUnavailableBody}</p>
              </div>
            )}
          </>
        )}
      </section>

      <section className="example-limitations" aria-labelledby="persisted-limitations-heading">
        <h2 id="persisted-limitations-heading">{copy.limitationsHeading}</h2>
        <ul>
          {view.limitations.map((limitation) => (
            <li key={limitation}>{limitation}</li>
          ))}
        </ul>
      </section>

      <nav className="example-result__actions" aria-label={copy.heading}>
        <TextLink href={attemptHref}>{copy.attemptLabel}</TextLink>
        <TextLink href={homeHref}>{copy.homeLabel}</TextLink>
      </nav>
    </article>
  );
}

function formatTemplate(template: string, values: Readonly<Record<string, number>>): string {
  return Object.entries(values).reduce(
    (result, [key, value]) => result.replaceAll(`{${key}}`, String(value)),
    template,
  );
}
