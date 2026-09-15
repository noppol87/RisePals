# Interactive source-verification mission v2

15 September 2026 · implemented after Jeff approved the experience review.

## What changed

The public lesson now asks the learner to spot an unsupported phrase, select a
relevant source, complete a corrected summary and choose what to do before using
it. Essential evidence stays visible beside the task. Choosing a summary fragment
updates the draft immediately. The result shows the original AI draft and the
learner's actual summary and next action.

The first fictional operations case is coached: a submitted choice receives a
short, specific explanation; the learner must correct it before continuing. The
completion copy explicitly says guidance was provided. A second fictional staff
survey case uses different evidence and withholds feedback until all four choices
are submitted. Incorrect decisions receive specific explanations; the actual
chosen summary remains visible rather than being silently replaced by an ideal
answer. A supported example is available separately. Repeating the case clears
its choices, and the independent result makes no validated proficiency claim.

Correct answers vary by position. No single repeated position passes either
case's complete authored answer key. Distractors address plausible mistakes:
using a simple average across different samples, treating missing data as zero,
using one-sided survey comments, and generalizing respondents to all staff.
These changes improve the exercise design; user testing is still required to
establish whether it improves learning or engagement.

The home page's primary action opens this mission. The six-scenario assessment
remains a secondary link. The lesson uses a smaller navigation/footer, concise
Thai/English copy, native SVG bars and a short summary-insertion movement.
Keyboard input, focus management and reduced motion are supported. Text remains
fully opaque throughout animation to maintain contrast.

## Content version and scope

- New authored content is explicitly versioned at
  `content/missions/source-verification/2.0.0.json`, with status `local-prototype`
  and validation status `unvalidated`.
- This is a public guided-mission contract, not a promotion of a new trusted
  published lesson for private saved practice.
- The operations facts reuse the immutable fictional source pack
  `source-verification-practice@1.0.0`. The AI draft and questions are newly
  authored in the v2 mission. The staff-survey case is newly authored fictional
  data: 100 invitations, 20 replies, 12 choosing evenings, 8 choosing other times,
  and 80 non-respondents whose preferences are unknown.
- The old lesson files and published registry were not edited. Registry aggregate
  SHA-256 remains `d1d73e26afc718fcdc86c2dab54853ddbd488ad171c1c1f81e3d64e2f55c1525`.
- Private v1 lesson attempts, assessment scoring and persistence remain on their
  existing contracts. Public v2 does not award XP, create a saved proof artifact,
  read assessment choices, or claim certification.
- Choices live only in React memory. Refresh or a locale navigation starts over.
  Connecting v2 to saved progress requires an explicit future publication and
  persistence integration, rather than reusing v1 identities.
- No dependency, raster asset, model call, hosted resource or DNS change was added.

## Verification performed

| Command / check | Result |
| --- | --- |
| `npm test -- --reporter=dot` | 418 tests in 46 files pass |
| `npm run typecheck` | Both TypeScript configurations pass |
| `npm run lint` | Pass |
| `npm run format:check` | Pass |
| `npm run content:validate` | Existing published registry plus new mission integrity checks pass |
| `npm run build` | Production build and all 27 static pages pass |
| `npm run test:e2e` | Initial run: 82 of 85 pass; three mission cases detected transient low contrast during the insertion fade |
| `npm run test:e2e -- tests/e2e/source-verification-lesson.spec.ts` | After making text fully opaque throughout motion, all 8 mission cases pass, including the three failures |
| `git diff --check` | Pass |

The browser checks cover Thai/English entry, both cases, each task's accessible
structure, before/after output, incorrect feedback, missing-answer focus,
keyboard operation, Back, reset, refresh, 320px reflow, 44px touch targets, both
motion preferences and absence of choice data in storage, cookies, URLs, logs or
network payloads. The original unsupported-locale Next.js `NoFallbackError` log
still appears while the associated 404 assertions pass.

Production screenshots were captured at 1440 × 1000 and 390 × 844 in both
languages, with reduced motion. Files are in
`docs/design/risepals-mission-v2-{th,en}-{desktop,mobile}-{start,claim,rewrite,result}.png`.
Thai mobile start/result and desktop Thai claim/English rewrite were visually
inspected; the final captures include the corrected inline button arrows.

## Changed-file map

- `content/missions/source-verification/2.0.0.json`: two bilingual versioned cases.
- `scripts/content/validate-mission.mjs`, `package.json`: build-time content checks.
- `src/modules/lesson/source-verification/mission-v2.ts`: typed content and complete-answer evaluation.
- `src/components/source-verification-lesson.tsx`: coached/independent interaction and honest result output.
- `src/app/experience.css`: scoped mission layout, touch controls, comparison and motion.
- `src/app/[locale]/lessons/source-verification-practice/page.tsx`: matching concise metadata.
- `src/components/public-narrative.tsx`, `src/lib/i18n/catalogs.ts`: mission-first home entry.
- `tests/components/source-verification-lesson.test.tsx`, `tests/components/public-narrative.test.tsx`: content integrity and interaction regression.
- `tests/e2e/source-verification-lesson.spec.ts`, `tests/e2e/app-shell.spec.ts`,
  `tests/e2e/experience-design.spec.ts`, `tests/e2e/persisted-lesson-progress.spec.ts`:
  browser coverage and updated navigation expectations.
- `README.md`, `PROJECT_STATUS.md`, `docs/17_EXPERIENCE_REVIEW.md`, this document
  and the v2 screenshots: review, implementation evidence and current status.

## Remaining work

No real-user study, independent content review, production deployment, hosted
Supabase setup or saved v2 progress was performed. The next useful product check
is the small usability round described in `docs/17_EXPERIENCE_REVIEW.md`: observe
whether Thai office workers can start unaided, explain their choices, and apply
the principle to the second case. No participants have been contacted.
