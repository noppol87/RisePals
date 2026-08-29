# Engineering Plan

**Turn:** RP-TURN-002  
**Status:** Accepted sequence through the authorized Git/Public-GitHub foundation; later turns still require separate approval  
**Reviewed:** 2026-08-02

## Planning rules

- Each turn has one reviewable outcome and explicit out-of-scope boundaries.
- Project Codex must accept or revise the current turn before Jeff authorizes the next one.
- Milestone gates measure learner understanding and behavior, not only code completion.
- Security, privacy, accessibility, responsive behavior, Thai content and reduced motion are built into each relevant turn.
- Provider/vendor selection receives its own decision gate before credentials, cost or external resources are created.
- Migrations and content versions are append-only/reversible by default; destructive changes need a separate plan.

The sequence below records the approved order. Completion of one turn does not authorize any later turn.

## Milestone 0 — Foundation

### RP-TURN-001 — Repository Foundation and Technical Architecture

Outcome: architecture, logical data model, engineering sequence, verified local-environment baseline, communication protocol and ignore policy.

Acceptance gate:

- Project Codex confirms the recommendation maps to the documented MVP
- Jeff accepts or revises the technical direction
- Cloud vendors remain explicitly open
- No application or external resource exists

### RP-TURN-002 — Git and Public GitHub Foundation

