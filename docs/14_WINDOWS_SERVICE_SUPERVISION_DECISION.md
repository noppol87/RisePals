# Windows Service Supervision Decision Pack

**Turn:** RP-TURN-019-R4  
**Status:** Option B repository-only prototype retained; R4-R3 context-independent artifact correction complete pending Project Codex review after LIVE2 stopped before UAC  
**Decision owner:** Project Codex and Jeff  
**Sources verified:** 2026-08-29

## Scope and accepted recovery facts

This decision pack records Jeff/Project Codex's selection of Option B only for a repository-owned prototype and authorizes no host mutation. It retains the original comparison for the confirmed Windows Server 2022 target after the RP-TURN-019 live recovery was Accepted.

The accepted safe state is:

- `RisePalsApp` and `RisePalsProxy` are Stopped and Disabled with PID 0;
- every original stalled PID, launcher/rehearsal process and process beneath `C:\RisePals` is absent;
- listeners on 80, 443, 2019, 3100, 8080 and 8443 are zero;
- enabled Rise Pals firewall rules, drain state and the synthetic canary are absent;
- the exact raw captures from the stalled invocation were deleted without their contents being read, and raw-capture residue is zero;
- the repository and `main` remained unchanged, and PR #17 remained Open, Draft and unmerged;
- no reboot, public mutation or deployment occurred.

Forced termination of exact stalled PIDs was emergency recovery. It was **not** graceful-stop success. Direct service stop did not complete, `RisePalsApp` remained Stop Pending, and the active-stream completion, controlled post-drain 503, no-forced-termination and bounded crash/restart gates remain unverified. The current WinSW design is therefore rejected as production supervision pending a new architecture decision. Another WinSW live rehearsal is prohibited.

## Non-negotiable supervision contract

The recommended production candidate must prove all of the following in a separately authorized loopback-only rehearsal:

1. A direct SCM stop transitions promptly to Stop Pending, rejects new application work and lets every already accepted response finish within an explicit deadline.
2. The service reports bounded wait hints/checkpoints correctly, then reports Stopped only after the child has exited or after an explicit, sanitized timeout failure.
3. Stop, preshutdown and crash paths cannot leave Node, helper or listener orphans.
4. Unexpected exits use a finite restart policy and end in an observable terminal state rather than an infinite loop.
5. Next.js streaming remains unbuffered end to end through Caddy.
6. The application runs as `NT SERVICE\RisePalsApp`, binds only to loopback and exposes no public or network-accessible control endpoint.
7. Releases remain immutable and checksum-bound; rollback never overwrites the last-known-good release.
8. Evidence contains fixed stages, counts, exit classes and digests but no secrets, identifiers or raw user data.

Microsoft documents that a service performing lengthy control work should return from its handler quickly, do the work on another thread, report the corresponding pending state and report completion afterward. The default modern preshutdown timeout is 10 seconds unless configured, and a preshutdown-aware service may update Stop Pending until the configured timeout or Stopped state. These rules make SCM state reporting part of the product's operational correctness, not only a wrapper detail.

## Scoring method

Score: `3` strong documented fit, `2` plausible but requires bounded proof, `1` weak or operationally costly fit, `0` fails the current contract. A zero on a hard gate cannot be offset by a higher total.

| Criterion | A: redesigned WinSW | B: service-aware host | C: IIS path | D: blue/green drain | E: Shawl |
|---|---:|---:|---:|---:|---:|
| Preserve accepted in-flight responses | 0 | 3 | 1 | 3 | 1 |
| Reject new traffic during drain | 2 | 3 | 2 | 3 | 0 |
| Bounded completion | 1 | 3 | 2 | 3 | 2 |
| Direct SCM stop behavior | 0 | 3 | 1 | 0 | 1 |
| Reboot/preshutdown behavior | 0 | 2 | 1 | 0 | 1 |
| Crash recovery and bounded restart | 2 | 3 | 3 | 1 | 2 |
| No orphan processes | 1 | 3 | 2 | 1 | 2 |
| Next.js streaming compatibility | 3 | 3 | 1 | 3 | 3 |
| Least-privilege virtual account | 3 | 3 | 3 | 2 | 3 |
| Signed/verifiable supply chain | 1 | 2 | 2 | 3 | 2 |
| Maintained and supported components | 1 | 3 | 2 | 3 | 3 |
| Operational simplicity | 2 | 2 | 1 | 2 | 2 |
| Deterministic release switch/rollback | 3 | 3 | 2 | 3 | 2 |
| Observable sanitized failure evidence | 2 | 3 | 2 | 3 | 2 |
| Implementation and maintenance burden | 2 | 1 | 1 | 2 | 2 |
| No external cost or production resource | 3 | 3 | 3 | 3 | 3 |
| **Total / 48** | **26** | **43** | **29** | **35** | **31** |

