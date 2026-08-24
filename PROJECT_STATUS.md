# Rise Pals — Project Status

**Status date:** 2026-08-24  
**Current phase:** RP-TURN-018 Alpha Hardening and Recovery implementation complete, pending Project Codex review  
**Current turn:** RP-TURN-018 is implemented on its authorized Draft PR; acceptance remains pending and RP-TURN-019 is unauthorized

## Locked decisions

- Product and brand name: **Rise Pals**
- Primary domain: **risepals.com** (registered by Jeff)
- Initial market: Thai office workers affected by AI-driven changes to work
- Core model: AI-Era High-Skilled Professional Strategy & Survival Framework, version 2.0
- Skill system: 8 core competencies + 2 independent multipliers
- Learning experience: self-learning with motion, animation, practice, feedback and gamification
- Commercial direction: monthly/yearly subscriptions plus course privileges
- Future expansion: employer-facing skill signals, vacancy matching and hiring opportunities
- New raster imagery and illustrations: GPT-Image-2
- Delivery process: Project Codex reviews and directs; VS Code Codex implements one approved turn at a time
- Cross-context messages identify source, destination and purpose; only marked TURN HANDOFF messages are completed-turn submissions
- Accepted technical direction: Next.js App Router, React with strict TypeScript, Node.js 24 LTS/npm, PostgreSQL/Drizzle, Git-versioned trusted MDX/metadata for pilot lessons and a modular monolith
- Production application deployment target: this Windows Server 2022 VPS using native Node.js after a separately approved infrastructure-readiness turn; the repository contains an application scaffold, but no production application/service/deployment exists yet
- Canonical source/history: Jeff's personal Public repository [`noppol87/RisePals`](https://github.com/noppol87/RisePals), connected locally as the single `origin`
- Synthetic-alpha identity provider: Clerk Development on Free/Hobby with email verification code only; US identity hosting accepted only for synthetic testing, while production suitability remains undecided

## Completed artifacts

