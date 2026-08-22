# RP-TURN-014 — Content Publication Pipeline

## Authorization

- **Source:** Project Codex turn authorization accepted by Jeff
- **Authorized base:** `85e61700942444586d76cfeda9c7eebf4eb02831`
- **Authorized branch:** `agent/content-publication-pipeline`
- **Draft PR title:** `feat: add trusted content publication pipeline`
- **Repository:** Public [`noppol87/RisePals`](https://github.com/noppol87/RisePals)

Jeff authorizes this bounded implementation turn. Do not expand it into lesson progress, production content operations, real-user data, CI, infrastructure, or deployment.

## Objective

Establish a deterministic, Git-reviewed publication pipeline for trusted local MDX and associated metadata, practice, rubric, proof, and source records. Publish the existing bilingual source-verification lesson as one immutable synthetic-alpha content version without evaluating MDX as executable JavaScript or changing its accepted practice behavior.

Publication in this turn means “available through the reviewed repository-local registry for synthetic alpha.” It does not mean external validation, proven learning efficacy, production release, or approval for real learners.

## Required reading

- `AGENTS.md`
- `README.md`
- `PROJECT_STATUS.md`
- `docs/01_PRODUCT_VISION.md`
- `docs/02_SKILL_FRAMEWORK.md`
- `docs/03_MVP_SCOPE.md`
- `docs/04_PRODUCT_ROADMAP.md`
- `docs/05_BRAND_VISUAL_CONTENT.md`
- `docs/06_CODEX_COLLABORATION_WORKFLOW.md`
- `docs/07_TECHNICAL_ARCHITECTURE.md`
- `docs/08_DATA_MODEL.md`
- `docs/09_ENGINEERING_PLAN.md`
- `docs/10_LOCAL_DEVELOPMENT.md`
- `docs/DECISION_LOG.md`
- `prompts/TURN_009_LESSON_PRACTICE_PROTOTYPE.md`
- `prompts/TURN_013_REPRODUCIBLE_SCORING_PRIORITY.md`
- `prompts/VS_CODE_HANDOFF_TEMPLATE.md`
- Every existing file under `content/`, `src/modules/lesson/source-verification/`, `src/app/[locale]/lessons/source-verification-practice/`, `tests/modules/lesson/`, and the directly related component/E2E tests

## Preparation

1. Verify the clean local repository, `origin/main`, and public GitHub `main` all equal the authorized base.
2. Verify `.env.local` remains ignored and untracked without displaying or modifying it.
3. Create this brief before implementation.
4. Create only `agent/content-publication-pipeline` from the exact authorized base.
5. Stop if main, ownership, visibility, or worktree state differs unexpectedly.

## D-021 architecture decision

### Pilot publication mechanism

- Git remains the only authoring source for pilot lessons.
- Use a deterministic build-time publication registry, not a database import job.
- Do not add lesson, practice, rubric, or source-claim tables or migrations in this turn.
- A database mirror, internal CMS, preview service, and production publishing operations remain future decisions.

### Operational publication versus validation

- The existing source-verification lesson may become operationally `published` for synthetic alpha.
- It must remain explicitly `prototype-unvalidated` for learning efficacy.
- Publication must not imply calibrated learning outcomes, credential value, employment relevance, or external validation.

### Declarative content boundary

- MDX is repository-local declarative content only.
- Never execute compiled MDX with `eval`, `new Function`, `vm`, dynamic remote import, or equivalent mechanisms.
- Never use `dangerouslySetInnerHTML`.
- Do not accept user-supplied, database-supplied, remote-CMS, or network-fetched MDX.
- Parse and validate local MDX into a controlled JSON render representation.
- Runtime rendering maps validated node/component identifiers to local React components.

### Immutability and provenance

- Every published lesson identity is the exact lesson key plus semantic version.
- Compute SHA-256 from strict UTF-8/LF source files using deterministic ordered paths and per-file digests.
- Generated output contains no current-time, machine-path, or nondeterministic field.
- Re-publishing identical input is idempotent.
- Changing source under an already published key/version fails with a digest conflict and requires a new semantic version.
- Failed validation leaves the existing registry and generated artifact unchanged.

## Required source bundle

```text
content/
  lessons/
    source-verification-practice/
      1.0.0/
        lesson.meta.json
        practice.json
        rubric.json
        proof.json
        sources.json
        locales/
          th/
            lesson.mdx
          en/
            lesson.mdx
  publication-manifest.json
  published-lessons.json
```

The exact generated filenames may change only if a materially safer design is documented before implementation. The architecture must still use tracked, deterministic, non-executable JSON publication output.

## Required metadata contract

- Contract/schema version
- Stable lesson key and version ID
- Semantic version
- Publication status
- Separate validation/efficacy status
- Exact Thai and English locale set
- Explicit fallback policy; both locales are required and silent fallback is prohibited
- Accepted framework version
- Target competency and working stage
- R.O.I. pillar
- Estimated active time and prerequisites
- Exact practice, rubric, and proof references
- Stable non-secret content-owner and reviewer references
- Explicit review/publication timestamps supplied as source data
- Provenance identifying the Git-reviewed publication pipeline

Do not fabricate authorship, review, or efficacy claims. Reviewer metadata describes repository/content-contract review only.

## Required content migration

Migrate the accepted source-verification lesson into the bundle without changing:

- lesson/version/framework/competency/stage/R.O.I. identities
- the synthetic Bright River Operations case
- three practice criteria and nine options
- exact rubric links and all-criteria-met rule
- 20/0 preview-XP behavior
- replace-not-add retry behavior
- non-persisted XP
- proof placeholder and non-collecting reflection
- route paths
- Thai/English meaning

Adjust only wording that would falsely say the lesson is operationally unpublished. Continue to label it clearly as synthetic-alpha, prototype, and externally unvalidated. Current result/priority references may continue to call it a prototype lesson. Do not change D-020 scoring or priority semantics.

## MDX trust rules

Allow only the minimal Markdown needed by the accepted lesson:

- paragraphs
- headings levels 2–4
- ordered/unordered lists
- strong/emphasis
- blockquotes
- inline code
- reviewed HTTPS or same-origin relative links

Allow only the smallest local component set needed to represent the accepted sections, equivalent to:

- `Scenario`
- `ConceptList`
- `PracticeMount`
- `RubricSummary`
- `ProofPlaceholder`
- `ReflectionPrompt`

Reject:

- import/export/ESM
- JavaScript or MDX expressions
- spread attributes
- expression-valued attributes
- event-handler properties
- raw HTML
- `script`, `style`, `iframe`, `object`, `embed`, or image nodes
- unknown elements or components
- `javascript:`, `data:`, `file:`, or other unapproved URL schemes
- absolute filesystem paths, path traversal, and symlinks
- duplicate IDs, files, lesson identities, or locale identities
- unsupported extensions
- non-string, empty, or structurally mismatched localized content

## Source and evidence validation

- Preserve the existing synthetic-source meaning.
- Synthetic records are explicitly classified as synthetic and cannot masquerade as real external evidence.
- Any future external claim accepted by the schema requires direct HTTPS URL, publisher, publication date, geography/context, limitation, last-verified date, and review/expiry date following `docs/05_BRAND_VISUAL_CONTENT.md`.
- Expired or incomplete external evidence blocks publication.
- Do not add new external claims or fetch any source at runtime in this turn.

## Publication commands

Add deterministic commands equivalent to:

- `npm run content:validate`
- `npm run content:publish`

Requirements:

- `content:validate` is read-only and compares source bundles, manifest, generated registry, and digests.
- `content:publish` validates all input before atomically writing deterministic artifacts.
- `npm run build` and `npm run check` fail when published content is stale or invalid.
- Normal build/check does not mutate the worktree.
- Runtime code imports only the validated published JSON registry through a server-only boundary.
- The lesson route remains statically renderable.
- The client receives only the locale-specific view required by the accepted lesson interaction.

## Dependency policy

- Prefer a small audited build/dev-only parser toolchain.
- If MDX parsing requires new packages, pin exact versions and document why each is required.
- Do not add a runtime MDX evaluator.
- Do not accept install scripts unless separately justified by the existing strict policy.
- Preserve exact `nanoid 3.3.18`, PostCSS `8.5.25`, Sharp `0.35.3`, and all unrelated direct dependencies.
- Reject unrelated `package-lock.json` drift.

## Required tests

### Canonical publication

- The exact source-verification bundle validates and publishes.
- Thai and English structural signatures match.
- Both locales resolve through the published registry.
- Repeated compilation produces byte-identical JSON and the same aggregate digest.
- Re-publishing the same bundle is idempotent.
- Editing a published bundle without a version change fails before output mutation.

### Contract rejection

- Invalid framework, competency, stage, or R.O.I. reference
- Missing locale, invalid fallback, or Thai/English structural mismatch
- Unknown/duplicate lesson, practice, rubric, proof, component, or content ID
- Broken practice/rubric/proof links
- Invalid semantic version or publication state
- Missing/invalid author-review metadata
- Incomplete or expired external evidence metadata
- Ambiguous bundle identity, digest conflict, path traversal, symlink, or unsupported file

### Non-executable MDX

- Reject ESM import/export.
- Reject JS/MDX expressions.
- Reject raw HTML, unsafe URL schemes, and forbidden elements.
- Reject unknown components, spread props, and event handlers.
- Prove malformed content cannot alter globals, read environment values, or produce executable output.
- Prove only allowlisted render nodes/components reach the runtime registry.

### Existing experience

- Thai and English lesson routes retain accepted content meaning, keyboard behavior, focus, feedback, 320px reflow, reduced-motion behavior, and accessibility.
- Practice remains in React memory and resets on refresh.
- No progress, answer, XP, proof, or reflection is persisted or transmitted.
- No assessment response, raw scoring input, internal identity, or database identifier enters the lesson client boundary.
- The result-to-lesson link retains the synthetic/provisional/non-personalized boundary.

## Authorized file areas

- `content/**`
- `scripts/content/**`
- `src/modules/lesson/publication/**`
- `src/modules/lesson/source-verification/**` only for migration/adaptation
- The existing source-verification lesson route/component and directly related locale copy only where required
- Directly related unit/component/E2E tests
- `package.json`, `package-lock.json`, and `.npmrc` only when required by the approved parser toolchain
- `prompts/TURN_014_CONTENT_PUBLICATION_PIPELINE.md`
- `PROJECT_STATUS.md`
- `README.md`
- `docs/07_TECHNICAL_ARCHITECTURE.md`
- `docs/08_DATA_MODEL.md`
- `docs/09_ENGINEERING_PLAN.md`
- `docs/10_LOCAL_DEVELOPMENT.md`
- `docs/DECISION_LOG.md`
- `content/README.md`

Do not modify assessment scoring, persisted-result policy, authentication, consent, profile, database schema, migrations, RLS, Clerk configuration, or provider smoke tooling.

## Documentation

- Add D-021 with the decisions above.
- Correct stale RP-TURN-013 status in `docs/09_ENGINEERING_PLAN.md`.
- Record RP-TURN-014 as implemented pending Project Codex review, not Accepted.
- Document exact publication commands, bundle layout, digest behavior, trust boundary, and limitations.
- Do not describe the lesson as externally validated or production-ready.
- RP-TURN-015 may be named only as the next recommended turn and remains unauthorized.

## Required verification

- `npm ci`
- pending install-script query
- `npm config get strict-allow-scripts`
- `npm ls --all`, including any new parser packages
- `npm run content:validate`
- deterministic publication/idempotency and immutable-conflict tests
- focused content-pipeline and lesson-contract tests
- `npm run format:check`
- `npm run lint`
- `npm run typecheck`
- `npm run test`
- `npm run build`
- `npm run check`
- `npm run test:e2e`
- `npm run db:test:disposable` as a regression gate, using only disposable PostgreSQL and completing full cleanup
- `npm audit --omit=dev`
- `npm audit`
- production manifest/chunk inspection
- forbidden executable-marker inspection over source and generated content
- proof that standard build/check/E2E remain explicitly Clerk-disabled and loopback-only
- strict UTF-8 without BOM
- balanced Markdown fences
- unresolved/conflict-marker scan
- `git diff --check` and staged diff check
- worktree, exact staged, proposed-history, and pushed-history Gitleaks `8.30.1` scans
- confirm `.env.local` remains ignored, untracked, and undisclosed
- confirm no database migration, production resource, service, CI, or deployment artifact exists
- matching local/origin/public feature-head hashes
- unchanged main
- clean final working tree

Do not run the real Clerk Development smoke. This turn does not change its command or shared authentication boundary.

## Acceptance criteria

- One exact bilingual source-verification lesson version is operationally published for synthetic alpha from trusted Git content.
- It remains visibly prototype/unvalidated and preserves all accepted RP-TURN-009 behavior.
- Publication output is deterministic, non-executable, and SHA-256 pinned.
- Same-version mutation and digest conflicts fail safely.
- Invalid framework, locale, rubric, proof, source, or review metadata blocks publication.
- Only allowlisted Markdown and local components render.
- Build/check fails on stale or invalid published artifacts and does not mutate the worktree.
- No database migration or durable lesson/progress/XP/proof state is introduced.
- No assessment, priority, authentication, privacy, or RLS contract is weakened.
- All required deterministic, browser, database-regression, audit, content-security, and Git checks pass.
- PR remains Open, Draft, and unmerged.
- RP-TURN-015 is not started or authorized.

## GitHub workflow

1. Inventory and review every changed file before staging.
2. Stage only authorized Turn 014 files.
3. Inspect `git status --short`, staged file list, cached stat, and `git diff --cached --check`.
4. Scan exact staged content before committing.
5. Commit intentionally with `feat: add trusted content publication pipeline` unless a bounded correction requires an additional commit.
6. Push only `agent/content-publication-pipeline` without force.
7. Open one Draft PR to unchanged `main` titled `feat: add trusted content publication pipeline`.
8. Verify PR owner, repository, base, head, Draft/unmerged state, and public file inventory.
9. Scan proposed and pushed history.
10. Retain Jeff-authorized GitHub development authentication without displaying or broadening credentials.
11. Do not merge the PR.

## End-of-turn requirement

Begin the response exactly with:

```text
SOURCE: VS CODE CODEX
DESTINATION: PROJECT CODEX
MESSAGE TYPE: TURN HANDOFF
```

Use `RP-TURN-014 — Content Publication Pipeline` and follow `prompts/VS_CODE_HANDOFF_TEMPLATE.md`. Include status, implementation commit/parent, unchanged main, Draft PR, exact files and bundle identity, per-file/aggregate SHA-256 evidence, parser/dependency decisions, allowlist/rejections, determinism/conflict results, route/accessibility/privacy/client evidence, disposable cleanup, audits, Gitleaks, hashes, clean worktree, out-of-scope confirmations, and confirmation that RP-TURN-015 was not started. Do not claim Project Codex acceptance before review.

## RP-TURN-014-R1 authorized correction

Project Codex required two bounded corrections after reviewing the initial implementation head:

- Add an independently Git-reviewed publication seal for `source-verification-practice@1.0.0` and canonical digest `51903ea9e6053a1102b4d60ad072c9a1dcde26a90d6a0ca7ae36cba8a6995e91`. The publisher must never rewrite the seal. Source mutation, removed entries from either or both generated outputs, and altered recorded digests must fail without changing the existing output bytes; identical republishing remains idempotent.
- Evaluate external-evidence expiry against the current UTC instant. The validation instant must be injectable for deterministic tests immediately before, exactly at and after expiry, without adding current-time fields to generated output. Expired evidence must block validation and publication before output mutation.

The correction preserves the canonical source, generated manifest, generated registry, aggregate digest, declarative MDX model, lesson behavior and all existing scope boundaries. PR #12 remains Draft and unmerged; RP-TURN-015 remains unauthorized.
