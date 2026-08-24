# RP-TURN-018 — Alpha Hardening and Recovery

**Source:** Project Codex  
**Destination:** VS Code Codex  
**Message type:** Turn authorization  
**Authorization date:** 2026-08-24  
**Authorized base/main:** `6ee0080253e97a935172296a2307d701113363fd`  
**Authorized branch:** `agent/alpha-hardening-recovery`  
**Draft PR title:** `chore: add alpha hardening and recovery`

## Objective

Harden the accepted synthetic-alpha product loop and prove non-production recovery, owner export and idempotent erasure behavior without introducing real users, production resources, CI, infrastructure or deployment.

This turn must produce an evidence-backed alpha-readiness decision package. Completion or acceptance of this turn does not authorize a public launch, real-user collection or VPS deployment.

## Required preparation

1. Read `AGENTS.md`, `README.md`, `PROJECT_STATUS.md`, `docs/01_PRODUCT_VISION.md`, `docs/02_SKILL_FRAMEWORK.md`, `docs/03_MVP_SCOPE.md`, `docs/07_TECHNICAL_ARCHITECTURE.md`, `docs/08_DATA_MODEL.md`, `docs/09_ENGINEERING_PLAN.md`, `docs/10_LOCAL_DEVELOPMENT.md`, `docs/DECISION_LOG.md` and `prompts/VS_CODE_HANDOFF_TEMPLATE.md`.
2. Confirm clean `main` at the exact authorized base.
3. Create this brief and commit it before implementation.
4. Create the authorized feature branch and one Draft PR against unchanged `main`.
5. Do not merge the PR or begin RP-TURN-019.

## Authorized scope

### A. Critical synthetic-alpha regression

Implement a deterministic full-flow regression covering:

- Thai and English protected entry;
- onboarding and current service-data consent;
- persisted assessment start, correction, submission and immutable receipt;
- deterministic scoring with separate core and multiplier outputs;
- zero-or-one priority recommendation;
- persisted lesson start, save, evaluation, explicit retry and demonstrated state;
- controlled private evidence start, save, ready and withdrawal;
- optional measurement grant, decline, withdrawal and re-grant;
- activation and later-UTC-day-return measurement behavior;
- logged-out denial and cross-owner isolation.

Use only repository-controlled synthetic identities and disposable PostgreSQL. Ordinary automation must remain Clerk-disabled and loopback-only. No real Clerk smoke is authorized.

### B. Owner export dry run

Add a server-only, schema-versioned canonical export contract:

`rise-pals-alpha-export-v1@1.0.0`

The export must be deterministic, owner-scoped and interpretable. It may contain only:

- minimized account lifecycle and controlled profile values;
- consent purpose, notice, action and timestamps;
- assessment sessions and raw selected-option revisions;
- reproducible scoring outputs, limitations and version references;
- lesson/practice/progress state and feedback;
- controlled private-evidence state and revisions;
- allowed product measurement events;
- framework, assessment, scoring, lesson and policy identifiers/digests required to interpret the records;
- a Thai/English human-readable manifest explaining synthetic-alpha and prototype-unvalidated limitations.

The export must exclude:

- another owner's rows;
- provider subjects, tokens, cookies, session values or credentials;
- measurement subject IDs and action/mutation digests;
- error occurrence correlation values and internal operational/security logs;
- database credentials, SQL values, environment variables and arbitrary metadata;
- unpublished licensed content or repository source files;
- claims of validated proficiency, employment suitability or legal completeness.

Use stable export-local references instead of exposing internal database UUIDs where relationships must be represented.

Export files may exist only under a uniquely created, verified directory beneath `%TEMP%\risepals-alpha-recovery`. Never print P2/P3 payload contents, commit an export or leave an artifact after verification.

### C. Synthetic owner-erasure dry run

Implement an operator-only, non-production erasure contract:

`rise-pals-alpha-erasure-v1@1.0.0`

Add one forward migration. The fresh database must contain exactly eight migrations and remain at twenty-six tables.

The migration may extend `user_accounts` only with:

- `deletion_request_id` UUID nullable and unique;
- `deletion_requested_at` `timestamptz` nullable;
- constraints tying these fields to `deletion_pending`/`deleted` lifecycle states.

Use the existing `deleted_at` field for completion. Do not add a new application-data table.

A narrowly scoped privacy-operator database boundary may be added only if it:

- uses a dedicated `NOLOGIN`, `NOINHERIT` and `NOBYPASSRLS` role;
- owns no application table;
- is inaccessible to `PUBLIC`, the application role, migration runtime, browser and identity resolver except through the exact separately controlled maintenance path;
- accepts only an internal owner UUID and opaque deletion-request UUID;
- enforces forced RLS and exact owner context;
- cannot target public framework/content definition rows;
- cannot be invoked from application routes or client code.

The erasure sequence must:

1. create an explicit `deletion_pending` state;
2. require a matching opaque request UUID;
3. delete all owner-linked P2/P3 assessment, scoring, lesson, evidence, measurement, profile, consent and external-identity records in deterministic dependency order;
4. retain only a minimized `user_accounts` tombstone with status `deleted`, request/timing fields and no provider/profile/content data;
5. make the deleted identity unresolvable and product access fail closed;
6. make exact replay mutation-free and idempotent;
7. reject cross-owner, conflicting-request, malformed, missing-context and unauthorized execution;
8. prove that another synthetic owner and every public definition/version/digest remain unchanged.

No user-facing deletion button, staff/admin UI, production operator credential or real identity-provider deletion is authorized. Provider-session revocation/deletion must remain an adapter contract exercised only with a fake deterministic adapter.

### D. Backup, restore and migration recovery rehearsal

Using only the pinned disposable PostgreSQL toolchain:

- create and seed a synthetic disposable database;
- apply all eight migrations from empty;
- prove migration from the accepted seven-migration state;
- create a database backup under the bounded temporary recovery directory;
- restore into a separate disposable database;
- verify migration journal, twenty-six-table inventory, forced-RLS policies, roles, constraints, publication identities/digests, scoring policy/digests and owner row counts;
- run export before erasure;
- run erasure and its exact replay;
- exercise at least one deliberately interrupted or invalid restore/migration path and prove fail-closed cleanup;
- document that restoration of a pre-erasure production backup could resurrect deleted data and remains blocked until a separately approved deletion-ledger/backup-expiry policy exists.

Do not create a production backup, durable database, scheduled job, Windows service or off-host storage resource.

### E. Threat review

Create a repository-local threat model covering at least:

- browser, Next.js server, identity provider, application role, migration role, privacy operator, PostgreSQL, Git/public history and temporary recovery artifacts;
- IDOR/cross-owner access and RLS bypass;
- CSRF, XSS, malicious locale/redirect/input values;
- replay, concurrency and idempotency abuse;
- scoring/content/version tampering;
- sensitive logging and error leakage;
- export scope confusion, path traversal and leftover temporary files;
- over-broad erasure and unauthorized operator execution;
- backup theft, restore resurrection and incomplete deletion;
- secret exposure and supply-chain/public-history risks;
- the retained non-production Clerk session-refresh warning.

Record mitigations, verified evidence, residual risk, owner/decision status and explicit stop conditions. Do not claim legal approval or production readiness.

### F. Accessibility and performance hardening

Exercise critical Thai and English flows using:

- desktop Chromium;
- mobile viewport including 320 CSS pixels;
- keyboard-only interaction;
- reduced-motion mode;
- axe accessibility checks.

Required accessibility result:

- zero serious or critical axe findings;
- correct focus movement, accessible names, announcements, error association and no keyboard trap;
- no horizontal overflow at 320 CSS pixels;
- Thai and English content remain readable and structurally equivalent.

Performance must use deterministic non-regression evidence:

- no unexpected third-party request;
- no new tracker, beacon, cookie or browser persistence;
- record accepted-base client-route/chunk byte baselines before implementation;
- production route/client bytes must not regress unless a narrowly documented hardening correction is necessary;
- any authorized correction must remain within a five-percent route-byte increase and include exact rationale;
- database checks must reject unbounded owner-data reads and prove bounded query behavior for export.

Do not add Lighthouse, an external performance service or another dependency merely to produce a score.

### G. Alpha recovery and support runbook

Create a bilingual-aware operational runbook covering:

- synthetic-alpha start/stop criteria;
- support triage without requesting sensitive payloads through chat;
- controlled incident classification and escalation;
- safe redacted diagnostic collection;
- export and erasure dry-run procedure;
- backup/restore and migration recovery;
- temporary-artifact cleanup;
- identity/session incident handling;
- credential rotation/revocation procedure without exposing values;
- known blockers for real-user or production use;
- explicit statement that RTO, RPO, retention periods, legal basis, provider suitability and staff access remain undecided.

The runbook must not contain credentials, real personal data, production host configuration or commands that target an unverified broad path.

## Decision record

Add D-025 documenting:

