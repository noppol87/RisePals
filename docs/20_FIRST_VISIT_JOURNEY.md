# Rise Pals — First-visit journey prototype

Date: 16 September 2026  
Base: `ad036f5`  
Status: local product prototype; user research and hosted setup remain pending

## Result

The home page now begins with the visitor rather than an available lesson. It
shows one decision at a time:

1. choose what they want to improve;
2. choose a recent situation with a concrete work impact;
3. see the stated goal, situation, suggested path, reason and next action together.

Thai copy uses short conversational language. English follows the same concise
structure. The four entries cover smoother work, changes in tools and methods,
the next opportunity, and an unsure/exploration route. They avoid job titles so
people in varied work contexts can recognize a relevant situation.

## Evidence boundary

This is an experience hypothesis, not completed user research. The result is
derived only from what the visitor selected and is labelled as not being an
assessment. Choices live in React memory, are not written to browser storage or
sent to a server, and reset on refresh.

The critical source-verification path links to the available fictional public
mission. Systematic-thinking and strategic-storytelling paths say that their
content is still in development and describe the existing mission as a nearby
example. No new course, validated skill inference, score, proof or career claim
was created.

## Files changed

- `src/components/first-visit-journey.tsx`
- `src/components/public-narrative.tsx`
- `src/app/experience.css`
- `tests/components/public-narrative.test.tsx`
- `tests/e2e/app-shell.spec.ts`
- `tests/e2e/experience-design.spec.ts`
- `README.md`
- `PROJECT_STATUS.md`
- `docs/20_FIRST_VISIT_JOURNEY.md`

The previously uncommitted consolidated plan in
`docs/19_PRODUCT_REALIGNMENT_PLAN.md` remains part of the same product
realignment work.

## Verification

- `npm run format:check` — passed
- `npm run lint` — passed
- `npm run typecheck` — passed
- `npm test` — 418 tests passed across 46 files
- `npm run build` — passed; content validation and 27 static pages completed
- targeted Chromium browser run — 17 tests passed, including both languages,
  keyboard operation, no storage mutation, route continuity and 320px reflow
- full Chromium browser run — all 85 tests passed
- visual review — Thai initial and result states at 1440 × 1000

## Next research step

Test the complete three-step flow with people from different work contexts.
Ask what they think Rise Pals will do next, whether the situation language fits
their experience, and whether the suggested path feels justified. Record mismatches
before expanding the question set or building more paths.
