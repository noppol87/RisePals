# Rise Pals repository-owned Windows service-host prototype

This directory contains the RP-TURN-019-R3-R1 **repository-only** prototype selected by D-027 plus the RP-TURN-019-R4 repository-only candidate rehearsal contract. Neither turn installs or replaces a Windows service, and neither is approved for production. The exact uninstalled candidate identity is `RisePalsServiceHostCandidate`; the existing `RisePalsApp`/WinSW and `RisePalsProxy` services remain untouched, Stopped and Disabled.

## Layout

- `RisePals.ServiceHost/` — self-contained `net10.0-windows`/`win-x64` host, pure orchestration and isolated native adapters.
- `RisePals.ServiceHost.Tests/` — Microsoft MSTest deterministic, private-IPC and Windows Job Object tests.
- `fixtures/node-service-fixture.mjs` — synthetic Node fixture with readiness, fixed three-chunk work, drain, crash and failure modes.
- `service-host-dependency-manifest.json` — reviewed tool/package inventory and prototype executable evidence.
- `candidate-rehearsal-contract.json` — exact future candidate identity/SID, executable/schema/manifest pins, nonce-scoped paths, ACLs, timing, loopback and 23-stage fail-closed rehearsal/cleanup contract.

Generated `bin`, `obj`, publish directories, SDK files and NuGet caches are ignored and must not be committed.

The R4 PowerShell harness lives under `scripts/infra/`. Its plan and deterministic suite are non-elevated and perform no service or `C:\RisePals` mutation. The parent never captures native output; the child keeps temporary stdout/stderr separate, deletes them unread and returns only a fresh nonce/head/script-hash/digest-bound structured result. The future live path requires a separately supplied exact-head authorization identifier and is never reached by repository tests. `candidate-rehearsal-probe.mjs` accepts only `127.0.0.1:3100` and writes a bounded structured result for the synthetic fixture; it has no credential, user-data or public-network path.

## Architecture

`ServiceOrchestrator` depends only on bounded contracts for status reporting, time, the Node child, Job Object ownership, drain transport, configuration resolution and sanitized evidence. Tests replace every adapter without SCM, elevation, listeners or `C:\RisePals`.

The Windows adapter binds one validated `ServiceRegistrationIdentity` to both native SCM dispatcher-table and control-handler registration. The candidate name is distinct from and cannot fall back to either retained service name. It reports monotonic Start Pending and Stop Pending checkpoints with bounded wait hints. Ordinary shutdown is not sufficient for the in-flight contract: production installation would need the service to accept `SERVICE_CONTROL_PRESHUTDOWN` and would need a separately reviewed per-service `SERVICE_CONFIG_PRESHUTDOWN_INFO` timeout. This prototype defines and tests the official constants/structure but deliberately does not call live service-configuration APIs and never changes global `ServicesPipeTimeout`.

The child adapter launches only an exact `node.exe` through native suspended process creation, with structured Windows argument quoting, an exact entrypoint and exact release working directory. It never launches a shell, npm or Windows PowerShell. Node and release paths must be existing children of distinct approved roots. Mutable logs must be outside the immutable release. Standard output and error are consumed independently, but their raw text is discarded; production evidence contains only fixed event/outcome/stream values plus bounded counters, with absolute per-event and per-file bounds and deterministic rotation.

Every startup attempt keeps its child, Job and drain transport local until create, possible assignment, resume and validated Ready all succeed. A failed stage disposes the exact local adapters, terminates a possibly assigned Job exactly once and proves emptiness within a fixed bound before terminal Stopped can be reported. Every child is assigned to a Windows Job Object configured with `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`. A timeout or host exit terminates/empties only that owned tree. Unexpected exits use deterministic exponential backoff, a bounded retry limit and a terminal failure state; Stop/Preshutdown cancellation shares the transition boundary and prevents restart.

## Private drain protocol v1

The host creates a local Windows named pipe with `PIPE_REJECT_REMOTE_CLIENTS` and a protected DACL granting access only to the exact service identity SID and `BUILTIN\Administrators`. The pipe is neither TCP nor Caddy-routable and is absent from browser/client surfaces. Messages are bounded newline-delimited JSON with only:

```text
version, type, nonce, state, activeCount
```

There are no request bodies, tokens, identities, personal data or secrets. The host requires `Ready → Draining → Drained → Stopped`, a unique 128-bit correlation nonce, bounded deadlines and zero active work before exit. Duplicate SCM Stop shares the same operation. Stale/replayed/mismatched acknowledgements, malformed messages, unsupported versions and disconnects fail closed.

The synthetic fixture accepts one fixed three-chunk stream before drain, rejects new work after Draining and sends Drained only after the accepted stream completes. It also supplies controlled crash, persistent startup failure, delayed exit, malformed Ready and stale acknowledgement modes.

## Portable verification

Run from this directory with the reviewed portable SDK and task-scoped caches. Do not persistently modify `PATH`.

```powershell
$env:DOTNET_CLI_HOME = '<task-specific-temp>\dotnet-home'
$env:NUGET_PACKAGES = '<task-specific-temp>\nuget'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
& '<verified-sdk>\dotnet.exe' restore .\RisePals.ServiceHost.slnx --configfile .\NuGet.config --locked-mode
& '<verified-sdk>\dotnet.exe' build .\RisePals.ServiceHost.slnx --configuration Release --no-restore
& '<verified-sdk>\dotnet.exe' test .\RisePals.ServiceHost.slnx --configuration Release --no-build --no-restore
```

Two clean self-contained publishes must have identical inventories and SHA-256 values. The prototype executable is intentionally not Authenticode-signed. Unsigned host installation is a production blocker; a later authorization must define signing identity, protected signing workflow, verification and release provenance before any host use.

## Explicit boundaries

- No UAC, service installation/configuration/start/stop, registry change, public listener, `C:\RisePals` access, deployment or reboot is part of this prototype.
- No secret belongs in config, arguments, logs, pipe messages, fixtures or build output.
- Existing Caddy/WinSW files are retained only as disabled recovery evidence and are not called by this host.
- Option D blue/green Caddy drain remains unauthorized.
- A live SCM/service-host proof, signed artifact, install/rollback plan and separate host authorization remain required before production consideration.