- the bounded synthetic-alpha hardening/recovery contract;
- canonical export and erasure versions;
- minimized deleted-account tombstone;
- operator-only/no-production erasure boundary;
- backup/restore evidence;
- accessibility/performance evidence;
- remaining restore-resurrection, retention, legal, provider and production blockers.

Do not mark D-025 Accepted before Project Codex review.

## Acceptance criteria

- Full synthetic assessment-to-practice flow passes in Thai and English.
- Desktop, mobile, keyboard and reduced-motion projects pass.
- Export is deterministic, owner-only, structurally interpretable and contains no prohibited field.
- Exporting the same unchanged state twice is byte-identical.
- Erasure removes the exact owner's private records, preserves another owner and public definitions, disables future resolution and is idempotent.
- Application and resolver roles cannot invoke erasure.
- Forced RLS remains enabled and enforced.
- Fresh and seven-to-eight migration paths pass.
- Backup/restore rehearsal passes entirely in disposable PostgreSQL.
- Failed recovery paths leave no unverified partial resource.
- Threat model and runbook explicitly record all open production blockers.
- Publication bundle/seal/registry bytes and aggregate digest remain unchanged.
- Assessment/scoring policy and digests remain unchanged.
- No saved XP, file proof, upload, sharing or employment inference is introduced.
- No temporary export, dump, database, process, service, listener or credential remains after verification.

## Required verification

Run and report actual results for:

- `npm ci`;
- pending install-script query and strict-allow-scripts policy;
- format, lint and strict typecheck;
- focused export/erasure/recovery tests;
- complete unit/component tests;
- production build and `npm run check`;
- multi-project Chromium E2E including focused Thai/English recovery/accessibility flows;
- disposable PostgreSQL integration;
- backup/restore and seven-to-eight migration rehearsal;
- production and full npm audits;
- strict UTF-8 without BOM;
- Markdown fences and unresolved/conflict-marker scans;
- PowerShell AST checks for recovery scripts;
- `git diff --check` and staged diff check;
- client manifest/chunk and outbound-network inspection;
- publication and scoring byte/digest preservation;
- P2/P3 log/output scan;
- Gitleaks worktree, exact staged content, proposed history and pushed history;
- local/origin/public feature hashes, unchanged main and clean final worktree;
- complete disposable-resource and temporary-artifact cleanup.

## Security and environment boundary

- `.env.local` must remain ignored and untracked and must not be read, displayed or modified.
- No real Clerk identity or provider smoke is authorized.
- No production database, backup, telemetry provider or external resource is authorized.
- No secrets may enter command output, logs, fixtures, export bundles, documentation, Git or the PR.
- No new dependency is authorized. `package.json` may change only for bounded repository scripts; `package-lock.json` must remain unchanged unless an approved dependency decision is requested.
- If a genuine blocker requires a dependency, external service, production credential, legal decision or broader data-model change, stop and request Project Codex review.

## Explicitly out of scope

- Real users or real personal/career data.
- Public or production alpha launch.
- Production Clerk/PostgreSQL/provider approval.
- Final legal basis, privacy notice or retention schedule.
- External analytics/error monitoring.
- Production backup/off-host storage.
- Uploads, object storage, free-text/file proof or sharing.
- Saved XP, gamification, payments or employer features.
- CI, branch protection, infrastructure, reverse proxy, Windows services or deployment.
- RP-TURN-019.

## GitHub workflow

- Work only on `agent/alpha-hardening-recovery`.
- Commit this authorization brief before implementation.
- Open one Draft PR against unchanged `main`.
- Do not force-push, force-merge or merge the PR.
- Keep Jeff-authorized GitHub development authentication without displaying credential details.
- Final worktree must be clean.
- RP-TURN-019 must remain unstarted and unauthorized.

## Required handoff

Use `prompts/VS_CODE_HANDOFF_TEMPLATE.md`.

Report:

- outcome and whether any acceptance decision remains;
- exact files, commits and tree;
- migration/table totals and exact schema changes;
- export/erasure contract versions and allowed/excluded fields;
- erasure counts, idempotency and cross-owner preservation evidence without displaying P2/P3 values;
- backup/restore and migration evidence;
- accessibility/performance results;
- threat/runbook documents and residual risks;
- every actual command and result;
- publication/scoring preservation;
- Git/GitHub state and Draft PR URL;
- disposable cleanup counts;
- confirmation that `.env.local` was not read or modified;
- confirmation that no real identity, production resource, CI, infrastructure, deployment or RP-TURN-019 work occurred.

Return the completed or partial handoff to Project Codex for review. Do not interpret technical completion as authorization to launch an alpha.

