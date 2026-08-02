# Local Development

**Turn:** RP-TURN-005  
**Status:** Public narrative and evidence contract accepted; no assessment, data collection or deployment exists  
**Checked:** 2026-08-02

## Confirmed host role and separation rule

This Windows Server 2022 VPS is the intended production application target. It currently also contains the development workspace and repository application scaffold at `C:\Codex PC SG2\Jeff\risepals`, but no production application is installed or running as a service and no deployment exists.

The current workspace is not a future live release directory. Once deployment begins:

- authoring/scaffold work happens in an authorized repository workspace or branch
- Jeff's Public repository [`noppol87/RisePals`](https://github.com/noppol87/RisePals) is the canonical source/history and this workspace is connected through `origin`
- builds happen in CI or a separate VPS build/staging area
- the reverse proxy serves only an activated versioned release
- persistent data, uploads, secrets and logs stay outside every release
- developers do not edit files inside the active served release

## Verified host facts

Commands ran from:

```text
C:\Codex PC SG2\Jeff\risepals
```

| Check | Actual result |
|---|---|
| Operating system | Microsoft Windows Server 2022 Datacenter, version 10.0.20348, build 20348, 64-bit |
| Shell | Windows PowerShell 5.1.20348.1, Desktop edition |
| Git | Git for Windows `2.55.0.windows.3`, official signed PortableGit distribution installed per-user |
| GitHub CLI | `gh 2.97.0`, official checksum-verified ZIP installed per-user |
| Node.js | `v24.18.1` LTS (Krypton), official x64 ZIP installed per-user; official SHA-256 matched and `node.exe` has a valid OpenJS Foundation signature |
| npm / npx | Bundled npm `11.16.0`; resolves from the same per-user Node.js directory |
| Playwright | `@playwright/test` and Playwright `1.62.1`; Chromium for Testing `151.0.7922.34` installed locally |
| Accessibility browser checker | `@axe-core/playwright` and `axe-core` `4.12.1` |
| Corepack | Not required or enabled by this npm-based scaffold |
| pnpm / Yarn / Bun / Deno | Not found in `PATH` |
| Python / Python launcher | Not found in `PATH` |
| Docker CLI | Not found in `PATH` |
| VS Code `code` CLI | Not found in `PATH`; this does not prove the desktop application is absent |
| WSL executable | `C:\windows\system32\wsl.exe` exists, but modern `--version`/distribution checks returned usage text and exit code 1; no usable distribution was verified |
| Windows Package Manager (`winget`) | Not found in `PATH` |
| Repository `.git` | Present at repository root with `main`, one `origin` and repository-local noreply identity |

RP-TURN-001 through R2 made no Git mutation. RP-TURN-002 separately verified the local ancestry and empty Public destination, installed source-control tooling, initialized this exact workspace, created the reviewed initial baseline and published it without force. RP-TURN-003 installed Node.js/npm and established the accepted minimal application/tooling baseline. RP-TURN-004 established the accepted localized structural shell. RP-TURN-005 established the accepted public narrative and static evidence contract only; it creates no assessment, data collection, service or deployment.

## Environment commands actually executed

The checks below are summarized for reproducibility. The combined runtime command returned exit code 1 only because `wsl --version` returned usage output; the individual command-availability results above remain valid.

```powershell
Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,OSArchitecture,BuildNumber
$PSVersionTable.PSVersion.ToString()
$PSVersionTable.PSEdition

$names = @('git','node','npm','npx','corepack','pnpm','yarn','bun','deno','python','py','docker','wsl','code')
foreach ($name in $names) {
  Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
}

Test-Path -LiteralPath '.git'
# The same Test-Path check was applied to each parent directory through C:\.

Get-Command winget -ErrorAction SilentlyContinue
wsl --version
wsl --list --quiet
```

`git status --short` was intentionally not attempted after the current-turn availability check because `git` was confirmed absent. A previous orientation attempt also produced `git is not recognized`; that earlier check is not reported as a successful RP-TURN-001 verification.

## Development prerequisites

Git and GitHub CLI were installed for the authorized RP-TURN-002 source-control work. RP-TURN-003 installed Node.js/npm from the official current Node 24 LTS distribution without requiring elevation.

### Required

