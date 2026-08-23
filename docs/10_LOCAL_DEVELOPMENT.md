# Local Development

**Turn:** RP-TURN-012  
**Status:** RP-TURN-012 Accepted by Project Codex for synthetic alpha; no real users, production database/service or deployment exists  
**Checked:** 2026-08-16

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

RP-TURN-001 through R2 made no Git mutation. RP-TURN-002 separately verified the local ancestry and empty Public destination, installed source-control tooling, initialized this exact workspace, created the reviewed initial baseline and published it without force. RP-TURN-003 installed Node.js/npm and established the accepted minimal application/tooling baseline. RP-TURN-004 established the accepted localized structural shell. RP-TURN-005 established the accepted public narrative and static evidence contract. RP-TURN-006 established the accepted versioned synthetic assessment-domain contract. RP-TURN-007 adds the bounded player prototype and temporary browser-session state described below. RP-TURN-008 adds only the fixed server-rendered synthetic example described below; neither turn creates a validated or personalized result, server response collection, durable persistence, service or deployment.

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

### Optional or task-specific

- Docker/Podman: not required; the RP-TURN-010 integration harness uses a supported portable PostgreSQL distribution and creates no service
- PostgreSQL server binaries: required only for `npm run db:test:disposable`; prepare the pinned/hash-verified 18.4 archive outside the repository with `npm run db:prepare:disposable`
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
- an honest locale-matched CTA to the six-scenario player prototype, stating that no validated assessment or result exists and that the landing page collects no data
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

## Verified assessment-domain fixture behavior

RP-TURN-006 adds no dependency, route, Client Component, browser API or runtime integration. `src/modules/assessment/` contains a pure TypeScript contract with:

- framework version `framework-rise-pals-8-plus-2-v2`, including the exact canonical eight core weights totaling 10,000 basis points and two structurally separate unweighted multipliers
- assessment version `assessment-workplace-scenarios-fixture-v1`, containing exactly six required bilingual scenario-choice items and no free text or personal field
- scoring version `scoring-integer-rubric-fixture-v1`, using the reviewed integer `0..2` option scale
- two synthetic raw-response fixtures, stored separately from expected scoring and explanation fixtures
- score outputs marked provisional/fixture-only, with core signals, separate multiplier observations, earned/available points, evidence counts, supporting item keys and all six unassessed core identities
- separate explanation-code records and Thai/English explanation/limitation copy

For each assessed target, the scorer sums selected option rubric points independently and sums the matching item maxima as available points. It does not apply core weights to a partial aggregate. Ownership and urgency rubric contributions never multiply or alter core signals, and one scenario is explicitly insufficient to establish a behavioral pattern.

Validation runs before scoring and rejects incompatible assessment/framework/scoring versions, missing required responses, duplicate item responses, unknown items/options, changed canonical weights, multiplier weights, invalid point scales, mismatched rubric maxima and non-integer/out-of-range contributions. The function does not sort or mutate caller responses; canonical output order makes the result independent of response order.

RP-TURN-006-R1 also validates runtime discriminator values before target lookup: every core definition must declare `kind: "core"`, every multiplier definition must declare `kind: "multiplier"` and every item rubric target kind must be exactly `core` or `multiplier`. An unknown kind can no longer be treated as a multiplier or be silently omitted by the scorer. Regression tests preserve the existing unknown/wrong-target and 2/2/1/1 distribution checks.

The contract emits no overall score, validated confidence, Aware–Leading stage, priority gap, lesson recommendation or employment/hiring field. Bilingual limitations state that the local slice is not a validated assessment and cannot predict job loss, job performance, employability or hiring eligibility.

R1 replaces internal English implementation terms in Thai scenario, explanation and limitation copy with natural Thai equivalents for the system contract, scoring criteria, competency, behavioral pattern, risk guardrails and workflow. Targeted tests scan Thai values only and allow established proper names such as AI, Ownership Thinking and Sense of Urgency.

## Verified assessment player prototype behavior

RP-TURN-007 adds statically generated `/th/assessment` and `/en/assessment` routes. The page and app shell remain Server Components; only `AssessmentPlayer` and the narrowly route-aware `ShellNavigation` are client boundaries. Route awareness preserves the equivalent assessment route during locale switching without converting the public narrative or full shell into a Client Component.

The server presentation adapter validates the accepted six-item domain and emits only assessment identity/version, localized prompt, item key/order and option ID/label. The client receives no rubric points, target mappings, framework weights, scoring-model configuration, explanation internals or raw/expected fixtures.

Player transitions and loaded-state validation are pure TypeScript. The interactive island presents one exact accepted scenario at a time with native `fieldset`/`legend`/required radios, separate current-position and answered-count text, Back/Continue controls, preserved selections, inline announced errors and deliberate non-trapping focus after transitions. Completion confirms six answers but calculates and displays no score, proficiency, confidence, multiplier pattern, priority gap, result or recommendation.

Same-tab refresh recovery uses `sessionStorage` key `rise-pals:assessment-player:v1` with schema version `1`. The exact allowlist is `schemaVersion`, `assessmentVersionId`, `phase`, `currentItemKey` and `selections[]` containing only `itemKey`/`optionId`. Selected IDs are P3 sensitive assessment data. No copy, rubric, score, timestamp, profile or free text is stored; no response enters a URL, cookie, log, analytics event or network request. Invalid/incompatible state is cleared, blocked storage degrades safely and the user-controlled clear/restart action removes state.

The route visibly labels the experience synthetic, unvalidated and uncalibrated, states that it cannot predict job loss, performance, employability or hiring eligibility, explains local temporary storage before start, and uses `noindex, noarchive` metadata. Starting is not represented as legal consent.

## Verified synthetic example-result prototype behavior

RP-TURN-008 adds statically generated `/th/assessment/example-result` and `/en/assessment/example-result` routes. The result page and presentation component are Server Components. Existing `ShellNavigation` remains the only client reference on the example route and preserves the equivalent result path when switching locale.

The visible example is fixed to reviewed fixture `synthetic-mixed-review`; changing or completing the RP-TURN-007 player has no effect on it. The route never imports the player storage adapter, reads `rise-pals:assessment-player:v1`, or receives answer data through a prop, URL, cookie, log, analytics event or request. The completion screen links to the example with explicit Thai/English copy that the user's choices are not used.

Pure versioned derivation emits contract `synthetic-example-result-contract-v1`. Before scoring, it validates the canonical reviewed-fixture registry and requires an exact approved fixture ID, exact assessment/framework/scoring compatibility metadata and the exact ordered item/option response pairs. Unknown fixture IDs, changed metadata or responses, duplicate fixture IDs and ambiguous identical canonical content under different IDs are rejected before reviewed-fixture provenance can be emitted. The accepted domain and exact canonical fixture then produce exactly two provisional raw core signals: Critical Thinking & Fact-Checking `1/4` from two item keys and Systematic Thinking `3/4` from two item keys. Six other core competencies are listed as unassessed. Ownership Thinking and Sense of Urgency remain separate observations with one supporting scenario each; the example result intentionally omits their rubric points and never aggregates or multiplies them into core signals.

The code-native visualization uses four discrete segments for each raw signal and provides the exact `earned / available` relationship as visible text. It does not create percentage proficiency, an Aware–Leading stage, a confidence percentage, an overall or weighted score, readiness/risk/personality semantics or an employment/hiring inference.

One fixed example next practice targets Critical Thinking & Fact-Checking. Its independently defined trace identifies `scoring-integer-rubric-fixture-v1@1.0.0`, item keys `verify-ai-summary-source` and `test-process-assumption`, and exact prototype lesson version `lesson-source-verification-practice-v1@1.0.0`. Both locales preserve the fixed-synthetic and non-personalized boundary while linking to the same-locale lesson route.

## Verified repository-local lesson/practice and publication behavior

RP-TURN-009 adds statically generated `/th/lessons/source-verification-practice` and `/en/lessons/source-verification-practice` routes. RP-TURN-014 migrates the exact accepted lesson to `content/lessons/source-verification-practice/1.0.0/`, fixes immutable published identity `source-verification-practice@1.0.0` and generates tracked SHA-256-pinned manifest/registry JSON. Operational status is `published` only for synthetic alpha; separate validation status remains `prototype-unvalidated`. Critical Thinking & Fact-Checking, working stage `Practicing`, R.O.I. pillar `Intelligent Risk & Governance` and stable practice/rubric/proof identities remain unchanged. Thai and English require exact structural parity and no silent fallback.