The matrix is a decision aid, not implementation proof. Option B still has to prove its two-point preshutdown score before any reboot request. Option D scores well for planned releases but has zeroes on direct-stop and reboot behavior under the existing contract.

## Option A — Retain WinSW with a redesigned stop contract

**Current supported release reviewed:** WinSW 2.12.0, published 2023-01-28 as the latest stable release. The project also exposes a 3.0 alpha, which is not a production-stable substitute.

WinSW documents that `stopexecutable` plus `stoparguments` launches a separate stop process and waits for both the stop process and wrapped process to exit before reporting termination. `stoptimeout` bounds that wait and is followed by forced termination. This is exactly the mechanism exercised by the R1 design.

**Assessment:** The observed Stop Pending stall shows that the existing local-drain helper plus WinSW wait contract did not satisfy direct `Stop-Service`. A materially different WinSW design would still have to coordinate two processes, prove correct SCM checkpoints/preshutdown behavior that WinSW does not document for this design, and prevent orphan descendants. Raising the timeout or weakening the stream/no-force gate would hide the failure rather than resolve it. The stable release's age, absence of an official checksum asset or Authenticode signature, and open project request for a newer stable build increase provenance and maintenance risk.

**Decision:** Reject. Do not perform another WinSW live attempt. Retain the current WinSW services/configuration Stopped and Disabled only as rollback evidence until a replacement passes; remove them in a separate exact cleanup turn after replacement acceptance.

## Option B — Repository-owned service-aware Windows host

**Prototype-selected architecture.** R3 builds one deliberately small, self-contained .NET 10 LTS Windows service executable whose only job is to supervise the pinned Node executable and translate SCM lifecycle events into a versioned private drain contract.

The candidate must:

- use `ServiceBase` or an equivalent explicit SCM implementation, register stop and preshutdown handling, report Stop Pending immediately, and advance bounded checkpoints/wait hints while a worker performs drain;
- launch only the reviewed absolute Node path and fixed standalone arguments without a shell or user-controlled command text;
- use a versioned ACL-protected Windows named pipe with no TCP/public route so Node stops admitting work, then wait for in-flight count zero or the fixed deadline;
- assign Node and descendants to a Windows Job Object with `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`, prohibit breakaway and close the job only after graceful completion or an explicit timeout;
- return Stopped only after the whole job is empty, or return a fixed failure classification after the timeout cleanup is verified;
- distinguish planned stop from unexpected child exit and allow only a finite reviewed restart schedule;
- run as the existing virtual service account with exact release-read/control-write/log-write rights and no public control endpoint;
- emit bounded Event Log or protected JSON evidence that excludes commands, environment values, secrets and user data.

Microsoft's .NET Windows Service guidance supports worker/service hosting and single-file publishing, but the generic host does not prove this complete SCM contract. R3 therefore isolates the minimal native dispatcher/handler/status adapter needed for Stop, Shutdown and Preshutdown. Checkpoint progression, child-job ownership and timeout behavior remain independently tested.

**Runtime and supply-chain consequence:** R3 verified official portable SDK 10.0.400 and runtime/security patch 10.0.11, uses package locks and publishes self-contained so no target-host shared runtime is assumed. .NET 10 is in active LTS support through 2028-11-14. Repository ownership improves inspectability but transfers patching, secure process-control design and release-signing responsibility to Rise Pals. The dependency manifest records the source/SDK/package/publish digest chain. Authenticode signing remains a production blocker because no approved signing identity exists.

