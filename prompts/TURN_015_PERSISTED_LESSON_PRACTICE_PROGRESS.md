# RP-TURN-015 — Persisted Lesson, Practice and Progress

## Authorization

- **Source:** Project Codex turn authorization approved by Jeff
- **Authorization status:** Bounded implementation authorized
- **Authorized base commit:** `721b284bc612d001d01f73c2b062db9224c80986`
- **Authorized base tree:** `54041a5c79866be0b173e5acbc5f698cbbbdcddf`
- **Working branch:** `agent/persisted-lesson-practice-progress`
- **Draft PR title:** `feat: persist lesson practice and progress`
- **Repository:** Public [`noppol87/RisePals`](https://github.com/noppol87/RisePals)

Do not merge the pull request in this turn. Do not begin RP-TURN-016.

## Objective

Add owner-scoped persistence for the one accepted published lesson and its deterministic practice. A signed-in synthetic-alpha learner may explicitly start, save a partial draft, resume after refresh or sign-in, evaluate the complete three-criterion response, retry a non-demonstrated result through a new immutable revision, and view meaningful progress.

The feature remains synthetic alpha and `prototype-unvalidated`. It does not establish validated proficiency, employability, production readiness, personalized learning effectiveness, saved XP, or proof.

## Required reading and preparation

Before implementation:

1. Read `AGENTS.md`, `README.md`, `PROJECT_STATUS.md`, the product/framework/MVP documents, technical architecture, data model, engineering plan, local-development guide, decision log, handoff template, the accepted RP-TURN-014 publication implementation, and the current lesson/authentication/consent/database/RLS/assessment-persistence modules.
2. Verify local `main`, `origin/main`, and public GitHub `main` equal the authorized base and tree.
3. Verify the index/worktree are clean, PR #12 is merged and closed, no conflicting Turn 015 branch or Draft PR exists, and `.env.local` is ignored and untracked without reading it.
4. Create this brief and commit it before implementation.

Stop if any immutable precondition differs.

## Preserved canonical content identity

- Lesson: `source-verification-practice@1.0.0`
- Lesson version ID: `lesson-source-verification-practice-v1`
- Practice: `source-verification-decision-v1@1.0.0`
- Rubric: `source-verification-rubric-v1@1.0.0`
- Evaluation contract: `source-verification-evaluation-v1`
- Lesson digest: `51903ea9e6053a1102b4d60ad072c9a1dcde26a90d6a0ca7ae36cba8a6995e91`
- Aggregate publication digest: `d1d73e26afc718fcdc86c2dab54853ddbd488ad171c1c1f81e3d64e2f55c1525`

The canonical MDX/JSON bundle, publication seal, manifest, generated registry, digests, versions, evidence records/review dates, and `prototype-unvalidated` classification are immutable in this turn. Do not run `content:publish` merely to rewrite unchanged artifacts.

## Architecture decision — D-022

### Separate public and protected surfaces

The existing public routes remain static, memory-only, and non-persisting:

- `/th/lessons/source-verification-practice`
- `/en/lessons/source-verification-practice`

Add protected dynamic routes:

- `/th/learning`
- `/en/learning`
- `/th/lessons/source-verification-practice/attempt`
- `/en/lessons/source-verification-practice/attempt`

Protected routes use the centralized authorization transaction, exact current consent, fixed same-locale safe sign-in returns, `noindex, noarchive`, and no identifier-bearing URL. GET is read-only; start/save/evaluate/retry require explicit actions.

### Three-table persistence boundary

Add one forward-only fifth migration and exactly three tables:

1. `lesson_attempts`
2. `practice_attempts`
3. `learning_progress_events`

The fresh baseline must contain five migrations and exactly twenty application tables. Existing migrations are immutable.

This turn intentionally uses an append-only practice-revision model and meaningful-event ledger. It adds no progress snapshot, XP ledger, proof table, analytics stream, or content mirror.

### Synthetic-alpha meaning

Persistence proves only a bounded technical learning loop for the accepted synthetic lesson. It is not learning-efficacy validation, a credential, certification, employment signal, production release, or permission to use real users/data.

## Protected route and disclosure contract

The authenticated attempt wrapper must disclose in Thai and English:

- selected option IDs and progress are stored for the signed-in account;
- no email is copied to learning records;
- no free text or file is collected;
- XP is preview-only and not saved;
- proof remains unavailable;
- completion is a synthetic-alpha practice result, not validated proficiency.

Do not edit sealed lesson content to add this wrapper. The browser receives only localized controlled copy, public canonical criterion/option IDs, the current user's selected IDs, a controlled revision, controlled progress state, and transparent criterion feedback.

The browser must not receive internal user/account/consent/attempt/event UUIDs, provider subjects/email, consent internals, database credentials/errors, publication seal/internal digest maps, or assessment/scoring/priority data. Do not use local/session storage, URL state, custom cookies, analytics, or telemetry for this flow.

## Explicit action lifecycle

Implement only:

1. Start lesson.
2. Save a partial draft.
3. Evaluate an exact complete three-criterion response.
4. Retry after a non-demonstrated evaluation by appending a new revision.
5. Read/restore the owner's current state.

Rules:

- Route visits and refreshes never write.
- Concurrent explicit starts converge on one attempt.
- Drafts contain only canonical criterion/option IDs and may be partial.
- Evaluation requires all and only the three canonical criteria.
- The accepted pure deterministic evaluator is authoritative; no AI, remote, probabilistic, or browser-authoritative score is allowed.
- A below-threshold evaluation remains `in_progress` and can be retried.
- Retry appends an immutable revision and never overwrites history.
- `demonstrated` requires all three rubric criteria.
- After demonstration, reopen, mutation, retry, and deletion are denied.
- No repeat-completion or multiple-completion model is authorized.

## Controlled progress states

`/[locale]/learning` may show only:

- Not started
- In progress
- Needs retry
- Demonstrated

It may expose only a fixed same-locale start/continue link. It must not show saved XP/balance, badges, streaks, levels, proof submission, assessment changes, proficiency certification, employability/opportunity predictions, personalized skill claims, or automatic product-stage transitions.

The existing 20 XP preview may remain visible only with the existing explicit statement that XP is not saved.

## Assessment separation

Lesson persistence must not require a completed assessment/result and must not read, change, or reinterpret assessment responses, signals, multipliers, scoring runs, priorities, rules, or digests.

The protected persisted result may change only its fixed Critical Thinking lesson action to the protected lesson-attempt route. The public synthetic example result continues to link to the public static lesson and remains fixed, synthetic, and non-personalized.

## Data model

### `lesson_attempts`

Required fields/semantics:

- internal UUID primary key and `user_id` owner;
- exact granted `consent_record_id` owner anchor;
- exact lesson key/version/version ID/digest;
- exact practice, rubric, and evaluation-contract compatibility anchors;
- status restricted to `in_progress` or `demonstrated`;
- database-owned start, last-meaningful-activity, and optional demonstrated timestamps;
- at most one attempt per owner and exact lesson identity;
- only `in_progress → demonstrated`;
- no reopen/delete;
- concurrent start converges on the same row.

Do not store copied email, provider subject, display name, locale copy, lesson body, or published-content mirrors.

### `practice_attempts`

Required fields/semantics:

- internal UUID primary key;
- composite `user_id` + `lesson_attempt_id` ownership;
- immutable append-only monotonic revision history;
- optional owner/lesson-scoped supersedes link to the prior revision;
- status only `draft` or `evaluated`;
- versioned response payload containing only canonical criterion/option IDs;
- drafts may be partial; evaluated payloads require exactly all three criteria;
- exact practice/rubric/evaluation-contract identity;
- deterministic criterion results and demonstrated flag;
- expected-revision concurrency control;
- unique client mutation UUID idempotency;
- same mutation replay returns the committed state;
- stale revision/conflicting mutation fails safely;
- no UPDATE or DELETE of committed history.

PostgreSQL must independently reject unknown/duplicate criteria, unknown options, mismatched pairs, missing/extra keys, malformed schema versions, altered compatibility, tampered criterion results/demonstrated flags, and cross-owner reparenting.

### `learning_progress_events`

This append-only meaningful-event ledger allows only:

- `lesson_started`
- `practice_evaluated`
- `practice_demonstrated`

It stores owner and lesson-attempt relationship, optional practice-attempt relationship where appropriate, event schema/version, stable source/idempotency identity, and database timestamp. Each event is atomically written with its corresponding state transition and exactly unique.

Do not record page views, route visits, refreshes, unrelated clicks, raw selections as analytics, email, provider subject, or free text.

## Consent and privacy

Use exact current `service-profile-learning-state` / `alpha-privacy-v1` consent.

- A current grant is required for start/read/save/evaluate/retry.
- Wrong purpose/version, declined, withdrawn, superseded, or another user's consent fails closed.
- Withdrawal blocks later protected reads and writes.
- Do not claim withdrawal deletes records.
- Deletion, export, retention automation, analytics, and telemetry are out of scope.
- Logs, browser console, URLs, error messages, and network boundaries must not expose selections, internal IDs, provider IDs, email, tokens, or secrets.

## Forced RLS and privileges

Enable and force RLS on all three new tables. Reuse transaction-local `app.current_user_id`, the accepted authorization transaction, active-account enforcement, and non-owner application role.

- Fail closed for missing/malformed user context.
- Composite owner foreign keys prevent cross-user references/reparenting.
- Application role receives minimum SELECT/INSERT privileges.
- No application DELETE.
- No UPDATE on practice/event payload/history.
- If lesson lifecycle columns require UPDATE, grant only those columns and protect transitions in PostgreSQL.
- Application role owns no table and has no superuser, role-creation, database-creation, inheritance, or `BYPASSRLS` capability.

Tests must reject cross-user read/write/reference/event attachment/reparenting and verify table ownership/privileges.

## UI and localization

Thai and English must provide equivalent route/state/disclosure/feedback copy, keyboard operation, visible focus, semantic controls, announced validation/status, 320px reflow, reduced-motion support, and zero serious/critical axe findings.

No product claim may imply demonstrated practice is validated proficiency, personalized effectiveness, employability, or production readiness.

## Dependencies and external-resource boundary

No dependency or material configuration change is authorized. Preserve `package.json`, `package-lock.json`, `.npmrc`, Next/TypeScript/PostCSS/Sharp/nanoid overrides, and accepted build/E2E/database configuration. Stop for a decision if a dependency or configuration change appears necessary.

No real Clerk smoke is authorized. Do not read, display, copy, validate, or modify `.env.local` or Clerk values; do not access Clerk Dashboard/API or create any identity. Do not create a production/durable database or any external resource. Standard build/browser gates remain explicitly Clerk-disabled and loopback-only.

## Documentation

Update only factual Turn 015 changes in:

- `PROJECT_STATUS.md`
- `README.md`
- `docs/07_TECHNICAL_ARCHITECTURE.md`
- `docs/08_DATA_MODEL.md`
- `docs/09_ENGINEERING_PLAN.md`
- `docs/10_LOCAL_DEVELOPMENT.md`
- `docs/DECISION_LOG.md`

Add D-022 covering separate public/protected routes, explicit-action-only persistence, the three-table append-only model, meaningful events instead of page-view analytics, no saved XP/proof, prototype-unvalidated meaning, and forced-RLS/consent boundaries. Record implementation as pending Project Codex review; do not claim acceptance.

## Acceptance criteria

### Public route preservation

- Thai/English public lesson routes remain static and memory-only.
- No public visit writes data.
- Publication seal, outputs, digests, and non-persistence copy remain unchanged.

### Protected behavior

- Logged-out access uses a fixed same-locale sign-in return.
- Missing current consent produces a controlled consent-required state.
- GET performs no write.
- Explicit start converges on one attempt.
- Partial draft restores from server state after refresh/sign-in.
- Complete evaluation uses the accepted evaluator.
- Below-threshold feedback permits append-only retry.
- All-three-criterion success demonstrates exactly once and is immutable.

### Integrity and concurrency

- Concurrent starts create one attempt.
- Mutation replay is idempotent; conflicting reuse fails.
- Stale expected revisions fail safely.
- Concurrent successors have one deterministic winner.
- Historical revisions remain immutable.
- PostgreSQL rejects tampered evaluation results.
- Progress events are append-only, exact, unique, and never generated by GET/navigation.

### RLS, privilege, and consent

- Own-row operations work only under the correct current grant/context.
- Cross-user/missing/malformed context and references fail.
- Application role has no DELETE and cannot update immutable practice/event data.
- All three tables remain forced-RLS; application owns none and is not `BYPASSRLS`.
- Exact current consent succeeds; wrong/declined/withdrawn/cross-owner consent fails.
- Withdrawal blocks subsequent protected reads/mutations without a deletion claim.

### Browser/privacy/accessibility

- HTML, React payloads, chunks, storage, URLs, logs, cookies, and network boundaries exclude internal IDs, provider/email/consent internals, selections outside the required same-origin mutation, raw database errors, assessment/scoring data, and secrets.
- No database or server-only publication module ships to client chunks.
- Thai/English keyboard, focus, live feedback, 320px, reduced-motion, axe, and loopback-only gates pass.

## Required verification

Run and report:

1. Clean base/hashes, `npm ci`, pending install-script query, strict-allow-scripts, and `npm ls --all`.
2. `npm run content:validate`; compare publication seal, lesson/aggregate digests, manifest, registry, and files against authorized `main`; do not rewrite them.
3. `npm run format:check`, `npm run lint`, `npm run typecheck`, focused tests, `npm run test`, `npm run build`, and `npm run check`.
4. Full Chromium E2E for both locales, protected/public states, safe returns, keyboard/focus, 320px, reduced motion, axe, Clerk-disabled, and loopback-only behavior.
5. Disposable PostgreSQL 18.4: five migrations, twenty tables, accepted regressions, new lifecycle/append-only/consent/concurrency/privilege/forced-RLS checks, and complete zero-resource cleanup.
6. Production/full npm audits, client-boundary inspection, strict UTF-8/no BOM, Markdown fences, unresolved/conflict/TODO/FIXME markers, syntax checks, `git diff --check`, migration inventory, prohibited-path/secret checks, and Gitleaks 8.30.1 for worktree, exact staged content, proposed history, and pushed history.
7. Local/origin/public feature hashes match; main remains the authorized base; final worktree is clean; PR stays Open, Draft, and unmerged.

## GitHub workflow

1. Work only on `agent/persisted-lesson-practice-progress` from the authorized base.
2. Inventory and review every changed file before staging.
3. Stage only authorized Turn 015 files; inspect status, staged names/stat, and cached diff checks.
4. Scan exact staged content before committing.
5. Commit intentionally and push without force.
6. Open one Draft PR to unchanged `main` titled `feat: persist lesson practice and progress`.
7. Verify public repository/base/head/Draft/unmerged state and matching local/origin/public feature hashes.
8. Scan proposed and pushed history.
9. Retain Jeff-authorized GitHub development authentication without exposing or broadening it.
10. Do not merge, modify branch protection/Actions/settings, or start RP-TURN-016.

## Explicitly out of scope

- Saved XP, XP ledger/balance, rewards, badge, level, streak, or leaderboard
- Proof input/submission/upload/storage/transmission or object storage
- New content/version or production content validation
- AI/remote evaluation or feedback
- Assessment/scoring/result/policy changes beyond the one authorized protected fixed lesson link
- Personalized learning or skill claims
- Analytics, telemetry, export, deletion, or retention automation
- Production identity/database/resource, real user/data, CI, infrastructure, service, deployment, monitoring, payment, licensing, or RP-TURN-016

## Stop conditions

Return Partial or Decision required without broadening scope if the base/worktree differs, content identity/digest must change, a dependency/configuration/external resource/real Clerk smoke becomes necessary, required three-table invariants cannot be enforced, a product/privacy/consent decision exceeds this brief, or a required security/RLS/audit/client/cleanup gate fails.

## Final handoff

Use `prompts/VS_CODE_HANDOFF_TEMPLATE.md` and begin exactly:

```text
SOURCE: VS CODE CODEX
DESTINATION: PROJECT CODEX
MESSAGE TYPE: TURN HANDOFF
```

Report status, authorized base, final feature commit, Draft PR, exact changed files, migration/table counts, implementation behavior, exact commands/counts, publication preservation, RLS/consent/concurrency/privacy evidence, dependency/audit/client/Gitleaks/cleanup results, local/origin/public hashes, unchanged main, Draft/unmerged PR state, assumptions/risks, ignored/unread `.env.local`, no external identity/resource, and all out-of-scope confirmations.