1. **Node.js 24 LTS x64** from the [official Node.js download page](https://nodejs.org/en/download), with bundled npm — installed as Node.js `24.18.1` and npm `11.16.0`; `.node-version`, `package.json` engines and `packageManager` record the baseline
2. **Git for Windows** from [git-scm.com](https://git-scm.com/download/win), added to the terminal `PATH` — installed in RP-TURN-002 as a verified per-user PortableGit distribution
3. An editor that preserves UTF-8; VS Code is recommended but its CLI is optional

Why Node 24: the official Node distribution index listed v24.18.1 as the current Krypton LTS release on 2026-08-02. Avoid v26 Current until it becomes an accepted LTS baseline and project dependencies support it.

### Not required yet

- Docker/Podman or a local PostgreSQL server: defer until the database turn decides disposable integration-test infrastructure
- WSL: Next.js supports Windows directly; use WSL only if the team deliberately standardizes it
- Python: the proposed web stack does not require it
- GitHub CLI: installed for repository authentication and remote verification; Jeff has approved retaining the current development login for convenience
- A cloud CLI: no cloud application host has been selected; production target is this VPS

## Runtime prerequisite verification

Git/gh versions were verified in RP-TURN-002. Node/npm were verified again in RP-TURN-004 with:

```powershell
git --version
gh --version
node --version
npm --version
npx --version
where.exe git
where.exe gh
where.exe node
where.exe npm
```

Verified result: Node reports `v24.18.1`, npm reports `11.16.0`, npm/npx resolve from `C:\Users\Administrator\AppData\Local\Programs\node-v24.18.1-win-x64`, and Git continues to resolve from the verified per-user PortableGit distribution.

If a future supported Next.js or Playwright release changes its Node support before scaffolding, review the official requirements and record the new LTS choice rather than forcing an incompatible version.

## Established Public GitHub source baseline

Jeff selected his personal-account repository [`noppol87/RisePals`](https://github.com/noppol87/RisePals), with **Public** visibility, as canonical source/history. RP-TURN-002 verified the owner, URL, visibility and empty remote before mutation; initialized this exact workspace with `main`; configured a repository-local GitHub noreply identity; added exactly one `origin`; created one reviewed foundation commit; and pushed without force.

The direct initial push to `main` was allowed only because the remote had no branch, tag or commit. Future implementation work uses bounded branches and reviewed pull requests. Jeff has approved retaining GitHub CLI authentication as a development convenience; no token material, scope or storage detail belongs in repository documentation. Before any production-readiness turn, persistent development credentials must be separately reviewed and narrowed or revoked. The public read-only `origin` remains. Branch protection, CI and deployment transport remain open and require separate authorization.

The root `.gitignore` covers application output, secrets/key material, local databases/dumps, uploads/proof artifacts and authentication state. Public-repository inventory, operational-document review and secret scanning remain mandatory before every push.

Required gates before the first push:

1. inventory every tracked/staged file and confirm it is suitable for a Public repository
2. run a secret scan over the worktree, staged content and every commit that would be pushed
3. use synthetic fixtures only; reject assessment answers, personal data, proof artifacts and production-derived values
4. confirm `.gitignore` coverage and verify ignored paths are not staged
5. review documentation for credentials, private endpoints, access instructions, host secrets and other operationally sensitive data
6. verify the destination is exactly `https://github.com/noppol87/RisePals` and visibility is **Public**
7. review the complete commit history before any push

Never commit `.env` files other than a reviewed safe `.env.example`; credentials, tokens or private keys; production configuration containing secrets; database dumps; uploads or proof artifacts; assessment answers or personal data; private logs or production telemetry; certificate private keys; generated production data; Playwright authentication state; or backups. Do not add a `LICENSE` until Jeff separately decides the software license.

Future implementation source flow:

```text
authorized bounded branch → commit → public GitHub noppol87/RisePals → pull request/review
→ automated checks → versioned release artifact → VPS staging
→ health-checked activation → rollback to last known-good release if needed
```

GitHub stores source/history, not `.env`, credentials, database dumps, uploads, generated production data, runtime logs, telemetry or backups.

## Established repository shape

RP-TURN-003 keeps one application at the repository root:

```text
content/                 trusted, versioned lesson and evidence-claim source
docs/                    product, architecture and engineering documents
prompts/                 approved turn briefs and handoff templates
src/
  app/                   Next.js routes, layouts and route handlers
  modules/               domain/application modules with public entry points
  components/            shared accessible UI primitives
  lib/                   narrow cross-cutting infrastructure/configuration
tests/                    Vitest unit/render tests and Chromium-only Playwright E2E tests
```

No `public/` directory is required by the current page. Database integration suites, a monorepo, a separate API and shared-package workspaces remain deferred until a real boundary requires them.

## Proposed production-host layout

The paths below are conceptual defaults for a later VPS infrastructure-readiness turn. They do not exist and were not created in RP-TURN-001-R1; the final root and ACLs require Jeff approval.

```text
C:\RisePals\workspace\                 repository checkout used for authorized source/deploy work; never served
C:\RisePals\staging\release-id\       unpacked/built candidate before activation
C:\RisePals\releases\release-id\      versioned, immutable/read-only application release
C:\RisePals\current\                  active-release pointer or switching boundary
C:\RisePals\data\uploads\             persistent private user artifacts; not inside a release
C:\RisePals\config\                   production secrets/config; ACL-restricted and outside Git
C:\RisePals\logs\                     rotated proxy/application/deployment logs
C:\RisePals\runtime\                  bounded cache/temp/PID/service-wrapper state when required
```

`release-id` means a concrete source commit plus artifact digest recorded at build time; it is not a literal directory name to create.

Boundary rules:

- The current `C:\Codex PC SG2\Jeff\risepals` folder remains a pre-deployment workspace. Do not make it the only copy or expose it through the reverse proxy.
- Build/test in CI or `staging`, never in `current` or an active release. Promote only a verified artifact.
- Release directories contain application code/build output and public static assets only. Treat them as replaceable and read-only to the application service.
- Persistent uploads/data, secret material and logs survive release changes and use separate least-privilege ACLs/backups.
- `current` may become a validated NTFS junction/symlink, proxy upstream/port switch or another Windows-safe mechanism. Selection waits for a rehearsal of file locks, permissions, atomicity and rollback.
- Keep the last known-good release. Rollback switches to that existing artifact, performs readiness/external HTTPS checks and records the incident; it does not edit the failed release.
- Database backups, upload backups and VPS/system recovery copies must be encrypted and off-host according to an approved policy. GitHub and another directory on the same VPS are not sufficient backups.

## Proposed production-host prerequisites

These requirements belong to a later bounded VPS infrastructure-readiness turn and were not executed:

1. inventory VPS CPU/RAM/disk/network, installed roles, public exposure and backup capability
2. install/pin Node LTS and any approved reverse proxy/service wrapper only after authorization
3. configure HTTPS termination and prove certificate issue, renewal and reload
4. supervise proxy and Node as Windows services with restart/graceful-stop tests
5. create least-privilege non-interactive service/deployment identities and exact path ACLs
6. expose only proxy TCP 80/443; restrict administration; keep Node/database ports private
7. place runtime secrets outside Git/releases and prove rotation/revocation
8. configure structured redacted logs, rotation, disk-pressure alerting and retention
9. implement liveness/readiness and external HTTPS monitoring without data leakage
10. rehearse versioned deployment, failed-health rollback and service/host restart
11. assign database/upload/config/system backup ownership and complete a non-production restore drill
12. document Windows/Node/proxy patching and incident-response ownership

Docker, WSL and Linux are not assumed. Caddy/Windows services and IIS/ARR are candidates documented in `docs/07_TECHNICAL_ARCHITECTURE.md`; neither is installed or selected.

## Verified scaffold behavior

RP-TURN-003 used Create Next App `16.2.12` only in a temporary directory to review the current official template, then added reviewed files explicitly to the non-empty repository. The scaffold provides:

- TypeScript strict mode with `skipLibCheck: false`, unchecked-index access checks and exact optional-property types
- `src/` directory and `@/*` import alias
- ESLint and an explicit formatter check
- Tailwind CSS `4.3.3` plus CSS custom-property design tokens
- an exact npm lockfile and Node/npm pins
- Vitest `4.1.10`, Testing Library and jsdom semantic render/configuration tests
- typed server-only `APP_BASE_URL` validation with no required secret and no `NEXT_PUBLIC_` value
- a neutral semantic page, responsive defaults, visible focus and reduced-motion baseline

Selected runtime versions are Next.js `16.2.12`, React/React DOM `19.2.4` and `server-only` `0.0.1`. The initial official template graph exposed high-severity advisories through Next's pinned PostCSS and optional Sharp dependencies. The reviewed root graph overrides only those transitive versions to PostCSS `8.5.25` and Sharp `0.35.3`; clean install, unit tests, production build and both audits verify the result.

Exact override rationale:

- Next.js `16.2.12` declares PostCSS `8.4.31`. The override to `8.5.25` addresses GHSA-qx2v-qp2m-jg93, GHSA-6g55-p6wh-862q and GHSA-r28c-9q8g-f849.
- Next.js `16.2.12` declares optional Sharp `^0.34.5`. The override to Sharp `0.35.3` addresses GHSA-f88m-g3jw-g9cj, but `0.35.3` is outside that declared range. It is a reviewed temporary security exception, not an accepted dependency-architecture change.
- Re-evaluate both overrides on every Next.js upgrade. Re-evaluate Sharp again before introducing Next image optimization or any production imagery; RP-TURN-003 and R1 add neither an image feature nor an image dependency.

Install-script policy is deny-by-default for reviewed dependencies:

- `unrs-resolver@1.12.2` is a development-only transitive dependency reached through `eslint-config-next → eslint-import-resolver-typescript`. Its postinstall calls `napi-postinstall` to prepare its native package, but the verified lint, test and production-build paths succeed without that script. `package.json` therefore records `allowScripts.unrs-resolver = false`.
- `fsevents@2.3.3` is Vite's development-only optional dependency, declares only `os: darwin` and uses `node-gyp rebuild` as its install script. It is neither installed nor required on the Windows development/production target, so `allowScripts.fsevents = false`. npm's supported deny command cannot select this platform-excluded package from Windows `node_modules`; the project policy records the equivalent explicit denial directly.

`.npmrc` sets `strict-allow-scripts=true` so any future install script without an individual allow/deny decision fails installation rather than producing only a warning. Do not replace this with `ignore-scripts=true`, a blanket approval or `dangerously-allow-all-scripts`.

## Verified localized shell behavior

RP-TURN-004 keeps Server Components as the default and adds no localization, component or animation library. It provides:

- `/` redirecting with Next.js `redirect()` to the Thai default `/th`
- statically generated `/th` and `/en` routes, deterministic not-found behavior for unsupported locale segments and locale-correct `<html lang>`
- matching typed Thai/English shell catalogs, BCP 47-compatible locale identifiers and a server-only catalog-resolution boundary prepared for native `Intl`
- a semantic skip link, header, text home/wordmark, primary navigation, real-link language switcher and stable focusable main target
- the currently required `PageContainer`, `Stack` and `TextLink` primitives only
- explicitly provisional semantic CSS roles for color, typography, spacing, containers, borders, radii, elevation, focus and reduced motion, using only system/local font fallbacks

Browser verification adds exact development dependencies `@playwright/test@1.62.1` and `@axe-core/playwright@4.12.1`; the latter resolves `axe-core@4.12.1`. `npm run test:e2e:install` installs only Playwright Chromium, which resolved to Chromium for Testing `151.0.7922.34` (`chromium v1234`) plus Playwright's required headless shell, FFmpeg and Winldd support files. These browser binaries are local tool state and are not committed.

The clean dependency installation returned no install-script warning or pending package. Existing `allowScripts.fsevents = false`, `allowScripts.unrs-resolver = false`, `strict-allow-scripts=true` and the reviewed PostCSS/Sharp overrides remain unchanged.

`npm run typecheck` runs the supported `next typegen` command before strict `tsc`. A development server writes ignored development route declarations under `.next/dev` and generates `next-env.d.ts` with a development-route import. `next typegen` deterministically regenerates production route declarations under `.next/types` and rewrites that generated import to the production route file before the compiler starts. The repository never edits `next-env.d.ts` manually and does not delete `.next` as a workaround.

`tsconfig.typecheck.json` inherits every strict compiler option, includes the generated production route declarations and excludes `.next/dev` from the standalone compiler program. `next.config.ts` uses the standard `tsconfig.json` for the development server and the isolated configuration for production/type generation. Together, the supported generation step and isolated compiler input preserve production route-type validation without mixing duplicate development declarations.

## Verified public narrative and evidence behavior

RP-TURN-005 keeps the accepted shell and Server Components as the default while replacing only the structural page content. It adds no dependency, runtime fetch, Client Component, raster/vector asset, remote font or third-party script. `/th` and `/en` remain statically generated and provide the same intentional information architecture:

- an optimistic-realism hero that does not predict job loss or guarantee employment
- an honest `#why-now` internal CTA that states assessment/onboarding are unavailable and collects no data
- exactly two evidence records, each with a localized claim, interpretation, constructive action, geography, method/context and visible limitation
- direct original-source links, publication dates, last-verified dates and review dates
- the complete Diagnose → Prioritize → Learn → Practice → Prove → Opportunity loop, with practice, feedback and proof distinguished from passive completion
- the documented eight core competencies and two behavioural multipliers kept in separate labeled groups, without questions, scoring, weights, personal risk or recommendations

The evidence model and validation live separately from presentation components. Build/publication validation rejects missing fields, incomplete/unsupported locales, blank localized values, malformed or non-HTTPS URLs, invalid ISO dates, review dates not later than verification, evidence past review, raw HTML and duplicate stable IDs. Unit tests exercise every required rejection path.

Both records were checked directly against their original sources on `2026-08-02`:

- ILO–NASK, *Generative AI and Jobs: A Refined Global Index of Occupational Exposure*, published `2025-05-20`: the rendered claim is global occupational/task exposure and explicitly is not a Thailand-specific estimate or an individual job-loss prediction.
- World Economic Forum, *The Future of Jobs Report 2025 — Skills Outlook*, published `2025-01-07`: the rendered `39%` is a surveyed-employer expectation. Visible context records 1,043 global-company responses, more than 14.1 million represented employees, 22 industry clusters, 55 economies and the large-employer emphasis; it is not certainty or an individual forecast and excludes small enterprises and the informal sector.

Both records use review date `2027-02-02`, six months after verification. The six-month review window reflects that labour-market and employer-expectation evidence is time-sensitive even when the original report is stable. Review must happen earlier if a source is corrected, replaced or superseded.

Production build evidence shows `/th` and `/en` as SSG. `src` contains no `use client` directive; the locale client-reference manifest and `.next/static/chunks` contain no narrative/evidence module. The narrative therefore adds no client hydration boundary or narrative client bundle. Browser tests also observe no unexpected third-party request during either locale's initial load.

## Verified day-to-day commands

The scaffold defines and verifies:

```powershell
npm ci
npm run dev
npm run format:check
npm run lint
npm run typecheck
npm run test
npm run test:watch
npm run build
npm run check
npm run test:e2e:install
npm run test:e2e
```

Use `npm ci` for clean/CI installs and commit `package-lock.json`. Developers may use `npm install` only when deliberately changing dependencies and must review the lockfile diff.

Final RP-TURN-003-R1 verification on 2026-08-02:

| Command | Exact result |
|---|---|
| `node --version` | PASS — `v24.18.1` |
| `npm --version` | PASS — `11.16.0` |
| `npm ci` | PASS — 458 packages installed, 459 audited, 0 vulnerabilities; completed without install-script warnings |
| `npm approve-scripts --allow-scripts-pending --json` | PASS — no packages with unreviewed install scripts |
| `npm config get strict-allow-scripts` | PASS — `true` |
| `npm run format:check` | PASS — all matched files use Prettier style |
| `npm run lint` | PASS — exit 0 with zero warnings (`--max-warnings=0`) |
| `npm run typecheck` | PASS — strict `tsc --noEmit`, exit 0 |
| `npm run test` | PASS — 2 files and 12 tests passed |
| `npm run build` | PASS — optimized Next.js 16.2.12 build; `/` and `/_not-found` statically generated |
| `npm run check` | PASS — aggregate format, lint, typecheck, test and build gates |
| `npm audit --omit=dev` | PASS — 0 production vulnerabilities |
| `npm audit` | PASS — 0 vulnerabilities across production and development graph |

Final RP-TURN-004 verification on 2026-08-02:

| Command or review | Exact result |
|---|---|
| `node --version` / `npm --version` | PASS — `v24.18.1` / `11.16.0` |
| `npm ci` | PASS — 462 packages installed, 463 audited, 0 vulnerabilities; no install-script warning |
| pending scripts / strict policy | PASS — no packages with unreviewed install scripts; `strict-allow-scripts=true` |
| `npm run format:check` | PASS — all matched files use Prettier style |
| `npm run lint` / `npm run typecheck` | PASS — zero ESLint warnings; `next typegen` succeeded and strict `tsc --noEmit` exited 0 |
| `npm run test` | PASS — 3 files and 17 tests passed, including matching complete catalogs and shell semantics |
| `npm run build` | PASS — `/`, `/_not-found`, `/th` and `/en` generated by Next.js `16.2.12` |
| `npm run check` | PASS — aggregate format, lint, typecheck, unit test and production-build gates |
| `npm run test:e2e` | PASS — 9 Chromium tests covering default/locale/not-found routing, document language, switching, skip-link focus, 320px/reflow, desktop, reduced motion and Thai/English axe scans |
| `npm audit --omit=dev` / `npm audit` | PASS — 0 production and 0 full-graph vulnerabilities |
| visual review | PASS — Thai at 320px and desktop plus English at 320px and desktop preserve reading order and Thai wrapping; 320px in-app browser review confirmed equal document client/scroll widths after scrollbar-aware correction |

RP-TURN-004-R1 repeated the development/typecheck transition from the same workspace in the required order:

| Ordered command | Exact result |
|---|---|
| `npm ci` | PASS — 462 packages installed, 463 audited, 0 vulnerabilities; no install-script warning |
| pending scripts / strict policy | PASS — no packages with unreviewed install scripts; `strict-allow-scripts=true` |
| first `npm run test:e2e` | PASS — 9 Chromium tests; `next dev` generated development route declarations |
| first `npm run typecheck` | PASS — `next typegen` regenerated production route types, then strict `tsc` exited 0 |
| `npm run check` | PASS — format, lint, generated-route strict typecheck, 3 files/17 unit tests and production build |
| second `npm run test:e2e` | PASS — 9 Chromium tests from a fresh `next dev` process |
| second `npm run typecheck` | PASS — production route types regenerated again and strict `tsc` exited 0 |
| `npm audit --omit=dev --audit-level=low` | PASS — 0 production vulnerabilities |
| `npm audit --audit-level=low` | PASS — 0 vulnerabilities across the full graph |

Final RP-TURN-005 verification on 2026-08-02:

| Command or review | Exact result |
|---|---|
| `node --version` / `npm --version` | PASS — `v24.18.1` / `11.16.0` |
| `npm ci` | PASS — 462 packages installed, 463 audited, 0 vulnerabilities; no install-script warning |
| pending scripts / strict policy | PASS — `npm approve-scripts --allow-scripts-pending --json` returned no packages with unreviewed scripts; `npm config get strict-allow-scripts` returned `true` |
| `npm run format:check` | PASS — all matched files use Prettier style |
| `npm run lint` | PASS — exit 0 with zero warnings (`--max-warnings=0`); the first invocation reached the 124-second command timeout without a result, and the exact command then passed with a longer timeout |
| `npm run typecheck` | PASS — `next typegen` succeeded and strict `tsc --noEmit` exited 0 |
| `npm run test` | PASS — 5 files and 32 tests, including every evidence-validation rejection path and public-narrative semantics |
| `npm run build` | PASS — optimized Next.js `16.2.12` build; `/th` and `/en` remained statically generated |
| `npm run check` | PASS — aggregate format, lint, generated-route strict typecheck, 5 files/32 unit tests and production build |
| `npm run test:e2e` | PASS — 14 Chromium tests covering both locales, sources and qualifiers, CTA/no-form contract, loop/framework, routing, keyboard/focus, 320px and desktop layouts, reduced motion, no unexpected third-party initial requests and Thai/English axe scans |
| `npm audit --omit=dev --audit-level=low` / `npm audit --audit-level=low` | PASS — 0 production and 0 full-graph vulnerabilities |
| evidence review | PASS — exactly the approved ILO–NASK and World Economic Forum primary-source records, required source metadata, visible context/limitations and `2027-02-02` review dates |
| client/network review | PASS — no `use client` directive, narrative/evidence module in the client-reference manifest or narrative/evidence module in static client chunks; no unexpected third-party initial request in either locale |
| visual and accessibility review | PASS — Thai and English at 320px and desktop preserve reading order and wrapping with no horizontal overflow; visible 44px source links and focus treatment; automated reduced-motion and axe checks passed |

## Environment-variable policy

### Files

- `.env.example`: committed names, descriptions and safe dummy values only
- `.env.local`: local secrets/configuration; ignored by Git
- `.env.test.local`: optional test-only secrets/configuration; ignored by Git
- Proposed VPS production config/secret location outside workspace, staging and releases: ACL-restricted to the application service and administrators; exact store/path remains open
- CI/deployment secret store: deployment-only values; separate from runtime application secrets
- No other `.env*` file is committed unless the policy is changed deliberately

The `.gitignore` rule ignores `.env*` and re-allows `.env.example`.

### Exposure rules

- Variables without `NEXT_PUBLIC_` are server-only.
- `NEXT_PUBLIC_` values are compiled into the browser bundle and are never secrets. Each public variable needs an explicit review reason.
- Do not store raw JSON credentials in a public variable, test snapshot, client error or CI log.
- Validate and type all required server variables once at startup. Fail with the variable name and remediation, never its value.
- Keep provider names behind configuration/adapters so domain code does not read vendor variables directly.

### Planned names

Names are a provider-agnostic contract; provider-specific additions wait for a vendor decision:

| Variable | Exposure | Purpose |
|---|---|---|
| `APP_BASE_URL` | Server | Canonical origin for secure redirects/links |
| `DATABASE_URL` | Server secret | PostgreSQL application connection |
| `DATABASE_MIGRATION_URL` | Server/CI secret | Optional higher-privilege migration connection |
| `AUTH_SECRET` | Server secret | Session/auth integration secret when required |
| `OBJECT_STORAGE_BUCKET` | Server | Private proof bucket identifier |
| `OBJECT_STORAGE_ENDPOINT` | Server | Provider adapter endpoint when required |
| `OBJECT_STORAGE_ACCESS_KEY` | Server secret | Object-store service credential |
| `OBJECT_STORAGE_SECRET_KEY` | Server secret | Object-store service credential |

Do not create analytics, monitoring, email or payment variable names until those vendors and purposes are approved. `NODE_ENV` is framework-controlled and must not be repurposed.

## Development and production database strategy

The application does not need PostgreSQL before the approved database turn. For development/integration tests, choose one of:

1. disposable local/container PostgreSQL for reproducible integration tests
2. provider development branch plus a separate disposable test database
3. both, if runtime-specific integration behavior justifies it

Production placement remains open. Managed PostgreSQL is preferred for operational isolation, while a database on the same VPS would require explicit capacity, patching, private binding, least-privilege roles, monitoring and encrypted off-host backup evidence. The decision must verify supported PostgreSQL major version, separate application/migration privileges, RLS behavior, pooling mode, TLS, backup/deletion and data-region needs. Never use production data in local/preview environments; seed only synthetic Thai/English fixtures.

## UTF-8 and Thai-content notes

Repository Markdown is intended to remain UTF-8. Windows PowerShell 5.1 may display UTF-8 output incorrectly through some automation pipelines even when file bytes are valid; `rg` in the same environment rendered the Thai content correctly. Do not “fix” a file based only on mojibake in one console.

RP-TURN-002 adds `.gitattributes` to keep Markdown at LF and to recognize intentional CommonMark hard-break spaces. A future `.editorconfig` may standardize editor behavior more broadly; continue verifying Thai content in browser, tests and diff.

## Troubleshooting order

1. Run `Get-Command git,node,npm` and the version checks after the relevant separately authorized installations; reopen the terminal afterward.
2. Confirm Node 24 and the reviewed lockfile before installing application dependencies.
3. Use `npm ci` to distinguish environment drift from lockfile problems.
4. Run typecheck/unit tests before browser/database suites.
5. For Thai display issues, inspect editor encoding and browser output before changing source bytes.
6. For database failures, confirm the target is a disposable development/test database before running any migration command.
7. Never paste secret values into a handoff, screenshot, issue or command output.

## Current boundary after RP-TURN-005

- RP-TURN-005 has passed Project Codex review and is accepted.
- The repository now contains a static public narrative and evidence contract, but no onboarding, assessment flow, personalized advice, scoring, lesson experience, learner profile, account system or data collection exists.
- No cloud or paid provider, database, production service or deployment was created.
- CI and branch protection remain separately authorized work even though the repository supplies reproducible local browser checks.
- Exact visual identity, final color/typography, localization operations, the Pal character system, credentials and production readiness remain open.
- RP-TURN-006 — Assessment Domain Fixtures and Scoring Contract is the next recommended turn, but it has not been started or authorized.
