# RP-TURN-004 — Design Foundation, App Shell and Localization

## Authorization and objective

Jeff approved this bounded turn for `C:\Codex PC SG2\Jeff\risepals` from base commit `6e5180fcf8fec9f94cef3aac49a790ad3255be81`.

Establish Thai-first locale routing, a semantic responsive Server Component application shell, provisional semantic design tokens and the smallest accessible primitives required by that shell. This turn prepares structure only; it does not implement the landing narrative or another Rise Pals product feature.

## Required scope

- Work only on `agent/design-foundation`; preserve `main` and do not merge the pull request.
- Support exactly `th` as the default locale and `en` as a prepared secondary locale.
- Redirect `/` to `/th`, render typed catalogs at `/th` and `/en`, return not-found for unsupported locale segments and set the document language correctly.
- Keep catalog lookup server-only and pass resolved strings into UI components. Use BCP 47-compatible identifiers and preserve a replaceable native `Intl`-ready boundary without adding a localization dependency.
- Create a semantic shell with a skip link, text wordmark/home link, primary navigation, real-link language switcher, stable main focus target and no unnecessary Client Component.
- Refine semantic code-native tokens for color, typography, spacing, containers, radii, borders, elevation, focus and motion. Keep exact identity and the Pal system provisional; use only system/local font fallbacks.
- Add only the PageContainer, Stack, TextLink and LanguageSwitcher primitives currently required by the shell.
- Add exact pinned `@playwright/test` and `@axe-core/playwright` development dependencies, Chromium-only browser installation and targeted locale, keyboard, focus, reflow, reduced-motion and accessibility tests.
- Update README, local-development documentation and project status factually. Record retained development authentication generically and require credential narrowing/revocation before production readiness.
- Commit as `feat: establish localized app shell`, push the bounded branch and open a Draft PR with the same title.

## Constraints

- No landing narrative/evidence blocks, final brand palette/typeface/Pal direction, raster asset, stock image, Pal character, assessment, scoring, lesson/MDX content, profile/authentication, database/Drizzle, analytics/monitoring, CI, branch protection, VPS infrastructure, DNS, deployment, public launch, `LICENSE` or RP-TURN-005 work.
- No localization library, component library, animation library, dashboard abstraction or unused form control.
- Server Components remain the default. Motion is never required to understand state and must honor `prefers-reduced-motion`.
- Preserve strict lifecycle-script policy and the reviewed PostCSS/Sharp overrides. Review every new dependency/script individually and never use blanket approval.
- Never expose, rotate or broaden the retained GitHub credential. Do not commit Playwright authentication state or verification screenshots.

## Acceptance criteria

- `/` reaches Thai by default; `/th`, `/en`, unsupported locale and `<html lang>` behavior are deterministic and tested.
- Thai and English catalogs satisfy the same typed key contract, contain shell-only intentional copy and no raw HTML.
- The semantic shell, skip link, focus target, navigation and language switcher are keyboard accessible and use understandable labels/current state.
- Semantic provisional tokens meet WCAG 2.2 AA for rendered text/controls, wrap real Thai text and preserve order without horizontal overflow at 320 CSS pixels and the 400%-zoom reflow equivalent.
- Full and reduced-motion modes work without autoplay, parallax or meaning-dependent animation.
- Chromium Playwright tests cover routing, locales, language switching, keyboard/focus, mobile and desktop layout, reflow, reduced motion and serious/critical axe findings.
- Existing format, lint, strict typecheck, unit test, build, aggregate check and both npm audits remain green.
- No prohibited data, asset, feature, CI or deployment is introduced; `main` remains unchanged and a Draft PR targets it.

## Exact verification requirements

Report Node/npm and new dependency/browser versions; `npm ci`; pending/strict install-script checks; format, lint, typecheck, unit test, build, aggregate check and `npm run test:e2e`; production and full audits; locale/catalog coverage; keyboard, focus, 320px, desktop, reduced-motion, reflow and axe results; visual inspection; UTF-8/Markdown/diff checks; complete changed-file inventory; prohibited-path, real-environment, worktree, staged and pushed-history secret scans; unchanged `main`; push/PR metadata; and retained authentication state without token material.
