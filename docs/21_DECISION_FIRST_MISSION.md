# Rise Pals — Decision-first source-verification mission

Date: 16 September 2026  
Status: local product prototype; user research and hosted setup remain pending

## Problem addressed

The previous lesson split the prompt, evidence and choices across the page. A
learner could see an attractive interface but still need to work out what they
were checking, why it mattered and which text the choices answered. On mobile,
the AI answer being checked disappeared completely.

## Result

Mission `2.1.0` now frames one realistic responsibility: help a team check an AI
summary before somebody uses it to make a decision. Each screen keeps the same
mission goal visible and asks one concrete action:

1. find the part that goes beyond the evidence;
2. choose the evidence that tests it;
3. write only what the evidence supports;
4. choose what should happen before the summary is used.

The question, short instruction and choices now live in one decision column.
The evidence and AI answer stay together in the other column and remain visible
at 320px. The progress tracker names the four actions, while the local heading
states only the action happening now. This removes duplicate step counters.

Feedback says why the selected answer fits or does not fit. The final screen
shows the original AI draft, the learner's supported summary and the action they
would take before using it. Its headline describes practical decision readiness
instead of claiming that the learner has fully fixed the source material.

Thai copy is short and conversational. English follows the same task logic and
length. Both fictional cases use general team decisions rather than job titles,
so the practice can make sense across office, service, operations and other work.

## Evidence boundary

Both scenarios and their figures are fictional. The experience teaches a
repeatable checking pattern; it does not assess proficiency, validate a career
skill or prove that the wording fits every occupation. Choices stay in React
memory, reset on refresh and are not stored or sent to a server.

## Files changed

- `content/missions/source-verification/2.1.0.json`
- `scripts/content/validate-mission.mjs`
- `src/modules/lesson/source-verification/mission-v2.ts`
- `src/components/source-verification-lesson.tsx`
- `src/app/[locale]/lessons/source-verification-practice/page.tsx`
- `src/app/experience.css`
- `tests/components/source-verification-lesson.test.tsx`
- `tests/e2e/source-verification-lesson.spec.ts`
- `tests/e2e/experience-design.spec.ts`
- `tests/e2e/persisted-lesson-progress.spec.ts`
- `README.md`
- `PROJECT_STATUS.md`
- `docs/21_DECISION_FIRST_MISSION.md`

Mission `2.0.0` is replaced by `2.1.0` because the prompts, answer explanations
and experience contract changed before publication. Immutable published lesson
v1 and private saved practice identities remain unchanged.

## Verification

- `npm run check` — passed
- formatting and lint — passed
- both TypeScript configurations — passed
- unit/component tests — 418 passed across 46 files
- content validation — mission `2.1.0` passed bilingual and answer-integrity checks
- production build — passed; 27 static pages generated
- targeted Chromium run — 16 passed across the first-visit and complete mission flows
- full Chromium run — all 85 browser checks passed
- 320px browser checks — touch targets, reflow and readable results passed
- visual review — Thai desktop and 390px mobile task states; the evidence and AI
  answer remain visible with no horizontal overflow

## Next research step

Watch first-time users from varied work settings complete both cases without
help. Ask what decision they believe they are supporting, which information they
look at first and how they would apply the four actions to their own work. Revise
the cases from observed confusion before treating this as validated learning
content.
