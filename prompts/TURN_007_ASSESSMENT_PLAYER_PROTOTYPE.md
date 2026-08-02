# RP-TURN-007 — Assessment Player Prototype

**Authorization:** Jeff approved this bounded implementation turn through Project Codex.  
**Authorized base:** `dbd46bb7978ca05ae7a5a7a459e153e827a911a5`  
**Branch:** `agent/assessment-player-prototype`  
**Draft PR title:** `feat: add assessment player prototype`

## Objective

Build an accessible Thai-first and English-complete multi-step assessment player prototype using the accepted six-item synthetic RP-TURN-006 contract. This player is a usability prototype, not a validated assessment. It must not produce a skill profile, score interpretation, priority gap or recommendation.

## Read before implementation

1. `AGENTS.md`
2. `README.md`
3. `PROJECT_STATUS.md`
4. `docs/01_PRODUCT_VISION.md`
5. `docs/02_SKILL_FRAMEWORK.md`
6. `docs/03_MVP_SCOPE.md`
7. `docs/05_BRAND_VISUAL_CONTENT.md`
8. `docs/07_TECHNICAL_ARCHITECTURE.md`
9. `docs/08_DATA_MODEL.md`
10. `docs/09_ENGINEERING_PLAN.md`
11. `prompts/VS_CODE_HANDOFF_TEMPLATE.md`
12. The accepted RP-TURN-006 assessment module and tests
13. This turn brief

## Authorized routes and shell boundary

- Add `/th/assessment` and `/en/assessment` through the existing locale boundary and app shell.
- Keep Thai as the default and make English intentionally complete.
- Unsupported locale segments fail consistently.
- Keep the route/page server-rendered or statically generated where possible.
- Limit Client Components to the interactive player and narrowly justified route-aware behavior.
- Do not convert the public narrative or full app shell into a Client Component.
- Add honest `noindex, noarchive` metadata to both unvalidated prototype routes.

## Required player flow

### Introductory context

- Label the experience as a prototype containing six synthetic workplace scenarios.
- State that it is not validated or calibrated.
- State that it cannot predict job loss, job performance, employability or hiring eligibility.
- State that no result or recommendation is available in this turn.
- Explain temporary same-tab/browser-session storage before start.
- Do not request role, employer, experience, goals, name, email, consent profile or free text.
- Starting the prototype is not a legal consent receipt.

### Six question steps

- Render exactly one accepted RP-TURN-006 scenario at a time.
- Preserve exact Thai and English question and option wording.
- Use native `fieldset`, `legend` and radio controls.
- Require one option before continuing.
- Provide Back and Continue controls.
- Preserve selections when navigating backward.
- Do not expose rubric points, target mappings, framework weights or scoring configuration to the Client Component.

### Honest progress

- Show current position as question/scenario N of 6.
- Distinguish current position from answered count.
- Never present completion percentage as a skill score.
- Announce step changes accessibly without excessive repetition.
- Move focus deliberately after transitions without trapping focus.

### Completion

- Confirm that all six prototype scenarios were answered.
- State that results are unavailable in RP-TURN-007.
- Do not calculate, display or imply score, proficiency, confidence, multiplier pattern, priority gap or recommendation.
- Provide actions to review answers, clear/start again and return to the localized home page.
- Clearing removes the stored prototype state.

## Session-only resume contract

- Use versioned `sessionStorage` only.
- Store only storage-schema version, assessment version ID, current player state/item identity and selected item/option IDs.
- Do not store localized copy, rubric points, scores, timestamps, profile data or free text.
- Do not place responses in URLs, cookies, console output, logs, analytics or network requests.
- Treat selected option IDs as sensitive assessment data even though storage is local and temporary.
- Validate loaded state against the current assessment definition.
- Reject and clear malformed, unknown, incomplete or version-incompatible stored state safely.
- Handle unavailable or throwing `sessionStorage` without crashing.
- Refresh in the same page session resumes the saved step and selections.
- Explain that storage is local to the browser session, not server persistence and is not guaranteed durable.
- Provide an explicit user-controlled clear action.
- Starting the prototype does not create a consent receipt.

## State and client-safe data architecture

- Keep player state transitions and stored-state validation in pure TypeScript separate from React.
- Keep `sessionStorage` access behind a narrow client adapter.
- Create a presentation DTO containing only the assessment ID/version needed for compatibility, localized prompt, item key/display order and option ID/localized label.
- Strip `rubricPoints`, rubric target IDs/kinds, framework weights, scoring configuration and explanation internals before data reaches the player.
- Do not import raw-response fixtures or expected-output fixtures into runtime UI code.
- Verify scoring configuration is absent from browser client chunks.

## Localization and navigation

