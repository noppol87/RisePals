# Rise Pals experience redesign — 15 September 2026

## Outcome

Jeff requested a more beautiful, engaging UI/UX across the website. The new
experience uses warm ivory, deep green, lime and restrained lilac, with locally
served Manrope and IBM Plex Sans Thai. The shared shell, navigation, controls,
assessment, result and lesson surfaces use the same visual language.

The landing page now leads with a concise invitation and an interactive 8-skill
map. Selecting a skill reveals its existing framework description. It does not
calculate a score, create an account or save the selection. The two multipliers
remain separately explained in the full framework below.

A direct entry into the existing source-verification mission makes practice
discoverable. The six-step development loop, both attributed evidence records,
eight competencies, two multipliers and synthetic-alpha boundaries remain
available. No testimonials, user counts or career outcomes have been invented.

## Interaction and accessibility decisions

- The primary action is visible near the top of both the landing and assessment
  introduction. Detailed prototype information follows the introduction.
- Navigation exposes home, assessment, practice and profile on desktop and mobile.
  Language switching keeps the current supported route.
- The skill map uses native buttons with accessible names, pressed states and a
  live description. Every target is at least 44px at the 320px viewport.
- The assessment has six visual segments driven by actual scenario/selection
  state. Existing keyboard focus, back, validation and temporary resume behavior
  are preserved. Completion decoration represents completed scenarios only.
- Lesson shortcuts jump directly to the scenario, concepts and practice, with
  space reserved for the sticky header.
- Motion uses short transforms and control feedback. Text remains fully opaque
  throughout entrance motion. Reduced-motion mode disables animation completely.
  Content is visible without waiting for JavaScript or an intersection observer.
- Technical turn IDs and database implementation terms were removed from the
  assessment's user-facing copy. The data-storage and prototype limitations remain.

## Assets and dependencies

All new visual elements are native SVG/CSS interface graphics: the Rise Pals mark,
skill icons/map and the source-checking card composition. No generated raster
illustrations, stock photos or external image requests are used.

`@fontsource-variable/manrope@5.3.0` and
`@fontsource/ibm-plex-sans-thai@5.3.0` provide self-hosted fonts under OFL-1.1.
The packages retain their licenses. Fonts use `font-display: swap`; browser
requests stay on the application origin. No animation library was added.

Screenshots in `docs/design/` show the actual local production build with
synthetic content, captured with Playwright:

- `risepals-home-desktop.png`: Thai home, 1440 × 1000.
- `risepals-home-mobile.png`: Thai home, 390 × 1000.
- `risepals-assessment.png`: English scenario and selected response, 1440 × 1000.

## Changed-file map

- `src/app/experience.css`: shared design tokens, layouts, controls, responsive
  adjustments and motion. Imported after the existing baseline styles.
- `src/app/[locale]/layout.tsx`: stylesheet and local font imports.
- `src/components/brand-mark.tsx`, `skill-orbit.tsx`, `experience-motion.tsx`:
  reusable graphics, skill exploration and progressively enhanced motion.
- `app-shell.tsx`, `shell-navigation.tsx`: wordmark, navigation and footer.
- `public-narrative.tsx`, `evidence-section.tsx`: landing composition and evidence
  presentation. Source claims, URLs and metadata remain intact.
- `assessment-player.tsx`, `source-verification-lesson.tsx`: action hierarchy,
  visual scenario progress, completion state and lesson shortcuts.
- `src/lib/i18n/catalogs.ts`: concise bilingual landing and assessment UI copy.
- Tests: updated copy expectations and five new browser interaction checks.
- `AGENTS.md`: Next.js itself added its version-specific guidance during
  `next dev`; verified against its installed generator and retained.

## Verification

Verified with Node 24.18.1, npm 11.16.0 and Playwright Chromium:

| Check | Result |
| --- | --- |
| `npm run format:check` | PASS |
| `npm run lint` | PASS |
| `npm run typecheck` | PASS: application and database configurations |
| `npm test` | PASS: 416 tests across 46 files |
| `npx --yes netlify-cli@27.6.0 build --offline --context deploy-preview` | PASS: application plus server and edge packaging |
| `npm run test:e2e` | PASS: 85 tests, including five new interaction checks |
| `npm run test:e2e:alpha` | PASS: 6 desktop/mobile/reduced-motion checks |
| `npm audit --omit=dev` | PASS: zero reported vulnerabilities |
| `git diff --check` | PASS |

Visual inspection covered the production home on desktop/mobile, a selected
scenario response, and lesson/result/auth surfaces. The browser tests check both
locales, absence of unexpected third-party requests, keyboard navigation,
temporary-response resume, 320px reflow and serious/critical axe findings.

An earlier browser pass found contrast loss during an opacity entrance animation
and an overridden lesson-label colour. The implementation now uses full-opacity
transforms and preserves the label's contrasting text. The final 85-test run
passes with the original accessibility assertions enabled. Unsupported-locale
404 checks still produce the previously documented Next.js `NoFallbackError` log;
their response assertions pass.

## Limits and next checks

This is a working visual redesign of the synthetic alpha, not evidence that the
assessment or learning outcomes are validated. Live-user usability research and
measurements on deployed mobile networks remain necessary before claiming a
production UX result. Database migrations, scoring logic and versioned lesson
content were not changed in this design pass.

The Supabase organization is selected. The tool quoted 10 USD/month for an
additional project, and explicit cost approval remains pending. No paid project,
live email flow, production deployment or domain change was made by this pass.
