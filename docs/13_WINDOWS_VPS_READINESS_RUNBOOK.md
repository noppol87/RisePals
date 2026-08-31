# Windows VPS Infrastructure Readiness Runbook

**Turn:** RP-TURN-019  
**Host:** confirmed Windows Server 2022 application target  
**Boundary:** non-public infrastructure rehearsal only  
**Last updated:** 2026-08-28; R2 supervision decision required after Accepted recovery and residue cleanup

## Authorization boundary

This runbook prepares a loopback-only application host. It does not authorize DNS, public IP exposure, enabled inbound 80/443, public ACME, real users/data, production Clerk/PostgreSQL/secrets, external monitoring, off-host backup procurement, CI or deployment.

The current WinSW supervision path is rejected pending a new Project Codex/Jeff decision. Do not execute another WinSW rehearsal, host setup, service install/start/stop/change, cleanup or reboot from this runbook. The commands retained below are historical operating evidence, not current authorization.

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
    control\                      protected local drain lifecycle only
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
- local drain/control: `drain-control.mjs`, `Get-RisePalsDrainAclSnapshot.ps1`, `rise-pals-standalone-server.mjs`, `request-rise-pals-drain.mjs`, `Update-RisePalsDrainControl.ps1`
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

The app can read Node/WinSW/current release/config and only the temporary rehearsal canary; it can modify its app log, shared Next cache and exact protected drain-control directory. `shared\control` has a protected DACL containing only Administrators, SYSTEM and `NT SERVICE\RisePalsApp`; the proxy receives no access. ACL validation uses canonical SIDs and numeric bitmasks rather than localized display text. The exact parent rules are explicit OI/CI Allow FullControl (`2032127`) for SYSTEM and Administrators plus explicit OI/CI Allow Modify|Synchronize (`1245631`) for the app. A state/temp child may be unprotected only when it is a direct same-volume child, all three rules are inherited from that exact protected parent with the same rights and no explicit, deny, unresolved or additional rule exists. Bare Modify (`197055`), app FullControl and every superset bit are rejected. The proxy can read Caddy/config and modify only proxy log/Caddy certificate state. The protected secret-directory DACL grants the app only non-inheriting `Traverse`, not listing/read, while the synthetic canary file separately grants app `Read`; the proxy has neither rule. Neither service runs as Administrator, LocalSystem, NetworkService or Jeff's interactive account.

WinSW has `autoRefresh=false`, bounded roll-by-size logs, two restart attempts followed by `none` and a one-hour failure reset. The reviewed R1 application XML starts pinned Node with `C:\RisePals\current\rise-pals-standalone-server.mjs` and uses pinned Node as `stopexecutable` with `C:\RisePals\current\request-rise-pals-drain.mjs` as `stoparguments`; `stoptimeout` remains 20 seconds. The local helper validates its strict state schema, creates a collision-resistant exclusive temp file inside the same control directory, flushes and closes it, validates its effective ACL, atomically renames it and validates the final ACL. Every failure removes only the exact remaining temp file. It requests one 15-second `Ready → Draining → Stopped` lifecycle and repeated requests preserve the original deadline. New work receives fixed 503 plus `Retry-After: 5`, accepted work remains tracked, and timeout/error cannot be reported as graceful success. No HTTP administration route, credential or secret is used. Caddy uses SCM with a matching bounded restart sequence. Service paths must remain beneath `C:\RisePals`; an unexpected existing service fails closed.

## Network boundary

| Listener | Address |
|---|---|
| Next standalone | `127.0.0.1:3100` |
| Caddy rehearsal redirect | `127.0.0.1:8080` |
| Caddy rehearsal HTTPS | `127.0.0.1:8443` |
| Caddy admin API | `127.0.0.1:2019` |

Both proxy site blocks use explicit `bind 127.0.0.1`; a host label in a Caddy site address is a request matcher and does not itself restrict the socket interface. IPv4 or IPv6 wildcard listeners fail the readiness gate.

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

Historical R1 procedure only—do not run without a new exact authorization. The former non-reboot host sequence used one elevated command from a clean committed feature branch:

```powershell
& "C:\Codex PC SG2\Jeff\risepals\scripts\infra\Invoke-RisePalsNonRebootRehearsal.ps1" -RepositoryRoot "C:\Codex PC SG2\Jeff\risepals" -Confirm:$false
```

