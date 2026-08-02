# Local Development

**Turn:** RP-TURN-002  
**Status:** Verified host baseline plus established Git/Public-GitHub source-control baseline; no application or deployment exists  
**Checked:** 2026-08-02

## Confirmed host role and separation rule

This Windows Server 2022 VPS is the intended production application target. It currently also contains the pre-development workspace at `C:\Codex PC SG2\Jeff\risepals`, but no application, service or deployment exists.

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
| Node.js | Not found in `PATH` |
| npm / npx / Corepack | Not found in `PATH` |
| pnpm / Yarn / Bun / Deno | Not found in `PATH` |
| Python / Python launcher | Not found in `PATH` |
| Docker CLI | Not found in `PATH` |
| VS Code `code` CLI | Not found in `PATH`; this does not prove the desktop application is absent |
| WSL executable | `C:\windows\system32\wsl.exe` exists, but modern `--version`/distribution checks returned usage text and exit code 1; no usable distribution was verified |
| Windows Package Manager (`winget`) | Not found in `PATH` |
| Repository `.git` | Present at repository root with `main`, one `origin` and repository-local noreply identity |

RP-TURN-001 through R2 made no Git mutation. RP-TURN-002 separately verified the local ancestry and empty Public destination, installed source-control tooling, initialized this exact workspace, created the reviewed initial baseline and published it without force. It did not install Node.js, scaffold an application or change a service/deployment.

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

Git and GitHub CLI were installed only for the authorized RP-TURN-002 source-control work. Node.js/npm remain absent and belong to the separately authorized RP-TURN-003 scaffold turn.

### Required

1. **Node.js 24 LTS x64** from the [official Node.js download page](https://nodejs.org/en/download), with bundled npm — proposed for RP-TURN-003 only after authorization
2. **Git for Windows** from [git-scm.com](https://git-scm.com/download/win), added to the terminal `PATH` — installed in RP-TURN-002 as a verified per-user PortableGit distribution
3. An editor that preserves UTF-8; VS Code is recommended but its CLI is optional

Why Node 24: the official Node release table listed v24 as LTS on 2026-08-01 and recommends LTS lines for production. Avoid v26 Current until it becomes an accepted LTS baseline and project dependencies support it.

### Not required yet

- Docker/Podman or a local PostgreSQL server: defer until the database turn decides disposable integration-test infrastructure
- WSL: Next.js supports Windows directly; use WSL only if the team deliberately standardizes it
- Python: the proposed web stack does not require it
- GitHub CLI: installed for RP-TURN-002 authentication and remote verification; persistent interactive authentication is removed after the initial push
- A cloud CLI: no cloud application host has been selected; production target is this VPS

## Runtime prerequisite verification

Git/gh versions were verified in RP-TURN-002. After installing Node in a separately approved scaffold turn, reopen the terminal and run:

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

Expected policy, not an asserted result:

- Node reports major version 24
- npm/npx resolve from the same Node installation
- Git resolves from Git for Windows

If a future supported Next.js or Playwright release changes its Node support before scaffolding, review the official requirements and record the new LTS choice rather than forcing an incompatible version.

## Established Public GitHub source baseline

Jeff selected his personal-account repository [`noppol87/RisePals`](https://github.com/noppol87/RisePals), with **Public** visibility, as canonical source/history. RP-TURN-002 verified the owner, URL, visibility and empty remote before mutation; initialized this exact workspace with `main`; configured a repository-local GitHub noreply identity; added exactly one `origin`; created one reviewed foundation commit; and pushed without force.

The direct initial push to `main` was allowed only because the remote had no branch, tag or commit. Future implementation work uses bounded branches and reviewed pull requests. Interactive GitHub authentication was removed after post-push verification; the public read-only `origin` remains. Branch protection, CI and deployment transport remain open and require separate authorization.

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

## Proposed repository shape

**Proposed — no application directories exist yet:** RP-TURN-003 should keep one application at the repository root:

```text
content/                 trusted, versioned lesson and evidence-claim source
docs/                    product, architecture and engineering documents
prompts/                 approved turn briefs and handoff templates
src/
  app/                   Next.js routes, layouts and route handlers
  modules/               domain/application modules with public entry points
  components/            shared accessible UI primitives
  lib/                   narrow cross-cutting infrastructure/configuration
tests/
  integration/           disposable PostgreSQL and boundary tests
  e2e/                   Playwright critical journeys
```

Do not create a monorepo, separate API service or shared-package workspace until a real second deployable/package makes that complexity useful.

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

## Proposed scaffold behavior

**Proposed — not executed:** the scaffold turn should create a Next.js App Router project with:

- TypeScript strict mode
- `src/` directory and `@/*` import alias
- ESLint and an explicit formatter check
- Tailwind CSS plus design tokens
- npm lockfile
- test scripts and a minimal build/render check
- server-only environment validation

The repository is already non-empty, so RP-TURN-003 must verify the current `create-next-app` behavior before choosing between a controlled temporary scaffold/merge and a reviewed manual root scaffold. It must preserve all existing documents and report every created file. This document deliberately does not prescribe a command that could overwrite the current repository.

## Proposed day-to-day commands

**Proposed — scripts do not exist and were not run:** after the scaffold turn defines them:

```powershell
npm ci
npm run dev
npm run format:check
npm run lint
npm run typecheck
npm run test
npm run test:integration
npm run test:e2e
npm run content:validate
npm run build
```

Use `npm ci` for clean/CI installs and commit `package-lock.json`. Developers may use `npm install` only when deliberately changing dependencies and must review the lockfile diff.

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

## Current blockers for RP-TURN-003

- Node.js 24 LTS/npm installation remains separately authorized work for the application-scaffold turn; it is currently absent.
- No cloud or paid provider, production service or deployment is needed to begin the local scaffold after that authorization.
- CI and branch protection remain separate decisions until the scaffold supplies real checks.
