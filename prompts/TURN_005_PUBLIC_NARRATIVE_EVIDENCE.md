# RP-TURN-005 — Public Narrative and Evidence Contract

**Authorization:** Jeff approved this bounded implementation turn through Project Codex.  
**Authorized base:** `89f14276cdf7e641cb9738533ad4e10cf5fe46e8`  
**Branch:** `agent/public-narrative-evidence`

## Objective

Replace the structural verification content at `/th` and `/en` with the first Thai-first public Rise Pals narrative prototype. Establish a reusable, validated and source-backed evidence contract plus an honest non-collecting CTA. This is a public narrative prototype only—not onboarding, assessment, waitlist collection or production launch.

## Read and verify first

1. Read `AGENTS.md`, `README.md` and `PROJECT_STATUS.md`.
2. Read `docs/01_PRODUCT_VISION.md` through `docs/05_BRAND_VISUAL_CONTENT.md`.
3. Read `docs/07_TECHNICAL_ARCHITECTURE.md`, `docs/09_ENGINEERING_PLAN.md` and `docs/10_LOCAL_DEVELOPMENT.md`.
4. Inspect the accepted localized shell and every existing test.
5. Verify both authorized primary sources directly before writing rendered claims. Search snippets and secondary reporting are not evidence for the rendered claims.

## Authorized evidence and factual boundaries

Render exactly these two evidence items. Stop for Project Codex review before adding any other statistical claim.

### ILO–NASK

- Direct source: <https://www.ilo.org/publications/generative-ai-and-jobs-refined-global-index-occupational-exposure>
- Publication date: `2025-05-20`
- Permitted factual basis:
  - Globally, about one in four workers are in occupations with some degree of GenAI exposure.
  - Because most occupations still contain tasks requiring human input, transformation is more likely than wholesale replacement.
- Required qualifier:
  - Exposure is task/occupation potential, not a prediction that an individual will lose their job.
  - The estimate is global and must not be presented as Thailand-specific.

### World Economic Forum, Future of Jobs Report 2025, Skills Outlook

- Direct source: <https://www.weforum.org/publications/the-future-of-jobs-report-2025/in-full/3-skills-outlook/>
- Report date: `2025-01-07`
- Permitted factual basis:
  - Surveyed employers expect 39% of workers’ core skills to change by 2030.
- Required qualifier:
  - This is an employer-expectation survey across the report’s documented economies and industries, not a certainty or individual forecast.
  - Verify and record the exact sample/context from the original report before rendering it.

## Required public narrative

### Hero

- Use Thai-first optimistic realism.
- Explain that work expectations are changing while people can prepare and grow.
- Do not predict job loss or imply the product can guarantee employment.

### Evidence / why now

- Render exactly the two authorized evidence items.
- Pair each risk/change signal with a constructive next action.
- Show concise source attribution and a direct source link.
- Make scope and limitations visible without a tooltip or hidden modal.

### Rise Pals response

- Explain the complete loop: Diagnose → Prioritize → Learn → Practice → Prove → Opportunity.
- Do not reduce Rise Pals to AI-tool or prompt training.
- State that practice, feedback and proof matter—not passive completion.

### 8+2 framework preview

- Present the documented eight core competencies and two multipliers accurately and compactly.
- Do not introduce scoring, weights, personal risk levels or assessment questions.
- Preserve the distinction between core competencies and multipliers.

### Honest CTA

- Use a real internal page anchor that helps the visitor continue reading the public explanation.
- State honestly that assessment and onboarding are not available in this turn.
- Add no disabled fake control, email field, waitlist form, pricing claim, account creation or data collection.

## Localization

- `/th` remains the default and uses intentional natural Thai copy.
- `/en` contains complete intentional English copy with the same information architecture and evidence contract.
- Catalog keys remain structurally identical.
- Source metadata may be shared when factually identical; rendered claim interpretation and qualifiers are localized.
- Catalog and evidence content contain no raw HTML.

## Evidence contract

Create a typed static evidence model separated from presentation components. Require at least:

- stable evidence ID
- localized claim text
- localized interpretation/action
- source title
- original direct HTTPS URL
- publisher
- publication date
- geography
- sample/method/context
- what the evidence does not prove
- date last verified
- review/expiry date

Add deterministic validation that rejects:

