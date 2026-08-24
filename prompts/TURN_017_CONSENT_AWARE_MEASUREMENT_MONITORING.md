# RP-TURN-017 — Consent-Aware Measurement and Error Monitoring

## Authorization

- Authorized by Jeff through Project Codex on 2026-08-24.
- Base: `a34773064f6a6f6b7eccf260af7be4e88521668f`.
- Branch: `agent/consent-aware-measurement-monitoring`.
- Draft PR title: `feat: add consent-aware measurement monitoring`.
- This turn is limited to a first-party, repository-local, synthetic-alpha foundation. It does not select or contact an external analytics or monitoring provider.

## Objective

Implement optional, separately versioned measurement-and-monitoring consent; provider-neutral server-only measurement and redacted-error adapters; a PostgreSQL adapter plus safe disabled adapter; a tightly allowlisted activation/meaningful-return contract; redacted operational error occurrences; forced-RLS persistence; and an accessible bilingual protected-profile control.

Measurement and monitoring are non-authoritative side effects. They must never alter product results, timestamps, lifecycle state, replay behavior or access to assessment, results, lessons, practice, progress, profile or private evidence.

## Required preparation and sequencing

1. Read the repository instructions, product/scope, architecture, data model, engineering plan, local-development guide, decision log and handoff template.
2. Confirm clean `main` at the authorized base.
3. Create this brief and commit it before implementation.
4. Open one Draft PR targeting unchanged `main`.
5. Implement, verify, document and push only on the authorized branch without force.
6. Keep the PR Open, Draft and unmerged. Do not begin RP-TURN-018.

## Decision D-024

### Separate optional consent

- Add a new measurement-and-monitoring purpose and notice version; do not reuse or modify the accepted service-data purpose/notice.
- Consent is optional, independent, never preselected and supports explicit grant, decline and withdrawal.
- Thai and English copy must state the exact allowed fields and that declining/withdrawing does not block product use.
- Consent evidence uses deterministic purpose/notice versions and proof digest.
- Capture fails closed when consent is absent, declined, withdrawn, stale or malformed.

### Provider-neutral server-only adapters

- Define narrow server-only interfaces for product measurement and redacted error occurrence reporting.
- Implement only a repository-local PostgreSQL adapter and a safe disabled/no-op adapter.
- Do not install or contact PostHog, Sentry, OpenTelemetry collectors or any external provider.

### Product event allowlists

Only these event classes are valid:

- `activation_completed`
- `meaningful_return_completed`

Only these surfaces are valid:

- `assessment`
- `result`
- `lesson_practice`
- `private_evidence`

Rules:

- Capture follows a successful explicit persisted domain action only.
- Passive GET/page view/refresh/navigation/language switch/sign-in view creates no event.
- Meaningful return requires an earlier activation and a successful explicit action on a later UTC calendar date.
- Exact action replay is idempotent; failed/denied mutations create no success event.
- Persistence failure never rolls back or changes the authoritative domain mutation.
- Do not infer or store marketing attribution, engagement/proficiency, employment risk or recommendation data.

### Redacted error occurrence allowlist

An occurrence may contain only:

- schema version;
- opaque correlation UUID;
- controlled operation and surface codes;
- locale;
- controlled error category and severity;
- retryable boolean;
- UTC occurrence time;
- optional context-bound SHA-256 mutation digest.

It must never contain exception messages/stacks, raw URLs/query/referrers, network/device identifiers, identity/authentication data, tokens/cookies/signed URLs, profile fields, assessment/scoring/result content, lesson/practice/progress content, evidence content, free text/arbitrary JSON, raw mutation UUIDs, SQL/database values or environment secrets.

Unexpected-error reporting preserves existing safe user-facing behavior. Reporter failure must not mask or broaden the original controlled outcome. No debug/error route is authorized.

## Database contract

Add one forward migration containing exactly:

- `measurement_subjects`
- `product_events`
- `error_occurrences`

The fresh schema must have exactly seven migrations and twenty-six tables.

All three tables use UUID identities and forced RLS. Subjects are owner-scoped and tied to the exact granted measurement consent receipt. Events/errors reference only a pseudonymous subject, never provider identity or email. Payloads use explicit database allowlists. Occurrences are append-only and normal application roles cannot update/delete them. Current consent is required at capture time; withdrawal stops capture immediately; re-grant creates a new subject. Owner/context/consent failures fail closed. Direct SQL cannot bypass field allowlists. Exact mutation replay cannot duplicate a product event. Retention/export/erasure remain open.

Use the trusted transaction-local authorization boundary. Do not weaken forced RLS or grant unrestricted migration-owner reads.

## Protected profile experience

Add a separated Thai/English measurement-and-monitoring consent section that:

