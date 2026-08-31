# RP-TURN-019 — Windows VPS Infrastructure Readiness

**Authorization date:** 2026-08-24  
**Authorized base:** `main` at `cd45e7356e902afbf3aafec0bdf8286dbccff7ad`  
**Branch:** `agent/windows-vps-infrastructure-readiness`  
**Status:** Authorized to begin

## Objective

Prepare and rehearse the confirmed Windows Server 2022 VPS as a bounded, non-public Rise Pals application host. The turn may prepare versioned runtime tools, immutable release artifacts, loopback-only service configuration, deployment and rollback scripts, least-privilege Windows services and operational evidence.

This turn does not authorize public deployment, DNS changes, real-user traffic, production credentials, production databases or real-user data.

## Repository and GitHub workflow

1. Start from the exact authorized main hash.
2. Work only on `agent/windows-vps-infrastructure-readiness`.
3. Commit this brief before implementation.
4. Keep `main` unchanged.
5. Push without force.
6. Open one Draft PR to `main` titled `chore: prepare Windows VPS infrastructure`.
7. Do not mark the PR ready, merge it or delete branches before Project Codex acceptance.
8. Do not start RP-TURN-020 or a production-launch turn.

## Core boundaries

- No public launch, DNS or registrar change.
- Do not expose Rise Pals on the public IP or enable public inbound ports 80/443.
- Do not alter RDP, SSH or unrelated firewall rules.
- Do not create production Clerk, PostgreSQL, monitoring, backup or storage resources.
- Do not read, copy, display, rotate or modify `.env.local` values.
- No real accounts or personal data.
- No CI/CD or GitHub Actions.
- Do not purchase services or change external accounts.
- Do not install Docker, WSL, IIS or ARR.
- Do not claim production readiness or launch authorization.
- Preserve every accepted synthetic-alpha, privacy, forced-RLS, scoring-separation, content-publication and prototype-unvalidated boundary.

## Phase A — Read-only host inventory

Before host mutation:

1. Verify the exact repository base, branch and clean worktree.
2. Inventory without sensitive values:
   - Windows Server version and pending-reboot state;
   - architecture, RAM and free disk;
   - Windows roles/features;
   - Node, Caddy, IIS, ARR, WinSW and wrapper installations;
   - conflicting services or executable paths;
   - listeners on 80, 443, 2019, 3100, 8080 and 8443;
   - firewall profiles and relevant enabled rules;
   - existing `C:\RisePals` paths;
   - certificate stores and automatic-certificate services.
3. Redact public IPs, machine identifiers, SIDs, credentials and unrelated infrastructure.
4. Stop for a decision if an existing service, listener or production resource conflicts.
5. Never stop, reconfigure or replace another application's service.

## Approved architecture and provenance gate

Candidate pins:

- Node.js `24.18.1`;
- Next.js standalone output;
- Caddy `2.11.4`, standard build only, as loopback-only proxy;
- WinSW `2.12.0` stable for Node supervision only;
- Windows Service Control Manager;
- Windows virtual service accounts.

Before installation:

1. Use official release metadata and binaries only.
2. Verify exact archive/executable length and SHA-256.
3. Verify Caddy's official checksum/signature chain where available.
4. Record source URL, version, byte length and digest in repository documentation.
5. Do not use Caddy custom builds/plugins or self-upgrade.
6. Do not use WinSW v3 alpha.
7. Set WinSW `autoRefresh=false`.
8. Use bounded roll-by-size logging, not roll-by-size-time.
9. Stop for a decision before installing if provenance cannot be established.

Do not substitute IIS, ARR, PM2, NSSM, Docker, Task Scheduler or another supervisor without a new decision.

## Persistent host layout

Create only after resolving and validating exact absolute paths:

```text
C:\RisePals\tools\node\24.18.1
C:\RisePals\tools\caddy\2.11.4
C:\RisePals\tools\winsw\2.12.0
C:\RisePals\staging
C:\RisePals\releases
C:\RisePals\current
C:\RisePals\shared\config
C:\RisePals\shared\secrets
C:\RisePals\shared\cache
C:\RisePals\logs\app
C:\RisePals\logs\proxy
C:\RisePals\logs\deploy
C:\RisePals\rehearsal
```

Rules:

