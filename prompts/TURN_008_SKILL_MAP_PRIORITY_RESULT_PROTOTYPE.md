# RP-TURN-008 — Synthetic Skill Map and Next-Step Result Prototype

## Authorization

- **Source:** Project Codex turn brief approved by Jeff
- **Authorized base:** `c9387ed34e82b7696ed043bf1c7e5ac6918293d2`
- **Authorized branch:** `agent/skill-map-priority-prototype`
- **Draft PR title:** `feat: prototype synthetic skill result`
- **Repository:** Public [`noppol87/RisePals`](https://github.com/noppol87/RisePals)

## Objective

Create an accessible Thai-first and English-complete example-result experience using only the reviewed synthetic RP-TURN-006 assessment fixtures. The route demonstrates how a future skill map, evidence limitations and next-step explanation could work. It must not read, score or interpret the current user's RP-TURN-007 `sessionStorage` selections and must not present a personalized assessment result.

## Read first

- `AGENTS.md`
- `README.md`
- `PROJECT_STATUS.md`
- `docs/01_PRODUCT_VISION.md`
- `docs/02_SKILL_FRAMEWORK.md`
- `docs/03_MVP_SCOPE.md`
- `docs/08_DATA_MODEL.md`
- `docs/09_ENGINEERING_PLAN.md`
- `docs/DECISION_LOG.md`
- `prompts/TURN_006_ASSESSMENT_DOMAIN_FIXTURES.md`
- `prompts/TURN_007_ASSESSMENT_PLAYER_PROTOTYPE.md`
- `prompts/VS_CODE_HANDOFF_TEMPLATE.md`
- Existing assessment domain, player, localization, component and browser-test code

## Required decision

Add a decision-log entry that fixes the RP-TURN-008 boundary: the example result is derived from an identified reviewed synthetic fixture only; it does not consume the user's temporary selections and is not a validated, personalized or production assessment result.

## In scope

1. Add locale-matched example-result routes beneath `/th/assessment` and `/en/assessment`.
2. Allow the RP-TURN-007 completion screen to link to the example only with explicit Thai/English wording that the user's choices are not used.
3. Use one reviewed fixture for the visible example and both reviewed fixtures in deterministic contract tests.
4. Present only the two core competencies covered by the fixture as provisional raw `earned / available` evidence signals.
5. List all six unassessed core competencies explicitly.
6. Present Ownership Thinking and Sense of Urgency separately as one-scenario observations rather than core signals, factors or patterns.
7. Provide text equivalent to every code-native visual relationship.
8. Present exactly one clearly labeled example next practice, not a personalized priority recommendation.
9. Trace the example practice to the scoring-model version, supporting assessment item keys, target competency and a planned lesson-version reference.
10. Mark the lesson reference planned and unavailable; do not create or imply an existing lesson or lesson player.
11. Provide complete Thai/English evidence-coverage and limitation copy.
12. Keep fixture input, derived evidence, explanation and example-practice metadata in separate contracts/modules.
13. Update only factual documentation and project status needed to describe this turn.

## Implementation constraints

- Keep result derivation pure, deterministic, versioned, non-mutating and independently tested.
- Validate the accepted assessment domain and exact compatible assessment/framework/scoring/fixture identities before deriving the example.
- Server-render and statically generate the localized example result.
- Keep scoring internals, raw response fixtures, rubric values, target mappings and framework weights out of client bundles.
- Use semantic HTML, code-native visualization and the existing provisional design tokens.
- Preserve keyboard access, visible focus, reduced-motion behavior and 320px reflow.
- Preserve the RP-TURN-007 exact `sessionStorage` allowlist and privacy classification.
- Do not add a new dependency, raster asset or unsupported runtime assumption.

## Prohibited

- No overall score, weighted aggregate, percentage proficiency, Aware–Leading stage or confidence percentage.
- No job-loss, job-performance, employability, hiring, readiness, risk or personality inference.
- No reading or scoring of the user's `sessionStorage` selections.
- No answer data in URLs, cookies, logs, analytics, console output or network requests.
- No server action, API, database, authentication, durable persistence or consent system.
- No new assessment questions, calibration claim or validation claim.
- No lesson player or claim that the planned lesson currently exists.
- No dependency, raster asset, CI, infrastructure, VPS service or deployment change.
- No force-push, merge or RP-TURN-009 work.

## Required tests

- Both accepted synthetic fixtures produce deterministic, immutable example-result contracts.
- The visible fixture identity and exact raw evidence values are fixed and reviewed.
- Exactly two assessed core signals and six unassessed core competencies are emitted.
- Ownership Thinking and Sense of Urgency remain two separate one-scenario observations.
- The example practice trace has the exact scoring model, supporting item keys, target competency and planned/unavailable lesson reference.
- Result contracts emit no overall, weighted aggregate, percentage proficiency, stage, confidence, hiring, readiness, risk or personality fields.
- Thai and English result copy is complete, intentional and free of raw HTML.
- The player completion link states that current choices are not used and routes to the same locale.
- Thai/English routes are keyboard-readable, focus-visible, text-equivalent, usable at 320px, reduced-motion-safe and free of serious/critical axe findings.
- Browser checks prove the route does not read assessment `sessionStorage`, expose answer IDs in URL/DOM/logs or contact an unexpected origin.
- Client manifest/chunk inspection proves result/scoring internals are absent from client bundles.

## Required verification

Run and report exact results for:

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

- strict UTF-8 decoding, balanced Markdown fences and unresolved-marker scan
- complete changed-file and dependency/config diff review
- Thai/English static route output and 320px/reduced-motion/accessibility behavior
- exact recommendation/practice trace and six-unassessed/two-multiplier invariants
- no forbidden result fields or personalized wording
- client-reference manifest and static client-chunk content
- Gitleaks `8.30.1` scans of the nonignored worktree, exact staged content, proposed history and pushed history
- unchanged local/remote `main`
- matching local/remote feature head
- exact Public GitHub destination, Draft/unmerged PR state and clean final worktree
- retained Jeff-authorized development authentication without displaying credentials

## GitHub workflow

1. Work only on `agent/skill-map-priority-prototype` from the authorized base.
2. Inventory and intentionally stage only reviewed RP-TURN-008 files.
3. Inspect staged names, status, diff stat and `git diff --cached --check` before commit.
4. Scan the exact staged content with Gitleaks before commit.
5. Create one intentional implementation commit unless a correction is required.
6. Push normally to the exact `origin` without force.
7. Open exactly one Draft PR to `main` titled `feat: prototype synthetic skill result`.
8. Verify the pushed history with Gitleaks and confirm local/remote head equality.
9. Do not mark ready, merge, configure CI/branch protection or begin RP-TURN-009.

## Acceptance criteria

- The example result is transparently identified as synthetic and derived from one exact reviewed fixture.
- Current player selections have no effect on the result and never cross the existing browser-only boundary.
- The visible contract contains two provisional raw core signals, six explicit unassessed cores and two separate single-scenario multiplier observations.
- The single example next practice is non-personalized and has a complete deterministic trace to a planned/unavailable lesson reference.
- No prohibited score, proficiency, confidence, employment, readiness, risk or personality semantics exist.
- Thai and English routes are statically generated, accessible, text-equivalent, reflow-safe and privacy-preserving.
- Tests use both accepted fixtures and all required quality/security gates pass.
- Main remains unchanged; the bounded branch is pushed to one Draft, unmerged PR; RP-TURN-009 is not started.

## End-of-turn requirement

Update `PROJECT_STATUS.md` with factual progress only, then return a handoff using `prompts/VS_CODE_HANDOFF_TEMPLATE.md`. The handoff must identify the exact visible fixture, result/example-practice contract, changed files, actual verification, client-boundary evidence, commit hash, Draft PR URL and confirmation that RP-TURN-009 was not started.
