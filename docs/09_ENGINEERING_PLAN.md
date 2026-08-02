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

Outcome: explainable competency profile, confidence/limitation copy and one clear recommended next step.

Gate:

- Text alternative communicates everything shown by the skill visualization
- Recommendation trace reaches scoring rule and lesson version
- No red fear gauge, fabricated risk score or hiring implication

### RP-TURN-009 — One End-to-End Lesson and Practice Prototype

Outcome: one validated micro-lesson with active decision, rubric feedback, XP rule and proof placeholder using versioned local content.

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

Gate:

- Server-side authorization, secure cookie/session behavior, logout and account-state cases pass
- Cross-user profile access is denied
- Privacy notice explains collected fields and purposes

Vendor decision required before the turn: auth provider, data region, plan/cost and identity deletion behavior.

### RP-TURN-012 — Persisted Assessment Sessions and Raw Responses

Outcome: owner-scoped start/save/resume/submit flow referencing immutable assessment/item versions.

Gate:

- Save retry is idempotent; refresh and re-authentication preserve correct state
- Submitted answers cannot be silently mutated
- Logs/analytics contain no answer payload

### RP-TURN-013 — Reproducible Scoring and Priority Recommendation

Outcome: versioned scoring runs, competency scores, explanation records and recommendations calculated from submitted responses.

Gate:

- Same input digest and scoring version produces the same output
- Re-scoring creates a new run and preserves history
- Failure states do not expose sensitive payloads

### RP-TURN-014 — Content Publication Pipeline

Outcome: validate trusted MDX/metadata/rubric/source files and publish immutable lesson versions without remote code execution.

Gate:

- Invalid framework reference, locale, rubric or evidence metadata blocks publication
- Digest/version conflicts fail safely
- Only allowlisted components render

### RP-TURN-015 — Persisted Lesson, Practice and Progress

Outcome: resumeable lesson attempts, versioned practice submissions, rubric results, progress events/snapshots and idempotent XP ledger.

Gate:

- Page viewing and demonstrated practice remain distinct
- Retried mutations cannot duplicate XP
- Historical attempts render against the original lesson/rubric version

### RP-TURN-016 — Private Evidence Artifact

Outcome: one approved proof type with owner-scoped metadata and, if needed, private object storage behind signed operations.

Gate:

- File type/size/checksum, authorization, download headers and delete behavior are tested
- Artifact is private by default; share grant is explicit, expiring and revocable
- Vendor cost, scanning and retention decisions are approved before uploads

### RP-TURN-017 — Consent-Aware Measurement and Error Monitoring

Outcome: allowlisted activation/return events and redacted operational monitoring behind adapters.

Gate:

- Event schemas reject prohibited P2/P3 fields
- Analytics honors current consent state
- Error tests prove answers, scores, proof content, tokens and signed URLs are redacted

### RP-TURN-018 — Alpha Hardening and Recovery

Outcome: complete assessment-to-practice regression suite, deletion/export dry runs, threat review, performance/accessibility audit and operational runbook.

Gate:

- Critical E2E flow passes across supported desktop/mobile projects and reduced-motion mode
- Backup/restore, migration and incident procedures are exercised in non-production
- Export is interpretable and deletion is idempotent
- Jeff approves a bounded alpha and its support/privacy process

### RP-TURN-019 — Windows VPS Infrastructure Readiness

Outcome: prepare and rehearse the confirmed Windows Server 2022 production target without making the application publicly available unless a later deployment brief explicitly authorizes launch.

This bounded turn requires fresh Jeff authorization before installing/configuring Node, reverse proxy, service wrapper, Windows services, service accounts, firewall rules, deployment credentials, monitoring or backup tooling. It does not inherit authorization from the scaffold or Git/GitHub turns.

Required gates:

- **HTTPS/reverse proxy:** selected Windows approach is installed/pinned; HTTP→HTTPS, certificate issue/renew/reload, request limits, forwarded headers and Next.js streaming are verified
- **Service supervision:** reverse proxy and Node run as separate supervised services; automatic start, graceful stop, bounded restart-on-failure and host reboot recovery pass
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