- Do not move or repurpose the development workspace.
- Releases are immutable except for an explicitly separated cache junction.
- `C:\RisePals\current` is an atomic junction to one reviewed release.
- Secrets, logs, mutable cache and configuration remain outside releases.
- Never recursively delete `C:\RisePals` or use unresolved variables/globs for destructive work.
- Validate every cleanup target as an exact resolved child before deletion.
- Preserve a sanitized host-change and created-path manifest.

## Application packaging

1. Configure Next.js `output: "standalone"`.
2. Include `public` and `.next/static` assets required by the release.
3. Add no dependency unless unavoidable and separately documented.
4. Produce a deterministic manifest with source commit, release ID, Node/npm/Next versions and file inventory/hashes plus configuration-template version.
5. Exclude secrets, `.env.local`, test artifacts, build caches and development credentials.
6. Put writable Next cache under `C:\RisePals\shared\cache`.
7. Build from an exact committed tree only.
8. Pass application gates before creating or switching the release junction.

## Health and rehearsal routes

Add only:

- `/health/live`: fixed non-sensitive liveness;
- `/health/ready`: loopback-only readiness;
- a fixed streaming probe enabled only with `RISE_PALS_INFRA_REHEARSAL=1`.

The streaming route must be absent/404 outside rehearsal. Health output must contain no secrets, database/user identifiers, environment/version details or detailed exceptions. Readiness fails closed when required rehearsal dependencies are unavailable. The proxy must not publish internal readiness.

## Loopback-only proxy rehearsal

Use exactly:

- Node: `127.0.0.1:3100`;
- Caddy HTTP: `127.0.0.1:8080`;
- Caddy HTTPS: `127.0.0.1:8443`;
- Caddy admin API: `127.0.0.1:2019`.

Requirements:

- No wildcard, public-IP or `0.0.0.0` listener.
- Node never listens publicly.
- Use only a local/internal rehearsal certificate.
- Do not permanently trust the local CA machine-wide; supply it explicitly to test clients.
- Verify local HTTP-to-HTTPS redirect, configuration reload and certificate reissue/reload.
- Do not claim public ACME issuance/renewal.
- Treat production DNS/certificate issuance/renewal as launch blockers.
- Replace forwarded headers safely.
- Apply and test bounded request/header limits and timeouts.
- Reject an oversized request.
- Prove Next.js streaming is not buffered.
- Redact sensitive query/header values in proxy access logs.

## Windows services and least privilege

Approved services and identities:

| Service | Identity | Supervisor |
|---|---|---|
| `RisePalsApp` | `NT SERVICE\RisePalsApp` | WinSW `2.12.0` stable |
| `RisePalsProxy` | `NT SERVICE\RisePalsProxy` | SCM/Caddy official Windows guidance |

Requirements:

1. Use passwordless virtual service accounts.
2. Never run as Administrator, LocalSystem, NetworkService or Jeff's account.
3. Caddy may use SCM; WinSW supervises Node only.
4. Services are independently restartable.
5. Bound restart-on-failure and prove no unlimited loop.
6. Stop/start leaves no orphan Node, WinSW or Caddy process.
7. Test in-flight behavior and graceful stop.
8. If stable WinSW cannot satisfy the contract, disable/remove the failed service and stop for a decision.
9. Grant exact filesystem rights only:
   - app reads current release and non-secret config, reads its authorized rehearsal secret, writes app logs/cache;
   - proxy reads Caddy config/certificate state, writes proxy logs/certificate working state and cannot read app secrets.
10. Neither identity may modify Git or immutable releases.
11. Do not take ownership or grant broad recursive Administrator access.

## Synthetic-secret rehearsal

Use one generated synthetic canary only. Never print it. Prove storage outside Git/releases, restrictive ACLs, app read, proxy denial, rotation, reload/restart, revocation, deletion and final absence. Scan Git, logs, service definitions and process arguments for exposure. Leave only non-secret templates.

## Release and rollback rehearsal

1. Create at least two reviewed rehearsal releases.
2. Switch `C:\RisePals\current` atomically.
3. Verify service health after switching.
4. Exercise a successful forward switch, failed candidate health, automatic rollback and manual rollback.
5. A failed deployment must not receive traffic.
6. Preserve redacted release/deployment logs.
7. Retain last-known-good.
8. Never deploy from an uncommitted tree.

## Database and recovery boundary

