# RP-TURN-003 — Application Scaffold and Quality Gates

## Authorization and objective

Jeff approved this bounded turn for `C:\Codex PC SG2\Jeff\risepals` from base commit `f5a6fb2e2d6a989502ba316047a8a16ddab69ec2`.

Create a minimal production-buildable Next.js App Router foundation at the repository root using React, strict TypeScript, Node.js 24 LTS/npm, a `src/` layout, Tailwind CSS design tokens and Server Components by default. Establish deterministic format, lint, typecheck, unit-test and build gates without implementing a Rise Pals product feature.

## Required scope

- Work only on `agent/application-scaffold`; preserve `main` and existing history.
- Install the current supported official Node.js 24 LTS x64 distribution and use bundled npm.
- Preserve existing documents; use a controlled temporary Create Next App scaffold as reference and merge only reviewed files.
- Create `src/app`, `src/components`, `src/lib`, `src/modules`, `content` and unit-test structure; create `public` only if required.
- Provide a semantic neutral Rise Pals root page, basic metadata, responsive defaults, visible focus and reduced-motion behavior.
- Add exact runtime/dependency pins, npm lockfile, strict TypeScript, Next-compatible ESLint, Prettier, Tailwind, Vitest, Testing Library, jsdom, safe `.env.example` and typed server-only environment validation.
- Update README, local-development documentation and project status factually. RP-TURN-003 remains pending Project Codex review.
- Commit as `chore: scaffold application foundation`, push the bounded branch and open a draft pull request to `main` with the same title.

## Constraints

- No landing-page implementation, full localization, assessment, scoring, lesson/MDX content, profile, authentication, database/ORM, proof upload, payment, animation library, component kit, analytics, monitoring, CMS, Playwright, Storybook, CI, branch protection, service, reverse proxy, firewall, DNS, deployment, public launch or `LICENSE`.
- Do not overwrite unexpected work, reset, rewrite history, force-push, merge the pull request or continue into RP-TURN-004.
- Do not expose credentials. Authenticate interactively only when ready to push and remove the persistent interactive credential after remote verification.

## Acceptance criteria

- Official Node.js 24 LTS/npm are installed, verified and pinned.
- A single minimal Next.js App Router scaffold builds at the repository root; Server Components remain the default.
- Strict TypeScript, formatting, lint, typecheck, terminating unit tests, production build and aggregate check all pass.
- `npm ci` reproduces the exact lockfile; production and development audits are reported separately and advisories are not hidden.
- The page has semantic accessible content, responsive defaults and reduced-motion support.
- `.env.example` contains safe values only, all other `.env*` remain ignored and server-only validation is typed.
- Secret/prohibited-path scans pass, README is current, no out-of-scope feature exists and `main` remains unchanged.
- The branch is pushed, a draft PR targets `main`, and final GitHub authentication status is reported after credential cleanup.

## Required verification

Report exact commands and results for Node/npm versions, `npm ci`, format check, lint, typecheck, test, build, aggregate check, tracked/untracked inventory, `git diff --check`, worktree and exact staged-content secret scans, prohibited-path and real-environment scans, production/development audits, committed-state checks, branch push, draft PR metadata, remote hashes, unchanged `main` and final authentication status.
