# RP-TURN-009 — One End-to-End Lesson and Practice Prototype

## Authorization

- **Source:** Project Codex turn authorization accepted by Jeff
- **Authorized base:** `f379b5bfecfe884f0a25b9eadf6f182e8d7b69bb`
- **Authorized branch:** `agent/source-verification-lesson-prototype`
- **Draft PR title:** `feat: add source verification lesson prototype`
- **Repository:** Public [`noppol87/RisePals`](https://github.com/noppol87/RisePals)

## Objective

Create one accessible Thai-first and English-complete source-verification micro-lesson and deterministic practice prototype. Demonstrate Learn → Practice → Feedback → Proof-placeholder behavior without authentication, persistence, real XP, personalized recommendations or claims of learning efficacy.

## Read first

- `AGENTS.md`
- `README.md`
- `PROJECT_STATUS.md`
- `docs/01_PRODUCT_VISION.md`
- `docs/02_SKILL_FRAMEWORK.md`
- `docs/03_MVP_SCOPE.md`
- `docs/04_PRODUCT_ROADMAP.md`
- `docs/05_BRAND_VISUAL_CONTENT.md`
- `docs/07_TECHNICAL_ARCHITECTURE.md`
- `docs/08_DATA_MODEL.md`
- `docs/09_ENGINEERING_PLAN.md`
- `docs/DECISION_LOG.md`
- `prompts/TURN_008_SKILL_MAP_PRIORITY_RESULT_PROTOTYPE.md`
- `prompts/VS_CODE_HANDOFF_TEMPLATE.md`
- Existing result, localization, navigation, component and test code

## Required decision

Add D-016 defining this prototype boundary:

- The lesson is schema-validated, Git-versioned local prototype content, not published or externally validated learning content.
- Use a typed local content contract for this experience turn.
- Do not establish the future MDX compilation/publication pipeline; it remains deferred to RP-TURN-014.
- Practice state exists in memory only and resets on refresh.
- No response, reflection, proof, progress or XP is persisted or transmitted.
- The fixed RP-TURN-008 example may link to this exact lesson, while remaining synthetic and non-personalized.

## Required identities

| Field | Exact value |
|---|---|
| Lesson key | `source-verification-practice` |
| Lesson version ID | `lesson-source-verification-practice-v1` |
| Version | `1.0.0` |
| Status | `prototype` |
| Target competency | Critical Thinking & Fact-Checking |
| Target competency ID | `critical-thinking-fact-checking` |
| Target working stage | `Practicing` |
| Primary R.O.I. pillar | `Intelligent Risk & Governance` |
| Locale coverage | `th`, `en` with meaning-equivalent content |

Content metadata also carries stable practice, rubric and proof identities, estimated active time and honest local-prototype provenance.

## Required experience

1. Add static locale-matched routes:
   - `/th/lessons/source-verification-practice`
   - `/en/lessons/source-verification-practice`
2. Update the fixed example-result lesson reference from planned/unavailable to exact prototype-available lesson version `lesson-source-verification-practice-v1`.
3. Link the example result to the matching locale lesson with explicit copy that the result remains fixed and synthetic, the lesson is a prototype, and the link is not a personalized recommendation.
4. Implement the complete lesson-design contract:
   - realistic, entirely synthetic workplace situation involving an AI-generated summary and source verification
   - only concepts needed for safe action
   - active structured decision
   - transparent rubric
   - deterministic feedback
   - proof-artifact placeholder
   - non-collecting reflection prompt
   - explicit Intelligent Risk & Governance connection
5. Evaluate exactly three transparent criteria:
   - evidence traceability
   - claim-to-source fit
   - safe next action
6. Each criterion is `met` or `not-met`; demonstrated practice requires all three. Do not emit percentage proficiency, confidence or an Aware–Leading judgment about the learner.
7. Keep XP as a preview rule only:
   - viewing content: 0 preview XP
   - incomplete or below-threshold practice: 0 preview XP
   - demonstrated practice: exactly 20 preview XP
   - retry/re-evaluation never accumulates XP
   - no XP is saved
8. Describe a future `source verification note` proof artifact and expected fields, but provide no free-text entry, upload or storage.
9. Keep practice selections and feedback in React memory only. Refresh starts a new attempt.
10. Viewing or reaching practice never implies demonstrated completion; only satisfying all three criteria may set the in-memory demonstrated state.

## Privacy and data boundary

- No `sessionStorage` or `localStorage` access.
- No cookie or URL/query encoding.
- No API, route handler, server action or external content/AI call.
- No analytics, console logging or network transmission of selections or feedback.
- No response, reflection, proof, progress, completion or XP persistence.
- Keep assessment fixtures, assessment scoring internals and assessment-player storage payload markers out of the lesson client boundary.

## Content constraints

- Use synthetic organizations, documents, people and values only.
- Do not introduce external statistics or unsupported factual claims.
- Do not invent author/reviewer identities or publication approval.
- Keep Thai professional, natural and concise; English must be meaning-equivalent.
- Avoid fear, shame, employment prediction and childish gamification.
- Label prototype provenance, limitations, in-memory behavior and unsaved XP clearly.

## Implementation constraints

- Keep content validation, practice evaluation and state transitions pure, deterministic, versioned and independently tested.
- Server-resolve locale content and pass only the lesson/practice DTO required by the Client Component.
- Preserve Server Components by default and keep the client island minimal.
- Use semantic HTML, native controls, code-native visuals and existing design tokens.
- Provide keyboard operation, visible focus, announced feedback, 320px reflow and reduced-motion behavior.
- Do not add a dependency, raster asset or remote content fetch.
- Do not create the MDX compiler/publication pipeline or a content CMS.

## Required tests

- Exact lesson/version/framework/competency/stage/R.O.I. identities validate.
- Thai and English content have complete structural parity.
- Malformed content, unknown identities, altered rubric links and invalid XP rules are rejected.
- Viewing alone cannot become demonstrated and yields zero preview XP.
- Partial/incorrect practice produces criterion-level feedback and zero preview XP.
- Meeting all three criteria produces demonstrated state and exactly 20 preview XP.
- Retry/re-evaluation never accumulates XP.
- Reset and refresh behavior are explicitly non-durable.
- Result-to-lesson links preserve locale and explicit non-personalized wording.
- Result route still never reads assessment `sessionStorage`.
- Lesson route reads/writes no browser storage and sends no practice data through URL, cookies, logs or network.
- Thai/English routes pass keyboard/focus, 320px reflow, reduced motion and serious/critical axe checks.
- Client manifest/chunks contain no assessment raw fixtures, scoring internals or player-storage payload markers.
- Unsupported locale returns not found and lesson metadata blocks indexing.

## Required verification

Run and report:

```powershell
npm ci
npm approve-scripts --allow-scripts-pending --json
npm config get strict-allow-scripts
npm run format:check
npm run lint
npm run typecheck
npm run test
npm run build
npm run check
npm run test:e2e
npm audit --omit=dev --audit-level=low
npm audit --audit-level=low
git diff --check
```

Also verify and report:

- strict UTF-8, balanced Markdown fences and unresolved markers
- exact changed-file and dependency/config inventory
- content-contract and localization parity
- rubric/feedback/XP invariants and no passive-view completion
- no persistence or network-boundary violation
- result and lesson client manifests/chunks
- Gitleaks `8.30.1` scans of the nonignored worktree, exact staged content, proposed history and pushed history
- unchanged local/remote/public `main`
- matching local/remote feature head
- exact Public GitHub destination
- one Open, Draft and unmerged PR
- clean final worktree
- retained Jeff-authorized GitHub authentication without displaying credential details

## GitHub workflow

1. Confirm local, origin and public `main` equal the authorized base and the worktree is clean.
2. Create only `agent/source-verification-lesson-prototype` from that base.
3. Inventory and intentionally stage only RP-TURN-009 files.
4. Inspect staged names, diff/stat and `git diff --cached --check`.
5. Scan exact staged content with Gitleaks before commit.
6. Create one intentional implementation commit unless a correction is required.
7. Push normally to `origin` without force.
8. Open exactly one Draft PR to `main` titled `feat: add source verification lesson prototype`.
9. Verify pushed history and local/remote feature-head equality.
10. Do not mark ready, merge or begin RP-TURN-010.

## Out of scope

- Externally validated learning or efficacy claims
- Any additional lesson or lesson catalog
- Personalized recommendation or assessment methodology/scoring change
- Proof capture, free text, file upload or storage
- Persisted completion, progress or XP ledger
- Account, authentication, consent, API, database or analytics
- AI-generated feedback or external AI call
- MDX compilation/publication pipeline or content CMS
- Pal character, generated raster asset or final visual identity
- Dependency, CI, branch protection, infrastructure, VPS service or deployment
- Force-push, merge or RP-TURN-010 work

## Acceptance criteria

- Exact typed, schema-validated, Git-versioned local lesson identity and bilingual contract exist.
- Static Thai/English lesson routes demonstrate Learn → Practice → Feedback → Proof-placeholder.
- The deterministic practice uses exactly three binary criteria, requires all three for demonstration and previews exactly 20 XP without saving it.
- Passive viewing, partial practice and retry cannot produce or accumulate demonstrated XP.
- The fixed RP-TURN-008 example links to the matching locale prototype without becoming personalized.
- Browser state is React-memory-only and no lesson response crosses storage, URL, cookie, log, analytics or network boundaries.
- Client bundles exclude assessment fixtures, scoring internals and assessment-player storage markers.
- Required quality, accessibility, privacy, build, audit and secret-scan checks pass.
- Main remains unchanged and exactly one Draft, unmerged PR is created; RP-TURN-010 is not started.

## End-of-turn requirement

Update `PROJECT_STATUS.md` with factual RP-TURN-009 progress only. Return a handoff using `prompts/VS_CODE_HANDOFF_TEMPLATE.md` with the lesson/version identity, practice/rubric/XP behavior, privacy/client boundary, exact changed files, actual verification results, commit hash, Draft PR URL, unchanged main and confirmation that RP-TURN-010 was not started.