- No production database or production connection.
- Use only the pinned disposable PostgreSQL 18.4 harness on loopback.
- Rehearse separate migration/application roles and disposable TLS with an explicit local CA where supported.
- Delete disposable clusters, certificates, processes and credentials afterward.
- Re-run migration, RLS, export, erasure, backup and restore gates.
- Do not claim off-host backup readiness.
- If no Jeff-approved encrypted off-host target exists, record it as an exact launch blocker without creating an account/provider.

## Firewall boundary

Only inventory and repository-local rule templates are authorized. Do not enable a public rule, change RDP/unrelated rules or create a public Node/PostgreSQL rule. Prove all rehearsal listeners are loopback-only. Prepare disabled/reviewable future proxy-only 80/443 templates. Record that an external port scan is required before launch.

## Monitoring and operational evidence

Implement only local/provider-neutral evidence: bounded rotated JSON/file logs, service state/failure evidence, health scripts, redacted deployment/inventory logs, manual monitoring/incident commands and a backup/restore decision record. Do not create external monitoring, alerting, scheduled production tasks or staff accounts.

## Controlled reboot checkpoint

This authorization alone does not permit reboot.

After all other gates pass:

1. Return a Decision Request asking Jeff through Project Codex for one controlled reboot.
2. State affected services, expected downtime, rollback/recovery commands and proof that VS Code/Git work is saved and clean.
3. Reboot only after explicit confirmation.
4. Verify automatic recovery after reboot.
5. End with both Rise Pals services stopped and startup type Disabled.

If confirmation is not received, status is Partial and reboot recovery is the only incomplete gate.

## Required repository artifacts

Add/update at minimum:

- this prompt;
- `PROJECT_STATUS.md`;
- `README.md`;
- `docs/07_TECHNICAL_ARCHITECTURE.md`;
- `docs/09_ENGINEERING_PLAN.md`;
- `docs/10_LOCAL_DEVELOPMENT.md`;
- `docs/DECISION_LOG.md`;
- a sanitized Windows VPS readiness/runbook;
- versioned Caddy and WinSW/application-service templates;
- deployment, health, rollback and cleanup scripts;
- deterministic release-manifest tooling;
- bounded tests for configuration and scripts.

PowerShell must use strict error handling, pass AST parsing, use validated `LiteralPath` operations, avoid shell-built destructive paths, be non-interactive where practical, provide `-WhatIf` or equivalent for mutations, fail closed on unexpected services/ACLs/ports/directories and never display secrets.

## Required verification

Run and report actual results for:

- `npm ci` and install-script policy;
- format, lint, strict typecheck, unit/component tests, production build and `npm run check`;
- normal and alpha Chromium E2E;
- disposable PostgreSQL and recovery suites;
- focused infrastructure/release/rollback tests;
- production and full npm audits;
- strict UTF-8/no BOM, Markdown fences, unresolved markers and `git diff --check`;
- PowerShell AST parsing;
- client/server boundary inspection;
- publication/scoring digest preservation;
- Gitleaks worktree, exact staged, proposed-history and pushed-history scopes;
- exact service identity/ACL and loopback-listener evidence;
- proxy redirect/TLS/reload/limit/streaming evidence;
- release switch/rollback and cleanup evidence.

## Final state

Unless reboot approval remains outstanding:

- `RisePalsApp` and `RisePalsProxy` installed, Stopped and Disabled;
- no Rise Pals public listener or new enabled public firewall rule;
- no DNS change or production certificate;
- no real credential, production database or real user/data;
- no disposable PostgreSQL or orphan Node/Caddy/WinSW/Playwright/rehearsal process;
- all temporary canary material removed;
- reviewed release artifacts and pinned tools may remain under `C:\RisePals`;
- `current` may target the last-known-good release;
- clean worktree and an Open Draft PR.

## Stop conditions

Return Decision required if there is a conflicting service/listener/path; unverifiable provenance; inability to use virtual service accounts; unsatisfactory restart/stop/orphan behavior; need for Administrator/LocalSystem runtime or broad ACLs; required public exposure, real credentials/resources, irreversible host mutation, architecture substitution, external cost/account decision or another unapproved expansion.

Return Complete pending Project Codex review only after all authorized non-reboot gates and the separately authorized reboot gate pass. Return Partial when the bounded implementation is sound but reboot confirmation or another explicit external blocker remains.

Use `prompts/VS_CODE_HANDOFF_TEMPLATE.md`. Report exact commits/trees/files, host paths/services, official URLs/lengths/SHA-256, executed commands/results, listeners/firewall, ACL identities, release/rollback, cleanup counts, launch blockers and Draft PR URL. Confirm RP-TURN-020 and public deployment were not started.