The orchestrator creates three exact-commit releases, performs forward/failed/manual switching, exercises ACL and canary boundaries, proxy TLS/reload/limits/streaming, independent restarts, graceful stop and bounded crash recovery, then always stops/disables both services and removes the canary. An interrupted rerun may reuse a deterministic release only after its canonical manifest identity and complete file inventory are independently regenerated and matched; a modified or ambiguous release fails closed. A separately supplied prior source commit must be a committed ancestor of the current clean feature head, allowing an already verified interrupted release trio to resume without unnecessary rebuilds after an infrastructure-script-only correction. A stopped/disabled `current` junction from a prior bounded run may be replaced only after its complete manifest verifies, its release ID matches its target and its source commit is an ancestor of the current feature head; an invalid or unrelated target stops the run before staging. Abandoned exact `staging\build-<GUID>` children are removed only while both services and every pinned-root process are stopped, and recursive cleanup deletes reparse points themselves without traversing their targets. The script writes only sanitized booleans/counts to `C:\RisePals\logs\deploy\non-reboot-rehearsal.json`.

### Current RP-TURN-019-R1B Phase 2D disposition

The original 2026-08-26 bounded run passed manifest reuse, exact loopback proxy/TLS/limits/streaming, independent restart, canary boundaries, forward switch, failed-candidate 503/automatic rollback, manual rollback and local-certificate reissue. Its first-byte-synchronized probe then showed default WinSW 2.12.0 stop cut the stream. Project Codex authorized the local R1 drain above without changing supervisor or weakening the assertion.

R1 repository verification passed at `ce13499ac4f879603eb8f1214b4a7129fba5004c`, but its first live sequence did not reach service startup. A later authorized sequence reached drain-state creation and left one valid `stopped` file after a principal-only checker incorrectly required a protected child and compared Windows' `Modify, Synchronize` representation against bare Modify. Phase 1C proved the child inherited only the exact three approved Allow ACEs from the protected parent, with no explicit, deny, unresolved or additional rule; Project Codex accepted this as a checker false negative rather than an ACL expansion.

Phase 2D revalidated the exact 190-byte file, accepted SHA-256, schema/state and effective ACL before deleting only that file. The parent directory remained present and its owner, protected flag, SDDL and ACE set were unchanged. The repository correction now reads ACLs as SID plus numeric bitmask evidence, accepts the approved inherited-child model, rejects every incomplete or broader app mask and validates both atomic temp and final files. Cleanup removes exact drain state, lock and recognized atomic-temp names after stopping/disabling services, and final evidence counts ports 80/443/2019/3100/8080/8443 plus process, staging, rehearsal, canary and drain residue.

Phase 2D repository gates passed: 34 focused ACL/infrastructure tests, 47 files/445 complete tests, 83 normal plus 6 alpha Chromium tests, the 27-route secret-free build, disposable PostgreSQL integration/recovery, both zero-vulnerability audits, unchanged publication/scoring digests and all required Gitleaks scopes. The exact 13-file correction was committed and pushed at `ed2b8046d10bf5be26fe3ce35c77705630691e2c`, tree `8fe0e03de77872b7532fa66a9b8b087a801363d2`, from a clean branch while main remained unchanged.

The single final elevated rehearsal entered at that exact clean head and passed the disabled virtual-service identity precondition plus canonical drain-control update. It then stopped at the side-effect-isolated Caddy configuration gate before service startup: external `*>&1` diagnostic capture caused Caddy's informational stderr to be surfaced as terminating PowerShell `NativeCommandError`. The attempt was not rerun and no speculative host or repository correction was made. Consequently there is no new direct Stop-Service stream, controlled 503, graceful-versus-forced termination or bounded crash/restart evidence from this attempt. Sanitized evidence records `completed=false`, `serviceIdentity=true` and every subsequent live-gate boolean false. Its final cleanup records Stopped/Disabled services and zero pinned-root processes, approved-port listeners, enabled Rise Pals firewall rules, staging/rehearsal children, drain state, atomic temporary files, drain locks and synthetic canaries. A controlled reboot cannot be requested; Project Codex must decide any next bounded authorization.

### R1C versioned elevated-rehearsal boundary