**Failure modes and proportionality:** deadlock during stop, incorrect checkpoint timing, child escape from the job, drain races and accidental command/environment logging are the main risks. R3 counters these with duplicate-stop sharing, bounded deadlines, monotonic checkpoints, native suspended creation before Job assignment, an exact DACL/nonce protocol and redacted rotated evidence. The host remains single-purpose: no HTTP administration, updater, deployment engine, secret store, proxy or application logic.

**Acceptance-contract implication:** preserves the direct `Stop-Service RisePalsApp` gate. No contract weakening is proposed.

## Option C — IIS/ARR and Microsoft process hosting

The official Microsoft path reviewed is IIS with URL Rewrite/Application Request Routing and HttpPlatformHandler 1.2. HttpPlatformHandler can start an arbitrary HTTP listener, proxy to it and apply startup retries, rapid-fail limits and request timeouts. ARR provides server farms, health tests and traffic distribution.

**Assessment:** this path adds the IIS role plus ARR, URL Rewrite and HttpPlatformHandler modules; it shifts TLS, proxy logging, request limits and patch ownership away from the already tested Caddy boundary. The current Microsoft pages remain available, but HttpPlatformHandler is still documented as version 1.2 and the official page does not define the exact Node drain, SCM Stop Pending checkpoint, preshutdown, whole-process-tree or Next.js App Router streaming contract required here. ARR health and server-farm draining are useful but do not prove graceful termination of the hosted Node process. Proxy buffering, streaming, WebSocket/HTTP behavior, installation provenance, module support lifecycle and rollback of Windows features would all require a new platform rehearsal.

**Decision:** reject for this MVP. It adds a second web platform and leaves the hardest service-stop proof unresolved. Reconsider only if Jeff deliberately chooses IIS operational ownership and Microsoft supplies a supported hosting contract that meets every hard gate.

## Option D — Deployment-orchestrated blue/green Caddy drain

**Fallback architecture.** Run two immutable application slots on separate loopback ports, for example 3100 and 3101. Start and verify the candidate slot, reload Caddy so only new requests reach it, keep the old slot alive until its active count reaches zero or a fixed deadline, and preserve the previous reviewed Caddy configuration plus old release for rollback. A failed candidate never becomes permanent; after a successful switch, rollback reloads the prior reviewed route while the old slot is still healthy.

Caddy documents graceful configuration reloads, passive/active upstream health checks, configurable shutdown delay/grace period and unbuffered streaming through `flush_interval -1`. Next.js documents self-hosted App Router streaming and requires end-to-end proxy support without buffering. These capabilities can preserve the user-visible no-truncation outcome for **planned deployments**.

This pattern is not a complete service supervisor. A manual app service stop, process crash or VPS reboot bypasses the traffic-switch sequence unless another service-aware host owns both slots. If adopted alone, the acceptance contract must deliberately change: the orchestrated deployment command—not bare `Stop-Service`—becomes the only guaranteed drain path. Direct stop, crash and reboot may truncate requests. Project Codex must explicitly accept that change; implementation may not assume it.

**Decision:** fallback only. It is also a useful later enhancement around Option B, where the service-aware host retains direct-stop correctness and blue/green reduces planned-release interruption.

## Option E — Other reviewed Windows supervisors

Only candidates with a recent stable release and provenance-verifiable official source were considered. Shawl was the qualifying candidate reviewed in detail.

| Candidate | Reviewed release/source | Maintenance and behavior | Limitations and disposition |
|---|---|---|---|
| Shawl | v1.9.0, 2026-05-03; signed GitHub tag and official release assets | Wraps arbitrary commands as Windows services; configurable exit-code restart, delay, log rotation/retention, stop timeout and Job Object process-tree termination; service identity remains an SCM configuration and can use a virtual account | Stop sends Ctrl-C, waits, then forcibly kills after timeout. The official CLI does not document a separate private drain handshake, SCM checkpoint/preshutdown contract or in-flight HTTP completion. Better current maintenance and process-tree control than WinSW, but not superior to Option B on the hard stop gate and not superior to Option D for planned drain. Reject as production recommendation. |

NSSM, PM2 and Task Scheduler were not scored because this review did not establish both an actively maintained current Windows-service release and a primary-source contract meeting the hard gates. They are not fallback assumptions.

## Recorded prototype decision

Project Codex and Jeff selected the first bounded direction for repository-only implementation:

1. **Selected for prototype — Option B:** repository-owned, self-contained .NET 10 LTS service host and non-elevated deterministic tests, preserving the direct SCM stop contract.
2. **Not authorized — Option D:** blue/green Caddy drain would still require explicit authorization and an acceptance-contract change if used alone.

Options A, C and E are rejected for the reasons above. Ease of testing is not the selection basis; direct SCM correctness, response preservation and bounded process ownership are.

## Implemented repository prototype and separately bounded rehearsal

Option B remains split into explicit repository review and live-authorization checkpoints. The service host and repository-only candidate harness are implemented; no candidate installation or live rehearsal is authorized:

### Repository-only prototype — implemented pending review

- Added the minimal Windows-only service-host project with SDK 10.0.400/runtime 10.0.11, locked Microsoft packages, official provenance record and deterministic self-contained build.
- Added one exact uninstalled candidate identity shared by native dispatcher and handler registration while rejecting both retained service names.
- Added typed SCM/start/stop/drain lifecycle, monotonic checkpoints, transactional create/assign/resume/Ready attempts and bounded graceful/timeout outcomes; Stopped is prohibited until Job emptiness is proven.
- Added fake-adapter and Windows integration tests for stop/replay, checkpoint monotonicity, exact deadlines, finite restart, typed evidence exclusion, every startup stage, stop/restart races, suspended-before-Job assignment and descendant cleanup.
- Added a DACL-restricted, remote-rejecting named pipe and a synthetic Node three-chunk fixture without a TCP/public listener.
- Kept Caddy, installed WinSW, releases, health contracts and application behavior unchanged.
- Produced a versioned dependency/inventory/checksum manifest. The executable remains NotSigned and is prohibited from host installation.

R3-R1 passed 51 .NET tests, including six Node-fixture tests and fifteen focused correction regressions. R4-R3 corrected its build-context-sensitive assembly metadata and proved three byte-identical clean publishes from one Git-aware and two file-only contexts with distinct paths/timestamps. The executable is 73,606,961 bytes with SHA-256 `d86c4e4afcc8c1f6d8e77694b5de163185326c460fea1be50e5533d29aca0e8c`. This is repository evidence, not a live SCM/host claim.

### Repository-only candidate rehearsal harness — implemented pending review

RP-TURN-019-R4-R1 wraps the exact accepted unsigned R3-R1 executable in a deterministic future-run contract without installing or launching it. The versioned contract fixes candidate service `RisePalsServiceHostCandidate`, virtual account `NT SERVICE\RisePalsServiceHostCandidate`, derived SID `S-1-5-80-146351416-2890358921-3199710220-422177557-4020786491`, Own Process/Manual service settings and a 30-second per-service Preshutdown timeout. That timeout retains a documented 10-second margin above the complete 15-second drain plus 5-second exit bound and never changes global `ServicesPipeTimeout`. The same contract pins exact signed Node v24.18.1 bytes/signature and the complete retained App/Proxy commands, accounts, Own Process types, executable bytes and Stopped/Disabled/PID 0 states.

Every future artifact is scoped under a fresh 128-bit nonce. Candidate runtime/fixture bytes use task-created immutable staging; configuration and structured temporary evidence are separate under `C:\RisePals\rehearsal`; sanitized rotated logs are separate under `C:\RisePals\logs\service-host-candidate`. Exact ACL classes contain only SYSTEM and Administrators with FullControl plus the candidate service identity with ReadAndExecute for immutable runtime/release/configuration or Modify for its log directory. The plan rejects path escape, reparse points, unexpected children/ACLs/listeners/processes/services, candidate/Node pin mismatch, retained-service substring spoofs, changed arguments/account/type/bytes, shared PIDs and missing/additional retained services.

The future parent does not capture native streams or infer failure from stderr. Its child keeps stdout and stderr in separate nonce-private temporary files, determines native status only from the process exit code, deletes both captures without parsing them and emits one atomic structured result. Result validation binds exact nonce, repository head, launcher-script SHA-256, UTC freshness, explicit exit code and canonical digest; a nonce is single-use, malformed/partial/stale/replayed/provenance-mismatched results fail closed and no raw service output enters review evidence.

