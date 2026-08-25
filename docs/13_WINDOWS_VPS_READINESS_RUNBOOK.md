# Windows VPS Infrastructure Readiness Runbook

**Turn:** RP-TURN-019  
**Host:** confirmed Windows Server 2022 application target  
**Boundary:** non-public infrastructure rehearsal only  
**Last updated:** 2026-08-24

## Authorization boundary

This runbook prepares a loopback-only application host. It does not authorize DNS, public IP exposure, enabled inbound 80/443, public ACME, real users/data, production Clerk/PostgreSQL/secrets, external monitoring, off-host backup procurement, CI or deployment.

Never read or copy `.env.local`. Release builds come from a clean `git archive` of an exact commit, so ignored development files cannot enter build input or release inventory.

## Read-only host baseline

The pre-mutation inventory found:

- Microsoft Windows Server 2022 Datacenter, 64-bit, build 20348;
- approximately 8 GiB RAM and more than 100 GiB free on `C:` at inspection time;
- no pending Component Based Servicing, Windows Update or pending-file-rename reboot;
- IIS/Web-Server, ARR, Hyper-V, Containers and WSL roles not installed/active for this design;
- no Caddy, WinSW, IIS, ARR or conflicting Rise Pals wrapper/service;
- no listener on 80, 443, 2019, 3100, 8080 or 8443;
- Windows Firewall enabled on every profile and no Rise Pals rule;
- no `C:\RisePals` path;
- no automatic-certificate service or conflicting application process;
- the inspection session was not elevated and performed no host mutation.

Public addresses, machine identity, account SIDs, certificate subjects and unrelated infrastructure are deliberately excluded from repository evidence.

## Verified runtime provenance

The canonical machine-readable record is [`infra/windows/tool-manifest.json`](../infra/windows/tool-manifest.json).

| Tool | Official source | Bytes | SHA-256 | Additional verification |
|---|---|---:|---|---|
| Node.js 24.18.1 x64 ZIP | `https://nodejs.org/dist/v24.18.1/node-v24.18.1-win-x64.zip` | 37,177,316 | `ec56b84a7551893ab2324ebdfdc4ab974a63b4781162600b68a1293cc3e53765` | exact official `SHASUMS256.txt`; extracted `node.exe` reports `v24.18.1` and has a valid OpenJS Foundation Authenticode signature |
| Caddy 2.11.4 standard Windows amd64 ZIP | `https://github.com/caddyserver/caddy/releases/download/v2.11.4/caddy_2.11.4_windows_amd64.zip` | 17,559,418 | `1708333f79e274c7697285afe6d592ab39314e0b131e9ec6bea08ad27df62ebf` | exact GitHub asset digest; official SHA-512 `cd5ccfd86a4b40732cf715890d0dca5bf3f63adefec5a7914de85adf240c60ce7e5d2791631b88ef9758e46b23bb1730e020b9c5d696889740b284ffd4788e35`; Fulcio/Rekor verification for exact `release.yml@refs/tags/v2.11.4`; binary reports `v2.11.4` |
| WinSW 2.12.0 x64 | `https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe` | 18,243,033 | `05b82d46ad331cc16bdc00de5c6332c1ef818df8ceefcd49c726553209b3a0da` | official release asset and commit `eef5bade59fca0254e387ac73ed7625ba6aa7147`; file metadata reports `2.12.0+eef5bad...` |

Caddy and WinSW are not Authenticode-signed. Caddy compensates with the verified official checksum and Sigstore chain. WinSW 2.12.0's release supplies neither a checksum artifact nor Authenticode signature; the recorded SHA-256 was computed from the exact TLS-delivered official GitHub release asset whose byte length and build commit matched official metadata. This limitation remains visible and must be reconsidered at any version change.

The Sigstore verifier used for the Caddy check was temporary, came from the official `sigstore/cosign` v3.1.3 GitHub release and matched that release asset's published length `198,819,314` and SHA-256 `9fe59be0eca1271873ce019061335eb1ac419b7059202e797828467ddabe33be`. It is not installed under `C:\RisePals`.