- Add typed assessment-player catalogs for Thai and English.
- Update the landing CTA and availability/boundary copy honestly: the six-scenario player prototype is available, but no validated assessment or result exists.
- Route the CTA to the matching locale assessment path.
- Preserve existing evidence records, URLs, qualifiers and review-expiry validation unchanged.
- Switching locale from an assessment route reaches the equivalent assessment route and retains the same session state.
- If route preservation requires a Client Component in the language switcher, keep it narrow and document the reason.
- Provide an obvious localized route back home.

## Accessibility and interaction

- Use native keyboard-operable radios and buttons with visible focus and at least 44px targets.
- Associate inline validation errors with the question group, announce them and move focus appropriately.
- Give progress an accessible text equivalent.
- Announce step changes without an excessive live-region loop.
- Preserve answers on Back.
- Support 320px and 400%-equivalent reflow without horizontal overflow.
- Keep desktop reading/focus order logical and Thai wrapping readable.
- Remove non-essential animation in reduced-motion mode.
- Automated axe checks must report zero serious or critical findings in both locales.

## Required tests

### Pure state and storage

- intro → question → completion transitions
- selection and replacement
- Back/Continue behavior
- honest current/answered counts
- complete-answer requirement
- reset behavior
- serialization round trip
- assessment/storage version mismatch
- malformed payload
- duplicate/unknown item or option
- unavailable or throwing `sessionStorage`
- no prohibited fields in stored payload
- no score/result fields in player state

### Component

- Thai and English introductory boundaries
- semantic fieldset/legend/radio structure
- required-answer error and focus behavior
- progress announcement
- backward answer preservation
- completion wording and actions
- clear/restart behavior
- no rendered score, proficiency, recommendation or hiring implication

### End-to-end

- localized landing CTA enters the matching player
- complete six-step flow by keyboard
- missing-answer validation
- Back and answer preservation
- refresh mid-flow resumes current step and selections
- clear action removes stored state
- equivalent-route locale switch preserves progress
- completion displays no result
- normal-motion and reduced-motion cross-step flow
- 320px/reflow and representative desktop behavior
- Thai and English axe checks
- no unexpected third-party request
- no response payload in URLs or outgoing requests

### Build and client inspection

- `/th/assessment` and `/en/assessment` build successfully.
- Public landing and accepted evidence behavior remain intact.
- Browser static chunks contain no scoring-model ID, `rubricPoints`, expected fixture output or raw fixture data.
- Only approved interactive boundaries appear in the client-reference manifest.

## Documentation

- Record the session-only prototype data boundary in `docs/08_DATA_MODEL.md`.
- Record `sessionStorage` as a prototype-only, non-production decision in `docs/DECISION_LOG.md`.
- Update `docs/10_LOCAL_DEVELOPMENT.md` with actual commands and results.
- Update `README.md` and `PROJECT_STATUS.md` only with facts changed in this turn.
- Mark RP-TURN-007 complete pending Project Codex review, not Accepted.
- State accurately that selected option IDs may temporarily exist in browser `sessionStorage`.

## Dependencies and security

- Add no dependency unless genuinely unavoidable; stop for a decision before adding one.
- Preserve the npm install-script policy and security overrides.
- Add no raster asset or illustration.
- Use no API route, Server Action, database, cookie, authentication, analytics or external service.
- Create no persistent account/profile or legal consent receipt.

## Required verification

- `npm ci`
- pending install-script query and `strict-allow-scripts` check
- `npm run format:check`
- `npm run lint`
- `npm run typecheck`
- `npm run test`
- `npm run build`
- `npm run check`
- `npm run test:e2e`
- `npm audit --omit=dev`
- `npm audit`
- strict UTF-8, Markdown-fence, unresolved-marker and Git diff checks
- client-boundary and browser-chunk inspection
- Gitleaks worktree, staged, proposed-history and pushed-history scans
- local/remote feature-head equality
- unchanged local/remote `main`
- clean final worktree
- Open, Draft and unmerged PR

## Out of scope

- RP-TURN-008 result or skill-map work
- scoring display or interpretation
- priority recommendations
- real assessment methodology or validation
- role/profile onboarding fields
- durable resume across browser sessions or devices
- database, authentication, analytics or consent receipts
- lesson, XP, proof or opportunity features
- CI, infrastructure, VPS service or deployment
- merge or closeout

## GitHub workflow

- Commit only the reviewed RP-TURN-007 scope.
- Push only `agent/assessment-player-prototype` without force.
- Open one Draft PR to `main` titled `feat: add assessment player prototype`.
- Do not merge.
- Retain Jeff-authorized GitHub development authentication without exposing, rotating or broadening credential material.

## Required handoff

Return a TURN HANDOFF using `prompts/VS_CODE_HANDOFF_TEMPLATE.md`. Include exact changed files, state/storage schema, privacy boundary, tests and actual results, client-bundle inspection, commit hash, Draft PR URL, authentication state and confirmation that RP-TURN-008 was not started.