R1C replaces external ad hoc elevation/capture with `Invoke-RisePalsElevatedRehearsal.ps1` and `Invoke-RisePalsElevatedRehearsalChild.ps1`. The non-elevated parent requires the exact repository, feature branch, requested commit and clean worktree. It creates a fresh UUID nonce beneath the exact temporary evidence root, launches Windows PowerShell 5.1 with structured arguments, waits and validates only the child process ExitCode plus `rise-pals-elevated-rehearsal-result-v1`. `-Verb RunAs` exists only on the future Live branch. The parent has no stdout/stderr redirection, pipe, merge, tee or console parsing around that child.

The child protects the exact nonce directory for the current identity, SYSTEM and Administrators before creating captures. It launches the fixture or live rehearsal as a separate process with exact FilePath and ArgumentList plus separate `native.stdout.log` and `native.stderr.log`, treats stderr as data rather than status and uses only ExitCode for native success. Raw streams never enter the result. After exact capture cleanup, the child writes `result.<nonce>.tmp` with exclusive creation, flushes it and atomically renames it to `result.json`. The parent validates exact fields, nonce, requested head, current coherent UTC timestamps, status/exit agreement, unique completion markers, result privacy, cleanup/resource counts and a canonical SHA-256 digest, then removes only the known exact files and nonce directory. Missing, malformed, partial, stale, replayed, mismatched or inconsistent evidence fails closed with a generic launcher error.

The PowerShell 5.1 suite passes 14 repository-only cases: informational stderr with exit 0; native exit 7; dual-stream success; missing result; malformed JSON/schema; wrong nonce; wrong head; stale timestamp; digest mismatch; process/result exit disagreement; partial result; controlled raw-capture cleanup failure; sanitized-result privacy; and repeated invocation with a new nonce and no reused artifact. Production launcher/rehearsal scripts contain zero `*>&1`, `2>&1`, `Invoke-Expression`, `"-Command"`, `"-EncodedCommand"`, `cmd /c` or `Tee-Object` patterns and zero `SHA256.HashData` calls. R1C was repository-only: no UAC, service start/stop, `C:\RisePals` mutation, live rehearsal or reboot occurred. Its later authorized live use is now closed by the Accepted recovery; do not run it again under the current WinSW architecture.

The required four Gitleaks scopes pass. A preceding overly broad directory-mode diagnostic also inspected ignored build output and `.env.local`, returned only redacted findings and displayed no value. The ignored file remains untracked and unmodified, but R1 does not claim it remained unread.

### Accepted live recovery and RP-TURN-019-R2 disposition

The later WinSW live attempt did not complete direct service stop: `RisePalsApp` remained Stop Pending. Exact-PID forced termination was required to recover the host. This is Accepted emergency-recovery evidence and is **not** graceful-stop, stream-completion, controlled-503, no-force or bounded crash/restart success.

Project Codex Accepted the final safe state and exact residue cleanup:

- `RisePalsApp` and `RisePalsProxy` are Stopped/Disabled at PID 0;
- every original stalled PID, launcher/rehearsal process and process beneath `C:\RisePals` is absent;
- listeners on 80, 443, 2019, 3100, 8080 and 8443 are zero;
- enabled Rise Pals firewall rules, drain state and canary are absent;
- the two exact raw-capture files and their invocation directory were deleted without reading their contents; raw-capture residue is zero;
- repository/head/index remained clean and PR #17 remained Open, Draft and unmerged;
- no reboot or public deployment mutation occurred.

RP-TURN-019-R3 selects Option B only for a repository-owned prototype pending Project Codex review. `infra/windows-service-host/` contains the minimal self-contained .NET 10 LTS service-aware host that models direct `Stop-Service`; two-slot Caddy blue/green drain remains unauthorized fallback only with an explicit acceptance-contract change. The prototype is unsigned, uninstalled and has not contacted SCM or `C:\RisePals`. Keep the existing WinSW services/configuration Stopped and Disabled as rollback evidence until a separately authorized signed candidate passes a later live proof; then remove them only in a separate exact cleanup.

### Elevated bootstrap/result-transport boundary