## RP-TURN-019-R1 amendment — WinSW local drain and graceful-stop correction

Project Codex authorized retaining WinSW 2.12.0 and implementing an ACL-restricted local drain through its supported stop hook. The bounded contract requires atomic/idempotent `Ready → Draining → Stopped`, a maximum 15-second drain deadline inside the 20-second service stop path, fixed 503/`Retry-After` for new work, preservation of already accepted work, stale-state reconciliation, fail-closed timeout/error behavior, no HTTP control surface/token/secret and no proxy access to control state. Direct SCM Stop, repeated stop, full three-chunk completion, new-work rejection, restart/crash bounds and persistent-failure terminal state require one live proof before reboot can be requested.

Implementation commit `ce13499ac4f879603eb8f1214b4a7129fba5004c` passed the deterministic repository gates. Its one authorized live sequence installed the reviewed XML and exact control ACL, verified the prior release manifest and then stopped before service startup because the external elevated output-capture wrapper promoted Caddy informational stderr to a terminating PowerShell error. The sequence was not repeated. Cleanup left both services Stopped/Disabled with zero process/listener/firewall/staging/rehearsal/canary/drain-state residue. Status is Decision required for a separately authorized non-reboot host run; this is not a reboot request or an acceptance claim.

## RP-TURN-019-R4 amendment — repository-only candidate rehearsal harness

Project Codex authorized a deterministic harness around the accepted R3-R1 service host without authorizing its mutating/elevated path. The harness must retain exact candidate service `RisePalsServiceHostCandidate`, virtual account `NT SERVICE\RisePalsServiceHostCandidate`, dedicated Own Process/Manual configuration and the accepted unsigned executable/schema/dependency-manifest pins. Existing `RisePalsApp` and `RisePalsProxy` remain retained Stopped/Disabled and cannot be overwritten or repurposed.

The repository contract must derive and verify the candidate service SID; use nonce-scoped paths under exact staging/rehearsal/log roots; reject path escape, reparse, collision, unexpected service/process/listener/path/ACL and pin mismatch; and grant only SYSTEM, Administrators and the candidate identity exact FullControl/ReadAndExecute/Modify rights by path class. A reviewed per-service Preshutdown timeout must exceed the complete drain-plus-exit bound with a visible margin. Global `ServicesPipeTimeout`, public listeners and public firewall/DNS/certificate behavior remain prohibited.

R4-R1 additionally pins the exact signed Node v24.18.1 executable and the complete retained `RisePalsApp`/`RisePalsProxy` commands, accounts, Own Process types, executable bytes and Stopped/Disabled/PID 0 states. Preflight must reject substring path spoofs, changed arguments/account/type/bytes, shared PIDs and missing/additional retained services; final proof compares the complete accepted snapshot. After staging, Node length/SHA-256/Valid signature/signer must still match.

The parent/child launcher must bind nonce, exact head, launcher-script SHA-256, UTC freshness, explicit native exit code, single-use structured result and canonical digest. The parent cannot capture or parse native output; the child keeps stdout and stderr separate, treats informational stderr as non-authoritative, deletes raw captures unread and exposes only controlled structured evidence. PowerShell 5.1 AST compatibility is mandatory.

The future sequence is encoded as 23 bounded stages covering candidate staging/install, loopback start/readiness, first-byte-synchronized three-chunk work, direct/repeated Stop, post-drain fixed 503/`Retry-After`, Stop checkpoint progress, read-only Preshutdown registration, graceful zero-Job exit, timeout cleanup/classification, bounded crash restart, persistent terminal failure, retained-proxy state preservation, process ownership and exact cleanup/final proof. No non-reboot script may send control 15 or claim system-delivered Preshutdown: it may query only the exact timeout and `SERVICE_ACCEPT_PRESHUTDOWN` while Running, with handler/shared-orchestration behavior supported by accepted repository tests. Actual delivery requires a separately authorized controlled reboot after non-reboot acceptance. `RisePalsProxy` must remain Stopped/Disabled/PID 0 and must never be enabled, started or restarted; independence is proven only by unchanged complete snapshots, no candidate dependency and direct loopback. Every stage has one fixed sanitized failure code. Cleanup first proves Stopped/Disabled/PID 0 and Job emptiness and then removes only task-created candidate service/config/log/staging/canary/evidence objects; uncertain, reparse or unexpectedly nonempty paths fail closed.