Outcome: install verified source-control tooling, review the complete public baseline, initialize `main`, create one intentional foundation commit and push it without force to the verified empty Public repository [`noppol87/RisePals`](https://github.com/noppol87/RisePals).

In scope:

- Install current supported Git for Windows and GitHub CLI from official sources
- Verify local ancestry and remote owner, URL, Public visibility and emptiness before mutation
- Authenticate interactively without exposing tokens; configure repository-local commit identity
- Inventory every candidate file and scan both worktree and exact staged content for secrets
- Initialize `main`, add exactly one `origin`, commit the reviewed foundation and push once without force
- Verify local/remote hashes and GitHub inventory, then remove the interactive credential
- Record exact commands, results, versions, security evidence and credential cleanup

Gate:

- Git and GitHub CLI versions and official distribution verification are recorded
- destination is exactly Public `noppol87/RisePals` and contains no pre-existing ref
- initial commit contains only the reviewed foundation files and no `LICENSE` or prohibited data
- worktree and exact staged-content secret scans pass
- local `main` and `origin/main` hashes match after a non-force push
- final working tree is clean and interactive GitHub authentication is removed
- no scaffold, Node.js, dependency, CI, branch protection, service or deployment is created

### RP-TURN-003 — Application Scaffold and Quality Gates

Outcome: one Next.js App Router application at repository root with strict TypeScript, npm lockfile, lint/format/typecheck/unit-test/build scripts and CI-ready commands.

In scope:

- Install the approved Node.js 24 LTS runtime and dependencies only after Jeff authorizes the turn
- Establish `src/`, `content/`, test and configuration boundaries
- Add environment schema and `.env.example` with names and safe dummy values only
- Add one minimal health/render test; no Rise Pals product feature UI
- Work on a bounded branch and prepare reviewed changes for a pull request

Gate:

- Clean install, lint, format check, typecheck, unit test and production build pass from documented commands
- Secret scanning confirms no credentials
- Scaffold uses server-first defaults and strict TypeScript
- no CI, branch protection, VPS service, DNS, database or deployment is created unless separately authorized

## Milestone 1 — Experience Prototype

Prototype turns may use validated local fixtures. They must not create production auth, database or analytics resources.

### RP-TURN-004 — Design Foundation, App Shell and Localization

Outcome: Thai-first locale routing, semantic app shell, design tokens, typography and reusable accessible primitives with reduced-motion behavior.

Gate:

- Thai and English sample catalog resolution is tested
- Keyboard, focus, 320px/mobile, desktop, 400% zoom and reduced-motion states pass targeted checks
- No final Pal character or generated raster asset is created without its own approved art-direction scope

### RP-TURN-005 — Public Narrative and Evidence Contract

Outcome: landing narrative structure with source-backed evidence-block component and honest CTA placeholder.

Gate:

- Every rendered statistical claim validates required provenance and review date
- Copy pairs risk with a useful next action and contains no individual job-loss prediction
- Page meets performance and accessibility budgets

### RP-TURN-006 — Assessment Domain Fixtures and Scoring Contract

Outcome: typed, versioned local fixtures for a deliberately small assessment slice plus deterministic scoring/explanation tests.

Gate:

- Raw response fixtures, scoring output and explanations are separate
- Framework/competency weights and multiplier treatment follow `docs/02_SKILL_FRAMEWORK.md`
- Product/assessment reviewer approves wording and limitations; no claim of scientific validation

### RP-TURN-007 — Assessment Player Prototype

Outcome: onboarding context and accessible multi-step assessment player using local data, including resume-in-session behavior and honest progress.

Gate:

- Keyboard, screen-reader labels, validation errors and mobile interaction pass
- Refresh behavior is explicitly labeled as prototype/local if persistence is not yet durable
- Cross-step E2E flow passes in normal and reduced-motion modes

### RP-TURN-008 — Skill Map and Priority Result Prototype

Outcome: Thai/English server-rendered example result from one reviewed synthetic fixture, with transparent raw evidence coverage, complete limitations and one fixed example next practice that never uses the current user's selections.

Gate:

- Pure versioned derivation is deterministic for both reviewed fixtures and the visible example maps back to its framework, assessment, scoring model and evidence item keys
- Visible output contains only two provisional raw core signals, six explicit unassessed cores and two separate one-scenario multiplier observations
- Text alternative communicates everything shown by the skill visualization
- Example-practice trace reaches the scoring-model version, supporting item keys, target competency and a planned/unavailable lesson-version reference
- Player selections are not read or scored; no answer data enters URLs, cookies, logs, analytics or network requests
- No overall/weighted score, percentage proficiency, stage, confidence percentage, personalized priority, red fear gauge, fabricated risk score, readiness/personality or employment/hiring implication

### RP-TURN-009 — One End-to-End Lesson and Practice Prototype

Outcome: one schema-validated local micro-lesson prototype with active decision, rubric feedback, XP rule and proof placeholder using versioned local content; this is not externally validated learning content.

Gate:

- Viewing alone does not award demonstrated completion
- Practice feedback maps to a transparent rubric and an R.O.I. pillar
- Content schema, source metadata and reduced-motion alternative pass build checks

### Milestone 1 evidence gate

Pause engineering expansion for structured usability sessions. Confirm participants understand their result, accept the tone, know the next action and can complete the first practice without coaching. The pilot method, recruitment and consent require Jeff approval before contacting participants.

## Milestone 2 — Functional Alpha

### RP-TURN-010 — PostgreSQL Schema and Migration Baseline

Outcome: approved provider/local database setup, Drizzle schema and first reviewed migration for identity mapping, versioned framework/assessment and consent.

Gate:

- Migration applies to an empty test database and schema constraints are integration-tested
- Two-user isolation tests fail closed
- No real user data or production database is created unless separately authorized

### RP-TURN-011 — Authentication, Profile and Consent

Outcome: selected identity provider behind the application boundary, minimal profile and versioned consent receipts.

Implementation status: Accepted by Project Codex. Clerk Development is selected only for a synthetic Free/Hobby alpha using email verification code; the provider boundary, dedicated sign-in/sign-up routes, same-locale redirect enforcement, protected routes, internal-account authorization, credentialless resolver role, controlled profile, second migration and append-only service-data consent passed review. The bounded 2026-08-16 real Development smoke and required R3 one-identity rerun passed with one stable internal mapping, consent/profile persistence, logout denial and safe return targets; each identity and disposable PostgreSQL/build resource was deleted and verified. R3 also pins patched `nanoid 3.3.18`, restores zero-vulnerability audits and makes standard build/check/E2E explicitly secret-free even when ignored Development keys remain present.

Gate:

- Server-side authorization, secure cookie/session behavior, logout and account-state cases pass
- Cross-user profile access is denied
- Privacy notice explains collected fields and purposes

Locked alpha vendor boundary: Clerk Development, Free/Hobby, US-hosted identity data accepted for synthetic testing only, email verification code only and synthetic identity deletion before handoff when a smoke identity exists. Production vendor suitability, region/privacy/legal review and deletion orchestration remain open.

### RP-TURN-012 — Persisted Assessment Sessions and Raw Responses

Outcome: owner-scoped start/save/resume/submit flow referencing immutable assessment/item versions.

Implementation status: Accepted by Project Codex for synthetic alpha. The bounded implementation adds one third migration, only `assessment_sessions`/`assessment_responses`, exact version/consent anchoring, forced owner RLS, append-only raw-option revisions, idempotent mutation keys and a protected Thai/English start/save/resume/submit route. Deterministic code/database/browser gates pass. The final bounded real-provider smoke verified Thai sign-up/onboarding, stable account mapping, current consent/profile, start/save/correction/refresh, complete atomic/idempotent submission, immutable receipt, explicit profile logout, logged-out denial, same-identity re-authentication, safe return handling, privacy/database evidence and complete identity/build/database cleanup. RP-TURN-013 was subsequently authorized as a separate bounded turn.

Gate:

- Save retry is idempotent; refresh and re-authentication preserve correct state
- Submitted answers cannot be silently mutated
- Logs/analytics contain no answer payload

### RP-TURN-013 — Reproducible Scoring and Priority Recommendation

Outcome: versioned scoring runs, competency scores, explanation records and recommendations calculated from submitted responses.

Implementation status: Accepted by Project Codex for synthetic alpha at reviewed head `b80c1c27902b856aac268eb7b17fbf983a62650e`. The bounded implementation pins `persisted-synthetic-priority-v1@1.0.0`, adds exactly five forced-RLS append-only derived tables in one fourth migration, implements canonical input/output SHA-256 provenance and a protected explicit-generation Thai/English result route, and keeps core signals, multiplier observations, explanations and zero-or-one priority physically and semantically separate. Deterministic/unit/build/browser/client-boundary/audit gates and disposable PostgreSQL 18.4 verification pass with 17 tables. The final bounded provider smoke verified the exact result shape, logout denial, same-identity restoration and privacy boundaries; the synthetic identity was deleted and re-queried absent and every disposable resource was removed.

Gate:

- Same input digest and scoring version produces the same output
- Re-scoring creates a new run and preserves history
- Failure states do not expose sensitive payloads

### RP-TURN-014 — Content Publication Pipeline

Outcome: validate trusted MDX/metadata/rubric/source files and publish immutable lesson versions without remote code execution.

Implementation status: Accepted by Project Codex for synthetic alpha at reviewed implementation head `e4572c02c4bbfa25f9e88b34d79d96b600da224f`. Git remains the authoring source, and the pilot uses a deterministic build-time JSON registry rather than a database import. One exact bilingual `source-verification-practice@1.0.0` bundle is operationally `published` while separately `prototype-unvalidated`. Exact source and aggregate SHA-256 digests, an independently reviewed immutable publication seal, strict locale/cross-reference/source validation, calendar-exact `publicationDate <= lastVerifiedDate < reviewExpiryDate` chronology, current-UTC expiry, non-executable MDX AST parsing, allowlisted local components and idempotent publication are enforced. Failed validation/publication leaves both generated outputs byte-identical. Build/check run the read-only validator and do not mutate content. RP-TURN-015 subsequently implemented the separately Accepted bounded persisted path.

Gate:

- Invalid framework reference, locale, rubric or evidence metadata blocks publication
- Digest/version conflicts fail safely
- Only allowlisted components render

### RP-TURN-015 — Persisted Lesson, Practice and Progress

Outcome: resumable owner-scoped lesson attempts, immutable practice revisions, deterministic rubric feedback and meaningful progress events. Saved XP, progress snapshots and proof remain excluded.

Implementation status: Accepted by Project Codex at reviewed implementation head `962b4422fa21c28b06c362f87ec55466281409e8`. One fifth migration adds exactly `lesson_attempts`, `practice_attempts` and `learning_progress_events`, producing twenty tables. Separate protected localized learning/attempt routes use explicit actions, current consent, server-authoritative evaluation and forced owner RLS while the public lesson remains static and memory-only. RP-TURN-016 was authorized separately and is recorded below.

Gate:

- Page viewing and demonstrated practice remain distinct
- Retried mutations cannot overwrite history or create duplicate progress events
- Historical attempts render against the original lesson/rubric version

### RP-TURN-016 — Private Evidence Artifact

Outcome: one owner/current-consent controlled synthetic source-verification note after the exact demonstrated persisted practice. Separate protected Thai/English evidence routes support explicit start, partial save, deterministic readiness and irreversible withdrawal. The accepted public lesson/proof placeholder remains static and non-collecting.

Implementation status: Accepted by Project Codex at reviewed implementation head `50a31fe910f93f8a8e065f6b58069fa73bdc5475`. One sixth migration adds exactly `evidence_artifacts`, `evidence_artifact_revisions` and `evidence_competency_links`, producing twenty-three tables. The strict `source-verification-note-artifact-v1@1.0.0` payload contains only fixed controlled Bright River values. Revisions are append-only with exact replay/conflict provenance; all three tables force owner RLS and current consent. Ready is a synthetic structural checklist only. No free text, file/upload, object storage, share/export, XP, scoring, recommendation or employment claim exists.

Gate:

- GET creates no row; browser mutations contain no internal identifier
- Exact demonstrated owner practice, current consent, replay/conflict/concurrency and lifecycle invariants pass at DAL and PostgreSQL boundaries
- Controlled payload, privacy/client, bilingual accessibility, 320px, reduced motion, audit and forced-RLS gates pass
- Artifact remains private and non-shareable; upload/object-storage/vendor and retention/export/erasure work stays deferred

### RP-TURN-017 — Consent-Aware Measurement and Error Monitoring

Outcome: allowlisted activation/return events and redacted operational monitoring behind adapters.

Implementation status: Accepted by Project Codex at reviewed implementation head `4d6fb73e33202379401b5a72763e27a71fdecda2`. One seventh migration adds exactly `measurement_subjects`, `product_events` and `error_occurrences`, producing twenty-six tables. A separate optional versioned consent controls a pseudonymous per-grant subject. Server-only repository-local PostgreSQL and disabled adapters receive only a prehashed exact controlled candidate; a private applied/replayed/non-applied envelope limits capture to newly committed actions. Owner-bound global digest uniqueness rejects exact replay across consent rotation. Controlled unexpected failures do not forward or rethrow raw errors. No external provider, dependency, environment variable, browser tracker, production approval or accepted production retention/export/erasure operation exists.

Gate:

- Event schemas reject prohibited P2/P3 fields
- Analytics honors current consent state
- Error tests prove answers, scores, proof content, tokens and signed URLs are redacted
- Forced owner RLS, withdrawal cutoff, re-grant subject rotation, replay idempotency, later-UTC-day return and append-only restrictions pass in disposable PostgreSQL
- Thai/English profile controls pass keyboard, 320px, reduced-motion, accessibility and no-network/client-boundary checks

### RP-TURN-018 — Alpha Hardening and Recovery

Outcome: complete assessment-to-practice regression suite, deletion/export dry runs, threat review, performance/accessibility audit and operational runbook.

Implementation status: Accepted by Project Codex at reviewed head `5b21b56e2e268d794fcc8fd4b55d79ecaaca9c80` for the bounded synthetic-alpha contract. The change adds a server-only canonical export, operator-only synthetic erasure, eighth no-new-table migration, disposable fresh/upgrade/backup/restore/invalid-recovery rehearsal, desktop/320px/reduced-motion browser projects, threat model and bilingual-aware support/recovery runbook. These remain non-production dry-run evidence and do not authorize launch or real-user collection. Production retention, deletion ledger, backup expiry, restore reconciliation, legal/privacy/provider suitability, RTO/RPO and staff/operator access remain open. No real Clerk smoke, user, production resource, dependency, CI, infrastructure or deployment is included. RP-TURN-019 was separately authorized on 2026-08-24.

Gate:

- Critical E2E flow passes across supported desktop/mobile projects and reduced-motion mode
- Backup/restore, migration and incident procedures are exercised in non-production
- Export is interpretable and deletion is idempotent
- Jeff approves a bounded alpha and its support/privacy process

### RP-TURN-019 — Windows VPS Infrastructure Readiness

Outcome: prepare and rehearse the confirmed Windows Server 2022 production target without making the application publicly available unless a later deployment brief explicitly authorizes launch.

Implementation status: R3 repository-only prototype complete pending Project Codex review on `agent/windows-vps-infrastructure-readiness`. The original bounded work proved provenance, exact release inventories, loopback Caddy TLS/limits/streaming, independent restart, canary isolation, forward switch, failed-candidate automatic rollback, manual rollback and local certificate reissue. Default WinSW stop first truncated the synchronized stream; the later local-drain design remained Stop Pending and required exact-PID forced recovery. Project Codex Accepted the recovery and residue cleanup, not graceful stop or WinSW production supervision. Final accepted host state remains both services Stopped/Disabled at PID 0, all original stalled processes and relevant listeners absent, enabled Rise Pals firewall rules zero, drain/canary absent and raw captures deleted unread with zero residue. No reboot, public mutation or deployment occurred. Do not run another WinSW live rehearsal.

R2 compared five paths across sixteen criteria. D-027 selected Option B for R3's deliberately small repository-owned self-contained .NET 10 LTS Windows service-host prototype with explicit SCM Stop/Shutdown/Preshutdown handling, private drain, bounded checkpoints, suspended Job-owned Node launch and finite restart. This preserves the direct `Stop-Service` gate in the modeled contract. Deployment-orchestrated two-slot Caddy blue/green drain remains unauthorized fallback only if Project Codex explicitly changes that gate; used alone it does not guarantee manual-stop, crash or reboot drain. WinSW redesign, IIS/ARR/HttpPlatformHandler and Shawl remain rejected for this MVP. Details and primary sources are in `docs/14_WINDOWS_SERVICE_SUPERVISION_DECISION.md`.

The repository-only prototype is authorized and implemented, but not yet Accepted. It uses portable SDK 10.0.400/runtime 10.0.11, locked Microsoft-only test dependencies, 37 passing tests and byte-identical self-contained publication. The executable is not Authenticode-signed. A host rehearsal requires a later exact authorization after repository review, signing remains a launch blocker and a controlled reboot remains prohibited until a separately authorized candidate passes every live non-reboot stop/stream/crash/orphan gate. RP-TURN-020 remains unauthorized.

Required gates:

- **HTTPS/reverse proxy:** selected Windows approach is installed/pinned; HTTP→HTTPS, certificate issue/renew/reload, request limits, forwarded headers and Next.js streaming are verified
- **Service supervision:** reverse proxy and Node run as separate supervised services; automatic start, graceful stop, bounded restart-on-failure and host reboot recovery pass
- **SCM state correctness:** direct stop reports bounded Stop Pending checkpoints and Stopped only after graceful child exit or verified explicit-timeout cleanup; no wrapper or process remains orphaned
- **Least privilege:** application, proxy and deployment identities have documented exact path/network rights; application does not run as Administrator/LocalSystem without an approved exception
- **Firewall:** external scan confirms only approved public ports; Node/database remain loopback/private and administration access is restricted
- **Secrets:** runtime/deployment secrets stay outside Git, workspace and releases; ACL, rotation and revocation are exercised without exposing values
- **Release separation:** workspace, staging, versioned releases, active-release switch, persistent data/uploads, secrets and logs are distinct; active release is not edited in place
- **Deployment/rollback:** checksum/source ID verification, readiness gate, external HTTPS smoke test, failed deployment and last-known-good rollback are rehearsed
- **Logs/monitoring:** redaction tests pass; rotation/retention/disk alerts, liveness/readiness, certificate expiry and service restart alerts have an owner
- **Database connectivity:** TLS and separate least-privilege application/migration roles are proven; no public database port or production data is introduced during rehearsal
- **Backup/restore:** named owner, encrypted off-host locations, retention/alerts and non-production restore drills cover database, uploads, configuration/certificates and host recovery
- **Operations:** Windows/Node/proxy patch cadence and incident response/secret rotation/evidence preservation are documented and rehearsed

Only after this gate and a separate production-deployment authorization may DNS, public traffic or real user data be introduced.

## Milestone 3 — Thai Pilot

Pilot work should be planned after Milestone 2 evidence. Likely independent turns include:

1. Pilot competency/lesson-set expansion based on validated content operations
2. Research consent, interview workflow and assessment/rubric calibration
3. Activation and return-loop iteration from observed evidence
4. Accessibility, privacy and security remediation
5. Pilot closeout with measured product and content decisions

Paid beta, billing, employer features and opportunity matching remain outside this plan until their roadmap gates are met.

## Smallest useful test pyramid

### Static gates — every implementation turn

- TypeScript strict typecheck with no unreviewed suppressions
- ESLint plus framework/security/accessibility rules
- Formatter check and generated-file drift check
- Content/schema validation and secret scan
- Production build

These checks are fast and must run on every pull request after CI exists.

### Unit/domain tests — broadest automated layer

Use Vitest for pure business behavior:

- framework weight and version invariants
- assessment state transitions and item validation
- scoring input digest, deterministic results, confidence/limitation rules and explanations
- recommendation ranking and tie behavior
- progress state, XP idempotency and no reward for passive viewing
- consent state, export selection and deletion orchestration
- analytics allowlist/redaction

Aim for risk coverage rather than a global coverage percentage. Scoring, authorization helpers, ledger rules and content validators require branch/edge-case tests.

### Component and accessibility tests

Use Testing Library in a browser-like environment for:

- semantic names, descriptions, errors and live feedback
- keyboard behavior, focus restoration and step navigation
- Thai text expansion/line breaking and locale fallback
- full/reduced motion state decisions
- charts/skill maps with accessible text equivalents

Automated axe checks catch common issues but do not replace keyboard and screen-reader-oriented review.

### Database integration tests

Run against disposable PostgreSQL after the database turn:

- forward migration from empty database
- constraints, transactions and idempotency
- two-user owner isolation in Data Access Layer and RLS policies
- immutable published versions and historical references
- export/deletion behavior and analytics separation

Mocking the ORM is not evidence that database authorization or constraints work.

### End-to-end tests — narrow critical journeys

Use Playwright for:

1. landing → onboarding → assessment → result → first lesson → practice → progress
2. save/resume after refresh and fresh sign-in
3. owner versus cross-user access denial
4. proof create/private/share/revoke when that feature exists
5. consent withdrawal and account export/delete request states

During prototype, run critical Chromium mobile/desktop projects per pull request and Firefox/WebKit in scheduled or milestone-gate suites. Before alpha, run the critical flow on all supported engines and include reduced-motion emulation.

## Proposed quality commands

These scripts do not exist yet and were not run through RP-TURN-002. RP-TURN-003 should create and verify the final names:

```powershell
npm ci
npm run format:check
npm run lint
npm run typecheck
npm run test
npm run test:integration
npm run test:e2e
npm run content:validate
npm run build
```

For a normal pull request, static/unit/component/content/build checks are required. Integration and critical E2E checks become required as soon as their infrastructure exists. A command may be omitted only when the turn documents why it is irrelevant; it may never be reported as passed without execution.

## Definition of done for a turn

- Approved scope and acceptance criteria are met without starting the next turn
- User and failure states are implemented at the same risk level as the happy path
- Relevant privacy, security, accessibility, localization, responsive and reduced-motion behaviors are verified
- Tests were run and exact results are reported
- Dependencies and material decisions are documented
- No secret, raw sensitive fixture or personal data entered source control/logs
- `PROJECT_STATUS.md` reflects only factual changes
- Handoff begins with the required source/destination/message envelope and identifies exact review focus

## Repository and change workflow

- Jeff approved the Public personal-account repository `noppol87/RisePals` as canonical source/history and authorized its verified empty-repository baseline in RP-TURN-002.
- The direct initial push to `main` is a one-time empty-repository exception; future implementation work uses one bounded branch and reviewed pull request per turn.
- Add a protected main branch/ruleset only after scaffold checks exist and Jeff separately authorizes the repository controls.
- Commit application code, lockfile, migration SQL, content source, test fixtures using synthetic data and decision documentation.
- Never commit `.env*` except a reviewed safe `.env.example`, credentials/tokens/private keys, secret-bearing production configuration, database dumps, uploads/proof artifacts, assessment answers/personal data, generated production data, Playwright auth state, private logs/production telemetry, certificate private keys or backup artifacts.
- GitHub stores source/history and CI evidence, not database/upload/system backups or production secret/log storage.
- Review all documentation for operationally sensitive content before public push, and do not add a `LICENSE` until Jeff makes a separate licensing decision.
- The VPS repository workspace, staging area and versioned served releases are separate. Build outside the active release and activate an immutable artifact only after checks.
- Database changes are forward migrations reviewed with the application change. Destructive migration is split into expand/migrate/contract turns.
- Published content/framework versions are not edited in place; add a version and retire the old one.

## Architecture and dependency change control

Create a decision-log entry when a change affects the main framework/runtime, persistence model, identity ownership, data collection, provider/cost, scoring philosophy, content execution or deployment shape. A package upgrade within an already accepted choice normally needs test evidence, not a new product decision.

Before adding a dependency, record:

- problem it solves and why platform/local code is insufficient
- runtime/client bundle impact
- maintenance activity and security posture
- license and data/network behavior
- replacement/removal path

## Milestone evidence register

At each milestone gate, Project Codex should check six workstreams from the roadmap:

| Workstream | Minimum evidence |
|---|---|
| Product and UX | Usability observation, funnel completion and next-step comprehension |
| Assessment science | Versioned method, limitations, calibration findings and challenge/correction path |
| Curriculum/content | Lesson contract validation, reviewer evidence, practice and proof quality |
| Engineering/data | Test/build results, migration/data-isolation evidence and operational risks |
| Brand/growth | Thai-first tone, evidence provenance and absence of fear/dark patterns |
| Privacy/safety/governance | Consent, minimization, export/delete, threat/accessibility review |

The gate can pass only on actual evidence. A finished screen or high self-reported score is not sufficient by itself.