The contract enumerates 23 ordered stages covering start/readiness, first-byte-synchronized three-chunk work, direct/repeated Stop, fixed 503/`Retry-After`, Stop checkpoints, read-only Preshutdown registration, zero-Job graceful exit, timeout classification/cleanup, crash/restart bounds, persistent terminal failure, retained-proxy state preservation, process ownership and exact cleanup/final proof. Every stage has one fixed sanitized failure code. The non-reboot registration stage queries only the exact configured timeout and `SERVICE_ACCEPT_PRESHUTDOWN` while the candidate is Running; no script sends control 15 or claims Windows delivered Preshutdown. Accepted repository tests cover the Preshutdown handler and its shared bounded orchestration with Stop. Actual system delivery remains pending a separately authorized controlled reboot. Retained-proxy independence compares complete before/after definitions and state while direct candidate probes use loopback; the proxy remains Stopped/Disabled/PID 0 and is never enabled, started or restarted.

R4-R1 repository tests exercise deterministic plan equality, exact Node source/staged metadata rejection, exact retained-service definition/state and complete-snapshot equality, service/hash/path/ACL/listener rejection, result success/nonzero/stderr separation, malformed/stale/replay/partial rejection, recursive cleanup inventory containment/idempotency, exact sanitized mapping for all 23 failure stages and PowerShell 5.1 AST compatibility. They also prove no candidate script sends non-reboot Preshutdown control or targets `RisePalsProxy` with Start/Stop/Set/Restart. The elevated child repeats the exact clean-head/main/branch and ignored/untracked `.env.local` preflight before any future staging. A live attempt still requires a separate Project Codex authorization naming the exact reviewed R4-R1 head. Existing `RisePalsApp` and `RisePalsProxy` definitions remain untouched, Stopped and Disabled.

The separately authorized LIVE1 attempt stopped before UAC in its fresh Phase A build after 50/51 tests: `ChildIsAssignedToJobBeforeSuspendedPrimaryThreadResumes` queried Job accounting immediately after child completion, before Windows reported the Job empty. R4-R2 treats that as a deterministic-test defect, not production evidence. Production orchestration remains byte-identical. Only post-exit/post-termination test assertions use a shared monotonic 20 ms poll with a strict three-second maximum and a final deadline query; immediate non-empty proof before primary-thread resume and descendant-absence checks remain unchanged. The exact failed test passed 10/10 consecutive runs, the full 51-test suite passed three consecutive runs and focused repository infrastructure tests passed 2 files / 26 tests. The LIVE1 authorization is not reusable.

LIVE2 stopped before UAC and its authorization is invalid. R4-R3 pins explicit executable-only Version/AssemblyVersion/FileVersion/InformationalVersion and disables source-revision suffixing without changing service behavior. Artifact provenance records post-policy service-host production source tree `125eb5a7765c58cbc7cee094fbe82207642fd2a5` and excludes volatile outer-repository commit metadata. Git-aware MSBuild discovery still observed the outer commit while file-only contexts did not, but all three outputs and assembly metadata were identical and neither outer commit identifier was embedded. No live/elevated execution or host mutation occurred.

### Separately authorized host rehearsal — not authorized

- install the candidate under a **new service name** while both existing WinSW services remain Stopped/Disabled;
- use only synthetic loopback endpoints and an immutable reviewed release;
- prove direct `Stop-Service`, first-byte synchronized stream completion, concurrent new-work 503, repeated stop, timeout cleanup, exact job emptiness, finite crash recovery, persistent-failure terminal state, retained-proxy state preservation, direct loopback independence, forward/failed/manual rollback and sanitized cleanup;
- do not request a reboot until every non-reboot gate passes and Project Codex accepts the evidence.

No implementation turn may install a production resource, enable public ports, use real users/data or deploy publicly.

## Rollback and reboot decision

Before candidate acceptance, keep the existing WinSW service definitions, binaries and configuration Stopped and Disabled. The candidate uses a different service name and must not overwrite them. If repository tests or the host rehearsal fail:

1. stop/disable and remove only the new candidate service and its exact reviewed binary/configuration;
2. remove only candidate-specific temporary state after exact path and process checks;
3. restore the prior reviewed service manifest if it was touched;
4. leave the `current` junction on the verified last-known-good release and restore the prior reviewed Caddy configuration if a route switch occurred;
5. verify zero candidate processes/listeners and retain sanitized evidence;
6. keep WinSW disabled; do not treat it as an automatic production fallback.