Repository tests must cover deterministic WhatIf/plan mode with zero host mutation, every preflight rejection, structured-result success/nonzero/stderr/malformed/stale/replay/partial behavior, cleanup containment/idempotency, failure at every modeled stage, PowerShell 5.1 AST and preservation of the accepted R3-R1 identity/startup-cleanup/evidence boundaries. They must prove that no live/elevated/service-control path is reached. A live attempt requires a separate exact-head Project Codex authorization after independent R4 review. R4 cannot request UAC, mutate a service or `C:\RisePals`, download/install tooling, reboot, change firewall/DNS/certificates, merge PR #17 or begin RP-TURN-020.

## RP-TURN-019-R4-DIAG1 amendment — elevated bootstrap and result transport

After LIVE3 returned exit code 1 without parent-validatable structured evidence and Recovery2 restored the Accepted zero-residue host state, Project Codex authorized a repository-only correction of the unobservable elevated-startup class. The exact historic cause must remain unknown because the old child could fail during typed parameter binding, elevated `%TEMP%`-relative path resolution, helper loading, ACL work or result initialization before any marker.

The corrected non-elevated parent pre-creates and validates one explicit non-reparse transient root and nonce directory with only the current account, SYSTEM and Administrators. A self-contained PowerShell 5.1 bootstrap accepts primitive strings only, validates authorization ID, nonce, expected HEAD and committed launcher/bootstrap/transport/child SHA-256 values using `SHA256.Create().ComputeHash(...)`, and atomically writes `bootstrap-started` before full-child dispatch. R1 supersedes the original premature child marker: the bootstrap writes `child-launch-attempted` immediately before process creation, while the child itself writes `child-started` and then `live-started`. A top-level fixed bootstrap-failure marker and deterministic parent classifications distinguish UAC/launch, never-entered, bootstrap-only, launch-attempted/no-child, child-pre-live, live-without-final, valid-final and invalid/inconsistent evidence.

The parent accepts only exact non-linked marker paths inside the explicit root and validates schema/property set, nonce, authorization ID, HEAD, script hashes, UTC order/freshness, digest, replay and final/exit agreement. Missing or invalid evidence never implies service, stream, drain, restart or cleanup success. At least 24 non-elevated simulations cover every authorized cancellation, launch, marker, malformed, stale, replay, reparse/outside-root, atomic-interruption, no-raw-output and cleanup case. DIAG1 authorizes no UAC, Live mode, service/process/`C:\RisePals` mutation, reboot, public change, merge or RP-TURN-020 work. Another host attempt requires a separate authorization naming the exact reviewed DIAG1 head.

## RP-TURN-019-R4-DIAG1-R1 amendment — durable parent evidence and truthful child start

Project Codex requires one authenticated parent result to remain reviewable after launcher exit. Simulation and Live callers must supply an explicit evidence directory separate from the transient invocation tree. Simulation uses a fresh task-scoped temporary directory; future Live mode accepts only a strict descendant of `C:\Users\Administrator\Documents\Codex`. The parent rejects linked/escaped directories, unexpected ACL principals and existing or interrupted result paths.

The schema-v2 parent result contains authorization ID, nonce, HEAD, launcher/bootstrap/transport/child hashes, elevated launch disposition and exit code, validated bootstrap/launch-attempt/child/live/final states, final classification, exact UTC and a canonical SHA-256 digest. It is written atomically, reopened from the exact evidence directory and independently validated before any transient marker or raw capture may be removed. Persistence or validation failure remains fail-closed, leaves transient cleanup unclaimed and never relies on stdout; stdout may expose only the sanitized result path, digest, classification and cleanup disposition.

The bootstrap owns `bootstrap-started` and `child-launch-attempted` only. The committed child owns `child-started`, written as early as safely possible in its process boundary, and later owns `live-started`. Marker provenance, predecessor order and timestamp coherence are mandatory. Repository-only simulations must distinguish bootstrap-without-attempt, attempted-without-child, child-without-live and live-without-final, and must cover durable reopen, replay, ACL/path/link rejection, interrupted export, no-stdout dependency and exact cleanup. This amendment changes no candidate service-host behavior and authorizes no UAC, Live mode, host mutation, merge or RP-TURN-020 work.
