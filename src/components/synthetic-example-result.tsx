import { TextLink } from "@/components/primitives/text-link";
import type { ExampleResultCatalog } from "@/lib/i18n/catalogs";
import type { SyntheticExampleResultView } from "@/modules/assessment/result/view";

type SyntheticExampleResultProps = Readonly<{
  assessmentHref: string;
  homeHref: string;
  messages: ExampleResultCatalog;
  view: SyntheticExampleResultView;
}>;

export function SyntheticExampleResult({
  assessmentHref,
  homeHref,
  messages,
  view,
}: SyntheticExampleResultProps) {
  const { result } = view;

  return (
    <article className="example-result" aria-labelledby="example-result-heading">
      <header className="example-result__hero">
        <p className="section-heading__eyebrow">{messages.eyebrow}</p>
        <h1 id="example-result-heading">{messages.heading}</h1>
        <p className="example-result__lead">{messages.introduction}</p>
        <p className="example-result__badge">{messages.exampleOnlyLabel}</p>
        <p className="example-result__boundary">{messages.userChoicesBoundary}</p>
      </header>

      <section className="example-result__section" aria-labelledby="example-provenance-heading">
        <header className="example-result__section-heading">
          <h2 id="example-provenance-heading">{messages.fixtureHeading}</h2>
          <p>{view.overviewExplanation.body}</p>
        </header>
        <dl className="example-result__provenance">
          <div>
            <dt>{messages.fixtureLabel}</dt>
            <dd>
              <code>{result.fixtureId}</code>
            </dd>
          </div>
          <div>
            <dt>{messages.contractLabel}</dt>
            <dd>
              <code>{result.contractVersionId}</code>
            </dd>
          </div>
        </dl>
      </section>

      <section className="example-result__section" aria-labelledby="example-coverage-heading">
        <header className="example-result__section-heading">
          <h2 id="example-coverage-heading">{messages.coverageHeading}</h2>
          <p>{messages.coverageIntroduction}</p>
        </header>

        <section aria-labelledby="example-assessed-heading">
          <header className="example-result__subheading">
            <h3 id="example-assessed-heading">{messages.assessedHeading}</h3>
            <p>{messages.assessedIntroduction}</p>
          </header>
          <div className="example-signal-grid">
            {view.coreSignals.map((signal) => {
              const headingId = `example-signal-${signal.competencyId}`;
              const evidenceText = formatTemplate(messages.rawEvidenceTemplate, {
                earned: signal.earnedPoints,
                available: signal.availablePoints,
              });

              return (
                <figure
                  className="example-signal"
                  aria-labelledby={headingId}
                  key={signal.competencyId}
                >
                  <figcaption>
                    <h4 id={headingId}>{signal.name}</h4>
                    <p className="example-signal__raw-text">{evidenceText}</p>
                  </figcaption>
                  <div className="example-signal__segments" aria-hidden="true">
                    {Array.from({ length: signal.availablePoints }, (_, index) => (
                      <span
                        className={
                          index < signal.earnedPoints
                            ? "example-signal__segment example-signal__segment--filled"
                            : "example-signal__segment"
                        }
                        key={index}
                      />
                    ))}
                  </div>
                  <p>
                    {formatTemplate(messages.evidenceCountTemplate, {
                      count: signal.evidenceCount,
                    })}
                  </p>
                  <p className="example-result__explanation">{signal.explanation.body}</p>
                  <TraceItemKeys
                    itemKeys={signal.supportingItemKeys}
                    label={messages.supportingItemsLabel}
                  />
                </figure>
              );
            })}
          </div>
        </section>

        <section
          className="example-result__subsection"
          aria-labelledby="example-unassessed-heading"
        >
          <header className="example-result__subheading">
            <h3 id="example-unassessed-heading">{messages.unassessedHeading}</h3>
            <p>{messages.unassessedIntroduction}</p>
          </header>
          <ul className="example-unassessed-list">
            {view.unassessedCoreCompetencies.map((competency) => (
              <li key={competency.competencyId}>
                <span>{competency.name}</span>
                <code>{competency.competencyId}</code>
              </li>
            ))}
          </ul>
        </section>

        <section
          className="example-result__subsection"
          aria-labelledby="example-multipliers-heading"
        >
          <header className="example-result__subheading">
            <h3 id="example-multipliers-heading">{messages.multipliersHeading}</h3>
            <p>{messages.multipliersIntroduction}</p>
          </header>
          <div className="example-multiplier-grid">
            {view.multiplierObservations.map((observation) => (
              <article
                className="example-multiplier"
                aria-labelledby={`example-multiplier-${observation.multiplierId}`}
                key={observation.multiplierId}
              >
                <h4 id={`example-multiplier-${observation.multiplierId}`}>{observation.name}</h4>
                <p className="example-multiplier__label">{messages.singleScenarioLabel}</p>
                <p>{observation.explanation.body}</p>
                <TraceItemKeys
                  itemKeys={observation.supportingItemKeys}
                  label={messages.supportingItemsLabel}
                />
              </article>
            ))}
          </div>
        </section>
      </section>

      <section className="example-practice" aria-labelledby="example-practice-heading">
        <p className="section-heading__eyebrow">{messages.practiceEyebrow}</p>
        <h2 id="example-practice-heading">{messages.practiceHeading}</h2>
        <p>{messages.practiceBody}</p>
        <div className="example-practice__action">
          <h3>{messages.practiceActionHeading}</h3>
          <p>{messages.practiceAction}</p>
        </div>

        <section className="example-practice__trace" aria-labelledby="example-trace-heading">
          <h3 id="example-trace-heading">{messages.traceHeading}</h3>
          <p>{messages.traceIntroduction}</p>
          <dl>
            <div>
              <dt>{messages.traceDefinitionLabel}</dt>
              <dd>
                <code>
                  {view.exampleNextPractice.definitionId}@
                  {view.exampleNextPractice.definitionVersion}
                </code>
              </dd>
            </div>
            <div>
              <dt>{messages.traceFixtureLabel}</dt>
              <dd>
                <code>{view.exampleNextPractice.fixtureId}</code>
              </dd>
            </div>
            <div>
              <dt>{messages.traceTargetLabel}</dt>
              <dd>
                <span>{view.exampleNextPractice.targetCompetencyName}</span>
                <code>{view.exampleNextPractice.targetCompetencyId}</code>
              </dd>
            </div>
            <div>
              <dt>{messages.traceScoringModelLabel}</dt>
              <dd>
                <code>
                  {view.exampleNextPractice.scoringModelVersionId}@
                  {view.exampleNextPractice.scoringModelVersion}
                </code>
              </dd>
            </div>
            <div>
              <dt>{messages.traceItemsLabel}</dt>
              <dd>
                <ItemKeyList itemKeys={view.exampleNextPractice.supportingItemKeys} />
              </dd>
            </div>
            <div>
              <dt>{messages.traceLessonLabel}</dt>
              <dd>
                <code>{view.exampleNextPractice.plannedLesson.lessonVersionId}</code>
                <strong>{messages.lessonUnavailableLabel}</strong>
              </dd>
            </div>
          </dl>
        </section>
      </section>

      <section className="example-limitations" aria-labelledby="example-limitations-heading">
        <header className="example-result__section-heading">
          <h2 id="example-limitations-heading">{messages.limitationsHeading}</h2>
          <p>{messages.limitationsIntroduction}</p>
        </header>
        <ul>
          {view.limitations.map((limitation) => (
            <li key={limitation.code}>{limitation.body}</li>
          ))}
        </ul>
      </section>

      <nav className="example-result__actions" aria-label={messages.heading}>
        <TextLink href={assessmentHref}>{messages.backToAssessmentLabel}</TextLink>
        <TextLink href={homeHref}>{messages.homeLabel}</TextLink>
      </nav>
    </article>
  );
}

function TraceItemKeys({
  itemKeys,
  label,
}: Readonly<{ itemKeys: readonly string[]; label: string }>) {
  return (
    <div className="example-item-trace">
      <p>{label}</p>
      <ItemKeyList itemKeys={itemKeys} />
    </div>
  );
}

function ItemKeyList({ itemKeys }: Readonly<{ itemKeys: readonly string[] }>) {
  return (
    <ul className="example-item-keys">
      {itemKeys.map((itemKey) => (
        <li key={itemKey}>
          <code>{itemKey}</code>
        </li>
      ))}
    </ul>
  );
}

function formatTemplate(
  template: string,
  values: Readonly<Record<string, string | number>>,
): string {
  return Object.entries(values).reduce(
    (formatted, [key, value]) => formatted.replaceAll(`{${key}}`, String(value)),
    template,
  );
}