- Product vision
- Product interpretation of the 8+2 framework
- MVP boundary
- Milestone roadmap
- Brand, visual and evidence principles
- Codex turn-by-turn collaboration protocol
- Turn brief and handoff templates
- Technical architecture and provider decision matrix
- Initial logical data model and sensitive-data lifecycle
- Sequenced engineering plan and test strategy
- Verified local-development environment baseline
- Next.js/npm-oriented root `.gitignore`
- Windows VPS production boundaries and approved Public-GitHub destination with proposed source/release workflow
- RP-TURN-002 Git/Public-GitHub brief and corrected engineering-turn sequence
- Git `2.55.0.windows.3`, GitHub CLI `2.97.0` and Gitleaks `8.30.1` verified from official releases
- Reviewed 20-file initial foundation baseline published without force to Public `noppol87/RisePals`
- Official Node.js `24.18.1` LTS x64 and bundled npm `11.16.0` installed per-user with matching official SHA-256 and a valid OpenJS Foundation executable signature
- Minimal Next.js `16.2.12` App Router scaffold on bounded branch `agent/application-scaffold`, with React `19.2.4`, strict TypeScript, Tailwind CSS tokens and Server Components by default
- Reproducible npm lockfile, typed server-only environment boundary, semantic scaffold render tests and format/lint/typecheck/test/build gates
- RP-TURN-003 application scaffold and quality gates accepted by Project Codex
- Thai-first `/th` and prepared English `/en` route boundary, with `/` default redirect, deterministic unsupported-locale handling and correct document language
- Matching typed Thai/English shell catalogs resolved server-side, semantic app shell, real-link language switcher, accessible layout primitives and provisional semantic design tokens
- Pinned Chromium-only Playwright and axe browser-test foundation covering locale routing, keyboard/focus, 320px reflow, desktop layout, reduced motion and serious/critical accessibility findings
- RP-TURN-004 design foundation, localized app shell and quality gates accepted by Project Codex
- Thai-first and intentional English public narrative prototype with an honest internal CTA, no collection and no claim of employment guarantees
- Typed static evidence contract with deterministic provenance, locale, URL, ISO-date, review-expiry, raw-HTML and duplicate-ID validation
- Exactly two source-backed evidence items from ILO–NASK and the World Economic Forum, each paired with localized interpretation, action, visible scope and limitations
- Complete Diagnose → Prioritize → Learn → Practice → Prove → Opportunity explanation and an 8-core/+2-multiplier preview without scoring or assessment content
- RP-TURN-005 public narrative, evidence contract and quality gates accepted by Project Codex
- Exact versioned 8-core/+2-multiplier framework metadata with canonical core weights totaling 100%
- Six synthetic bilingual scenario-choice items across the authorized 2/2/1/1 assessment slice
- Pure deterministic integer-rubric scorer with separate core signals, multiplier observations, explicit unassessed core identities and no overall score
- Separate synthetic raw-response, expected-score, expected-explanation and localized limitation contracts with traceable item keys
- Explicit runtime validation for framework and item target kinds, preserving the authorized 2/2/1/1 slice and deterministic scoring boundary
- RP-TURN-006 versioned synthetic assessment-domain contract and quality gates accepted by Project Codex
- Thai-first `/th/assessment` and English-complete `/en/assessment` prototype routes using the accepted six synthetic scenarios and locale shell
- Client-safe assessment view stripped of rubric points, target mappings, framework weights, scoring configuration and explanation internals
- Accessible one-question flow with native radio groups, honest current/answered progress, Back/Continue behavior, focus management, inline validation and a no-result completion state
- Versioned same-tab `sessionStorage` resume containing only assessment/player state plus selected item/option IDs, with strict validation, safe discard and explicit clearing
- RP-TURN-007 assessment player prototype, privacy/client boundaries and quality gates accepted by Project Codex
- Thai-first `/th/assessment/example-result` and English-complete `/en/assessment/example-result` static example routes, explicitly independent of the user's temporary player selections
- Pure versioned `synthetic-example-result` derivation using reviewed fixture `synthetic-mixed-review`, with exact raw core signals `1/4` and `3/4`, all six unassessed core identities and two separate one-scenario multiplier observations
- Exact reviewed-fixture provenance guard that rejects unknown IDs, changed compatibility metadata, changed response pairs and duplicate or ambiguous canonical registry identities before scoring
- Code-native segmented evidence visualization with complete text equivalents, 320px reflow, reduced-motion compatibility and no overall/proficiency/confidence/employment inference
- One fixed example next practice traced to scoring model `scoring-integer-rubric-fixture-v1@1.0.0`, two supporting item keys, Critical Thinking & Fact-Checking and exact prototype lesson reference `lesson-source-verification-practice-v1@1.0.0`
- RP-TURN-008 brief, D-015 synthetic-example-only boundary, exact reviewed-fixture provenance guard and quality gates accepted by Project Codex
- Schema-validated, Git-versioned Thai/English lesson source bundle for `source-verification-practice@1.0.0`, operationally `published` only through the repository-local synthetic-alpha registry and separately `prototype-unvalidated`
- Static `/th/lessons/source-verification-practice` and `/en/lessons/source-verification-practice` routes with synthetic AI-summary/source-verification content, transparent three-criterion rubric and exact framework/stage/R.O.I. identity
- Pure deterministic practice evaluation and memory-only state: incomplete or below threshold previews 0 XP, all three criteria preview 20 XP, retry replaces rather than accumulates and refresh resets
- Proof-artifact placeholder and non-collecting reflection with no free text, upload, artifact generation, storage, response transmission or assessment-player data access
- RP-TURN-009 brief, D-016 repository-local lesson/practice prototype boundary, runtime copy-leaf validation and quality gates accepted by Project Codex
- RP-TURN-010 bounded PostgreSQL/Drizzle schema, one forward migration and typed server-only connection boundary for nine authorized baseline tables
- Forced RLS for the three user-owned tables, a decoded-role-validated non-owner application credential separated from migration tooling, trusted transaction-local user context, append-only consent and published/retired lifecycle immutability
- Deterministically locked OLD/NEW framework and assessment parents, closing child reparent and concurrent publication/mutation bypasses
- Complete normal-role verification (`NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOINHERIT`, `NOBYPASSRLS`, zero owned application tables) and own/cross-user/missing/malformed-context coverage across all three user-owned tables
- Reproducible loopback-only PostgreSQL 18.4 preparation and verification with a pinned EDB archive hash, validated Microsoft runtime publisher, synthetic data, fresh migration and safe cleanup; no Windows service or production database was created
- Deterministic verification on the Windows VPS: Vitest reuses one bounded `vmThreads` worker while isolating every file in a VM context, and Playwright serves the existing production build through `next start`
- RP-TURN-011 internal `IdentityProvider` boundary and Clerk Development adapter, rejecting absent/incomplete/live key configuration and keeping vendor SDK imports inside the provider integration
- Server-only authentication/authorization transaction that validates a Clerk session, maps only its subject to an internal UUID, resolves account state and establishes trusted PostgreSQL context before any protected operation
- Second forward migration adding the controlled `profile-v1` `user_profiles` table with forced RLS plus a hardened, minimum-grant, concurrency-safe identity resolve-or-provision function owned by a credentialless `NOLOGIN`/`NOBYPASSRLS` resolver role that neither application nor migration owner may assume after bootstrap
- Thai-first/English-complete sign-in, sign-up, onboarding and profile routes with same-locale safe return paths, fail-closed account states, controlled profile codes, Clerk-managed logout and no custom auth cookie/token storage
- Versioned `alpha-privacy-v1` service-data notice, deterministic proof digest and serialized append-only grant/decline/withdrawal receipts; declining does not create or update a profile and withdrawal is not presented as deletion
- Bounded real Clerk Development smoke on 2026-08-16 proving localized email-code sign-up/sign-in, one stable internal mapping, consent/profile persistence, logout denial, safe return targets and verified synthetic-identity deletion against disposable PostgreSQL
- Explicit secret-free `build`, aggregate check and Chromium E2E runners that disable Clerk even while ignored Development keys remain present, plus one isolated ignored build used only by the opt-in real-provider smoke
- RP-TURN-012 third forward migration adding only `assessment_sessions` and `assessment_responses`, with exact published-version/consent anchors, database-owned timestamps, bounded `in_progress → submitted` lifecycle and forced owner RLS
- Strict raw-response payloads containing only the selected option ID and schema version, append-only monotonic revisions, explicit supersession, idempotent client mutation IDs, stale-write conflicts and exactly one active revision per session/item
- Dynamic Thai/English `/assessment/attempt` path with explicit start, one-at-a-time save, server restore after refresh, review, atomic submission and immutable no-result receipt; the original public sessionStorage player remains separate and is never imported
- Disposable PostgreSQL integration proving 155 statements across three migrations and 12 tables, concurrent-start convergence, mutation replay, concurrent-save winner/conflict, incomplete/post-submit rejection, current-consent enforcement and cross-user/missing-context forced-RLS behavior
- Secret-free application gates for RP-TURN-012: 27 test files / 219 tests, a 17-page production build and Chromium 62/62; no scoring/result/recommendation, new dependency, production database or deployment was added
- Bounded RP-TURN-012 real Clerk Development smoke proving Thai email-code sign-up/onboarding, one stable internal mapping, current consent/profile persistence, start/save/correction/refresh, atomic idempotent submission, immutable receipt, profile logout denial, same-identity re-authentication, safe return handling and browser/database privacy boundaries; the one synthetic identity and all disposable resources were deleted and verified absent
- Immutable repository-local result policy `persisted-synthetic-priority-v1@1.0.0` with pinned canonical JSON and SHA-256 digest `10f2ab076828d50b228ff53d57332527dfe9d1b2769c4b57bd0476dd3c263157`
- Pure server-only persisted-result derivation with canonical input/output digests, exact integer normalization/cross-multiplication, two assessed core rows, six unassessed cores, two separate multiplier observations, controlled explanations and zero-or-one unique-lowest priority
- Fourth forward migration adding exactly `scoring_runs`, `competency_scores`, `multiplier_observations`, `score_explanations` and `priority_recommendations`; the fresh disposable schema has 17 tables and all five derived tables are forced-RLS protected and append-only for the application role
- Protected Thai/English `/assessment/result` flow with explicit generation only, refresh-safe replay, bounded lesson/unavailable action, no identifier-bearing URL and a client DTO that omits raw answers, option IDs, database IDs, digests, policy internals and RLS context
- RP-TURN-013 deterministic evidence: 29 test files / 238 tests, 19 generated production pages/routes, Chromium 65/65, PostgreSQL 18.4 integration with 234 statements across four migrations and 17 tables, exact result-route chunk inspection and zero-vulnerability production/full audits
- RP-TURN-013 accepted real-provider evidence: one normal scoring run from seven historical/six active responses, two assessed core rows/cards, six unassessed cores, two separate multiplier observations, six explanations and one Critical Thinking priority; logout denial, same-identity restoration and privacy checks passed, the synthetic identity was deleted and re-queried absent, and every disposable resource was removed
- RP-TURN-013 reproducible synthetic result implementation and quality gates accepted by Project Codex for synthetic alpha at reviewed head `b80c1c27902b856aac268eb7b17fbf983a62650e`
- RP-TURN-014 trusted local MDX/JSON source bundle, deterministic SHA-256 manifest and generated JSON registry, with build-time stale-content enforcement and no MDX execution
- Strict declarative MDX allowlist for six local lesson section identifiers; ESM, expressions, raw HTML, unsafe links, unknown components, event handlers, spreads, images, traversal, symlinks and unsupported files fail closed
- Immutable `source-verification-practice@1.0.0` publication identity protected by an independently Git-reviewed identity/digest seal that the publisher cannot rewrite, with exact Thai/English locale parity, synthetic-source provenance, explicit content-owner/reviewer references and source-supplied review/publication timestamps
- Calendar-exact external-evidence dates constrained to `publicationDate <= lastVerifiedDate < reviewExpiryDate`, plus current-UTC expiry with an injectable deterministic test instant; invalid, exact-expiry and later evidence fail before any generated-output write
- Fifth forward migration adding exactly `lesson_attempts`, `practice_attempts` and `learning_progress_events`; the fresh disposable schema has 20 tables and all three new tables use forced owner RLS, current-consent enforcement and append-only history
- Separate dynamic `/th|en/learning` and `/th|en/lessons/source-verification-practice/attempt` paths with explicit start/save/evaluate/retry actions, while both public lesson routes remain statically generated and memory-only
- Exact published lesson/practice/rubric/evaluation/digest anchors, server-authoritative deterministic evaluation, immutable revisions, controlled progress states and meaningful events only; normalized intent/locale/expected-revision provenance makes only an exact mutation replay idempotent and rejects conflicting UUID reuse without another row, event or lesson transition. After a non-demonstrated evaluation, both DAL and PostgreSQL require an explicit payload-preserving retry draft before another save/evaluate mutation; denied transitions leave rows, events and lesson timestamps unchanged. No page-view event, saved XP, proof input or assessment/scoring coupling exists.
- RP-TURN-015 deterministic/unit/build/browser/database/security evidence Accepted by Project Codex at reviewed implementation head `962b4422fa21c28b06c362f87ec55466281409e8`; no real Clerk smoke or external resource was used
- Sixth forward migration adding exactly `evidence_artifacts`, `evidence_artifact_revisions` and `evidence_competency_links`; the fresh disposable schema has 23 tables and all three new tables use current-consent forced owner RLS, database-enforced provenance and no application DELETE
- Separate dynamic `/th|en/evidence` and `/th|en/evidence/source-verification-note` routes for one private controlled Bright River source-verification note after exact demonstrated practice, with explicit start/save/ready/withdraw actions and no write on GET
- Strict `source-verification-note-artifact-v1@1.0.0` payload with fixed claim, ordered allowlisted source references, controlled fit/correction/safe-action selections, immutable revisions, exact replay/conflict behavior and deterministic readiness feedback; no free text, file/upload, URL, share/export, XP, assessment/scoring or employment signal
- RP-TURN-016 Accepted at reviewed head `50a31fe910f93f8a8e065f6b58069fa73bdc5475`: historical exact replay validates the original mutation while the locked artifact returns its latest revision, payload, feedback and truthful lifecycle; database-enforced cross-intent mutation UUID uniqueness, the authenticated server-to-client allowlist and deterministic/unit/build/browser/database/security evidence passed, sealed lesson/publication bytes and digests remain unchanged and no real Clerk smoke or external resource was used
- Separate optional `measurement-monitoring` consent under `measurement-consent-contract-v1` and `alpha-measurement-monitoring-v1`; it is independent of service-data consent, never preselected and permits explicit grant, decline or withdrawal without blocking product use
- Seventh forward migration adding exactly `measurement_subjects`, `product_events` and `error_occurrences`; the fresh disposable schema has 26 tables and all three new tables use current-consent forced owner RLS, controlled database allowlists and append-only application privileges
- Provider-neutral server-only measurement/error interfaces with only a repository-local PostgreSQL adapter and disabled adapter; only newly applied explicit accepted actions may create `activation_completed` or a later-UTC-day `meaningful_return_completed`, while exact replay is distinguished server-side and never captured
- Raw mutation UUIDs are context-hashed before the exact five-field adapter boundary; owner-bound global digest uniqueness prevents retroactive replay capture across consent rotation, and unexpected action failures return fixed controlled results without forwarding or rethrowing raw messages, stacks or causes
- Measurement/error capture is non-authoritative, exact-action replay safe and fail-closed; it cannot alter accepted domain mutations, lifecycle state or user access, and no passive page view, external request, browser telemetry identifier, cookie, storage, SDK, collector or vendor was added