After Option B passes and is accepted, remove the old WinSW service/configuration in a separate authorized cleanup. Retaining two dormant supervision stacks indefinitely would create ambiguity.

A reboot rehearsal becomes meaningful only after the recommended host proves every non-reboot direct-stop, streaming, controlled rejection, timeout, crash, restart and orphan gate plus exact Preshutdown timeout/accepted-control registration. A separately authorized controlled reboot must then verify actual system-delivered Preshutdown receipt, bounded Stop Pending checkpoints, automatic service recovery, Caddy/application ordering, loopback health and final Stopped/Disabled cleanup. No reboot is authorized now.

## Remaining uncertainties

- Live proof of the explicit native Preshutdown/checkpoint adapter under SCM; ordinary Shutdown alone is insufficient.
- Exact stop and preshutdown deadlines that preserve the longest permitted Rise Pals response without delaying Windows shutdown unreasonably.
- Live confirmation that suspended-before-assignment Node and descendants remain in the host Job Object under the final virtual service account policy; repository Windows tests pass.
- Authenticode ownership for the repository-built host and the approved SDK/package update cadence.
- Caddy connection behavior during application-side 503 drain and during a future two-slot reload under long HTTP streaming.
- Production DNS/TLS, public firewall, monitoring, off-host backup, database/identity/privacy suitability, CI/deployment transport and operator access; none is resolved by supervision selection.

## Primary sources

All sources below were reviewed on 2026-08-28.

| Area | Official/primary source |
|---|---|
| SCM state transitions | https://learn.microsoft.com/en-us/windows/win32/services/service-status-transitions |
| SCM control-handler timing | https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nc-winsvc-lphandler_function |
| SCM preshutdown timeout | https://learn.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_preshutdown_info |
| Windows service creation/virtual-account syntax | https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-createservicea |
| Per-service SID configuration | https://learn.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_sid_info |
| Job Object process-tree limit | https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_basic_limit_information |
| .NET Windows Service guidance | https://learn.microsoft.com/en-us/dotnet/core/extensions/windows-service |
| `ServiceBase.RequestAdditionalTime` | https://learn.microsoft.com/en-us/dotnet/api/system.serviceprocess.servicebase.requestadditionaltime?view=net-10.0 |
| .NET deployment modes | https://learn.microsoft.com/en-us/dotnet/core/deploying/ |
| .NET support policy | https://dotnet.microsoft.com/en-us/platform/support/policy |
| Next.js self-hosting and streaming | https://nextjs.org/docs/app/guides/self-hosting |
| Next.js platform requirements | https://nextjs.org/docs/app/guides/deploying-to-platforms |
| Caddy reverse proxy | https://caddyserver.com/docs/caddyfile/directives/reverse_proxy |
| Caddy shutdown/grace options | https://caddyserver.com/docs/caddyfile/options |
| Caddy graceful stop | https://caddyserver.com/docs/command-line#caddy-stop |
| WinSW 2.12.0 release | https://github.com/winsw/winsw/releases/tag/v2.12.0 |
| WinSW stop executable/timeout configuration | https://github.com/winsw/winsw/blob/v3/docs/xml-config-file.md |
| WinSW stable-release maintenance concern | https://github.com/winsw/winsw/issues/1129 |
| IIS HttpPlatformHandler configuration | https://learn.microsoft.com/en-us/iis/extensions/httpplatformhandler/httpplatformhandler-configuration-reference |
| IIS HttpPlatformHandler v1.2 release | https://www.iis.net/downloads/microsoft/httpplatformhandler |
| ARR load balancing and health | https://learn.microsoft.com/en-us/iis/extensions/configuring-application-request-routing-arr/http-load-balancing-using-application-request-routing |
| ARR 3.0 official download | https://www.microsoft.com/en-us/download/details.aspx?id=47333 |
| Shawl v1.9.0 release | https://github.com/mtkennerly/shawl/releases/tag/v1.9.0 |
| Shawl service/restart/stop CLI contract | https://github.com/mtkennerly/shawl/blob/master/docs/cli.md |