## Approved host layout

```text
C:\RisePals\
  tools\
    node\24.18.1\
    caddy\2.11.4\
    winsw\2.12.0\
  staging\
  releases\<release-id>\
  current\                       atomic junction to one reviewed release
  shared\
    config\
    secrets\
    cache\
  logs\
    app\
    proxy\
    deploy\
  rehearsal\
```

The development workspace remains `C:\Codex PC SG2\Jeff\risepals` and is never served. Releases contain standalone application bytes plus a deterministic manifest. `.next\cache` alone is an explicit junction to shared writable cache. Secrets, configuration and logs are outside releases.

## Repository artifacts

- Caddy: `infra/windows/caddy/Caddyfile`
- WinSW: `infra/windows/winsw/RisePalsApp.xml`
- future disabled firewall template: `infra/windows/firewall/future-public-proxy-rules.json`
- path/ACL helpers and host inventory: `scripts/infra/common.ps1`, `Get-RisePalsHostInventory.ps1`
- layout/tool/service setup: `Initialize-RisePalsHost.ps1`, `Install-RisePalsTools.ps1`, `Install-RisePalsServices.ps1`
- clean-tree packaging and release manifest: `New-RisePalsRelease.ps1`, `release-manifest.mjs`
- activation/rollback: `Switch-RisePalsRelease.ps1`, `Rollback-RisePalsRelease.ps1`
- secret lifecycle: `Set-RisePalsRehearsalSecret.ps1`
- start/health/cleanup: `Start-RisePalsRehearsal.ps1`, `Test-RisePalsHealth.ps1`, `Clear-RisePalsRehearsal.ps1`
- one-command non-reboot rehearsal: `Invoke-RisePalsNonRebootRehearsal.ps1`
- bounded non-listening app-identity diagnosis: `Invoke-RisePalsReadinessDiagnostic.ps1`
- separately authorized reboot preparation/completion: `Prepare-RisePalsRebootCheckpoint.ps1`, `Complete-RisePalsRebootCheckpoint.ps1`
- sanitized host-change evidence: `Write-RisePalsHostManifest.ps1`

Every mutating PowerShell entry point supports `-WhatIf`, uses strict error handling, resolves the exact approved root and validates child paths before recursive removal.

## Service and ACL model

| Service | Runtime identity | Startup during rehearsal | Final startup |
|---|---|---|---|
| `RisePalsApp` | `NT SERVICE\RisePalsApp` | Manual | Disabled |
| `RisePalsProxy` | `NT SERVICE\RisePalsProxy` | Manual | Disabled |

The app can read Node/WinSW/current release/config and only the temporary rehearsal canary; it can modify only its app log and shared Next cache. The proxy can read Caddy/config and modify only proxy log/Caddy certificate state. The protected secret-directory DACL grants the app only non-inheriting `Traverse`, not listing/read, while the synthetic canary file separately grants app `Read`; the proxy has neither rule. Neither service runs as Administrator, LocalSystem, NetworkService or Jeff's interactive account.

WinSW has `autoRefresh=false`, bounded roll-by-size logs, two restart attempts followed by `none` and a one-hour failure reset. Caddy uses SCM with a matching bounded restart sequence. Service paths must remain beneath `C:\RisePals`; an unexpected existing service fails closed.

## Network boundary

| Listener | Address |
|---|---|
| Next standalone | `127.0.0.1:3100` |
| Caddy rehearsal redirect | `127.0.0.1:8080` |
| Caddy rehearsal HTTPS | `127.0.0.1:8443` |
| Caddy admin API | `127.0.0.1:2019` |

Caddy replaces incoming forwarded headers, caps headers at 32 KB and request bodies at 1 MB, uses bounded timeouts, disables response buffering for the streaming probe and removes credential headers plus selected sensitive query values from access logs. `/health/ready` is blocked at the proxy. The certificate is Caddy's local internal rehearsal certificate; clients pass its CA explicitly. Do not add it to a permanent machine-wide trust store.