The entirely synthetic Bright River Operations scenario presents an over-broad AI-generated summary and a source pack with intentionally incomplete evidence. Only the concepts needed to act safely are included. The active practice uses native radio groups and the three visible binary criteria `evidence-traceability`, `claim-source-fit` and `safe-next-action`. Pure evaluation requires all three criteria for the in-memory demonstrated state: passive viewing, incomplete work and below-threshold work produce 0 preview XP; all three met produce exactly 20 preview XP. Retrying or re-evaluating replaces the outcome and never accumulates XP. No XP is saved.

The lesson Client Component receives only the validated locale DTO needed to render the synthetic content and transparent practice. Selections and feedback remain in React memory and refresh starts a new attempt. The lesson never reads assessment-player storage and does not use `sessionStorage`, `localStorage`, cookies, answer-bearing URLs, APIs, server actions, analytics, logs or network transmission for practice data. The source-verification-note proof area lists only future expected fields; it has no text input, upload, file generation or storage. The reflection prompt is also non-collecting.

`npm run content:publish` validates every source before atomically writing deterministic outputs. `npm run content:validate` is read-only and compares current source, manifest, registry and digests. `npm run build` and therefore `npm run check` call that validator first, so stale or invalid publication artifacts fail without rewriting the worktree. Build-only `unified@11.0.5`, `remark-parse@11.0.0` and `remark-mdx@3.1.1` parse AST nodes only. No compiled MDX, `eval`, `new Function`, VM execution, dynamic remote import or `dangerouslySetInnerHTML` exists.

## Verified day-to-day commands

The scaffold defines and verifies:

```powershell
npm ci
npm run dev
npm run content:validate
npm run content:publish
npm run format:check
npm run lint
npm run typecheck
npm run test
npm run test:watch
npm run build
npm run check
npm run test:e2e:install
npm run db:prepare:disposable
npm run test:e2e
npm run db:test:disposable
```

Use `npm ci` for clean/CI installs and commit `package-lock.json`. Developers may use `npm install` only when deliberately changing dependencies and must review the lockfile diff.

`npm run test:e2e` serves the existing production build with `next start`; run `npm run build` first. This isolates the browser suite from development output and makes the clean build-to-E2E transition deterministic without deleting `.next` or retrying the suite.

Vitest uses the supported `vmThreads` pool with `fileParallelism: false` and a `1GB` worker memory limit. Vitest reuses one worker thread while isolating each file in a separate VM context, avoiding unreliable repeated Windows worker startup without disabling isolation or dropping any test file/assertion. The bounded suite has 20 files; review the explicit memory limit if that count or module graph grows materially.

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

Final RP-TURN-006-R1 verification on 2026-08-02:

| Command or review | Exact result |
|---|---|
| `node --version` / `npm --version` | PASS — `v24.18.1` / `11.16.0` |
| `npm ci` | PASS — 462 packages installed, 463 audited, 0 vulnerabilities; no install-script warning |
| pending scripts / strict policy | PASS — no packages with unreviewed install scripts; `strict-allow-scripts=true` |
| `npm run format:check` | PASS — all matched files use Prettier style |
| `npm run lint` | PASS — exit 0 with zero warnings (`--max-warnings=0`) |
| `npm run typecheck` | PASS — `next typegen` succeeded and strict `tsc --noEmit` exited 0 |
| `npm run test` | PASS — 9 files and 66 tests, including 4 assessment-domain files covering framework, fixtures, scoring, explanations, runtime kind discriminators, Thai terminology and every required rejection case |
| `npm run build` | PASS — optimized Next.js `16.2.12` build; `/th` and `/en` remained statically generated and the assessment module added no route |
| `npm run check` | PASS — aggregate format, lint, generated-route strict typecheck, 9 files/66 unit tests and production build |
| `npm run test:e2e` | PASS — all 14 accepted Chromium public-shell tests passed; no visible application behavior changed |
| `npm audit --omit=dev` / `npm audit` | PASS — 0 production and 0 full-graph vulnerabilities |
| fixture inventory | PASS — 6 bilingual items/18 options in the exact 2/2/1/1 target distribution; 2 synthetic raw-response fixtures; expected score and explanation fixtures stored separately |
| scoring invariants | PASS — exact eight-core weights total 10,000 basis points; order-independent/non-mutating integer sums; separate +2 observations; six unassessed cores; no overall/confidence/stage/recommendation/hiring output |
| rejected inputs | PASS — incompatible assessment/framework/scoring versions, missing/duplicate responses, unknown items/options, unknown or wrong item target kind, wrong core/multiplier definition kind, changed core weights, multiplier weights, invalid rubric maxima, impossible option points and invalid scoring scale |
| explanation/limitation review | PASS — exact supporting-item traces and codes; complete Thai/English copy; Thai internal-implementation-term guard; explicit not-validated, job-loss, job-performance, employability, hiring and single-scenario limitations |

Final RP-TURN-007 verification on 2026-08-02:

| Command or review | Exact result |
|---|---|
| `node --version` / `npm --version` | PASS — `v24.18.1` / `11.16.0` |
| `npm ci` | PASS — 462 packages installed, 463 audited, 0 vulnerabilities; no install-script warning |
| pending scripts / strict policy | PASS — `npm approve-scripts --allow-scripts-pending --json` reported no packages with unreviewed install scripts; `npm config get strict-allow-scripts` returned `true` |
| `npm run format:check` | PASS — all matched files use Prettier style |
| `npm run lint` | PASS — exit 0 with zero warnings (`--max-warnings=0`) |
| `npm run typecheck` | PASS — `next typegen` succeeded and strict `tsc --noEmit` exited 0 |
| `npm run test` | PASS — 13 files and 97 tests, including pure player state/storage/view, Thai/English component behavior and existing evidence/scoring contracts |
| `npm run build` | PASS — optimized Next.js `16.2.12` build; `/th`, `/en`, `/th/assessment` and `/en/assessment` are statically generated |
| `npm run check` | PASS — aggregate format, lint, generated-route strict typecheck, 13 files/97 tests and production build |
| `npm run test:e2e` | PASS — 26 Chromium tests covering locale-matched CTA, keyboard flow, missing-answer focus, Back/refresh/clear/locale resume, no-result completion, motion modes, 320px/desktop layout, axe and no answer in URL/request |
| `npm audit --omit=dev` / `npm audit` | PASS — 0 production and 0 full-graph vulnerabilities |
| strict UTF-8 / Markdown fences / markers / `git diff --check` | PASS — 29 changed files decode as strict UTF-8; all 25 Markdown files have balanced fences; no unresolved markers or whitespace errors |
| dependency/config review | PASS — `package.json`, `package-lock.json` and `.npmrc` are unchanged; no dependency was added |
| client-reference manifest | PASS — landing has only project client reference `shell-navigation.tsx`; assessment has only `shell-navigation.tsx` and `assessment-player.tsx` |
| static client chunks | PASS — no scoring model ID, `rubricPoints`, raw fixture IDs/exports or expected fixture output markers |
| browser privacy/network review | PASS — selected IDs remain in versioned same-tab `sessionStorage`; no unexpected third-party origin, request body or option ID in URL/request was observed |
| Gitleaks `8.30.1` nonignored worktree scan | PASS — 95 files / approximately 504.65 KB scanned, no leaks found |

Final RP-TURN-008 verification on 2026-08-02:

| Command or review | Exact result |
|---|---|
| `node --version` / `npm --version` | PASS — `v24.18.1` / `11.16.0` |
| `npm ci` | PASS — 462 packages installed, 463 audited, 0 vulnerabilities; no install-script warning |
| pending scripts / strict policy | PASS — `npm approve-scripts --allow-scripts-pending --json` reported no packages with unreviewed install scripts; `npm config get strict-allow-scripts` returned `true` |
| `npm run check` | PASS — Prettier, ESLint with zero warnings, `next typegen`, strict `tsc`, 15 files / 111 unit-component tests and the production build all passed |
| `npm run build` within `check` | PASS — `/th`, `/en`, both assessment routes and both `/assessment/example-result` routes are statically generated by Next.js `16.2.12` |
| `npm run test:e2e` | PASS — 35 Chromium tests covering the accepted shell/player plus Thai/English result content, keyboard/focus, locale switching, text equivalence, 320px reflow, both motion modes, axe and storage/network/privacy boundaries |
| `npm audit --omit=dev --audit-level=low` / `npm audit --audit-level=low` | PASS — 0 production and 0 full-graph vulnerabilities |
| result contract | PASS — both reviewed fixtures derive deterministically without mutation; visible `synthetic-mixed-review` yields exact core signals `1/4` and `3/4`, six unassessed cores and two separate single-scenario observations |
| next-practice trace | PASS — exact scoring model/version, two supporting item keys, target core and planned/unavailable lesson-version reference; incompatible traces and available-lesson claims are rejected |
| forbidden output review | PASS — no overall/weighted score, percentage proficiency, stage, confidence percentage, priority gap, personalized recommendation, employment/hiring, readiness/risk/personality or framework-weight field |
| client-reference manifest / result-route chunk | PASS — only project client reference is `shell-navigation.tsx`; the route client chunk contains no result/scoring fixture, rubric, player-storage or selected-option markers |
| browser privacy review | PASS — the result route did not read `rise-pals:assessment-player:v1`; the selected option ID was absent from DOM, URL, request bodies/URLs, console output and cookies; no unexpected origin was contacted |
| strict UTF-8 / Markdown fences / markers / `git diff --check` | PASS — 102 text files decoded as strict UTF-8; all 26 Markdown files had balanced fences; no unresolved markers or whitespace errors |
| dependency/config review | PASS — `package.json`, `package-lock.json` and `.npmrc` are unchanged; no dependency, raster asset, CI, infrastructure or deployment change exists |
| Gitleaks `8.30.1` scope-correct nonignored worktree scan | PASS — 105 files / approximately 849.43 KB scanned through `stdin`, no leaks found |

