# RP-TURN-006 — Assessment Domain Fixtures and Scoring Contract

**Authorization:** Jeff approved this bounded implementation turn through Project Codex.  
**Authorized base:** `a63f634595589e80873f9013ebaa3a714657eb72`  
**Branch:** `agent/assessment-domain-fixtures`  
**Draft PR title:** `feat: establish assessment domain fixtures`

## Objective

Create a pure, typed and versioned assessment-domain foundation using synthetic local fixtures. Establish deterministic scoring and explanation contracts without creating an assessment UI, collecting data or claiming scientific validation.

## Read before implementation

1. `AGENTS.md`
2. `README.md`
3. `PROJECT_STATUS.md`
4. `docs/01_PRODUCT_VISION.md`
5. `docs/02_SKILL_FRAMEWORK.md`
6. `docs/03_MVP_SCOPE.md`
7. `docs/08_DATA_MODEL.md`
8. `docs/09_ENGINEERING_PLAN.md`
9. `prompts/VS_CODE_HANDOFF_TEMPLATE.md`
10. This turn brief

## Authorized assessment slice

Create exactly six bilingual Thai/English scenario-choice items:

- 2 × Critical Thinking & Fact-Checking
- 2 × Systematic Thinking
- 1 × Ownership Thinking
- 1 × Sense of Urgency

Every situation must be workplace-generic, respectful and synthetic. Use stable assessment, item, option, framework and scoring-version identifiers. Options may carry reviewed deterministic integer rubric contributions. Do not add free-text responses, personal profiles, employer data, email, names or any other PII.

## Framework contract

- Represent all eight canonical core competencies with the exact weights from `docs/02_SKILL_FRAMEWORK.md`.
- Validate that core weights total 100% (10,000 basis points).
- Keep Ownership Thinking and Sense of Urgency structurally separate from the eight weighted core competencies.
- Do not multiply the +2 into core scores.
- Do not produce an overall 8+2 score from this partial slice.
- Do not map results to Aware–Leading proficiency stages.
- Do not produce priority-gap or lesson recommendations.

## Required separation

Keep these concerns in separate contracts/modules:

1. assessment and item definitions
2. synthetic raw-response fixtures
3. deterministic scoring outputs
4. explanation and limitation records
5. localized Thai/English explanation copy

## Scoring contract

The scorer must be a pure deterministic TypeScript function. It must not mutate caller inputs and must return the same result regardless of response order.

It must validate:

- assessment, framework and scoring-version compatibility
- complete required responses
- no duplicate item responses
- known item and option IDs
- valid rubric configuration
- possible integer point values

It must return:

- separate core-skill signals and multiplier observations
- earned and available points
- evidence count
- traceable supporting item keys
- a provisional/fixture-only marker
- all six unassessed core competencies explicitly

It must not return:

- an overall score
- a validated confidence claim
- an Aware–Leading proficiency stage
- priority-gap or lesson recommendations
- an employment, job-loss, job-performance, employability or hiring implication

Multiplier observations may retain internal deterministic rubric contributions for testing. They must not expose a precise multiplicative factor and must state that one scenario cannot establish a behavioral pattern.

## Explanation contract

- Store explanation codes separately from calculated scoring records.
- Trace every explanation to supporting item keys.
- Keep localized Thai/English explanation copy separate from explanation records.
- Include explicit bilingual limitations.
- State that this small local slice is not a validated assessment.
- State that it cannot predict job loss, job performance, employability or hiring eligibility.
- Use dignified, actionable wording without shame, fear gauges or fabricated causal claims.
- Submit all item, option, explanation and limitation wording for Project Codex review.

## Fixtures and tests

- Keep valid synthetic raw-response fixtures separate from expected scoring fixtures and expected explanation fixtures.
- Use synthetic identifiers only.
- Test framework identities and the 100% core-weight invariant.
- Test fixture uniqueness, locale completeness and stable references.
- Test deterministic, order-independent and non-mutating scoring.
- Test every required rejection case.
- Test that multipliers never alter or aggregate into core scores.
- Test that no overall-score, proficiency-stage, priority-gap or hiring field is emitted.
- Test exact evidence counts, supporting-item traces and limitation codes.
- Prefer explicit assertions over broad snapshots.

## Implementation boundary

- Use `src/modules/assessment/` for pure domain contracts, framework metadata, fixtures, validation, scoring and explanations.
- Use `tests/modules/assessment/` for the domain tests.
- Do not import React, Next.js or browser APIs into the scoring domain.
- A stable framework-ID refactor shared with the public catalog is allowed only if it produces no visible output change; avoid relocating localized copy unnecessarily.

## Documentation

- Record the provisional fixture/scoring contract in `docs/08_DATA_MODEL.md`.
- Record the no-overall-score and separate-multiplier decision in `docs/DECISION_LOG.md`.
- Update `docs/10_LOCAL_DEVELOPMENT.md` with actual verification results.
- Update `README.md` and `PROJECT_STATUS.md` only with facts changed by this turn.
- Mark RP-TURN-006 complete pending Project Codex review, not Accepted.

## Dependencies and configuration

- Add no dependency unless implementation is genuinely impossible without one; stop for Project Codex decision before adding one.
- Do not change the accepted npm install-script policy or security overrides.
- Do not weaken TypeScript, lint, audit, secret-scanning or browser-test gates.

## Required verification

- `npm ci`
- `npm run format:check`
- `npm run lint`
- `npm run typecheck`
- `npm run test`
- `npm run build`
- `npm run check`
- `npm run test:e2e`
- `npm audit --omit=dev`
- `npm audit`
- strict UTF-8, Markdown-fence, unresolved-marker and Git diff checks
- Gitleaks worktree, staged/proposed-content and pushed-branch-history scans
- local/remote feature hash equality
- unchanged `main`
- open, Draft and unmerged PR
- clean final working tree

## Out of scope

- RP-TURN-007 assessment player or any UI/route
- onboarding or resume/session behavior
- personalized skill map or priority recommendation
- scientific/psychometric validation or calibration
- real user, profile, assessment or career data
- authentication, database, analytics or persistence
- lesson, XP, proof or opportunity features
- new dependency, CI, infrastructure, service or deployment
- merge or closeout

## GitHub workflow

- Commit only the reviewed RP-TURN-006 scope.
- Push only `agent/assessment-domain-fixtures` without force.
- Open one Draft PR to `main` titled `feat: establish assessment domain fixtures`.
- Do not merge.
- Retain Jeff-authorized GitHub development authentication without exposing, rotating or broadening credential material.

## Required handoff

Return a TURN HANDOFF using `prompts/VS_CODE_HANDOFF_TEMPLATE.md`. Include exact changed files, tests and real results, fixture inventory, scoring formulas, rejected-input coverage, limitations, commit hash, Draft PR URL, authentication state and confirmation that RP-TURN-007 was not started.
