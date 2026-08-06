# RP-TURN-011 — Authentication, Profile and Consent

Repository root:
`C:\Codex PC SG2\Jeff\risepals`

Authorized base:
`55037ba8080180623960d1a17eba43fb3c936b4a`

Authorized branch:
`agent/auth-profile-consent`

## Objective

Establish a server-authorized Clerk Development authentication boundary, an internally owned account/profile model, and a versioned service-data consent flow for synthetic alpha testing without creating production identity, database, infrastructure, or learner data.

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
- The accepted RP-TURN-010 schema, migration, database boundary, preparation scripts, disposable PostgreSQL harness, and tests

## Locked alpha identity decision

- Clerk is selected only for synthetic alpha development.
- Use a Jeff-controlled Clerk Development application on the Free/Hobby plan without payment information or paid features.
- Email verification code is the only permitted authentication method.
- Clerk identity data is US-hosted; this is accepted only for synthetic alpha tests.
- Real users and real personal or career data are prohibited.
- Production suitability remains undecided pending separate privacy, legal, residency, security, and vendor review.
- Synthetic Clerk test identities must be deleted before handoff.
- Do not create, activate, or configure a Clerk Production instance.

## In scope

### Provider boundary and configuration

- Define an internal `IdentityProvider` contract and a Clerk adapter.
- Keep Clerk SDK imports inside provider/server integration modules.
- Accept only Clerk development keys (`pk_test_` and `sk_test_`) from ignored local environment configuration, fail closed on live or incomplete key pairs, and never print secrets.
- Use Clerk Thai localization for `/th` and English for `/en`; document its experimental status and cover visible fallback copy.
- Preserve Clerk-managed sessions. Do not add custom auth cookies or store tokens manually.

### Identity resolution and authorization

- Treat a validated Clerk subject only as an external identity lookup key.
- Resolve the provider subject to internal `user_accounts.id` before setting `app.current_user_id`.
- Add one narrowly scoped, concurrency-safe database resolve-or-provision boundary available only to the normal application role after server session validation.
- Provision `user_accounts` and `external_identities` atomically and prevent one provider subject from resolving to multiple accounts.
- Centralize server-only session, account-state, and authorization checks in the DAL.
- Permit active accounts; fail closed for suspended, deletion-pending, deleted, absent, invalid, and expired sessions.
- Protect profile, onboarding, and consent reads/mutations close to the database transaction.
- Validate locale-preserving return paths and reject open redirects.
- Implement logout and verify protected data becomes unavailable afterward.

### Profile and database migration

- Add exactly one forward migration after `0000`.
- Add `user_profiles` with canonical fields: `user_id`, `preferred_locale`, `timezone`, `role_family`, `function`, `experience_band`, `goals`, `onboarding_completed_at`, `profile_schema_version`, and `updated_at`.
- Use only versioned controlled codes, including an `other` code with no associated free-text field.
- Treat goals as sensitive career data.
- Prohibit employer name, exact job title, salary, national identifier, and free-text career concerns.
- Add forced RLS, owner-only policy, and least-privilege grants consistent with RP-TURN-010.
- Preserve existing tables, append-only consent history, RLS, role separation, lifecycle triggers, and sealed-definition protections.

### Localized profile and consent experience

- Add accessible, responsive Thai-first and English-complete sign-in, onboarding, and profile routes.
- Add a deliberately small, provisional, versioned vocabulary for role family, function, experience band, and goals.
- Validate all mutations on the server and expose only client-safe DTOs.
- Add a concise versioned privacy notice describing collected fields, purpose, Clerk US identity hosting, sensitive career/assessment data, and the non-production alpha boundary.
- Add one explicit MVP service-data purpose for profile and future learning-state processing, separate from marketing, analytics, and research.
- Declining must not create or update a profile.
- Grant, decline, and withdrawal must each append a receipt; withdrawal is not account deletion.
- Derive `proof_digest` deterministically from the canonical versioned notice/purpose representation.
- Serialize concurrent receipt writes and derive the current consent state deterministically.

### Deterministic verification

- Cover provider mapping, server-only boundaries, session states, redirect validation, logout, all account statuses, atomic/concurrent provisioning, cross-user denial, profile validation, bilingual parity, accessibility, append-only consent, digest stability, forced RLS, and client-bundle exclusions.
- Use only synthetic fixtures and disposable PostgreSQL resources; remove every temporary database, credential, and synthetic Clerk identity after verification.
- If Jeff supplies ignored Clerk Development keys, perform a real synthetic Clerk smoke test and delete the synthetic identity. If not, report the turn as `Partial` and never claim full acceptance readiness.

## Out of scope

- Real users or real personal/career data
- Clerk Production, paid plans, payment details, custom domains, social OAuth, SMS, passwords, Organizations, or expanded RBAC
- Production PostgreSQL, VPS services, DNS, deployment, or other infrastructure
- Persisted assessment answers/results, durable lesson progress, or XP
- Account-erasure worker or final retention policy
- Analytics, marketing consent, research consent, or email campaigns
- CI or RP-TURN-012

## Required verification

- `npm ci`
- `npm query ':attr(scripts)' --json` and `npm config get strict-allow-scripts`
- `npm run format:check`
- `npm run lint`
- `npm run typecheck`
- `npm run test`
- `npm run build`
- `npm run check`
- `npm run test:e2e`
- `npm run db:test:disposable`
- `npm audit --omit=dev` and `npm audit`
- Strict UTF-8, Markdown-fence, unresolved/conflict-marker, and `git diff --check` checks
- Result/lesson/auth route client-manifest and chunk inspection for database code, secrets, provider subjects, and server-only internals
- Gitleaks worktree, exact staged content, proposed history, and pushed history scans
- Local/remote feature-head equality, unchanged main, Draft PR state, and clean final worktree

## Documentation and Git workflow

Update factual Turn 011 changes only in:

- `PROJECT_STATUS.md`
- `README.md`
- `docs/07_TECHNICAL_ARCHITECTURE.md`
- `docs/08_DATA_MODEL.md`
- `docs/09_ENGINEERING_PLAN.md`
- `docs/10_LOCAL_DEVELOPMENT.md`
- `docs/DECISION_LOG.md`

Commit intentionally on `agent/auth-profile-consent`, push without force, and open one Draft PR against unchanged `main`. Do not mark ready, merge, or delete the branch.

## End-of-turn requirement

Return the canonical `TURN HANDOFF` envelope from `prompts/VS_CODE_HANDOFF_TEMPLATE.md`, including the Draft PR URL, exact hashes, complete changed-file inventory, actual checks, synthetic-user cleanup evidence without identifiers, credential state, limitations, and confirmation that RP-TURN-012 was not started.