Final RP-TURN-008-R1 verification on 2026-08-02:

| Command or review | Exact result |
|---|---|
| `npm ci` | PASS — 462 packages installed, 463 audited, 0 vulnerabilities; no install-script warning |
| pending scripts / strict policy | PASS — `npm approve-scripts --allow-scripts-pending --json` reported no packages with unreviewed install scripts; `npm config get strict-allow-scripts` returned `true` |
| `npm run format:check` / `npm run lint` / `npm run typecheck` | PASS — formatting matched, ESLint completed with zero warnings, `next typegen` succeeded and strict `tsc` completed without errors |
| focused result-contract tests | PASS — 1 file / 13 tests, including rejection of an unknown fixture ID, one altered response, each altered compatibility field, a duplicate fixture ID and ambiguous identical canonical content |
| `npm run test` | PASS — 15 files / 118 unit-component tests |
| `npm run build` | PASS — all nine pages generated; `/th`, `/en`, both assessment routes and both `/assessment/example-result` routes remain statically generated by Next.js `16.2.12` |
| `npm run check` | PASS — Prettier, ESLint, strict typecheck, 15 files / 118 tests and the production build all passed in the aggregate gate |
| `npm run test:e2e` | PASS — 35 Chromium tests including Thai/English result content, keyboard/focus, text equivalence, 320px reflow, both motion modes, axe and storage/network/privacy boundaries |
| `npm audit --omit=dev --audit-level=low` / `npm audit --audit-level=low` | PASS — 0 production and 0 full-graph vulnerabilities |
| exact reviewed-fixture provenance | PASS — derivation resolves an exact canonical fixture before scoring and cannot emit `reviewed-synthetic-fixture` provenance for unknown, changed, duplicate or ambiguous fixture input |
| result-route client manifest / chunk | PASS — only project client reference is `shell-navigation.tsx`; the route chunk contains none of the seven reviewed fixture, scoring, rubric or player-storage markers |

Final RP-TURN-009 verification on 2026-08-03:

| Command or review | Exact result |
|---|---|
| `node --version` / `npm --version` | PASS — `v24.18.1` / `11.16.0` |
| `npm ci` | PASS — 462 packages installed, 463 audited, 0 vulnerabilities; no install-script warning |
| pending scripts / strict policy | PASS — `npm approve-scripts --allow-scripts-pending --json` reported no packages with unreviewed install scripts; `npm config get strict-allow-scripts` returned `true` |
| `npm run format:check` / `npm run lint` / `npm run typecheck` | PASS — formatting matched, ESLint completed with zero warnings, `next typegen` succeeded and strict `tsc` completed without errors |
| `npm run test` | PASS on exact rerun — 18 files / 140 unit-component tests, including lesson identity/content validation, deterministic evaluation/state, result trace and localized component behavior |
| `npm run build` | PASS — all 11 pages generated; `/th`, `/en`, both assessment routes, both example-result routes and both source-verification lesson routes are statically generated by Next.js `16.2.12` |
| `npm run check` | PASS — Prettier, ESLint, strict typecheck, 18 files / 140 tests and the 11-page production build all passed in the aggregate gate |
| `npm run test:e2e` | PASS — 46 Chromium tests covering existing flows plus Thai/English lesson content, locale-matched non-personalized link, keyboard/focus, 320px reflow, both motion modes, refresh reset, axe and storage/URL/cookie/log/network boundaries |
| `npm audit --omit=dev --audit-level=low` / `npm audit --audit-level=low` | PASS — 0 production and 0 full-graph vulnerabilities |
| lesson contract / deterministic state | PASS — exact lesson/framework/competency/stage/R.O.I./practice/rubric/proof identities and locale parity validate; passive/incomplete/partial are not demonstrated, all three criteria produce exactly 20 preview XP, retry replaces rather than accumulates and reset returns to zero |
| result/lesson client manifests and chunks | PASS — result has only `shell-navigation.tsx`; lesson has only `shell-navigation.tsx` and `source-verification-lesson.tsx`; both route chunks contain 0/7 assessment fixture, scoring and player-storage markers |
| browser privacy review | PASS — result still did not read assessment storage; lesson choices remained memory-only and were absent from storage, query, request body/URL, cookie and console output; no unexpected origin was contacted |
| strict UTF-8 / Markdown fences / markers / `git diff --check` | PASS — 119 text files decoded as strict UTF-8; all 27 Markdown files had balanced fences; no unresolved markers or whitespace errors |
| dependency/config review | PASS — `package.json`, `package-lock.json`, `.npmrc` and build/test configuration are unchanged; no dependency, raster asset, MDX pipeline, CI, infrastructure or deployment change exists |
| Gitleaks `8.30.1` nonignored worktree scan | PASS — 119 files / approximately 990.01 KB scanned through `stdin`, no leaks found |

The first exact `npm run test` attempt immediately after the slow clean install passed every started assertion (15 files / 99 tests) but correctly exited nonzero because three Vitest fork workers timed out before startup. No test assertion failed. The unchanged exact command was rerun after the filesystem warmed and passed all 18 files / 140 tests; `npm run check` independently repeated the same 18/140 result before build.

Final RP-TURN-009-R1 verification on 2026-08-03:

| Command or review | Exact result |
|---|---|
| focused lesson-contract tests | PASS — 1 file / 13 tests; matched Thai/English `metadata.title` number, nested practice-option label boolean and proof-field label `null` all fail through the localized content-type validator rather than the structural-parity check |
| `npm run format:check` / `npm run lint` / `npm run typecheck` | PASS — formatting matched, ESLint completed with zero warnings, `next typegen` succeeded and strict `tsc` completed without errors |
| `npm run test` | PASS — 18 files / 143 unit-component tests |
| `npm run build` | PASS — all 11 pages generated, including both statically generated source-verification lesson routes |
| `npm run check` | PASS — Prettier, ESLint, strict typecheck, 18 files / 143 tests and the 11-page production build all passed in the aggregate gate |
| `npm run test:e2e` | PASS — all 46 Chromium tests passed with unchanged lesson behavior, privacy, focus, reflow, reduced-motion and accessibility boundaries |
| `npm audit --omit=dev --audit-level=low` / `npm audit --audit-level=low` | PASS — 0 production and 0 full-graph vulnerabilities |
| result/lesson client manifests and chunks | PASS — result still has only `shell-navigation.tsx`; lesson still has only `shell-navigation.tsx` and `source-verification-lesson.tsx`; both route chunks contain 0/7 assessment fixture, scoring and player-storage markers |

R1 changes only runtime copy-leaf validation and its regression coverage. Canonical lesson content, IDs, locale structure, rubric, XP behavior, routes, privacy boundaries, dependencies and configuration are unchanged.

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

### Active and planned names

Names remain minimal; Clerk-specific additions are limited to the approved synthetic-alpha Development boundary:

| Variable | Exposure | Purpose |
|---|---|---|
| `APP_BASE_URL` | Server | Canonical origin for secure redirects/links |
| `DATABASE_URL` | Production application server secret | Normal non-owner PostgreSQL application connection; the runtime reads only this URL |
| `DATABASE_MIGRATION_URL` | Migration/test tooling secret only | Separate migration/table-owner connection; never place it in the production application environment |
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` | Browser-visible provider locator | Clerk Development publishable key; must start `pk_test_` and is not an application authorization value |
| `CLERK_SECRET_KEY` | Server secret | Matching Clerk Development backend key; must start `sk_test_`, remain ignored and never enter output/client code |
| `OBJECT_STORAGE_BUCKET` | Server | Private proof bucket identifier |
| `OBJECT_STORAGE_ENDPOINT` | Server | Provider adapter endpoint when required |
| `OBJECT_STORAGE_ACCESS_KEY` | Server secret | Object-store service credential |
| `OBJECT_STORAGE_SECRET_KEY` | Server secret | Object-store service credential |

Do not create analytics, monitoring, email or payment variable names until those vendors and purposes are approved. `NODE_ENV` is framework-controlled and must not be repurposed.

## RP-TURN-010 database baseline

### Dependency rationale and typechecking

The exact lockfile adds only `drizzle-orm 0.45.2` and `pg 8.22.0` at runtime plus `drizzle-kit 0.31.10` and `@types/pg 8.20.3` for migration generation and TypeScript. `pg` is the server-side PostgreSQL driver; Drizzle supplies typed schema metadata and a reviewable SQL migration workflow. The reviewed `esbuild 0.25.12` override removes the vulnerable transitive version used by Drizzle Kit. `npm approve-scripts --allow-scripts-pending --json` reports no pending packages, and only `esbuild` is allowed to run an install script.

Application and Next.js typechecking retain strict mode with `skipLibCheck: false`. Drizzle's published declarations import optional Gel/MySQL/SingleStore/SQLite dialect declarations that fail the repository's TypeScript settings even when only PostgreSQL subpaths are imported. `tsconfig.database.json` therefore performs a second strict check over only `drizzle.config.ts` and the Rise Pals Drizzle schema while skipping third-party declaration bodies. This does not skip checking any Rise Pals source file.

### Typed connection boundary

Normal application runtime requires and reads only `DATABASE_URL`; `createApplicationPool()` does not access `DATABASE_MIGRATION_URL`. Migration and disposable-test tooling intentionally receive both URLs and require distinct decoded role names. URL usernames/passwords/database components are percent-decoded with PostgreSQL-compatible URI interpretation before role checks; malformed encoding fails closed, privileged owner/migration/admin/postgres-like application roles are rejected after decoding, and differently encoded forms of the same role cannot satisfy separation. Both URLs require a single explicit database and exactly one approved `sslmode`. Loopback test URLs require `sslmode=disable`; non-loopback URLs reject disabled encryption. Errors contain remediation but never echo connection values.

The normal pool is created only from a server-only module. `withUserDatabaseTransaction` validates a non-nil UUID, starts a transaction and sets `app.current_user_id` transaction-locally before calling data access. RP-TURN-011 adds the validated-session-to-internal-UUID authorization boundary above it; browser input still never controls this context directly. The real-provider smoke and required R3 rerun are accepted only for synthetic alpha; production authentication/provider suitability remains undecided.

### Disposable PostgreSQL verification

`scripts/db/prepare-postgres.ps1` downloads and verifies the exact EDB archive linked for advanced Windows users by PostgreSQL/EDB, then extracts it outside the repository:

- Official distribution page: `https://www.enterprisedb.com/download-postgresql-binaries`
- Source URL: `https://get.enterprisedb.com/postgresql/postgresql-18.4-1-windows-x64-binaries.zip`
- Archive: `postgresql-18.4-1-windows-x64-binaries.zip`, 337,444,127 bytes
- SHA-256: `7EFFE34C0BF89027B3F171447D351CBC460F4566C8D0F643DAEC67F140787858`
- Publisher evidence: the ZIP and PostgreSQL executables provide no Authenticode signature (`NotSigned`), so the script does not claim one. It anchors the archive to the official HTTPS source and pinned hash, then requires and copies only Authenticode-valid Microsoft Corporation VC runtime DLLs (observed EdgeCore `151.0.4129.59`, runtime `14.50.35719.0`) into the portable bin directory.

The preparation script fails before extraction on a length or checksum mismatch, refuses a destination inside the repository, verifies PostgreSQL reports exactly `18.4`, and changes no machine-wide PATH, service, firewall rule or elevation state. The default prepared location is `%TEMP%\risepals-postgresql-18.4\pgsql\bin`; `RISE_PALS_POSTGRES_BIN` remains an explicit override for an already prepared equivalent directory.

`scripts/db/run-disposable-postgres.ps1` creates a fresh cluster and random credentials outside the repository, binds PostgreSQL only to `127.0.0.1` on an ephemeral port, disables SSL only on that loopback listener, creates separate `rise_pals_owner` and `rise_pals_app` roles, applies the ordered forward migrations and runs synthetic constraint/RLS checks. It never registers a Windows service, changes the firewall or machine PATH, or creates a production account.

Run the complete safe harness:

```powershell
npm run db:prepare:disposable
npm run db:test:disposable
```

The harness always restores process-local environment values and deletes bootstrap password/SQL files even if normal stop fails. It recursively removes a disposable cluster only after a clean stop or verified absence of the exact process; a live or unverified process leaves its bounded diagnostics directory in place and returns an error rather than deleting it. Cleanup paths must remain under `%TEMP%\risepals-postgres-tests`. After a successful run, no PostgreSQL process, service, database directory or temporary credential remains. `npm run db:test` is the inner test only; run it directly only against a newly created disposable empty database with separately scoped test roles.

The six migrations create exactly twenty-three tables: the accepted nine-table baseline, `user_profiles`, `assessment_sessions`, `assessment_responses`, the five RP-TURN-013 derived tables, the three RP-TURN-015 learning tables and the three RP-TURN-016 controlled evidence tables. Version rows must be inserted as drafts; publication runs database validation; publication-to-retirement must change status only; retired rows cannot update or delete. Exact canonical 8+2 and sealed-parent validation applies to published and retired history. Competency/item/mapping triggers lock every relevant OLD and NEW parent in deterministic order, blocking moves out of or into a sealed parent and closing concurrent publication/mutation races. The fifth migration adds only the forced-RLS lesson attempt, immutable practice revision and meaningful progress-event contracts. The sixth adds only the private artifact lifecycle, immutable controlled revisions and one competency traceability link; neither adds saved XP, upload/object storage or sharing.

The resolver function is owned by `rise_pals_identity_resolver`, a credentialless `NOLOGIN`, `NOINHERIT`, `NOBYPASSRLS` role with no table ownership and only the exact account/Clerk-mapping operations used by the function. The disposable superuser bootstrap temporarily grants the migration owner membership so migration SQL can transfer function ownership, then the test-only bootstrap connection revokes that membership and enforces `PASSWORD NULL` before verification continues. `RISE_PALS_DISPOSABLE_BOOTSTRAP_URL` exists only inside the disposable PowerShell process for this post-migration revocation/assertion step; it is restored or removed in `finally`, never enters application configuration and is not a production runtime credential. A future production migration run needs an equivalent separately approved privileged bootstrap/revocation step.

The integration harness proves those lifecycle/reparent/concurrency paths plus validated JSON, business/provider uniqueness, atomic concurrent first-sign-in mapping, controlled profiles, serialized append-only consent and restrictive deletion. Through the normal role it verifies `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOINHERIT`, `NOBYPASSRLS` and zero application-table ownership. It also proves the resolver is `NOLOGIN`/`NOBYPASSRLS` with no password, neither normal role can assume it or enumerate identities without context, `PUBLIC` cannot execute its function and the application has no other executable `SECURITY DEFINER` function. Its two-user matrix covers own and cross-user SELECT/INSERT/UPDATE/DELETE as applicable, plus missing and malformed trusted context, across `user_accounts`, `external_identities`, `consent_records` and `user_profiles`; every prohibited result asserts its row count or SQLSTATE.

Production placement remains open. Managed PostgreSQL is preferred for operational isolation, while a database on the same VPS would require explicit capacity, patching, private binding, least-privilege roles, monitoring and encrypted off-host backup evidence. A later decision must verify supported PostgreSQL major version, TLS, pooling mode, backups/deletion, data region, credential rotation and operational access. Never use production data in local or preview environments.

### RP-TURN-010-R1 implementation verification