- missing required fields
- unsupported locale coverage
- blank localized values
- non-HTTPS or malformed source URLs
- invalid ISO dates
- review date not later than verification date
- evidence past its review date at publication/build time
- raw HTML
- duplicate evidence IDs

Use static reviewed repository content only. Add no runtime API fetch, remote CMS, executable MDX, analytics or third-party script.

## Components and architecture

- Keep Server Components as the default.
- Add only the semantic landing/evidence components required by this turn.
- Reuse `PageContainer`, `Stack` and `TextLink` where appropriate.
- Preserve the app shell, locale routing and server-only catalog boundary.
- Use semantic headings, sections, lists and figure/citation semantics where appropriate.
- Do not create a general-purpose component library or premature design abstraction.
- Add no npm dependency. If implementation becomes impossible without one, stop for Project Codex decision.

## Visual and performance constraints

- Continue using the provisional RP-TURN-004 tokens; do not declare palette, typography or layout final.
- Add no raster image, illustration, stock image, Pal character, remote font, icon pack or decorative asset.
- If an illustration becomes necessary, stop for a separate GPT-Image-2 scope.
- Add no Client Component for the narrative and no third-party request during page load.
- Keep `/th` and `/en` statically generated.
- Record evidence that the turn adds no client-side hydration boundary or narrative client bundle.
- Maintain 320px and 400%-zoom-equivalent reflow, visible focus, 44px interactive targets and reduced-motion behavior.

## Required tests

- Unit tests for every evidence-validator rejection case.
- Tests proving Thai and English catalogs/evidence contain matching complete keys.
- Semantic render tests for hero, evidence section, product loop, 8+2 distinction, qualifiers, source links and honest CTA.
- Browser tests for root redirect, both locales, document language, language switching, visible evidence attribution/qualifiers, exact source destinations, honest CTA/internal target, keyboard order/skip link, 320px/mobile, representative desktop, no horizontal overflow, reduced motion, serious/critical axe findings and no unexpected third-party request during initial page load.

## Required verification

- `node --version` and `npm --version`
- `npm ci`
- pending install-script query and `strict-allow-scripts=true`
- `npm run format:check`
- `npm run lint`
- `npm run typecheck`
- `npm run test`
- `npm run build`
- `npm run check`
- `npm run test:e2e`
- production and full npm audits at `--audit-level=low`
- manual Thai/English visual review at 320px and desktop, plus keyboard focus and reduced motion
- rendered-evidence comparison with both original sources
- provenance/review-date checks
- UTF-8, Markdown fences, unresolved-marker and `git diff` checks
- complete changed-file inventory
- prohibited-path and real-environment checks
- worktree, staged and proposed-history Gitleaks scans
- confirmation of no new dependency, runtime external request, client boundary, raster asset or personal data
- confirmation that `main` remains unchanged

## Documentation and status

- Update `README.md` with factual public-narrative behavior and commands only.
- Update `docs/10_LOCAL_DEVELOPMENT.md` only where verification facts change.
- Update `PROJECT_STATUS.md` to `RP-TURN-005 complete pending Project Codex review`; do not mark it Accepted.
- Preserve every open decision.
- Record evidence verification dates and review/expiry rationale.
- Do not add a `LICENSE`.

## GitHub workflow

- Commit only the reviewed bounded work with `feat: add public narrative and evidence contract`.
- Push only `agent/public-narrative-evidence` without force.
- Open one Draft PR to `main` titled `feat: add public narrative and evidence contract`.
- Include both source URLs, claim limitations, dependency statement and exact verification in the PR body.
- Do not merge the PR.
- Retain Jeff-authorized GitHub development authentication without displaying, rotating or broadening credential material.

## Out of scope

- onboarding
- assessment questions or scoring
- personalized risk or recommendations
- user profile or authentication
- waitlist or email collection
- pricing or payments
- database or Drizzle
- analytics or monitoring
- CMS or MDX execution
- lesson engine
- proof/evidence portfolio
- final branding, Pal system or generated imagery
- CI or branch protection
- VPS infrastructure, DNS or deployment
- public launch
- `LICENSE`
- RP-TURN-006

## Required handoff

Return a TURN HANDOFF labeled exactly `RP-TURN-005 — Public Narrative and Evidence Contract`. Include the new head SHA, complete changed-file list, both evidence records and their limitations, exact verification results, visual QA evidence, Draft PR URL/state and confirmation that no out-of-scope work or RP-TURN-006 was started.