## Open decisions

- VPS deployment authentication and transport
- Branch protection/ruleset and CI provider/plan details
- GitHub deployment transport, artifact retention and software licensing
- Production identity provider suitability, privacy/legal/data-residency review, deletion orchestration and final credential/session operations
- Windows reverse proxy, Node service supervisor, release switching and monitoring implementation
- Managed PostgreSQL/database placement, object storage and backup placement/ownership
- Payment provider and Thailand-specific billing requirements
- External analytics/monitoring vendors, production privacy/legal suitability and telemetry retention/export/erasure periods
- Assessment question methodology and validation process
- Validated result UX, personalized priority logic, proficiency/confidence semantics and real learner recommendation rules
- Additional lesson availability, learning-efficacy evidence and external validation
- Future content-operations workflow beyond the implemented pilot Git-reviewed registry, including a database mirror, internal CMS, preview service and production publishing operations
- Exact visual identity, color, typography and Pal character system
- Localization library and translation operations beyond the native Thai-first typed route/catalog contract
- Pilot audience and recruitment method

## Current risks

- Framework scores may look scientifically precise before validation; the UI must communicate their diagnostic nature
- Fear-based acquisition may create short-term conversion but damage trust and learner wellbeing
- Building job matching too early would dilute the learning and proof loop
- Gamification can reward superficial activity unless XP is tied to practice and demonstrated capability
- Self-learning content production may become the largest operational bottleneck
- Assessment, career and employment data will require strong privacy controls
- The scaffold and localized shell prove technical and interaction foundations only; they contain no validated product flow and must not be presented as Milestone 1 user-experience progress
- The reviewed dependency graph now pins patched `nanoid 3.3.18` explicitly while preserving exact PostCSS `8.5.25` and Sharp `0.35.3`; future upstream upgrades must re-evaluate all three overrides rather than changing them silently
- Drizzle `0.45.2` declarations span unsupported optional dialects under the repository's TypeScript settings; application typechecking retains `skipLibCheck: false`, while the isolated strict database-schema project skips third-party declaration checking only
- RLS trusts a server-set transaction-local user UUID; exposing the application database credential or letting browser input set that context would break the security boundary
- Canonical server-only owner export `rise-pals-alpha-export-v1@1.0.0` with deterministic bounded reads, stable export-local references and bilingual synthetic/prototype limitations
- Operator-only erasure dry run `rise-pals-alpha-erasure-v1@1.0.0`, minimized deleted-account tombstone and an eighth no-new-table migration; the schema remains exactly 26 tables
- Disposable fresh/upgrade/backup/restore/invalid-recovery rehearsal plus a repository-local threat model and bilingual-aware alpha recovery/support runbook
- Desktop, 320 CSS-pixel and reduced-motion Chromium hardening coverage for Thai and English critical surfaces, with keyboard/focus, loopback-only network and serious/critical axe checks
- The migration/table-owner credential must remain absent from the production application environment and be supplied only to separately controlled migration tooling
- Cloud vendor region, DPA, backup deletion and cost have not been evaluated or accepted
- Clerk Development localization is experimental, Clerk's US identity hosting is approved only for synthetic alpha, and the vendor's supported Development session flow transiently uses `__clerk_handshake`; the final smoke URL was clean, but production provider/session/privacy suitability remains undecided
- RP-TURN-012 acceptance is limited to synthetic alpha and does not approve Clerk, PostgreSQL, retention/export/erasure operations or the broader privacy/session design for real users or production.
- The final RP-TURN-013 Clerk Development smoke emitted a recurring session-refresh redirect-loop warning with a generic possible key-mismatch suggestion. It did not disrupt the verified functional/session flow; the frontend-created identity was found and deleted by the Backend API, the authenticated provider subject matched the internal mapping, and logout/re-authentication/restoration passed. The diagnostic guard remains in the smoke harness, while production Clerk suitability, session behavior and provider approval remain unresolved.
- The Public repository exposes every pushed file and commit to unrestricted readers; inventory, secret/history scanning, synthetic-fixture checks and operational-document review remain mandatory for future pushes