| Check | Result |
|---|---|
| `npm ci` | PASS — 488 packages installed, 489 audited, 0 vulnerabilities; only the existing deprecated `@esbuild-kit` notices were emitted |
| install-script policy | PASS — no packages with unreviewed scripts; `esbuild` allowed, `fsevents` and `unrs-resolver` denied |
| `npm run format:check` / `npm run lint` / `npm run typecheck` | PASS — formatting, zero-warning ESLint, Next route generation and both strict Rise Pals TypeScript projects completed |
| `npm run test` / `npm run check` | PASS — one reused `vmThreads` worker with an isolated VM context per file completed 20 files / 165 tests without worker-start timeout; aggregate gate also completed the 11-page static production build |
| clean `npm run build` → first `npm run test:e2e` → `npm run typecheck` | PASS — Chromium 46/46 on the first attempt through `next start`, then production route generation and strict typecheck passed; no `.next` deletion or retry |
| `npm run db:prepare:disposable` | PASS — exact 18.4 archive length/SHA-256, official URL, `NotSigned` PostgreSQL executable state and Microsoft-signed EdgeCore VC runtime verified outside the repository |
| `npm run db:test:disposable` | PASS — PostgreSQL 18.4, 85 migration statements, 9 tables, sealed lifecycle/reparent/concurrency enforcement, full normal-role attributes and complete two-user forced-RLS matrix |
| production/full npm audits | PASS — 0 vulnerabilities in both graphs; all `esbuild` paths resolve to reviewed override `0.25.12` |
| client boundary | PASS — expected result/lesson client references only; 11 production client chunk files contain 0 database URL, PostgreSQL, Drizzle, `pg`, private-schema or trusted-context markers |
| disposable cleanup | PASS — 0 PostgreSQL processes, services and disposable test roots after the run; temporary database files and credentials removed |

## RP-TURN-011 synthetic-alpha authentication and profile

### Clerk Development configuration

The exact lockfile adds `@clerk/nextjs 7.7.0` and `@clerk/localizations 4.14.1` from the public npm registry. Both are pinned. The SDK supplies the official Next.js session/UI integration; the localization package supplies `thTH` and `enUS`. Clerk localization is experimental, so Rise Pals displays authoritative Thai-first/English-complete product/privacy/fallback copy outside the vendor widget and tests that coverage.

Clerk SDK imports are limited to small `.mjs` runtime shims under `src/modules/identity/providers/clerk/`. Reviewed local `.d.mts` files type only the adapter surface because Clerk 7.7.0's published declaration graph conflicts with this repository's `exactOptionalPropertyTypes` and references optional wallet/password packages not installed for the email-code flow. Application strict mode and `skipLibCheck: false` remain unchanged; every Rise Pals TypeScript source and the local adapter declarations are checked.

To run an authorized bounded real smoke, use this dashboard/environment checklist without sharing values in chat:

1. Create or select one Jeff-controlled Clerk **Development** application on Free/Hobby; do not activate Production or add payment information.
2. Configure email verification code as the only alpha sign-up/sign-in method; do not enable passwords, social OAuth, SMS or Organizations.
3. Put the matching Development values only under `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` and `CLERK_SECRET_KEY` in ignored `.env.local`.
4. Use only Clerk's reserved synthetic test-email convention, run the bounded smoke, delete the synthetic identity and verify deletion before handoff.

The ignored file contains only these variable names:

```dotenv
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...
```

Never paste values into chat, commits, screenshots, logs or handoff text. Incomplete pairs and `pk_live_`/`sk_live_` fail closed. Do not create/activate Production, add payment details, social OAuth, SMS, passwords, Organizations or custom domains. Test only with Clerk's reserved synthetic email convention and remove every synthetic identity before handoff. Without keys, sign-in/sign-up/profile routes render an explicit unavailable state, make no Clerk request and do not initialize the database pool.

Run the opt-in smoke independently of the standard secret-free build:

```powershell
npm run test:auth:clerk:development
```

The command refuses absent, incomplete or live keys. It creates a loopback-only disposable PostgreSQL cluster, applies the reviewed migrations, creates a strict typechecked Clerk-enabled production build only in ignored `.next-clerk-development-smoke`, uses Clerk's official synthetic-email/testing-token convention, and succeeds only after the unique remote identity is deleted and verified. Its temporary build, database, logs and generated credentials are removed in `finally`.

Standard `npm run build`, `npm run check` and `npm run test:e2e` invoke `scripts/run-secret-free.mjs`. That runner sets both Clerk variables to empty only in its child environment before Next can load `.env.local`; the ignored file remains present and untouched. Playwright starts through the same runner, and its shared fixture aborts and fails on every browser request outside exact loopback origin `http://127.0.0.1:3104`. Normal application configuration parsing is unchanged, so incomplete or live pairs still fail closed outside this bounded standard-gate wrapper.

### Server authorization, profile and consent

`IdentityProvider` returns only a validated server session state and provider subject. The server-only authorization transaction takes a provider-key advisory lock, calls the hardened resolve-or-provision function through the normal application role, checks the internal account state and only then establishes `app.current_user_id`. Active accounts proceed; absent, invalid, expired, unavailable, suspended, deletion-pending and deleted states fail closed. Provider subjects and tokens are never client DTO fields. Clerk manages logout/session cookies; Rise Pals creates no custom auth cookie or token store.

The dynamic `/th|en/sign-in`, `/sign-up`, `/onboarding` and `/profile` routes preserve only allowlisted paths whose first segment exactly matches the current route locale. Absolute, protocol-relative, query-bearing, fragment-bearing, encoded, unsupported-locale and cross-locale return targets fall back to that locale root. `ClerkProvider`, `SignIn` and `SignUp` receive explicit matching URLs; sign-in points to the dedicated sign-up route and sign-up points back to sign-in. `profile-v1` accepts controlled codes only, including `other` without free text. Goals are P3 sensitive career data. The UI and validator do not collect employer name, exact title, salary, national identifier or career-concern text.

`alpha-privacy-v1` covers the `service-profile-learning-state` purpose only. Its proof digest is SHA-256 over one canonical versioned contract. Consent mutations lock the internal account row, use post-lock `clock_timestamp()` and append grant/decline/withdrawal receipts. Current state sorts by `occurred_at`, then receipt UUID. Decline never invokes profile persistence; profile upsert rechecks a current grant inside the same owner-scoped transaction. Withdrawal is described as access-state change, not deletion.

On 2026-08-16 the Jeff-controlled Personal Workspace/Hobby/Development application was verified with email verification code as its only method; password authentication, social/OAuth providers and Organizations were disabled. No Production instance, payment method, SMS or custom domain was created. The matching Development pair remains locally configured in ignored `.env.local`; only presence/test form, matching Development instance, ignore status and non-staged/non-tracked state were verified, and no value or fragment is recorded.

The real-provider smoke created one unique reserved synthetic test identity, rendered the real Thai and English Clerk components, completed email-code sign-up/sign-in, reused one internal UUID, persisted one service-data consent and controlled profile without copying email, denied profile access after logout, and rejected cross-locale/external return targets. Cleanup deleted and re-queried the remote identity, stopped PostgreSQL and removed temporary data, logs and credentials. Clerk's supported Development session synchronization transiently used the vendor-controlled `__clerk_handshake` query parameter during authentication; the harness rejects every other JWT-bearing application URL parameter and verifies the final application URL has no query or fragment. This Development-only behavior is not production approval.

### Accepted RP-TURN-011 verification

| Check | Result |
|---|---|
| `npm ci` | PASS — 499 packages installed, 500 audited, 0 vulnerabilities; only the existing deprecated `@esbuild-kit` notices were emitted |
| pending scripts / strict policy | PASS — `npm approve-scripts --allow-scripts-pending --json` reported no unreviewed package; `npm config get strict-allow-scripts` returned `true` |
| Clerk dependency pins | PASS — `@clerk/nextjs 7.7.0` and `@clerk/localizations 4.14.1` are exact direct dependencies |
| `npm run format:check` / `npm run lint` / `npm run typecheck` | PASS — Prettier, zero-warning ESLint, Next route generation and both strict Rise Pals TypeScript projects completed |
| `npm run test` / `npm run check` | PASS — 25 files / 209 tests; aggregate gate completed production generation for 15 pages with sign-in/sign-up/onboarding/profile dynamic and the established public routes static |
| `npm run test:e2e` | PASS — Chromium 56/56 with ignored Development keys still present; the secret-free wrapper kept auth routes unavailable and the shared fixture observed no origin outside exact loopback. Next.js emitted four internal `NoFallbackError` diagnostic lines while Playwright exercised negative/dynamic-route cases; the command exited 0 with no failed or user-visible cases. |
| `npm run db:test:disposable` | PASS — PostgreSQL 18.4, 108 statements across 2 migrations, 10 tables, credentialless/non-assumable resolver role, zero-context identity non-enumeration, atomic concurrent Clerk provisioning, profile controls, consent serialization, sealed lifecycle/concurrency rules and complete two-user forced-RLS matrix; cluster/data/logs/credentials removed |
| `npm ls nanoid postcss --all` | PASS — one valid `nanoid 3.3.18` override under exact PostCSS `8.5.25`; exact Sharp `0.35.3` and all unrelated direct dependencies remain unchanged |
| production/full npm audits | PASS — 0 vulnerabilities in both graphs; `GHSA-2v37-7h3g-55p8` is resolved by exact `nanoid 3.3.18` |
| production client boundary | PASS with recorded upstream marker — 17 client chunks / 1,092,184 bytes contain 0 database URL, migration URL, disposable-bootstrap URL, provider-subject, identity-resolver, Drizzle, PostgreSQL URL or Clerk secret-value-prefix markers. The Clerk client SDK itself contains one literal environment-variable name `CLERK_SECRET_KEY`; no value/prefix is bundled, and all six result/lesson/onboarding/profile/sign-in/sign-up manifests contain 0 Rise Pals server/DAL markers. All 448 standard build files contain 0 local publishable-key value, secret-key value or provider-host value. |
| `npm run test:auth:clerk:development` | PASS — after the R3 execution-boundary change, exactly one new synthetic identity exercised real Thai/English Clerk email-code components, same-locale onboarding, one account/mapping, consent/profile, logout denial, repeat sign-in, safe return rejection and privacy checks; the identity, isolated build and disposable PostgreSQL process/data/logs/credentials were removed |
| ignored key-state proof | PASS — both Development values were present in test form and matched the same Development instance; `.env.local` was ignored, untracked, unstaged and retained locally without printing values |

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

