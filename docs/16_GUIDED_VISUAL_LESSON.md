# Guided visual lesson — 15 September 2026

## Result

Jeff found the source-verification lesson confusing and too text-heavy. The
public lesson now presents three stages: see the AI summary, check visual
source evidence, then answer one question at a time. Both languages follow the
same flow. The first screen has one prominent “Check this summary” action.

Initial Thai `main.innerText` fell from 2,408 to 494 characters (79% reduction,
rounded down), and the English initial view contains 585 characters. This
measures the first view with optional details closed, not removed source content.

## Visual evidence and data meaning

- An illustrated AI-summary card shows its unverified claim that all three teams
  improved by 30%. The original claim text and unverified label remain visible.
- The evidence stage compares team A at 30% across 12 fictional cases and team B
  at 8% across 40 cases. Team C has incomplete data and a question mark, with no
  zero-valued bar. The bars share a proportional scale.
- Two compact cards retain the 60-day pilot scope and two unresolved team C
  escalations. The source records can be expanded in full.
- Figures belong to the published fictional lesson v1. A version guard prevents
  reusing the illustration for an unknown lesson version. No learner score is
  inferred from the chart. Unit checks compare figures with the published source.
- All graphics use local SVG/CSS and adjacent readable text. No raster image,
  image-model call, dependency or external asset request was added.

## Guided practice

Each question has three original options, Back and Next controls, and a compact
progress indicator. An empty choice focuses a localized error. Moving backward
preserves selections, and the evidence is available in a disclosure beside the
question. Results appear only after all three decisions.

Existing rubric evaluation, criterion feedback, 0/20 preview XP, retry and reset
rules remain. Preview XP never accumulates or persists. Reload starts the lesson
again. No choices enter storage, cookies, URLs or network payloads. Private saved
practice and versioned lesson definitions are unchanged.

The stage controls identify the current step. Stage and question changes focus
the appropriate heading; hidden stages are excluded from keyboard navigation and
the accessibility tree. Reduced-motion settings disable bar animation. Full
method, version and proof-boundary details remain under the optional demo section.
JavaScript is required for the guided interaction, with an explicit noscript note.

## Changed files

- `src/components/source-verification-lesson.tsx`: stage navigation, single-question
  flow, recall disclosure, focus and validation behavior.
- `src/components/lesson-evidence-visual.tsx`: version-bound visual case, SVG bars,
  missing-data state, scope cards and original source records.
- `src/app/experience.css`: scoped guided-lesson desktop/mobile layouts.
- `tests/components/source-verification-lesson.test.tsx`: guided flow, validation,
  Back, rubric feedback, XP/reset and visual-data/version checks.
- `tests/e2e/source-verification-lesson.spec.ts`: both languages, every stage,
  keyboard focus, reflow, accessibility, privacy and reload behavior.
- `tests/e2e/experience-design.spec.ts` and `persisted-lesson-progress.spec.ts`:
  navigation into the new guided lesson.
- `README.md`, `PROJECT_STATUS.md`, this record, `docs/design/risepals-guided-*.png`:
  current handoff and actual production screenshots.

## Validation

- Formatting, ESLint and both TypeScript configurations pass.
- `npm test`: 418 tests across 46 files pass.
- Netlify CLI 27.6.0 offline deploy-preview build passes, including server and
  edge-function packaging.
- Targeted browser run: 24 of 25 passed initially. The English source assertion
  matched both the chart caption and original record; scoped it to the original
  record. Targeted rerun: 1 of 1 passes. All 25 relevant cases now pass.
- `npm run test:e2e:alpha`: all six desktop/mobile/reduced-motion checks pass.
- Accessibility scans cover all three stages in both languages. Keyboard focus,
  320px reflow, original-source access, Back, retry/reset, and memory-only
  behavior are exercised.
- Production screenshots reviewed for Thai/English story, evidence and first
  question, plus Thai mobile story and evidence. Captures use reduced motion
  and reset the viewport before full-page capture.

## Notes

The development server's HMR WebSocket failed to connect during visual checks;
interaction verification uses the successfully built production preview on port
3106. The existing unsupported-locale Next.js NoFallbackError log remains, while
404 assertions pass. No hosted service or DNS change was made.