## Next recommended action

**Project Codex review of RP-TURN-018 — Alpha Hardening and Recovery**

RP-TURN-018 is implemented on `agent/alpha-hardening-recovery` under its authorized bounded synthetic-alpha scope. Technical completion does not authorize a launch or constitute Project Codex acceptance. RP-TURN-019 remains unstarted and unauthorized.

RP-TURN-007 through RP-TURN-017 are Accepted for their documented synthetic/prototype boundaries. RP-TURN-018 adds only non-production hardening evidence: a dry-run owner export, fake-adapter/operator-only erasure, disposable recovery rehearsal, threat model, runbook and browser/accessibility regression. Standard build/check/E2E explicitly disable Clerk and allow only the exact loopback origin. Patched `nanoid 3.3.18` is pinned while PostCSS `8.5.25` and Sharp `0.35.3` remain unchanged. Production identity-provider suitability, privacy/legal review, data residency, retention/deletion-ledger/backup-expiry operations and database operations remain undecided. The private artifact remains controlled synthetic P3 state only and is not validated proficiency, a credential, external verification or a shareable portfolio. No real account/data, external telemetry, production resource, saved XP, upload/object storage/share flow, CI, production service or deployment exists.

## Turn history

| Turn | Status | Outcome |
|---|---|---|
| 000 | Complete | Initialized the Rise Pals project folder and operating documents |
| 001 | Accepted | Architecture/data/plan/local baseline, Public `noppol87/RisePals` decision, first-push security gates and canonical workflow/status/decision/template updates verified |
| 002 | Accepted | Git/Public-GitHub tooling, security review, local `main`, single `origin`, intentional initial commit/push and credential cleanup verified |
| 003 | Accepted | Minimal application scaffold, pinned Node/npm/dependencies, deterministic quality gates and security review accepted by Project Codex |
| 004 | Accepted | Thai-first localized route boundary, semantic responsive app shell, provisional design tokens, accessible primitives and Chromium/axe verification accepted by Project Codex |
| 005 | Accepted | Thai-first public narrative, two validated source-backed evidence items, honest non-collecting CTA, full product loop and 8+2 preview accepted by Project Codex |
| 006 | Accepted | Versioned synthetic assessment-domain contract with exact canonical 8+2 metadata, deterministic separate core/multiplier signals, explicit limitations and runtime validation accepted by Project Codex |
| 007 | Accepted | Accessible Thai/English six-scenario player prototype, client-safe view, versioned session-only resume and explicit no-result/privacy boundaries accepted by Project Codex |
| 008 | Accepted | Static Thai/English synthetic example result with exact canonical-fixture identity/content validation before scoring, two raw core signals, six unassessed cores, separate one-scenario +2 observations, complete limitations and a traceable planned/unavailable example practice; never reads player selections |
| 009 | Accepted | Schema-validated Thai/English local lesson prototype with synthetic source-verification content, strict runtime copy-leaf validation, memory-only three-criterion practice, deterministic 0/20 preview XP, proof placeholder and no collection or persistence accepted by Project Codex |
| 010 | Accepted | Nine-table PostgreSQL/Drizzle baseline with runtime/migration credential separation, decoded-role checks, sealed lifecycle and parent locking, complete forced-RLS matrix, reproducible disposable PostgreSQL preparation and deterministic build-to-E2E verification accepted by Project Codex; no production database or persisted learner activity |
| 011 | Accepted | Synthetic-alpha Clerk Development provider boundary, deterministic sign-in/sign-up routing, server-only internal account/profile authorization, dedicated credentialless resolver role, controlled profile/forced-RLS migration and versioned append-only service-data consent accepted by Project Codex; real-provider smoke and R3 rerun passed with every synthetic identity deleted and verified absent, patched `nanoid 3.3.18` and zero-vulnerability audits, while standard build/check/E2E remain explicitly Clerk-disabled and loopback-only |
| 012 | Accepted | Owner-scoped synthetic assessment start/save/resume/submit implementation, two-table forced-RLS migration, append-only revision/idempotency contract, deterministic/database/browser gates and the final bounded logout/re-auth/privacy/database smoke accepted by Project Codex for synthetic alpha only |
| 013 | Accepted | Reviewed head `b80c1c27902b856aac268eb7b17fbf983a62650e`: reproducible owner-scoped synthetic result, five-table forced-RLS append-only migration, deterministic policy/digests, one normal run with two core rows/cards, six unassessed cores, two multiplier observations, six explanations and one Critical Thinking priority; deterministic/browser/database/privacy gates and complete identity/disposable cleanup accepted for synthetic alpha only, with the Clerk Development session-refresh warning retained as a non-production known issue |
| 014 | Accepted | Reviewed head `e4572c02c4bbfa25f9e88b34d79d96b600da224f`: Git-reviewed trusted local MDX/JSON source bundle, independent publication seal, deterministic non-executable registry, calendar-exact evidence chronology/current-UTC expiry enforcement and immutable SHA-256 identity for one bilingual synthetic-alpha lesson; no database migration, durable lesson state or production publication |
| 015 | Accepted | Reviewed head `962b4422fa21c28b06c362f87ec55466281409e8`: owner/current-consent persisted lesson start/save/evaluate/retry flow with exact mutation replay and a DAL/PostgreSQL-enforced evaluated-failure → explicit retry draft → save/evaluate state machine; three-table forced-RLS append-only migration, server-authoritative deterministic feedback and meaningful progress events; public lesson remains static/memory-only and XP/proof remain unpersisted |
| 016 | Accepted | Reviewed head `50a31fe910f93f8a8e065f6b58069fa73bdc5475`: one private controlled synthetic source-verification artifact with demonstrated-practice eligibility, exact current consent, append-only revisions, current-state historical replay, deterministic ready/withdraw lifecycle, three-table forced-RLS migration and bilingual no-share/no-upload UI accepted by Project Codex |
| 017 | Accepted | Separate optional measurement consent, provider-neutral server-only adapters, allowlisted activation/later-day-return events, redacted errors and three-table forced-RLS first-party persistence; no external telemetry or production approval |
| 018 | Pending review | Bounded synthetic-alpha hardening with deterministic owner export, operator-only idempotent erasure, eighth no-new-table migration, disposable fresh/upgrade/backup/restore rehearsal, threat model, support runbook and Thai/English desktop/mobile/reduced-motion accessibility regression; no launch or production approval |