LIVE3 exited with code 1 before producing parent-validatable structured evidence. Recovery2 restored and proved the accepted zero-residue host state, but the functional rehearsal is not accepted. Because the former elevated child could fail during typed parameter binding, elevated `%TEMP%`-relative directory resolution, helper loading or ACL/result initialization before any marker, the exact historic cause is unknowable. Do not infer service-host or cleanup behavior from that exit.

R4-DIAG1-R2 replaces that unobservable boundary with an explicit parent-owned transport and a two-record durable review protocol:

- the non-elevated parent keeps its transient nonce directory separate from an explicit caller-supplied durable evidence directory. Future Live evidence is restricted beneath `C:\Users\Administrator\Documents\Codex`; simulations use an isolated task-scoped temporary root. Linked/escaped paths and any ACL principal beyond the current user, SYSTEM and Administrators are rejected;
- the PowerShell 5.1 bootstrap accepts primitive strings only, self-validates the authorization ID, nonce, expected HEAD and launcher/bootstrap/transport/child hashes and atomically writes `bootstrap-started` before the full child is dispatched;
- the bootstrap writes `child-launch-attempted` immediately before process creation but never claims that the child started. The child owns `child-started` and writes it before `live-started`; a top-level fixed bootstrap-failure marker records any reached bootstrap failure without exception text;
- the parent validates exact path, reparse state, schema/property set, provenance, timestamps, digest, sequence, replay and exit/final consistency before producing a deterministic classification. It atomically persists, reopens and independently validates a digest-bound pre-cleanup checkpoint before any transient deletion;
- after the exact cleanup attempt, the parent writes and reopens a separate schema-v3 authoritative result that binds the checkpoint filename/digest to launch, marker and child-final state plus cleanup attempted/completed state, invocation absence and sanitized remaining-object metadata. Cleanup failure is durable failure and preserves uncertain residue;
- both durable records survive launcher exit. Overall success requires the successful child final, the reopened checkpoint, attempted/completed cleanup, absent invocation directory, zero transient/temporary objects and the reopened final receipt. Final-result persistence failure leaves the checkpoint and returns nonzero. Stdout is only an advisory concise summary;
- missing evidence is always failure and parent-generated diagnostics contain no service, drain, stream, restart or cleanup success claim.

The R2 process-boundary suite launches the actual clean committed parent through hidden Windows PowerShell 5.1 and independently validates evidence after ten separate processes exit: complete success, child launch failure, exit before child marker, child before live, live without final, invalid final, transient-cleanup failure, interrupted checkpoint write, interrupted authoritative-result write and pre-existing durable path. It never parses stdout as authority. All R4-DIAG1 simulations are non-elevated, use only fresh temporary paths outside `C:\RisePals` and delete only their controlled resources after assertion. They do not authorize another UAC prompt or host rehearsal. Project Codex must review the exact new commit and issue a separate exact-head authorization before any future Live attempt.

LIVE4B subsequently ran once and failed with parent exit 86 and elevated-child exit 1. Its durable records prove complete cleanup, absent invocation directory, zero residue and a safe final host, but their older schemas do not establish the exact internal failed stage or individual functional-gate outcomes. Do not infer either. DIAG2 is future-only: after validating the transient child result, the parent derives a strict digest-authenticated diagnostic containing only controlled stage/code/status values, a contiguous stage prefix, exactly 21 fixed gate dispositions and monotonic mutation/install/start/direct-Stop booleans. The reopened pre-cleanup checkpoint and post-cleanup result must retain an equivalent diagnostic digest. Missing, malformed, reordered, inconsistent, tampered or non-equivalent diagnostic evidence is terminal failure; stdout remains non-authoritative. DIAG2 does not authorize another Live run, UAC, service operation, reboot or deployment.

## Health and failure evidence

