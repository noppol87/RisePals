# RP-TURN-016 — Private Structured Evidence Artifact

## Authorization

- **Source:** Project Codex turn authorization approved by Jeff
- **Authorization status:** Bounded implementation authorized
- **Authorized base commit:** `980e45db70255fab60477edac064501f762d0f08`
- **Authorized base tree:** `39344f8ea44fe9c2dc583cb36d408ee0e81bbd2a`
- **Working branch:** `agent/private-evidence-artifact`
- **Draft PR title:** `feat: add private evidence artifact`
- **Repository:** Public [`noppol87/RisePals`](https://github.com/noppol87/RisePals)

Do not merge the pull request in this turn. Do not begin RP-TURN-017.

## Objective

Implement one private, owner-scoped, structured evidence artifact for the accepted synthetic Bright River Operations source-verification case. An authenticated synthetic-alpha learner whose exact persisted source-verification practice is demonstrated may explicitly start a draft, save controlled synthetic selections, review deterministic field feedback, mark the exact complete artifact ready, restore it after refresh or later sign-in, and withdraw it from use.

This is a synthetic-alpha technical proof only. It is not validated proficiency, a certificate or credential, employer-verifiable evidence, a public portfolio, a hiring signal, a production proof-storage system, or learning-efficacy validation.

## Required reading and immutable preparation

Before implementation:

1. Read `AGENTS.md`, `README.md`, `PROJECT_STATUS.md`, `docs/01_PRODUCT_VISION.md`, `docs/02_SKILL_FRAMEWORK.md`, `docs/03_MVP_SCOPE.md`, `docs/04_PRODUCT_ROADMAP.md`, `docs/07_TECHNICAL_ARCHITECTURE.md`, `docs/08_DATA_MODEL.md`, `docs/09_ENGINEERING_PLAN.md`, `docs/10_LOCAL_DEVELOPMENT.md`, `docs/DECISION_LOG.md`, `prompts/VS_CODE_HANDOFF_TEMPLATE.md`, the Turn 014/015 briefs, the accepted publication/lesson/authentication/consent/RLS/evaluation modules, and the canonical proof/source bundle.
2. Verify local `main`, `origin/main`, and public GitHub `main` equal the authorized base and tree.
3. Verify the worktree/index are clean, PR #13 is merged and closed, Turn 015 branches are absent, no conflicting Turn 016 branch or Draft PR exists, and `.env.local` is ignored and untracked without reading it.
4. Create this brief and commit it before implementation.

Stop if any immutable precondition differs.

## Preserved publication and lesson boundary

Do not change:

- lesson `source-verification-practice@1.0.0`;
- lesson digest `51903ea9e6053a1102b4d60ad072c9a1dcde26a90d6a0ca7ae36cba8a6995e91`;
- aggregate publication digest `d1d73e26afc718fcdc86c2dab54853ddbd488ad171c1c1f81e3d64e2f55c1525`;
- proof `source-verification-note-placeholder-v1@1.0.0`, including `capturesInput: false`;
- the canonical MDX/JSON source, publication seal, publication manifest, generated registry, evidence dates, or `prototype-unvalidated` status.

Public and protected lesson pages continue to show the accepted non-collecting proof placeholder. The new artifact is a separate authenticated application contract that references the placeholder and source pack without modifying either one.

## Artifact contract — D-023

Create one strict repository-local TypeScript contract with exact identity:

- contract ID `source-verification-note-artifact-v1`;
- version `1.0.0`;
- artifact type `source-verification-note`;
- source proof reference `source-verification-note-placeholder-v1@1.0.0`;
- source lesson `source-verification-practice@1.0.0`;
- source pack `bright-river-operations-synthetic-source-pack-v1`;
- classification `synthetic-private-evidence`;
- validation status `prototype-unvalidated`.

The payload may contain only:

- `schemaVersion`;
- the fixed synthetic `claimId`;
- ordered unique `sourceReferenceIds` selected only from `pilot-table`, `scope-note`, and `risk-log`;
- `fitCheckId` selected only from `supported`, `partially-supported-overgeneralized`, and `unsupported`;
- `correctedWordingOptionId` resolving through the accepted practice option registry;
- `safeNextActionOptionId` resolving through the accepted practice option registry.

Drafts may be partial. A ready artifact requires the exact complete five-field structure, the fixed AI-summary claim, all source references needed to trace performance, scope, and unresolved risk, the correct fit interpretation, the accepted evidence-supported correction, and the accepted safe next action. Evaluation is pure, transparent, deterministic, and local. No AI, probability, remote evaluator, or human-review claim is permitted.

Never add free text, rich text/Markdown input, names, user-entered URLs, file/clipboard import, upload, media/document capture, external lookup, object storage, export/download, reflection input, or real/personal/employer/client/confidential content. The UI must instruct users to use only the fictional Bright River case.

## Protected routes and browser boundary

Add dynamic owner-only routes:

- `/th/evidence` and `/en/evidence`;
- `/th/evidence/source-verification-note` and `/en/evidence/source-verification-note`.

They must be `noindex, noarchive`, use fixed same-locale sign-in returns, contain no internal identifier in path/query/fragment, and perform no write on GET, refresh, or locale switch. No public artifact, bearer-token route, or share link exists. The index shows only unavailable-until-demonstrated, not-started, draft, ready, or withdrawn. After demonstrated persisted practice, `/[locale]/learning` may show one fixed same-locale link to the private evidence area. Public result/lesson links remain unchanged.

The browser may receive only controlled bilingual copy, public synthetic field/option IDs, the owner's current controlled selections, controlled revision number, lifecycle state, and transparent field feedback. It must never receive account/user/consent/artifact/revision/practice/lesson UUIDs, provider subject/email, consent internals, database errors/credentials, seal/digest internals, assessment responses, scoring/multiplier/priority data, share tokens, or storage keys.

Mutation requests contain only locale, fixed intent, controlled payload where applicable, expected revision, and client mutation UUID. No local/session storage, custom cookie, URL state, analytics, or client log may persist selections.

## Explicit lifecycle

Authorized actions are exactly start, save draft, mark ready, and withdraw.

- Start requires the exact demonstrated owner practice and current consent; concurrent starts converge on one artifact.
- Save appends an immutable revision.
- Exact UUID/request replay returns the existing revision; conflicting UUID reuse changes nothing; stale/concurrent distinct successors yield one winner and controlled conflict.
- Ready requires the latest exact complete canonical revision.
- Ready does not mean validated proficiency or external verification and permits no further content revision.
- Draft or ready may transition to withdrawn.
- Withdrawn cannot reopen, edit, become ready, or be shared.
- No application DELETE, erasure claim, correction/replacement after ready, or replacement after withdrawal is authorized.

## One sixth migration and three-table model

Add exactly one forward-only sixth migration and exactly:

1. `evidence_artifacts`;
2. `evidence_artifact_revisions`;
3. `evidence_competency_links`.

Do not rewrite migrations `0000`–`0004`. The final fresh schema must contain six migrations and exactly twenty-three application tables.

### `evidence_artifacts`

- internal UUID primary key and `user_id` owner;
- exact current granted `consent_record_id`;
- exact owner `lesson_attempt_id` and demonstrated `practice_attempt_id` source;
- exact contract/type/proof/lesson/version/digest/source-pack identities;
- status only `draft`, `ready`, or `withdrawn`;
- database-owned created/updated/ready/withdrawn timestamps;
- at most one artifact per owner, exact demonstrated practice, and contract;
- only `draft → ready`, `draft → withdrawn`, and `ready → withdrawn`;
- no reopen/delete/content duplication.

### `evidence_artifact_revisions`

- internal UUID primary key and composite owner/artifact relationship;
- positive monotonic append-only revision and optional exact supersedes link;
- strict versioned JSON payload;
- mutation intent fixed to `save`, normalized locale, expected revision, and unique client mutation UUID;
- exact replay only when UUID, intent, locale, expected revision, and canonical payload all match;
- controlled conflict for UUID reuse and stale/concurrent successors;
- no UPDATE or DELETE and database-owned creation time.

PostgreSQL independently rejects unknown/extra payload keys, unknown claim/source/fit/option identities, duplicated or noncanonical source order, unsupported schema/contract versions, altered source identities, skipped/branched provenance, cross-owner links, conflicting supersession, and committed-history modification.

### `evidence_competency_links`

- owner-scoped artifact relationship;
- exact accepted framework/competency version;
- only Critical Thinking & Fact-Checking;
- relationship `synthetic-practice-evidence`;
- no proficiency, score, rank, employment, or eligibility field;
- immutable one-to-one mapping for this artifact contract;
- no UPDATE or DELETE.

The link provides framework traceability only and is not a validated competency claim.

## Source eligibility, consent, RLS, and privileges

Artifact start resolves every internal source server-side inside one accepted authorization transaction and requires:

- active internal account;
- current granted `service-profile-learning-state` / `alpha-privacy-v1` consent;
- owner lesson attempt with status `demonstrated`;
- owner practice revision with status `evaluated` and `demonstrated = true`;
- exact lesson/practice/rubric/evaluation identities and accepted lesson digest;
- the exact proof/source-pack artifact contract.

The browser never supplies internal lesson/practice/competency/consent IDs. Current exact grant is required for start/read/save/ready/withdraw. Missing, declined, withdrawn, wrong-version, cross-owner, or malformed state fails closed. Consent withdrawal is not data deletion; retention/export/erasure remain deferred. Treat artifact state as P3 even though all values are controlled and synthetic.

Enable and force RLS on all three tables. Preserve `withAuthorizedUserTransaction`, active-account enforcement, transaction-local `app.current_user_id`, non-owner least-privilege application role, `NOBYPASSRLS`, composite owner foreign keys, and missing/malformed-context failure. Grant only necessary SELECT/INSERT and narrowly limited lifecycle UPDATE columns. Grant no revision/competency UPDATE, application DELETE, table ownership, BYPASSRLS, or unrestricted maintenance path. PostgreSQL triggers independently enforce source eligibility, lifecycle, revision provenance, readiness, and withdrawal.

## Private, scoring, and product separation

Every artifact is private. Do not add share grants, portfolio/public preview, tokens/QR, employer access, download/email/signed URL, opportunity matching, object storage, or uploads. Do not add XP/balance/awards, badges/streaks/levels/leaderboards, assessment or competency scores, recommendation changes, automatic stage progression, or hiring/employability fields. Readiness changes no assessment, scoring, or lesson history.

## Thai/English UI and accessibility

Provide equivalent Thai and English structure, controlled options, synthetic/private/prototype disclosures, lifecycle distinction, explicit no-sharing notice, keyboard-complete operation, visible focus, semantic field groups, announced validation/status, non-color-only meaning, 320px reflow, reduced-motion support, and zero serious/critical axe findings. Add no raster or illustration asset.

## Dependencies, external resources, and secrets

No dependency or material configuration change is authorized. Preserve `package.json`, `package-lock.json`, `.npmrc`, Next/TypeScript/test/database configuration, exact PostCSS/Sharp/nanoid overrides, Clerk-disabled standard verification, and loopback-only E2E.

No real Clerk Development smoke is authorized. Do not read, copy, display, validate, or modify `.env.local` or key values; access Clerk Dashboard/API; create a Clerk identity; create a durable/production database; or create any external resource. Stop for a decision if a dependency, object-storage provider, configuration expansion, or external resource appears necessary.

## Documentation

Update only factual Turn 016 changes in:

- `PROJECT_STATUS.md`;
- `README.md`;
- `docs/07_TECHNICAL_ARCHITECTURE.md`;
- `docs/08_DATA_MODEL.md`;
- `docs/09_ENGINEERING_PLAN.md`;
- `docs/10_LOCAL_DEVELOPMENT.md`;
- `docs/DECISION_LOG.md`.

Add D-023 for the separate private routes, demonstrated-practice eligibility, controlled synthetic fields, three-table forced-RLS model, append-only replay/conflict revisions, private/no-upload/no-share boundary, no XP/scoring/employment coupling, and `prototype-unvalidated` meaning. Record implementation as complete pending Project Codex review, never Accepted. RP-TURN-017 may be named only as recommended and remains unauthorized.

## Acceptance criteria

### Publication and public preservation

- Public lesson remains static and memory-only; the existing placeholder stays non-collecting.
- No public route creates/exposes an artifact.
- Sealed source, manifest, registry, identities, and digests remain byte-identical.

### Eligibility and explicit creation

- GET creates no row.
- Absent/non-demonstrated practice cannot start.
- Exact demonstrated owner practice explicitly starts one artifact and concurrent starts converge.
- Browser supplies no internal source identifier.

### Revision and lifecycle integrity

- Partial controlled drafts save and restore.
- Exact replay returns the existing revision; UUID conflict/stale successor changes nothing; concurrent distinct successors yield one winner.
- Revisions remain append-only; PostgreSQL rejects malformed/noncanonical payloads.
- Ready rejects missing/invalid fields and succeeds once for the exact canonical structure.
- Ready content is immutable and makes no proficiency claim.
- Draft/ready may withdraw; withdrawn is read-only and no operation deletes rows or claims erasure.
- Denied operations preserve rows, revisions, lifecycle timestamps, and source history.

### RLS, consent, and privileges

- Correct owner/current grant succeeds for every new table.
- Cross-user access/references, missing/malformed context, and declined/withdrawn/wrong consent fail.
- Application DELETE and immutable UPDATE privileges are absent.
- All new tables force RLS; the app owns none and has no BYPASSRLS.

### Privacy and accessibility

- HTML, React payloads, chunks, URLs, storage, cookies, console, analytics, logs, and third-party boundaries expose no prohibited internal/provider/consent/database/assessment/scoring/storage/share values.
- Thai/English equivalence, keyboard/focus/live state, 320px, reduced motion, axe, Clerk-disabled, and loopback-only gates pass.

## Required verification

Run and report:

1. Clean base/hashes, `npm ci`, pending install-script query, `strict-allow-scripts`, and `npm ls --all`.
2. `npm run content:validate` and exact comparison of sealed source, seal, manifest, registry, lesson/aggregate digests against authorized main. Do not run `content:publish` merely to rewrite unchanged files.
3. Format, lint, strict typecheck, focused artifact contract/DAL/component tests, full unit/component suite, production build, and `npm run check`.
4. Complete Chromium E2E for both locales/routes/states, logged-out/consent boundaries, public/lesson regression, keyboard/focus, 320px, reduced motion, axe, Clerk-disabled, and loopback-only behavior.
5. Disposable PostgreSQL 18.4 applying six migrations and exactly twenty-three tables, with accepted regression plus eligibility/lifecycle/revision/replay/conflict/concurrency/RLS/consent/privilege assertions and complete cleanup leaving zero process/service/listener/child/database resource.
6. Production and full npm audits, client-boundary inspection, strict UTF-8/no BOM, Markdown fences, unresolved/conflict/TODO/FIXME markers, syntax/diff checks, migration inventory, prohibited-path/secret checks, and Gitleaks 8.30.1 over worktree/candidate, exact staged content, proposed history, and pushed history.
7. Matching local/origin/public feature hashes; unchanged main; Open Draft unmerged PR; clean final worktree; `.env.local` still ignored/untracked and unread.

## GitHub workflow

1. Work only on `agent/private-evidence-artifact` from the authorized base.
2. Commit this brief before implementation.
3. Inventory and review every changed file; stage only authorized Turn 016 files.
4. Inspect status, staged names/stat, cached diff, and exact staged Gitleaks before each commit.
5. Commit intentionally and push without force.
6. Open one Draft PR to unchanged `main` titled `feat: add private evidence artifact`.
7. Verify repository/base/head/Draft/unmerged state and local/origin/public hashes.
8. Scan proposed and pushed history.
9. Retain Jeff-authorized GitHub development authentication without displaying or broadening it.
10. Do not merge, modify settings/branch protection/Actions, or start RP-TURN-017.

## Stop conditions

Return Partial or Decision required without broadening scope if the base/worktree differs; sealed publication bytes/digests must change; free text/upload/object storage/sharing is needed; dependency/configuration/external resource/real Clerk smoke is needed; the three-table database model cannot enforce the required invariants; a privacy/retention/product claim exceeds this brief; or any required security/RLS/audit/client-boundary/cleanup gate fails.

## Final handoff

Use `prompts/VS_CODE_HANDOFF_TEMPLATE.md` and begin exactly:

```text
SOURCE: VS CODE CODEX
DESTINATION: PROJECT CODEX
MESSAGE TYPE: TURN HANDOFF
```

Report status, authorized base, final implementation commit, Draft PR URL, exact files, artifact identity/controlled fields, migration/table counts, eligibility/revision/readiness/withdrawal and replay/conflict/concurrency evidence, consent/RLS/privilege results, exact commands/counts, publication preservation, audits/client/Gitleaks/cleanup, local/origin/public hashes, unchanged main, clean Draft/unmerged state, assumptions/risks, ignored/unread `.env.local`, every out-of-scope confirmation, and confirmation that RP-TURN-017 was not started. Ask Project Codex for Accepted, Revision required, or Decision required.