No firewall mutation is part of the rehearsal. The future rule template remains disabled and proxy-only. Before any later launch, an externally executed scan must prove that only separately approved ports are reachable.

## Safe command sequence

Run the initial validation without elevation:

```powershell
npm run infra:test
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\infra\Get-RisePalsHostInventory.ps1
```

Use an elevated Windows PowerShell process only for the approved host mutations:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\infra\Invoke-RisePalsHostSetup.ps1
# Or run the four bounded components individually:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\infra\Initialize-RisePalsHost.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\infra\Install-RisePalsTools.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\infra\Install-RisePalsServices.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\infra\Set-RisePalsRehearsalSecret.ps1 -Action Create
```

All four commands accept `-WhatIf` for a bounded preview.

Build a reviewed release only after committing and returning to a clean worktree:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\infra\New-RisePalsRelease.ps1 -ReleaseId <reviewed-id>
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\infra\Switch-RisePalsRelease.ps1 -ReleaseId <reviewed-id> -SkipHealthCheck
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\infra\Start-RisePalsRehearsal.ps1
```

`New-RisePalsRelease.ps1` builds from `git archive` in an isolated staging child. It refuses a dirty worktree, excludes ignored `.env.local` by construction, performs `npm ci` and a secret-free production build, generates hashes, moves the candidate to immutable releases and creates only the approved cache junction.

For the one bounded automatic-rollback negative test, `-RehearsalDenyManifestRead` creates a separately identified release whose manifest bytes remain intact but whose final DACL deliberately denies the app service's readiness dependency. The service can start, readiness fails closed, the switch restores the previous junction and restarts the last-known-good release. This parameter is rehearsal-only and is not a production deployment mode.

