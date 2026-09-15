# Less reading, more trying — 15 September 2026

## Request and result

Jeff asked for shorter, conversational Thai, equally concise English, and more
visual interaction. The first visit now leads with a small action, an interactive
skill map and a practice mission. Extra detail is available through native
expandable sections instead of a long initial page.

- Thai headline: “ไม่ต้องเก่งทุกอย่าง / เริ่มแค่อย่างเดียว”.
- English headline: “You don’t need it all. / Just a place to start.”
- Everyday landing labels, skill names, mission artwork, navigation and footer
  are localized. The English language switch and proper source titles remain
  intentionally identifiable.
- The six-step journey remains complete. Eight skills and two supporting habits
  remain separate; there is no personal score on the landing page.
- Evidence claims, source links, scope, limitations and dates are preserved in
  expandable references. Claims are not detached from their qualifications.
- Assessment details are expandable; the no-score introduction and temporary
  browser-storage explanation remain visible before starting.
- Lesson framing, actions and explanatory labels use shorter copy. Lesson
  metadata, feedback criteria and future proof structure are expandable. The
  versioned scenario, source records, response choices and scoring rules remain
  unchanged. The fictional organization has a Thai display name.
- Example-result provenance and method details are expandable. The visible
  “not your result” boundary and text-equivalent synthetic evidence remain.
- Test-account, saved-learning and private-record copy is shorter in both
  languages. Consent notices, data behavior and access rules are unchanged.

## Measured first-load reading load

Measured `main.innerText.length` on the local production builds before and after,
using a 1440 × 1000 viewport with disclosures initially closed. These are
character counts including spaces, not Thai word counts or usability outcomes.

| Route | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Thai home | 5,744 | 1,017 | 82% |
| English home | 6,568 | 1,132 | 83% |
| Thai assessment intro | 1,153 | 383 | 67% |
| Thai lesson | 4,057 | 2,408 | 41% |
| Thai example result | 4,275 | 1,870 | 56% |
| Thai sign-in | 304 | 172 | 43% |
| Thai saved learning | 549 | 374 | 32% |
| Thai private records | 872 | 589 | 32% |

Expansion reveals the full supporting material. This reduction measures what a
visitor initially sees, not deletion of the evidence or lesson content.

## Visuals and motion

Used Jeff's suggested SVG/motion alternative. The available image tool cannot
select or confirm GPT Image 2.5, so no image was generated under that model name.
No raster asset, stock image, dependency or remote-media request was added.

The existing native SVG skill map now traces the selected connection on
interaction. The mission icon draws on entering view, and disclosure controls
rotate on expansion. Motion finishes quickly and is disabled with
`prefers-reduced-motion`. Text stays opaque throughout. Native disclosures work
with keyboard input and without JavaScript.

Production screenshots in `docs/design/`:

- `risepals-concise-th-desktop.png` and `risepals-concise-en-desktop.png`:
  full landing pages, 1440px wide.
- `risepals-concise-th-mobile.png`: full Thai landing, 390px wide.
- `risepals-concise-lesson.png`: full Thai lesson, 1440px wide.

## Changed-file map

- `src/lib/i18n/catalogs.ts`: bilingual landing, assessment and example copy.
- `src/components/public-narrative.tsx`, `evidence-section.tsx`: concise home
  composition and expandable framework/references.
- `skill-orbit.tsx`, `app-shell.tsx`: localized visual labels and footer.
- `assessment-player.tsx`, `source-verification-lesson.tsx`,
  `synthetic-example-result.tsx`: concise framing and optional details.
- `src/app/experience.css`: disclosure controls, tighter layout and SVG motion.
- `src/modules/profile/copy.ts`, `src/modules/lesson/persistence/copy.ts`,
  `src/modules/evidence/copy.ts`: simpler account and saved-work copy.
- Component/browser tests: new copy, explicit disclosure interaction, retained
  source/trace/score/privacy assertions and concise-first-visit checks.
- `README.md`, `PROJECT_STATUS.md`, this record and screenshots: handoff evidence.

## Verification

- `npm run format:check`: pass.
- `npm run lint`: pass.
- `npm run typecheck`: both configurations pass.
- `npm test`: 416 tests across 46 files pass.
- `netlify-cli@27.6.0 build --offline --context deploy-preview`: passes with
  Next.js Runtime 5.15.13, including server and edge-function packaging.
- `npm run test:e2e`: 75/88 passed initially. The remaining 13 had obsolete
  text selectors or duplicate-CTA selection; updated those expectations without
  changing the behavior checks. `npm run test:e2e -- --last-failed`: 13/13 pass.
- `npm run test:e2e:alpha`: six desktop/mobile/reduced-motion checks pass.
- Three added browser cases cover initial reading load, fully Thai everyday
  landing labels, keyboard expansion/collapse and JavaScript-disabled references.
- Additional Axe scans with all details expanded: Thai/English home, lesson and
  example result, no serious or critical WCAG A/AA violations.
- Production screenshots reviewed on desktop and mobile; landing captures use
  reduced-motion mode to show settled graphics.
- The known unsupported-locale Next.js `NoFallbackError` log remains; the
  corresponding tests still receive the expected 404 responses.

## Limits

This is a local, synthetic prototype. No hosted service, deployment, DNS change,
real-person data collection or paid resource was created in this pass. Real-user
usability testing and deployed performance measurements remain outstanding.