- `/health/live` returns only `{"status":"ok"}`.
- direct-loopback `/health/ready` returns only `ready`, `draining` or `unavailable` and requires rehearsal mode, release manifest, readable 64-byte synthetic canary and an exact protected lifecycle state. Next standalone may normalize the loopback socket into one exact loopback `x-forwarded-for` value; only `127.0.0.1`, `::1` or mapped `::ffff:127.0.0.1` is accepted, while chains/non-loopback values fail closed and Caddy still blocks the route with 404.
- `/health/stream` is 404 unless rehearsal mode is exact; in rehearsal it emits three fixed chunks and validates forwarded-header replacement. Its proxy boundary accepts only the fixed loopback source/protocol and either the direct loopback host or Caddy's exact `127.0.0.1:8443` host normalization; any other host or port fails closed.
- proxy readiness is 404.
- health tooling uses pinned Node 24 with the explicit Caddy local CA (never an insecure TLS bypass) to verify HTTPS status/body, 413 oversized body and unbuffered streaming; it also verifies redirect, admin reload and exact loopback listeners. This avoids depending on the host's legacy Windows curl TLS backend. Caddy's documented anti-spoof behavior ignores incoming `X-Forwarded-*` values, while the reviewed configuration explicitly overwrites the three upstream values without a wildcard operation that could delete the replacements.
- stop/restart checks must prove no orphan tool process or listener.
- three consecutive unexpected failures must exhaust the bounded restart plan instead of looping indefinitely.

## Synthetic secret lifecycle

The canary is random, exactly 64 bytes and never printed. It exists only at `C:\RisePals\shared\secrets\rehearsal.canary`, outside Git/releases. Exercise Create, app readiness, proxy DACL denial, Rotate, Revoke and Delete. Scan repository, service definitions, process commands and logs for leakage. Final cleanup requires the file and temporary variants to be absent.

Active WinSW/Caddy logs are scanned through a read-only handle that shares existing writers and deletion/rotation. The scanner does not modify or lock the logs and still fails closed if it cannot read a file or detects any raw, Base64 or hex canary form.

## Database and recovery

Only the accepted disposable PostgreSQL 18.4 harness is allowed. It remains loopback-only, uses separate migration/application roles and removes child databases, credentials, logs and processes. Re-run:

```powershell
npm run db:test:disposable
npm run db:test:recovery
npm run db:test:tls:disposable
```

The TLS-only disposable rehearsal uses PostgreSQL 18.4 on loopback, an ephemeral local CA supplied explicitly with `verify-full`, and separate synthetic owner/application roles. It removes the cluster, certificates, private keys and credentials afterward. The accepted full integration and recovery harnesses continue to use their existing isolated loopback transport; production database TLS and placement remain undecided.

No off-host encrypted backup target is approved. GitHub, another VPS directory and the disposable rehearsal are not backups. Off-host ownership, encryption, retention, deletion reconciliation, alerts, RTO/RPO and restore authority remain launch blockers.

## Historical cleanup and incident commands

Do not execute these commands under the current authorization. They are retained only to explain the R1 evidence and require a new exact recovery or implementation authorization.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\infra\Clear-RisePalsRehearsal.ps1
Get-Service RisePalsApp,RisePalsProxy
Get-NetTCPConnection -State Listen | Where-Object LocalPort -in 2019,3100,8080,8443
sc.exe qfailure RisePalsApp
sc.exe qfailure RisePalsProxy
```

The historical cleanup stops and disables both services, deletes the canary, the exact drain state/lock, only recognized atomic temp files and validated rehearsal children, then fails if a Rise Pals process/listener or drain residue remains. It deliberately retains the protected control directory, verified tools, reviewed releases, `current`, non-secret configuration and bounded logs.

## Reboot checkpoint and remaining launch blockers

This turn cannot reboot. A reboot rehearsal is not meaningful under the rejected WinSW supervision. The R3 repository prototype does not change that boundary: a separately authorized, signed service-aware-host candidate must first prove direct stop, full stream completion, new-work rejection, timeout cleanup, crash/restart, no-orphan and explicit preshutdown behavior live. Project Codex must accept those non-reboot results and Jeff must then authorize one controlled reboot with exact affected services, downtime and recovery commands. The final state remains both services Stopped and Disabled.

The existing versioned checkpoint scripts do not reboot the host themselves and are not approved for reuse with a replacement supervisor without review. Any future checkpoint must require the exact approved source commit and candidate service definition, write only sanitized evidence, prove Windows booted after that checkpoint, verify preshutdown and automatic recovery plus local health, and restore the Stopped/Disabled/no-canary final state.

Even a successful reboot rehearsal does not approve public deployment. Remaining blockers include DNS and public certificate lifecycle, external port scan, production identity/database/privacy/legal/data residency, production secrets, off-host backup/RTO/RPO, monitoring/alert ownership, staff/operator access, CI/deployment transport and a separately reviewed launch decision.