Use the same switch primitive for a reviewed manual rollback:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\infra\Rollback-RisePalsRelease.ps1 -LastKnownGoodReleaseId <reviewed-id>
```

A switch with health checking automatically restores the prior junction on failure. Never delete the last-known-good release.

After host setup and service-identity repair pass, run every authorized non-reboot host mutation and cleanup through one elevated command from a clean committed feature branch:

```powershell
& "C:\Codex PC SG2\Jeff\risepals\scripts\infra\Invoke-RisePalsNonRebootRehearsal.ps1" -RepositoryRoot "C:\Codex PC SG2\Jeff\risepals" -Confirm:$false
```

The orchestrator creates three exact-commit releases, performs forward/failed/manual switching, exercises ACL and canary boundaries, proxy TLS/reload/limits/streaming, independent restarts, graceful stop and bounded crash recovery, then always stops/disables both services and removes the canary. An interrupted rerun may reuse a deterministic release only after its canonical manifest identity and complete file inventory are independently regenerated and matched; a modified or ambiguous release fails closed. A separately supplied prior source commit must be a committed ancestor of the current clean feature head, allowing an already verified interrupted release trio to resume without unnecessary rebuilds after an infrastructure-script-only correction. A stopped/disabled `current` junction from a prior bounded run may be replaced only after its complete manifest verifies, its release ID matches its target and its source commit is an ancestor of the current feature head; an invalid or unrelated target stops the run before staging. Abandoned exact `staging\build-<GUID>` children are removed only while both services and every pinned-root process are stopped, and recursive cleanup deletes reparse points themselves without traversing their targets. The script writes only sanitized booleans/counts to `C:\RisePals\logs\deploy\non-reboot-rehearsal.json`.

## Health and failure evidence

- `/health/live` returns only `{"status":"ok"}`.
- direct-loopback `/health/ready` returns only `ready`/`unavailable` and requires rehearsal mode, release manifest and readable 64-byte synthetic canary. Next standalone may normalize the loopback socket into one exact loopback `x-forwarded-for` value; only `127.0.0.1`, `::1` or mapped `::ffff:127.0.0.1` is accepted, while chains/non-loopback values fail closed and Caddy still blocks the route with 404.
- `/health/stream` is 404 unless rehearsal mode is exact; in rehearsal it emits three fixed chunks and validates forwarded-header replacement. Its proxy boundary accepts only the fixed loopback source/protocol and either the direct loopback host or Caddy's exact `127.0.0.1:8443` host normalization; any other host or port fails closed.
- proxy readiness is 404.
- health tooling uses pinned Node 24 with the explicit Caddy local CA (never an insecure TLS bypass) to verify HTTPS status/body, 413 oversized body and unbuffered streaming; it also verifies redirect, admin reload and exact loopback listeners. This avoids depending on the host's legacy Windows curl TLS backend. Caddy's documented anti-spoof behavior ignores incoming `X-Forwarded-*` values, while the reviewed configuration explicitly overwrites the three upstream values without a wildcard operation that could delete the replacements.
- stop/restart checks must prove no orphan tool process or listener.
- three consecutive unexpected failures must exhaust the bounded restart plan instead of looping indefinitely.

## Synthetic secret lifecycle

The canary is random, exactly 64 bytes and never printed. It exists only at `C:\RisePals\shared\secrets\rehearsal.canary`, outside Git/releases. Exercise Create, app readiness, proxy DACL denial, Rotate, Revoke and Delete. Scan repository, service definitions, process commands and logs for leakage. Final cleanup requires the file and temporary variants to be absent.

## Database and recovery

Only the accepted disposable PostgreSQL 18.4 harness is allowed. It remains loopback-only, uses separate migration/application roles and removes child databases, credentials, logs and processes. Re-run:

```powershell
npm run db:test:disposable
npm run db:test:recovery
npm run db:test:tls:disposable
```

The TLS-only disposable rehearsal uses PostgreSQL 18.4 on loopback, an ephemeral local CA supplied explicitly with `verify-full`, and separate synthetic owner/application roles. It removes the cluster, certificates, private keys and credentials afterward. The accepted full integration and recovery harnesses continue to use their existing isolated loopback transport; production database TLS and placement remain undecided.

No off-host encrypted backup target is approved. GitHub, another VPS directory and the disposable rehearsal are not backups. Off-host ownership, encryption, retention, deletion reconciliation, alerts, RTO/RPO and restore authority remain launch blockers.

## Cleanup and incident commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\infra\Clear-RisePalsRehearsal.ps1
Get-Service RisePalsApp,RisePalsProxy
Get-NetTCPConnection -State Listen | Where-Object LocalPort -in 2019,3100,8080,8443
sc.exe qfailure RisePalsApp
sc.exe qfailure RisePalsProxy
```

Cleanup stops and disables both services, deletes the canary and validated rehearsal children, then fails if a Rise Pals process/listener remains. It deliberately retains verified tools, reviewed releases, `current`, non-secret configuration and bounded logs.

## Reboot checkpoint and remaining launch blockers

This turn cannot reboot without a later explicit Jeff confirmation through Project Codex. After every non-reboot gate passes, the handoff must request one controlled reboot with exact affected services, downtime and recovery commands. Only after confirmation may automatic service recovery be tested. The final state is both services Stopped and Disabled.

The versioned checkpoint scripts do not reboot the host themselves. After separate authorization, preparation requires the exact approved source commit, creates one temporary canary, starts only the two loopback services as Automatic and writes a sanitized checkpoint. Completion proves Windows booted after that checkpoint, verifies automatic recovery and local health, and restores the Stopped/Disabled/no-canary final state.

Even a successful reboot rehearsal does not approve public deployment. Remaining blockers include DNS and public certificate lifecycle, external port scan, production identity/database/privacy/legal/data residency, production secrets, off-host backup/RTO/RPO, monitoring/alert ownership, staff/operator access, CI/deployment transport and a separately reviewed launch decision.