- displays current status accurately;
- offers explicit grant, decline and withdrawal actions;
- uses non-coercive copy and accessible keyboard/screen-reader semantics;
- works at 320 CSS pixels and respects reduced motion;
- exposes no measurement subject/row IDs, history, correlation values or digests in props/HTML.

No analytics dashboard, staff UI, history viewer or export UI is authorized.

## Instrumentation boundary

Instrument only existing accepted server-side persisted flows needed to prove the event contract. Preserve assessment scoring and multiplier separation, priority policy/digests, publication bundles/seals/registries/digest, lesson evaluation, persisted state machines, private-evidence payload/lifecycle, identity-provider behavior and public lesson memory-only behavior.

## Acceptance criteria

### Consent

- Accepted service-data consent identifiers, copy and proof digest remain byte-identical.
- Measurement consent is separate, deterministic and versioned.
- Default/decline/withdrawal and service-only grant create no measurement/error rows.
- Grant enables only authorized capture; withdrawal stops capture without blocking product use; re-grant rotates the pseudonymous subject.

### Measurement

- Only the two event classes and four surfaces are accepted.
- Explicit successful actions produce deterministic events; passive reads produce none.
- Replay is idempotent; conflicts/denials/validation failures create no success events.
- Later-UTC-day meaningful return uses an injectable deterministic clock.
- Measurement failure cannot change authoritative mutation outcome.

### Error monitoring

- Prohibited P2/P3 fields are rejected by TypeScript, DAL and PostgreSQL.
- Sanitizer coverage includes nested values, arrays, `Error`, URLs, token-like values and unexpected keys.
- Storage contains only controlled fields and no raw payload/message/stack/metadata.
- Reporter failure preserves the original controlled behavior.

### Privacy and authorization

- Forced-RLS owner isolation passes on all three tables.
- Missing/malformed/stale/cross-owner contexts fail closed.
- Application roles cannot update/delete occurrences.
- No telemetry identifiers/payloads reach client props/chunks.
- No external request, tracking cookie, browser storage, beacon, pixel or third-party script is introduced.

## Required verification

Run and report actual results for:

- `npm ci`, pending install-script query and strict-allow-scripts policy;
- formatting, lint, strict typecheck, focused and complete unit/component tests;
- production build, `npm run check`, Chromium E2E and focused Thai/English consent browser tests;
- disposable PostgreSQL 18.4 integration;
- production and full npm audits;
- strict UTF-8 without BOM, Markdown fences, unresolved/conflict markers and `git diff --check`;
- client manifest/chunk inspection;
- publication byte/digest and scoring policy/digest preservation;
- Gitleaks worktree, exact staged content, proposed history and pushed history;
- local/origin/public feature hashes, unchanged main and clean final worktree.

PostgreSQL verification must prove exactly seven migrations/twenty-six tables, forced RLS, allowed inserts, current-consent enforcement, owner isolation, append-only enforcement, schema/field rejection, replay idempotency, withdrawal cutoff, subject rotation and complete disposable cleanup.

Ordinary browser/automated gates remain Clerk-disabled and loopback-only. `.env.local` must not be read, displayed or modified. A real Clerk smoke is neither authorized nor required.

## Documentation

- Record the decision as D-024 in `docs/DECISION_LOG.md`.
- Update architecture, data model, engineering plan and local-development documentation only where facts change.
- Update `PROJECT_STATUS.md` only with established Turn 017 facts.
- Preserve synthetic-alpha, prototype-unvalidated and public-history security wording.
- Do not claim production readiness, legal approval, validated proficiency or external monitoring coverage.

## Explicitly out of scope

- External analytics/monitoring vendors, SDKs, collectors or outbound telemetry.
- Marketing analytics, attribution, funnels, experiments, raw page/click tracking, cookies or fingerprinting.
- Saved XP/gamification, free text/file evidence, uploads/object storage, sharing/external verification.
- Retention/export/erasure implementation, staff/admin analytics.
- Real users/data, production Clerk/PostgreSQL/secrets/resources.
- CI, infrastructure, reverse proxy, Windows service or deployment.
- RP-TURN-018.

## Dependency and configuration boundary

No dependency, package/lockfile change, environment variable, credential or external configuration is authorized. If a genuine blocker requires one, stop for Project Codex approval.

## Required handoff

Use `prompts/VS_CODE_HANDOFF_TEMPLATE.md` and include outcome; exact file/commit/tree inventory; migration/table totals; consent purpose/notice/schema versions; all allowlists; actual commands/results; client/privacy and preservation evidence; Git/GitHub hashes and Draft PR state; limitations/open production decisions; confirmation that `.env.local` was not read/modified; and confirmation that no external telemetry, CI, infrastructure, deployment or RP-TURN-018 work occurred.
