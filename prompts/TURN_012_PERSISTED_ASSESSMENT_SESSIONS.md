# RP-TURN-012 — Persisted Assessment Sessions and Raw Responses

## Authorization

- **Source:** Project Codex turn authorization accepted by Jeff
- **Authorized base:** `a6ff9d9206fabd6f8cefd91496875927a36ade63`
- **Authorized branch:** `agent/persisted-assessment-sessions`
- **Draft PR title:** `feat: persist synthetic assessment sessions`
- **Repository:** Public [`noppol87/RisePals`](https://github.com/noppol87/RisePals)

## Objective

Implement a synthetic-alpha, owner-scoped PostgreSQL start/save/resume/submit flow for the accepted six-item assessment. Persist only raw selected item/option identities with immutable version references and revision provenance. Do not calculate or display a score, result, proficiency, priority recommendation or employment inference.

## Read first

- `AGENTS.md`
- `README.md`
- `PROJECT_STATUS.md`
- `docs/01_PRODUCT_VISION.md`
- `docs/02_SKILL_FRAMEWORK.md`
- `docs/03_MVP_SCOPE.md`
- `docs/07_TECHNICAL_ARCHITECTURE.md`
- `docs/08_DATA_MODEL.md`
- `docs/09_ENGINEERING_PLAN.md`
- `docs/DECISION_LOG.md`
- `prompts/VS_CODE_TURN_BRIEF_TEMPLATE.md`
- `prompts/VS_CODE_HANDOFF_TEMPLATE.md`
- Accepted RP-TURN-006 assessment contract
- Accepted RP-TURN-007 player and `sessionStorage` boundary
- Accepted RP-TURN-010 database/RLS implementation
- Accepted RP-TURN-011 authorization, profile and consent DAL

## Locked boundaries

- Synthetic alpha only; real users and real personal, career or assessment data are prohibited.
- Clerk Development and disposable loopback PostgreSQL are the only permitted external/runtime test resources.
- Existing session-only prototype data is never imported, copied or silently promoted into PostgreSQL.
- PostgreSQL is authoritative only inside the new authenticated persisted-attempt flow; the public prototype remains separate.
- Selected item/option IDs are P3 sensitive assessment data.
- No answer, session ID or user ID may appear in URLs, analytics, console output, logs or error text.
- Preserve the accepted `service-profile-learning-state` / `alpha-privacy-v1` consent purpose and notice.
- No scoring, result, recommendation, lesson progress, XP, proof or analytics persistence.
- Prefer no new dependency and preserve exact `nanoid 3.3.18`, PostCSS `8.5.25`, Sharp `0.35.3` and the install-script policy.
- No Production Clerk/PostgreSQL, CI, infrastructure, service or deployment.

## Database scope

Add exactly one forward migration after `0001` plus consistent Drizzle schema and metadata for only:

1. `assessment_sessions`
2. `assessment_responses`
3. Required enums, constraints, indexes, triggers and narrowly scoped functions

Do not add scoring runs, competency scores, recommendations, lesson attempts/progress, XP, proof or analytics tables.

## Session contract

- Internal UUID primary key and internal `user_accounts.id` owner.
- Reference one exact published `assessment_version` and exact accepted service-data consent receipt.
- Support only `in_progress → submitted`.
- Store database-generated started/updated/submitted timestamps and a validated last-item-version resume marker.
- Store no context snapshot because this bounded flow does not require one.
- At most one active in-progress session per owner/assessment version.
- Concurrent starts converge on and return one active session.
- Owner, assessment version and consent receipt are immutable.
- A submitted session cannot reopen, be replaced or mutate.
- Reassessment, abandonment, voiding and deletion are excluded.

## Raw response contract

- Each revision belongs to one session and exact item version.
- Payload has exact versioned keys only: `schemaVersion` and `selectedOptionId`.
- Never persist localized copy, prompt/rubric/target/framework data, explanations, score fields, client timestamps or free text.
- PostgreSQL validates item/session compatibility and the option against the exact item version's canonical response schema.
- Corrections use monotonically increasing revisions and `supersedes_response_id`.
- Each save has a client mutation UUID. Exact replay returns the same result; conflicting reuse fails.
- Expected revision is required. A stale concurrent write fails without overwrite.
- Exactly one active revision exists per session/item.
- All response rows/history are immutable after submission.
- Application DELETE access is prohibited.

## Authorization, consent and RLS

- Enable and force RLS on both new tables.
- The normal application role remains non-owner, `NOSUPERUSER` and `NOBYPASSRLS`.
- Every read and mutation runs inside the accepted server-only authorization transaction with trusted `app.current_user_id`.
- Owners see only their session/response rows; cross-user, missing/malformed context and guessed IDs fail without existence disclosure.
- Start/save/resume/submit require an active account and current granted `service-profile-learning-state` / `alpha-privacy-v1` receipt.
- Decline/withdrawal blocks new persistence and submission but is not described as deletion.
- Browser input never sets owner ID, provider subject, consent receipt, assessment database ID or RLS context.

## Application flow

- Add protected locale-matched `/[locale]/assessment/attempt` without a session UUID in the URL.
- Preserve `/[locale]/assessment` and its existing session-only storage unchanged except for one honest separate entry link.
- Unauthenticated access uses same-locale sign-in.
- Missing/declined/withdrawn consent renders a bounded state without session creation.
- Missing compatible published assessment data renders unavailable; production migration does not seed definitions.
- Disposable verification alone seeds repository-local synthetic published definitions.
- Explicitly start or resume the owner's current attempt.
- Save one option at a time with pending/saved/error feedback; Back/forward and refresh restore server state.
- Logout blocks access; same-owner re-authentication restores it.
- Submission locks session/responses and requires the complete six-response set atomically.
- Double-submit is idempotent and returns one immutable bilingual receipt/status.
- State clearly that scoring and personalized results do not exist in this turn.

## Client/privacy boundary

- DTOs contain only localized item presentation, item/option IDs, current selections, revision numbers and non-sensitive persistence status.
- Database IDs not needed by the client, provider subjects, consent history, server DAL, rubric/scoring/framework internals remain server-only.
- Persisted answers use no browser storage, cookie, URL/query/fragment, analytics or telemetry.
- Server errors use structured codes without identifiers, payloads, SQL or stacks.
- Preserve keyboard/focus behavior, visible errors/status, 320px reflow and reduced motion.

## Required database evidence

- Published assessment/item compatibility at start.
- Immutable session owner/assessment/consent links.
- Unknown item/option and malformed payload rejection.
- One active session under concurrent start.
- Mutation replay idempotency and conflicting-reuse rejection.
- One winner/one stale result for concurrent saves with the same expected revision.
- Active-response uniqueness and explicit supersession.
- Incomplete submission leaves status unchanged.
- Complete submission records one `submitted_at`; double-submit returns it unchanged.
- Post-submit session/response insert/update/delete rejection.
- Complete own/cross-user/missing/malformed-context RLS matrix.
- Application runtime contains no migration/table-owner privilege or URL.

## Real-provider verification

If required for the authenticated persisted boundary, run at most one bounded real Clerk Development smoke with one unique synthetic identity and disposable PostgreSQL seeded only with repository-local synthetic definitions. Verify start, save, refresh resume, logout denial, repeat sign-in resume, correction, complete submission, double-submit idempotency, post-submit immutability and privacy boundaries. Delete and verify the Clerk identity absent, then remove the isolated build and all disposable PostgreSQL process/data/log/credential state. Never output identifiers, credentials or answer payloads. If smoke or cleanup cannot be proven, return `Partial`.

## Required verification

- `npm ci`
- install-script pending query and `npm config get strict-allow-scripts`
- `npm ls nanoid postcss --all`
- `npm run format:check`
- `npm run lint`
- `npm run typecheck`
- `npm run test`
- `npm run build`
- `npm run check`
- `npm run test:e2e`
- `npm run db:prepare:disposable` when needed
- `npm run db:test:disposable`
- bounded authenticated persistence smoke
- `npm audit --omit=dev`
- `npm audit`
- strict UTF-8, balanced Markdown fences and unresolved/conflict markers
- `git diff --check` and staged diff check
- PowerShell AST validation for changed PowerShell scripts
- client manifest/chunk inspection for database/response/rubric/scoring/provider/secret leakage
- Gitleaks worktree, exact staged content, proposed history and pushed history
- matching local/origin feature head, unchanged local/origin/public main, Draft PR and clean worktree

## Documentation

Update factual Turn 012 changes only where relevant:

- `PROJECT_STATUS.md`
- `README.md`
- `docs/07_TECHNICAL_ARCHITECTURE.md`
- `docs/08_DATA_MODEL.md`
- `docs/09_ENGINEERING_PLAN.md`
- `docs/10_LOCAL_DEVELOPMENT.md`
- `docs/DECISION_LOG.md`
- this brief

## GitHub workflow

1. Create `agent/persisted-assessment-sessions` from exact main `a6ff9d9206fabd6f8cefd91496875927a36ade63`.
2. Inventory and intentionally stage only Turn 012 files.
3. Inspect staged names/stat/check and scan exact staged content.
4. Commit intentionally and push without force.
5. Open one Draft PR to unchanged `main` titled `feat: persist synthetic assessment sessions`.
6. Do not mark ready, merge, delete the branch or begin RP-TURN-013.

## Acceptance criteria

- Exactly one new forward migration adds only session/response persistence structures.
- PostgreSQL and DAL enforce ownership, consent, immutable version references, idempotency, revision provenance, concurrency and post-submit immutability.
- The protected bilingual attempt route restores only server-authoritative same-owner state and has no answer/session/user identifiers in its URL or browser storage.
- The existing session-only player remains separate and never imports its state.
- No score, result, recommendation, proficiency or employment inference exists.
- Full quality, database, browser, audit, client-boundary and secret-scan gates pass.
- Real-provider smoke and cleanup pass without retaining identifiers or resources.
- Main remains unchanged and exactly one Draft unmerged PR is created.

## End-of-turn requirement

Return the canonical handoff from `prompts/VS_CODE_HANDOFF_TEMPLATE.md` with exact changed files, migration/tables/invariants, RLS and cross-user evidence, idempotency/concurrency evidence, real-provider smoke/cleanup evidence without identifiers, commands/results, hashes, Draft PR URL, assumptions/limitations and explicit confirmation that RP-TURN-013 was not started.

## Actual verification disposition

Implementation and deterministic/database/browser gates completed. The single authorized real-provider smoke reached persisted start, response correction, refresh resume, complete submission/double-submit protection and immutable receipt, then stopped before logout/re-auth/final privacy checks because the harness looked for the profile-only logout control on the receipt route. The harness now navigates to profile first, but the one-run authorization prohibits a rerun. Cleanup deleted and verified the unique synthetic identity absent and removed the isolated build plus disposable PostgreSQL process/data/logs/credentials. The turn must therefore be handed off as **Partial**, not acceptance-ready; a follow-up smoke requires new Project Codex authorization and RP-TURN-013 remains unstarted.