## RP-TURN-012 persisted synthetic assessment verification

The protected `/th|en/assessment/attempt` route is distinct from `/th|en/assessment`. It requires a validated Clerk Development session, active internal account and current `service-profile-learning-state` / `alpha-privacy-v1` grant. Page load does not create a session. Explicit start uses the repository-local synthetic published definition only in disposable bootstrap data; the production migration contains schema/invariants only. Browser saves contain locale, accepted item/option IDs, expected revision and a mutation UUID, never an owner/session/row UUID or trusted context. The route uses no local/session storage, answer-bearing cookie, query or fragment.

The third migration creates only `assessment_sessions` and `assessment_responses`. Both use forced owner RLS. Session/version/consent anchors are immutable, timestamps are database-owned, only `in_progress → submitted` is allowed, re-assessment/reopen/delete are absent and complete submission is atomic. Raw payloads contain only `assessment-response-v1` plus one canonical selected option ID; correction appends a monotonic revision that explicitly supersedes the prior row. Mutation IDs are unique per session, a replay resolves to the stored revision, concurrent expected-revision saves produce one winner and one conflict, and a deferred invariant preserves exactly one active answer per item. Application DELETE and response-payload UPDATE privileges are absent.

### Actual RP-TURN-012 verification

| Check | Result |
|---|---|
| `npm ci` | PASS — 499 packages installed, 500 audited, 0 vulnerabilities; only the established two deprecated `@esbuild-kit` notices were emitted |
| exact `npm query ':attr(scripts)' --json` | NOT SUPPORTED by npm 11.16.0 — exited 1 with `EQUERYATTR` because `:attr` requires an attribute matcher; this is reported rather than claimed as a pass |
| install-script policy / strict setting | PASS — `npm approve-scripts --allow-scripts-pending --json` reported no unreviewed package; supported preinstall/install/postinstall queries returned no preinstall/install package and only reviewed `esbuild 0.25.12` plus denied `unrs-resolver 1.12.2` postinstall entries; `npm config get strict-allow-scripts` returned `true` |
| `npm ls nanoid postcss --all` | PASS — exact `nanoid 3.3.18` under overridden/deduplicated PostCSS `8.5.25`; no dependency or lockfile change in this turn |
| focused persisted tests | PASS — 3 files / 19 tests cover accepted registry/input shapes, browser DTO exclusions, stale conflict, six-answer review/submission and the original sessionStorage-player boundary |
| `npm run check` | PASS — Prettier, zero-warning ESLint, strict application/database typechecks, 27 files / 219 tests and secret-free production build completed; 17 pages were generated and `/[locale]/assessment/attempt` is dynamic |
| `npm run test:e2e` | PASS in the final workspace — Chromium 62/62; Thai/English unavailable states, 320px reflow, axe, honest sessionStorage separation and locale switching passed with Clerk explicitly disabled and no non-loopback request |
| `npm run db:test:disposable` | PASS — PostgreSQL 18.4 applied 155 statements across 3 migrations and created 12 tables; concurrent start, same-mutation replay, concurrent save winner/conflict, revision history, malformed/unknown response rejection, incomplete/successful/post-submit states, current-consent blocking, privileges and cross-user forced-RLS evidence passed; process/data/logs/credentials removed |
| production/full npm audits | PASS — both graphs report 0 vulnerabilities |
| persisted-route client boundary | PASS — exact 3 route client chunks / 410,560 bytes and route client manifest contain no DAL/contract/assessment-domain module, database URL, migration/bootstrap URL, table/payload/trusted-context/provider-subject, `pg`/Drizzle, response-schema, rubric/weight/scoring or secret-value marker. One generic `pk_test_` SDK literal exists; all 470 build files contain zero Development key value-prefix matches. |
| final bounded real Clerk Development smoke | PASS — one new synthetic identity completed Thai email-code sign-up/onboarding, one stable internal account mapping, current consent/profile persistence, persisted start, first-answer correction, refresh resume, six-answer submission/double-submit protection, immutable receipt reload, explicit profile logout, logged-out same-locale denial, same-identity re-authentication, safe return handling and final browser/privacy assertions. Database evidence confirmed 1 submitted session, 7 historical revisions, 6 active responses, no copied email and rejected post-submit mutation. |
| final smoke cleanup | PASS — cleanup deleted the unique synthetic identity and re-queried it absent without logging an identifier. Read-only checks found zero PostgreSQL processes/services, zero disposable child roots/files, no isolated smoke build and no tracked `.env.local`; temporary data/logs/credentials were removed. |

Project Codex Accepted the implementation and deterministic/database/browser/real-provider verification for synthetic alpha only. This acceptance did not itself authorize production use or RP-TURN-013; Turn 013 was subsequently authorized through a separate brief.

## Current boundary after RP-TURN-014 acceptance

- RP-TURN-006 and RP-TURN-007 are Accepted by Project Codex.
- RP-TURN-008 is Accepted by Project Codex and contains one static Thai/English example result derived only after exact `synthetic-mixed-review` identity and content validation against the canonical reviewed registry.
- RP-TURN-009 is Accepted by Project Codex and adds one schema-validated Thai/English local lesson/practice prototype linked from the fixed synthetic result with an explicit non-personalized boundary and strict runtime copy-leaf validation.
- RP-TURN-010 is Accepted by Project Codex and adds only the nine-table PostgreSQL/Drizzle definition baseline, one forward migration, split typed server/tooling connection boundary and disposable database verification.
- RP-TURN-011 is Accepted only for synthetic alpha. It adds Clerk Development authentication, internal identity/profile authorization, a second migration, protected routes and versioned append-only service-data consent. The bounded real-provider smoke and required R3 rerun passed; each synthetic identity was deleted and verified absent. Standard build/check/E2E explicitly disable Clerk and allow only the exact loopback origin. Patched `nanoid 3.3.18` remains pinned while PostCSS `8.5.25` and Sharp `0.35.3` are unchanged, and both npm audits report zero vulnerabilities. Production identity-provider suitability, privacy/legal review and data residency remain undecided; no real user/data or production identity resource exists.
- RP-TURN-012 owner-scoped raw synthetic assessment start/save/resume/submit is Accepted by Project Codex for synthetic alpha. Its deterministic, disposable-database and final bounded real-provider verification gates pass.
- RP-TURN-013 owner-scoped reproducible synthetic result and zero-or-one provisional priority contract is Accepted by Project Codex for synthetic alpha at reviewed head `b80c1c27902b856aac268eb7b17fbf983a62650e`.
- RP-TURN-014 is Accepted by Project Codex at reviewed implementation head `e4572c02c4bbfa25f9e88b34d79d96b600da224f`. It operationally publishes one exact repository-local lesson version for synthetic alpha through an independently sealed, deterministic non-executable registry; this is not external validation or production release.
- The repository contains a static public narrative, synthetic assessment-domain definitions/tests, a Thai/English six-scenario usability player, the separate fixed example result, one repository-published but prototype-unvalidated lesson, bounded account/profile/consent and raw assessment persistence implementations, and an accepted synthetic persisted-result prototype. It is not a validated real assessment and creates no real-user result, validated recommendation, externally validated learning content or production account system.
- Selected assessment item/option IDs may exist temporarily in same-tab `sessionStorage` only in the public player. The persisted assessment path never reads them. Public lesson selections/feedback remain only in React memory and reset on refresh; the separate protected lesson path persists allowlisted selections/revisions only after explicit authenticated actions and current consent. No XP is saved.
- No paid or Production cloud resource, production database, persistent local database, Windows service, production account or deployment was created. The Development-only synthetic identity and completed disposable cluster/credentials were removed.
- CI and branch protection remain separately authorized work even though the repository supplies reproducible local browser checks.
- Assessment methodology/validation, confidence semantics, proficiency mapping, personalized priority logic, lesson efficacy/external validation, production content operations, exact visual identity, final color/typography, localization operations, the Pal character system, credentials and production readiness remain open.
- No real profile/data, validated score/result/recommendation, saved XP, file proof, object storage or share flow exists. RP-TURN-012 stores synthetic-alpha raw selected-option revision history; RP-TURN-013 stores only synthetic-alpha reproducible derived evidence and a bounded provisional priority; RP-TURN-015 adds only synthetic-alpha lesson/practice/progress state; RP-TURN-016 adds one private controlled synthetic note. Retention/export/erasure and production use remain open. RP-TURN-017 is not authorized or started.

