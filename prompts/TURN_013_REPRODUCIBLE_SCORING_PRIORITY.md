# RP-TURN-013 — Reproducible Scoring and Priority Recommendation

## Authorization

- **Source:** Project Codex turn authorization accepted by Jeff
- **Authorized base:** `e4731ab183d66cee7bb98f8e165b681017204073`
- **Authorized branch:** `agent/reproducible-scoring-priority`
- **Draft PR title:** `feat: add reproducible scoring and priority`
- **Repository:** Public [`noppol87/RisePals`](https://github.com/noppol87/RisePals)

## Objective

Add an owner-scoped, reproducible synthetic-alpha derived-result flow for submitted persisted assessment responses. Persist versioned core signals, separate multiplier observations, traceable controlled explanations, and at most one bounded provisional next-practice priority. This work does not validate the assessment, establish a complete skill profile, or authorize real-user or production use.

## Required reading

- `AGENTS.md`, `README.md`, and `PROJECT_STATUS.md`
- `docs/01_PRODUCT_VISION.md`, `docs/02_SKILL_FRAMEWORK.md`, and `docs/03_MVP_SCOPE.md`
- `docs/07_TECHNICAL_ARCHITECTURE.md`, `docs/08_DATA_MODEL.md`, `docs/09_ENGINEERING_PLAN.md`, and `docs/DECISION_LOG.md`
- `prompts/VS_CODE_TURN_BRIEF_TEMPLATE.md` and `prompts/VS_CODE_HANDOFF_TEMPLATE.md`
- Accepted RP-TURN-006, RP-TURN-008, RP-TURN-010, RP-TURN-011, and RP-TURN-012 contracts

## Locked boundaries

- Synthetic alpha only. Real identities, real assessment data, and production use remain prohibited.
- Preserve the exact accepted 8+2 framework and six-item assessment: two Critical Thinking & Fact-Checking items, two Systematic Thinking items, one Ownership Thinking item, and one Sense of Urgency item.
- Six core competencies remain unassessed and must have no score row.
- Framework weights remain metadata and cannot affect this partial result or priority.
- Ownership Thinking and Sense of Urgency remain separate, unweighted, one-scenario observations and cannot alter, aggregate into, multiply, or rank core signals.
- No overall, weighted, readiness, risk, proficiency, confidence, personality, employment, salary, hiring, eligibility, job-loss, or job-performance inference.
- Profile fields, role family, function, experience band, and goals cannot affect scoring or priority.
- Derived data and digests are P3 sensitive assessment data. No analytics, marketing, telemetry, or research use.
- Retention, export, erasure, and production privacy/legal operations remain open.
- Preserve the public player's `sessionStorage` behavior. Never score/import its temporary selections.
- Preserve the fixed synthetic example-result route as a separate fixture demonstration.

## Immutable result policy

- Preserve accepted assessment, framework, and scoring-model identities unchanged.
- Do not mutate `scoring-integer-rubric-fixture-v1@1.0.0`.
- Add immutable repository-local `persisted-synthetic-priority-v1@1.0.0`.
- Give it a deterministic canonical JSON representation and pinned SHA-256 digest.
- Every scoring run records the exact scoring-model version and result-policy key, version, and digest.
- Record this bounded decision as D-020 without changing prior decisions.

## Database scope

Add exactly one forward migration after `0002`, resulting in exactly 17 fresh-schema tables. Add exactly:

1. `scoring_runs`
2. `competency_scores`
3. `multiplier_observations`
4. `score_explanations`
5. `priority_recommendations`

Only required indexes, constraints, enums, triggers, and narrowly scoped functions may accompany them. Do not alter raw-answer payloads, session lifecycle, accepted published definitions, or add lesson/progress/XP/proof/analytics tables or production seed data.

## Run and canonicalization contract

- A run belongs to one internal owner and one exact submitted, complete assessment session and references its exact assessment/framework/scoring versions.
- Record monotonically increasing run number, canonical input digest, canonical output digest, policy identity/version/digest, and an optional prior-run provenance link.
- Canonical input is SHA-256 over exact content identities and digests, policy identity/version/digest, and active responses in canonical item order with item identity, revision, and option identity.
- Exclude user/session UUIDs, timestamps, and locale from semantic input.
- Exclude database UUIDs, timestamps, and localized copy from semantic output.
- The same canonical input/model/policy produces the same semantic output and output digest.
- Normal replay or concurrent generation converges on the existing current run.
- Only an explicit server-only rescore can create the next immutable run with `supersedes_scoring_run_id`; browser input cannot request it.
- Runs and children are atomically complete and append-only. Any failure rolls back all rows and returns a controlled result without sensitive details.
- Application UPDATE and DELETE are prohibited for all five tables.

## Derived contracts

### Core scores

- Persist exactly the two assessed core rows with integer earned/available points, evidence count, and normalized basis points.
- Normalize using deterministic integer floor arithmetic. Basis points are calculation metadata, not scientific precision.
- Display earned/available fractions only, never proficiency percentages.
- Derive the six unassessed core names from the exact framework minus assessed rows in canonical framework order.

### Multiplier observations

- Persist only in `multiplier_observations`, never `competency_scores`.
- Persist exactly one Ownership Thinking and one Sense of Urgency observation.
- Keep earned/available rubric points server-only; expose only observation label and evidence count.
- Every observation carries the one-scenario-cannot-establish-a-pattern limitation.

### Explanations

- Store controlled codes, validated non-sensitive parameters, and target-validated supporting item keys only.
- Store no localized prose, selected option, copied answer payload, profile data, or free text.
- Resolve Thai/English copy server-side from repository catalogs.
- Persist exactly one run limitation, two core explanations, two multiplier explanations, and one priority/no-priority explanation.
- Do not claim causation, stable behavior, validated proficiency, or employment outcomes.

### Priority

- Candidate set: only assessed core signals with complete expected evidence.
- Unassessed cores, weights, profile data, and multiplier observations cannot be candidates, tie-breakers, or modifiers.
- Compare earned/available ratios by exact integer cross multiplication.
- A unique lowest assessed-core ratio persists exactly one rank-1 `unique-lowest-assessed-core-signal` recommendation.
- A tie persists zero recommendation rows and one `no-distinct-priority` explanation; framework order cannot break it.
- Never persist more than one recommendation or call it the learner's largest overall gap.

## Lesson/action boundary

- Do not add a lesson-version table or new lesson content/progress/XP/proof.
- Critical Thinking may link only to existing `lesson-source-verification-practice-v1@1.0.0`, with explicit prototype and provisional/synthetic wording.
- Systematic Thinking shows that a matching practice is unavailable.
- A tie shows no personalized lesson link.

## Authorization, consent, and RLS

- Enable and force RLS on all five tables. The app role remains non-owner, `NOSUPERUSER`, and `NOBYPASSRLS`.
- Resolve ownership only through trusted transaction-local `app.current_user_id`.
- Enforce owner-linked foreign keys to the submitted session.
- Cross-user, missing/malformed context, and guessed IDs reveal no row or existence signal.
- Generation and reads require an active account, current granted `service-profile-learning-state` / `alpha-privacy-v1` consent, and one compatible submitted complete owner session.
- Decline/withdrawal blocks generation/read without claiming deletion.
- Browser input cannot supply identity, session/database IDs, provider subject, model/policy identity, consent receipt, or RLS context.

## Application and client boundary

- Add protected `/th/assessment/result` and `/en/assessment/result`, with no IDs/payload in path, query, or fragment.
- GET/page render never creates a run. The submitted receipt exposes one explicit localized generation action.
- The Server Action accepts only locale and an idempotency mutation UUID; the server resolves all trusted state.
- Refresh returns the existing run. Logout denies access; same-owner reauthentication restores it.
- Client DTO contains only localized core names, raw fractions, evidence counts, six unassessed names, localized multiplier labels/counts, controlled localized explanations/limitations, zero/one priority name, and bounded prototype/unavailable action state.
- Keep scorer, responses/options, database IDs/table internals, digests, policy internals, provider subjects, secrets, and RLS context server-only.
- No derived result or answer data in browser storage, cookies, URLs, logs, analytics, console output, or unauthorized requests.
- Preserve keyboard/focus behavior, visible pending/error states, 320px reflow, reduced motion, and accessibility.

## Pure derivation and history

- Reuse the accepted integer-rubric engine without changing RP-TURN-006/008 semantics.
- SQL/response order and locale cannot change output. Use no random, clock, locale collation, or floating point in semantic derivation.
- Reject missing, duplicate, unknown, tampered, wrong-version, altered-definition, incomplete-evidence, and impossible-rubric input.
- Stable output order follows canonical framework/item order.
- Lock the submitted session. Concurrent normal generation converges to one run; replay returns it.
- Explicit server-only rescores serialize, increment run number, preserve the prior run, and reproduce exact semantic rows/digest for identical inputs.

## Required verification

- `npm ci`, pending-install-script query, `npm config get strict-allow-scripts`, and `npm ls nanoid postcss --all`
- Format, lint, strict typecheck, all unit/component tests, focused result tests, production build, `npm run check`, Chromium E2E, and disposable PostgreSQL integration
- Production and full npm audits
- Strict UTF-8, balanced Markdown fences, unresolved/conflict markers, diff checks, and changed-PowerShell AST validation
- Client manifest/chunk inspection
- Gitleaks worktree, exact staged content, proposed history, and pushed history
- Database evidence: 17 tables; five forced-RLS derived tables; app non-ownership/no bypass; submitted/complete/current-consent gate; exact compatibility; replay/concurrency/rescore; two core/six unassessed/two multiplier; unique-lowest/tie; atomic rollback; immutability; full own/cross/missing/malformed RLS matrix; sanitized failures
- Unit evidence: pinned known digests/signals; order/locale invariance; malformed-input rejection; normalization; Critical/Systematic/tie priority; weight/multiplier independence; forbidden-field absence; prior fixture compatibility
- Browser evidence: localized protected routes; explicit pending/success/unavailable/tie/error states; refresh/re-auth; isolation; exact lesson boundary; keyboard/focus; 320px; reduced motion; zero serious/critical Axe findings; loopback-only privacy

## One bounded real-provider smoke

Run at most one real Clerk Development smoke only after deterministic, database, and browser gates pass, using one unique synthetic identity, one fresh browser context, disposable loopback PostgreSQL, and repository-local published definitions. Verify Thai sign-up/onboarding/consent/profile; six persisted responses and submission; explicit result generation; exact 2 core, 2 separate multiplier, 6 unassessed presentation; bounded priority/tie; refresh and repeated-generation idempotency; logout denial and same-identity restoration; owner isolation and privacy; exact database counts. Delete and verify the identity absent, then remove isolated build and every disposable process/data/log/credential resource.

If the smoke fails, do not rerun or make speculative fixes. Complete cleanup and return Partial with the exact sanitized failing stage.

## Scope exclusions

- No real user/data or production Clerk/PostgreSQL.
- No full profile, real validation/calibration, reassessment, abandonment, deletion, retention/export/erasure implementation, new lesson/publishing/progress/XP/proof, analytics, payment, employment matching, CI, branch protection, infrastructure, service, or deployment.
- Prefer no dependency change. Preserve `nanoid 3.3.18`, PostCSS `8.5.25`, Sharp `0.35.3`, strict install policy, and ignored `.env.local` without disclosure.
- Do not start RP-TURN-014.

## Documentation and GitHub workflow

Update only factual Turn 013 details in the authorized status, README, architecture, data-model, engineering-plan, local-development, decision-log, and this brief. Inventory and intentionally stage only Turn 013 files; inspect staged names/stats/diff checks; scan exact staged content; commit intentionally; push without force; and open one Draft PR to unchanged main using the approved title. Keep it Draft/unmerged and retain the feature branch.

The canonical handoff must report status, commit/PR, exact file inventory, migration/table evidence, canonicalization and policy digest, core/multiplier/priority/history/RLS evidence, browser/client/privacy and bounded-smoke cleanup evidence, exact commands/results, audits/dependencies, hashes, limitations/known issues, and confirmation that RP-TURN-014 was not started. Do not claim Project Codex acceptance.