## RP-TURN-013 reproducible synthetic result verification

The protected `/th|en/assessment/result` route is dynamic and read-only on GET. An explicit localized Server Action accepts only locale and a mutation UUID, resolves the current owner/consent/submitted session server-side and derives the result through immutable `persisted-synthetic-priority-v1@1.0.0`. The result shows exact earned/available fractions for two assessed cores, six unassessed names, two separate one-scenario multiplier observations and zero or one provisional priority. It never displays a proficiency percentage, overall/weighted score, confidence or employment inference.

The fourth migration adds exactly `scoring_runs`, `competency_scores`, `multiplier_observations`, `score_explanations` and `priority_recommendations`. Every table has ENABLE/FORCE RLS, owner/session provenance and application SELECT/INSERT only. Deferred triggers require an atomically complete run and reproduce canonical rubric evidence. Normal concurrent generation converges on one run; server-only rescore appends the next run without changing prior history.

### Final accepted RP-TURN-013 verification

| Check | Result |
|---|---|
| `npm ci` | PASS — 499 packages installed, 500 audited, 0 vulnerabilities; only the established `@esbuild-kit` deprecation notices appeared |
| install-script/dependency policy | PASS — no unreviewed install script; `strict-allow-scripts=true`; exact `nanoid 3.3.18` under PostCSS `8.5.25`; Sharp `0.35.3` and direct dependencies unchanged |
| formatter/lint/typecheck/unit/build | PASS — Prettier, zero-warning ESLint, Next route generation and both strict TypeScript projects; 29 files / 238 tests; production build generated 19 routes/pages and kept `/[locale]/assessment/result` dynamic |
| focused result tests | PASS — 4 files / 26 tests cover exact policy/digests, core/multiplier/unassessed shape, Critical/Systematic/tie actions, DTO exclusions and locale-route preservation |
| `npm run test:e2e` | PASS — Chromium 65/65 with Clerk explicitly disabled; Thai/English result unavailable states, route preservation, no result identifiers and loopback-only requests passed alongside existing reflow/reduced-motion/axe coverage |
| `npm run db:test:disposable` | PASS — PostgreSQL 18.4 applied 234 statements across 4 migrations and created exactly 17 tables; derived-run concurrency/replay/rescore semantics, exact evidence/priority/tie shape, immutability, current consent and forced-RLS isolation passed; process/data/logs/credentials removed |
| policy/digest evidence | PASS — canonical policy digest `10f2ab076828d50b228ff53d57332527dfe9d1b2769c4b57bd0476dd3c263157`; pinned known input/output digests and order independence pass |
| result client boundary | PASS — the exact three route client chunks contain zero raw-option, scorer, derived-table, digest, policy, RLS-context, database-URL or secret markers |
| production/full npm audits | PASS — both dependency graphs report 0 vulnerabilities |
| final bounded Clerk Development smoke | PASS for the accepted functional/data/privacy contract — one normal run from seven historical/six active responses produced two core rows/cards, six unassessed cores, two separate multiplier observations, six explanations and one Critical Thinking priority. Refresh/repeated access preserved one run; logout denial, same-identity restoration, safe returns and browser/database/log/storage/third-party privacy checks passed. |
| final smoke cleanup | PASS — the synthetic identity was deleted and re-queried absent; PostgreSQL processes/services, smoke Node and Playwright browser processes, listeners and disposable child resources were zero; the isolated build and temporary data/logs/credentials were removed; `.env.local` remained ignored and untracked. |
| Clerk Development session-refresh warning | KNOWN DEVELOPMENT ISSUE — the recurring redirect-loop message with a generic possible key-mismatch suggestion was caught by the retained diagnostic guard after the complete flow passed. It did not disrupt navigation/session restoration, and the frontend-created identity was found/deleted through the Backend API with the authenticated subject matching the internal mapping. This is not production-provider approval; production Clerk suitability and session behavior remain unresolved. |

Project Codex Accepted RP-TURN-013 through RP-TURN-015 for their bounded synthetic-alpha contracts. RP-TURN-016 is complete pending review. This does not approve validated assessment/proficiency or learning-efficacy claims, a credential or externally verifiable proof, real users or career data, production Clerk/PostgreSQL, retention/export/erasure operations, uploads/sharing, CI, infrastructure or deployment. RP-TURN-017 is recommended only and is not authorized or started.

## RP-TURN-014 trusted content publication verification

Status: Accepted by Project Codex for the documented synthetic-alpha boundary at implementation head `e4572c02c4bbfa25f9e88b34d79d96b600da224f`.

| Check | Result |
|---|---|
| `npm ci` | PASS — 573 packages installed, 574 audited, 0 vulnerabilities; only the established `@esbuild-kit` deprecation notices appeared |
| install-script/dependency policy | PASS — no package with an unreviewed install script; `strict-allow-scripts=true`; exact build-only `unified 11.0.5`, `remark-parse 11.0.0` and `remark-mdx 3.1.1`; patched `nanoid 3.3.18`, PostCSS `8.5.25` and Sharp `0.35.3` unchanged |
| `npm run content:validate` | PASS — one exact `source-verification-practice@1.0.0` version; canonical aggregate SHA-256 remains `d1d73e26afc718fcdc86c2dab54853ddbd488ad171c1c1f81e3d64e2f55c1525` |
| independent publication seal | PASS — Git-reviewed `publication-seal.json` authorizes only canonical lesson digest `51903ea9e6053a1102b4d60ad072c9a1dcde26a90d6a0ca7ae36cba8a6995e91`; `content:publish` reads but never rewrites the seal, whose file SHA-256 remained `122453362FDE63C3940FFFE190D454F18D270670F1C89C4D4569D412893A33A9` |
| deterministic publication | PASS — two consecutive `npm run content:publish` operations preserved byte-identical manifest and registry files and the same aggregate digest; manifest SHA-256 remained `73A4AA24E29D8F67AC8E93530A76267E4FAC73EAB564006A640FFE603274A5D3` and registry SHA-256 remained `4DAB8A29B95011D2F5E2C12A2F17388DCD653321C11A913B7B61B19FB1EB5163` |
| focused publication/lesson tests | PASS — 4 files / 77 tests; R1 seal cases remain green; R2 rejects non-leap February 29, February 30, month 13, day 00, verification before publication and expiry equal to/before verification, accepts valid leap-year February 29, preserves exact UTC expiry boundaries and proves failed validation/publication leave both outputs byte-identical |
| formatter/lint/typecheck/unit/build/check | PASS — Prettier, zero-warning ESLint, Next type generation and both strict TypeScript projects; 30 files / 291 tests; production build generated 19 routes/pages and kept both lesson locales static |
| `npm run test:e2e` | PASS on final full rerun — Chromium 65/65; Thai/English operational and validation statuses, accepted content, keyboard/focus, refresh reset, 320px reflow, reduced motion, axe and loopback-only privacy behavior passed |
| `npm run db:test:disposable` | PASS after checksum-pinned runtime re-preparation — PostgreSQL 18.4 applied 234 statements across four unchanged migrations and created 17 tables; process/data/logs/credentials removed, zero service/process/listener and zero disposable child remained |

## RP-TURN-015 persisted lesson/practice/progress verification

Status: Accepted by Project Codex at reviewed implementation head `962b4422fa21c28b06c362f87ec55466281409e8` for the documented synthetic-alpha and `prototype-unvalidated` boundary.

The fifth forward migration adds exactly `lesson_attempts`, `practice_attempts` and `learning_progress_events`, producing twenty tables. Public lesson routes remain static and memory-only. Protected `/[locale]/learning` and `/[locale]/lessons/source-verification-practice/attempt` routes are dynamic, noindex/noarchive and use explicit start/save/evaluate/retry actions. Current consent and forced owner RLS govern reads and writes. Practice revisions persist normalized mutation intent, locale and expected revision; replay requires every provenance field and canonical save/evaluate selection to match. A non-demonstrated evaluated revision permits only an explicit retry draft that copies and supersedes the exact predecessor. DAL and PostgreSQL deny direct save/evaluate without changing a row, event or lesson timestamp; save/evaluate becomes available again only after the retry draft exists. Exact replay remains valid after demonstration while every new mutation is denied. The server resolves exact content identity and performs deterministic evaluation; the client receives no evaluator mapping, internal UUID, provider/email, consent internals, digest map or assessment/scoring data. XP stays preview-only and proof remains unavailable.

| Verification | Result |
|---|---|
| focused persisted lesson replay/state-machine tests | PASS — 2 files / 21 tests; exact save/evaluate/retry replay, six collision variations, both concurrency outcomes, denied direct save/evaluate after failed evaluation, explicit retry, post-retry save/evaluate and demonstrated replay/denial passed |
| `npm run check` | PASS — 33 files / 314 tests plus a 23-page/route production build; public lesson routes static and both protected route families dynamic |
| `npm run test:e2e` | PASS — Chromium 71/71, including Thai/English protected fail-closed states, loopback-only requests, language switching, 320px/axe and public memory-only regression |
| `npm run db:test:disposable` | PASS — PostgreSQL 18.4 applied 294 statements across 5 migrations and created exactly 20 tables; direct save/evaluate after a failed evaluation were rejected with row/event/timestamp state unchanged, exact-payload retry and post-retry save/evaluate passed, and lesson lifecycle, canonical evaluation, mutation provenance, immutable revisions/events, withdrawal and cross-user RLS checks passed; process/data/logs/credentials removed |
| publication preservation | PASS — aggregate digest remains `d1d73e26afc718fcdc86c2dab54853ddbd488ad171c1c1f81e3d64e2f55c1525`; content publish was not run |
| dependency/install policy | PASS — `npm ci` added 573 packages / audited 574 with zero vulnerabilities and no unreviewed install script; `strict-allow-scripts=true`; `npm ls --all` exited 0 |
| production/full audits | PASS — both report zero vulnerabilities |
| protected lesson client boundary | PASS with recorded upstream marker — exact 3 route client chunks / 410,571 bytes contain zero database URL/context/table, provider subject, assessment/scoring, evaluator mapping, canonical digest, publication artifact, Drizzle/pg or secret-value markers; the manifest contains no DAL/registry/database source path. The shared Clerk SDK chunk contains one literal environment-variable name `CLERK_SECRET_KEY`, not a value or Rise Pals server module. |

Project Codex accepted the final audit, client-boundary, repository-integrity and four-scope Gitleaks evidence. No Clerk Development smoke was part of this turn.
| production/full npm audits | PASS — both report 0 vulnerabilities |
| lesson client boundary | PASS — five referenced route client chunks / 474,796 bytes contain zero publication seal/manifest/registry names, canonical digest, parser-package, database, assessment-fixture or scoring-table markers; the route client manifest contains no server pipeline/registry source path |
| executable-content inspection | PASS — source/generated content contains no ESM statement, `dangerouslySetInnerHTML`, `new Function`, VM import or `javascript:`, `data:` or `file:` marker; rejection tests also cover expressions, spread/expression props, event handlers, raw HTML, images and unknown components |

Operational publication remains limited to the Git-reviewed repository registry for synthetic alpha. It does not create a database migration, lesson attempt/progress, saved XP, proof, real external evidence, production content operation or learning-efficacy claim. The real Clerk Development smoke was not run because this turn changes neither its command nor the shared authentication boundary.

## RP-TURN-016 private structured evidence verification

Status: RP-TURN-016-R1 complete pending Project Codex review for the bounded controlled synthetic-alpha and `prototype-unvalidated` contract.

The sixth forward migration adds exactly `evidence_artifacts`, `evidence_artifact_revisions` and `evidence_competency_links`, producing twenty-three tables. Protected `/[locale]/evidence` and `/[locale]/evidence/source-verification-note` routes are dynamic, noindex/noarchive and read-only on GET. Explicit start requires current consent and the exact demonstrated owner source-verification practice. Saves append an exact controlled six-key payload; ready and withdraw use guarded lifecycle provenance. The browser receives controlled copy/IDs, selections, revision, status and feedback only. It receives no internal UUID, provider/email, consent internal, publication digest, assessment/scoring record, database error/credential or share/storage token and persists nothing in URL, storage, analytics or a custom cookie.

R1 resolves an existing save mutation before the non-draft gate, so exact request replay remains successful after ready or withdrawal and returns the truthful current lifecycle. PostgreSQL now rejects one mutation UUID reused across start, save, ready or withdraw and preserves rows plus lifecycle timestamps on every rejected cross-intent operation. The server-to-client view contains only controlled copy/options and public synthetic field identities; the contract, proof, source-pack and internal provenance metadata remain server-only. The test-only authenticated boundary is a Vitest module mock only, makes no network request and cannot alter production authentication.

The existing public lesson and its proof placeholder remain static, memory-only and non-collecting. The canonical lesson digest remains `51903ea9e6053a1102b4d60ad072c9a1dcde26a90d6a0ca7ae36cba8a6995e91`; aggregate publication digest remains `d1d73e26afc718fcdc86c2dab54853ddbd488ad171c1c1f81e3d64e2f55c1525`.

| Verification | Result |
|---|---|
| focused artifact contract/DAL/component/boundary tests | PASS — 4 files / 39 tests cover exact contract/source identities, six-key payload validation, canonical readiness, absent/non-demonstrated denial, concurrent start/save convergence, lifecycle-safe replay/conflict, all Thai/English draft/ready/withdrawn states and the exact authenticated server-to-client allowlist |
| dependency/install policy | PASS — `npm ci` added 573 packages and audited 574 with zero vulnerabilities; no package had an unreviewed install script; `strict-allow-scripts=true`; `npm ls --all` exited 0 with only platform/peer optional dependencies absent |
| `npm run check` | PASS — Prettier, zero-warning ESLint, strict application/database typechecks, 37 files / 353 tests and secret-free production build; public lesson routes remain static and both evidence route families are dynamic |
| focused evidence Chromium | PASS — 5/5; Thai/English fail-closed states, GET-only/loopback-only behavior, fixed route-preserving locale switches, 320px reflow, reduced motion and zero serious/critical axe violations |
| `npm run test:e2e` | PASS — Chromium 76/76 in explicitly Clerk-disabled mode; the new private-evidence cases passed alongside all accepted browser, reflow, reduced-motion, accessibility and loopback-only privacy coverage |
| `npm run db:test:disposable` | PASS — PostgreSQL 18.4 applied 351 statements across 6 migrations and created exactly 23 tables; cross-intent start/save/ready/withdraw UUID reuse, controlled payloads, stale/skipped provenance and post-ready mutation were rejected with row/timestamp preservation; lifecycle, consent, cross-owner/missing/malformed-context RLS and least-privilege checks passed; process/data/logs/credentials removed |
| publication preservation | PASS — `npm run content:validate` retained one lesson and the exact aggregate digest; tracked source, seal, manifest and registry are unchanged from authorized main and `content:publish` was not run |
| dependency/configuration boundary | PASS — no package, lockfile, npm/Next/TypeScript/test configuration or dependency override changed; standard verification remained explicitly Clerk-disabled and loopback-only |
| production/full npm audits | PASS — both dependency graphs report 0 vulnerabilities |
| evidence client/Flight boundary | PASS — authenticated Thai/English server-to-client props contain exactly copy, controlled view/options, selections, revision, lifecycle and feedback; the exact five referenced production client chunks total 470,680 bytes and contain no artifact-contract/proof/source-pack identity, lesson digest, database URL/table/RLS context, provider subject, consent/source UUID, assessment/result table or secret-value marker; both route client manifests contain no evidence DAL/contract/view, database or publication-registry server source path |

No real Clerk Development smoke, identity, durable/production database, external resource, upload, object storage, sharing, saved XP, CI, infrastructure or deployment was used or created. `.env.local` remained ignored, untracked and unread. RP-TURN-017 was not started or authorized.
