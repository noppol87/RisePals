import { spawn, spawnSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { mkdir, mkdtemp, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../..");

async function text(relativePath: string): Promise<string> {
  return readFile(resolve(repositoryRoot, relativePath), "utf8");
}

async function createIncompatibleSecurityModuleRoot(): Promise<string> {
  const moduleRoot = await mkdtemp(join(tmpdir(), "risepals-candidate-powershell7-modules-"));
  const moduleDirectory = join(moduleRoot, "Microsoft.PowerShell.Security");
  await mkdir(moduleDirectory);
  await writeFile(
    join(moduleDirectory, "Microsoft.PowerShell.Security.psd1"),
    [
      "@{",
      "  RootModule = 'Microsoft.PowerShell.Security.dll'",
      "  ModuleVersion = '99.0.0'",
      "  GUID = '217e3446-dc29-4294-bad3-60474726db4d'",
      "  PowerShellVersion = '7.0'",
      "  CmdletsToExport = @('Get-Acl')",
      "}",
      "",
    ].join("\n"),
    "utf8",
  );
  return moduleRoot;
}

describe("repository-only candidate service rehearsal harness", () => {
  it("pins the accepted candidate identity, executable, schema and dependency manifest", async () => {
    const executableProject = await text(
      "infra/windows-service-host/RisePals.ServiceHost/RisePals.ServiceHost.csproj",
    );
    const testProject = await text(
      "infra/windows-service-host/RisePals.ServiceHost.Tests/RisePals.ServiceHost.Tests.csproj",
    );
    const contract = JSON.parse(
      await text("infra/windows-service-host/candidate-rehearsal-contract.json"),
    ) as {
      candidate: {
        serviceName: string;
        virtualAccount: string;
        serviceSid: string;
        serviceType: string;
        startMode: string;
        retainedServices: string[];
      };
      prototype: Record<string, unknown>;
      node: Record<string, unknown>;
      retainedServices: Array<Record<string, unknown>>;
      authorization: Record<string, boolean>;
    };
    const dependencyManifest = JSON.parse(
      await text("infra/windows-service-host/service-host-dependency-manifest.json"),
    ) as {
      artifactIdentity: Record<string, unknown>;
      publish: Record<string, unknown>;
    };

    expect(executableProject).toContain("<Version>0.1.0-rp19-prototype</Version>");
    expect(executableProject).toContain("<AssemblyVersion>0.1.0.0</AssemblyVersion>");
    expect(executableProject).toContain("<FileVersion>0.1.0.0</FileVersion>");
    expect(executableProject).toContain(
      "<InformationalVersion>0.1.0-rp19-prototype</InformationalVersion>",
    );
    expect(executableProject).toContain(
      "<IncludeSourceRevisionInInformationalVersion>false</IncludeSourceRevisionInInformationalVersion>",
    );
    expect(executableProject).not.toContain("<SourceRevisionId>");
    expect(testProject).not.toMatch(
      /<Version>|<AssemblyVersion>|<FileVersion>|<InformationalVersion>|<IncludeSourceRevisionInInformationalVersion>|<SourceRevisionId>/u,
    );

    expect(contract.candidate).toEqual({
      serviceName: "RisePalsServiceHostCandidate",
      displayName: "Rise Pals Service Host Candidate",
      virtualAccount: "NT SERVICE\\RisePalsServiceHostCandidate",
      serviceSid: "S-1-5-80-146351416-2890358921-3199710220-422177557-4020786491",
      serviceType: "SERVICE_WIN32_OWN_PROCESS",
      startMode: "demand",
      retainedServices: ["RisePalsApp", "RisePalsProxy"],
    });
    expect(contract.prototype).toMatchObject({
      executableLength: 73_606_961,
      executableSha256: "d86c4e4afcc8c1f6d8e77694b5de163185326c460fea1be50e5533d29aca0e8c",
      authenticode: "NotSigned",
      artifactIdentity: {
        version: "0.1.0-rp19-prototype",
        assemblyVersion: "0.1.0.0",
        fileVersion: "0.1.0.0",
        informationalVersion: "0.1.0-rp19-prototype",
        includeSourceRevisionInInformationalVersion: false,
        serviceHostProductionSourceTree: "125eb5a7765c58cbc7cee094fbe82207642fd2a5",
        volatileOuterRepositoryCommitMetadataExcluded: true,
      },
      schemaLength: 1_672,
      schemaSha256: "64cd256addecd8489228f3ecfa6658d43eef897681326ffcd3bfd53c832a2b32",
      dependencyManifestLength: 5_629,
      dependencyManifestSha256: "b5abd30d2afe52c7685717561432ba5208482073e4957e8e0eef538982e8f60e",
    });
    expect(dependencyManifest.artifactIdentity).toEqual(contract.prototype.artifactIdentity);
    expect(dependencyManifest.publish).toMatchObject({
      contextCount: 3,
      contexts: [
        "git-aware",
        "git-archive-file-only",
        "second-file-only-distinct-path-and-timestamps",
      ],
      byteIdentical: true,
      files: [
        {
          name: "RisePals.ServiceHost.exe",
          length: 73_606_961,
          sha256: "d86c4e4afcc8c1f6d8e77694b5de163185326c460fea1be50e5533d29aca0e8c",
          authenticode: "NotSigned",
        },
        {
          name: "service-host-config.schema.json",
          length: 1_672,
          sha256: "64cd256addecd8489228f3ecfa6658d43eef897681326ffcd3bfd53c832a2b32",
        },
      ],
    });
    expect(contract.node).toEqual({
      version: "v24.18.1",
      sourcePath: "C:\\RisePals\\tools\\node\\24.18.1\\node.exe",
      executableLength: 92_540_232,
      executableSha256: "ac51903c4c111815d52280b1fdcc8da067cbb37e2fe1a765097b85c3292c8582",
      authenticode: "Valid",
      signerSubject:
        "CN=OpenJS Foundation, O=OpenJS Foundation, L=San Francisco, S=California, C=US",
      signerThumbprint: "285AE8801AFDD52B8F7B9B6436B50052911AF7C2",
    });
    expect(contract.retainedServices).toEqual([
      {
        serviceName: "RisePalsApp",
        serviceType: "Own Process",
        virtualAccount: "NT SERVICE\\RisePalsApp",
        pathName: '"C:\\RisePals\\tools\\winsw\\2.12.0\\RisePalsApp.exe"',
        executablePath: "C:\\RisePals\\tools\\winsw\\2.12.0\\RisePalsApp.exe",
        executableLength: 18_243_033,
        executableSha256: "05b82d46ad331cc16bdc00de5c6332c1ef818df8ceefcd49c726553209b3a0da",
        expectedState: "Stopped",
        expectedStartMode: "Disabled",
        expectedProcessId: 0,
      },
      {
        serviceName: "RisePalsProxy",
        serviceType: "Own Process",
        virtualAccount: "NT SERVICE\\RisePalsProxy",
        pathName:
          "C:\\RisePals\\tools\\caddy\\2.11.4\\caddy.exe run --config C:\\RisePals\\shared\\config\\Caddyfile --adapter caddyfile",
        executablePath: "C:\\RisePals\\tools\\caddy\\2.11.4\\caddy.exe",
        executableLength: 49_535_488,
        executableSha256: "5cb9ab71e5756ce72840b8234177a2f40c8b4ab47a806b8e841e2b784e9df62b",
        expectedState: "Stopped",
        expectedStartMode: "Disabled",
        expectedProcessId: 0,
      },
    ]);
    expect(contract.authorization).toEqual({
      repositoryOnly: true,
      liveExecutionAuthorized: false,
      liveExecutionRequiresSeparateExactHeadAuthorization: true,
      productionApproved: false,
    });
  });

  it("keeps candidate paths nonce-scoped and mutable state outside immutable content", async () => {
    const contract = JSON.parse(
      await text("infra/windows-service-host/candidate-rehearsal-contract.json"),
    ) as {
      paths: Record<string, string>;
      timing: {
        preshutdownTimeoutMilliseconds: number;
        preshutdownMarginMilliseconds: number;
        drainTimeoutSeconds: number;
        exitTimeoutSeconds: number;
      };
      network: Record<string, unknown>;
      aclPlan: Array<{ pathKind: string; rights: Record<string, string> }>;
    };

    expect(contract.paths.root).toBe("C:\\RisePals");
    for (const [name, path] of Object.entries(contract.paths)) {
      if (name.endsWith("Template") && name !== "taskNameTemplate") {
        expect(path).toContain("candidate-{nonce}");
        expect(path).toMatch(/^C:\\RisePals\\(staging|rehearsal|logs)\\/u);
      }
    }
    expect(contract.paths.configPathTemplate).not.toContain("release-root");
    expect(contract.paths.logDirectoryTemplate).not.toContain("release-root");
    expect(contract.timing.preshutdownTimeoutMilliseconds).toBe(30_000);
    expect(
      contract.timing.preshutdownTimeoutMilliseconds -
        1_000 * (contract.timing.drainTimeoutSeconds + contract.timing.exitTimeoutSeconds),
    ).toBe(contract.timing.preshutdownMarginMilliseconds);
    expect(contract.network).toMatchObject({
      address: "127.0.0.1",
      candidatePort: 3100,
      publicListenersAllowed: false,
    });
    expect(contract.aclPlan).toHaveLength(4);
    for (const acl of contract.aclPlan) {
      expect(Object.keys(acl.rights).sort()).toEqual([
        "BUILTIN\\Administrators",
        "NT SERVICE\\RisePalsServiceHostCandidate",
        "SYSTEM",
      ]);
      expect(acl.rights["NT SERVICE\\RisePalsServiceHostCandidate"]).toBe(
        acl.pathKind === "mutable-log" ? "Modify" : "ReadAndExecute",
      );
    }
  });

  it("encodes every future proof stage and one fixed failure classification per stage", async () => {
    const contract = JSON.parse(
      await text("infra/windows-service-host/candidate-rehearsal-contract.json"),
    ) as { rehearsalStages: string[]; sanitizedFailureCodes: string[] };

    expect(contract.rehearsalStages).toEqual([
      "preflight",
      "stage-immutable-inputs",
      "apply-exact-acls",
      "validate-candidate-config",
      "create-own-process-service",
      "configure-service-sid",
      "configure-preshutdown-timeout",
      "start-and-ready",
      "stream-first-byte",
      "direct-stop",
      "reject-new-work-during-drain",
      "complete-three-chunk-stream",
      "duplicate-stop",
      "verify-stop-checkpoints",
      "verify-preshutdown-registration",
      "verify-graceful-zero-job",
      "verify-timeout-cleanup",
      "verify-bounded-crash-restart",
      "verify-persistent-failure-terminal",
      "verify-retained-proxy-independence",
      "verify-process-ownership",
      "cleanup",
      "final-read-only-proof",
    ]);
    expect(contract.sanitizedFailureCodes).toHaveLength(contract.rehearsalStages.length);
    expect(new Set(contract.sanitizedFailureCodes).size).toBe(
      contract.sanitizedFailureCodes.length,
    );
    expect(contract.sanitizedFailureCodes).toContain("proxy-state-preservation-failed");
    expect(contract.sanitizedFailureCodes).not.toContain("proxy-independence-failed");
  });

  it("models read-only Preshutdown registration without dispatching a fake control", async () => {
    const live = await text("scripts/infra/Invoke-RisePalsCandidateLiveSequence.ps1");
    const control = await text("scripts/infra/Invoke-RisePalsCandidateServiceControl.ps1");
    const adapter = await text(
      "infra/windows-service-host/RisePals.ServiceHost/WindowsScmAdapter.cs",
    );
    const orchestrationTests = await text(
      "infra/windows-service-host/RisePals.ServiceHost.Tests/OrchestrationTests.cs",
    );
    const nonRebootScripts = (
      await Promise.all(
        (await readdir(resolve(repositoryRoot, "scripts/infra")))
          .filter(
            (name) =>
              name.endsWith(".ps1") && !name.includes("Reboot") && !name.startsWith("Test-"),
          )
          .map((name) => text(`scripts/infra/${name}`)),
      )
    ).join("\n");

    expect(live).toContain("QueryServiceConfig2");
    expect(live).toContain("QueryServiceStatusEx");
    expect(live).toContain("SERVICE_ACCEPT_PRESHUTDOWN");
    expect(live).toContain("Get-RisePalsCandidatePreshutdownRegistration");
    expect(live).toContain("verify-preshutdown-registration");
    expect(nonRebootScripts).not.toMatch(/sc(?:\.exe)?[^\r\n]*control[^\r\n]*15/iu);
    expect(control).toContain('[ValidateSet("Stop")]');
    expect(control).not.toContain('"Preshutdown"');
    expect(adapter).toContain("ServiceAcceptPreshutdown");
    expect(adapter).toContain("ServiceControlPreshutdown");
    expect(orchestrationTests).toContain("PreshutdownUsesTheSameBoundedDrainContract");
  });

  it("keeps the retained proxy stopped and proves direct-loopback independence by snapshot", async () => {
    const candidateScripts = (
      await Promise.all(
        [
          "scripts/infra/candidate-rehearsal-contract.ps1",
          "scripts/infra/candidate-rehearsal-transport.ps1",
          "scripts/infra/Invoke-RisePalsCandidateRehearsal.ps1",
          "scripts/infra/Invoke-RisePalsCandidateElevatedBootstrap.ps1",
          "scripts/infra/Invoke-RisePalsCandidateRehearsalChild.ps1",
          "scripts/infra/Invoke-RisePalsCandidateElevationProbeChild.ps1",
          "scripts/infra/Invoke-RisePalsCandidateLiveSequence.ps1",
          "scripts/infra/Invoke-RisePalsCandidateServiceControl.ps1",
        ].map(text),
      )
    ).join("\n");
    const live = await text("scripts/infra/Invoke-RisePalsCandidateLiveSequence.ps1");

    expect(live).toContain("verify-retained-proxy-independence");
    expect(live).toContain("Assert-RisePalsCandidateRetainedSnapshotEquality");
    expect(live).toContain("ServicesDependedOn");
    expect(live).toContain('"http://127.0.0.1:3100"');
    expect(candidateScripts).not.toMatch(
      /(?:Start|Stop|Restart|Set)-Service[^\r\n]*RisePalsProxy/iu,
    );
    expect(candidateScripts).not.toMatch(
      /(?:sc(?:\.exe)?|Invoke-RisePalsCandidateSc)[^\r\n]*(?:start|stop|control|config)[^\r\n]*RisePalsProxy/iu,
    );
    expect(candidateScripts).not.toContain("verify-independent-proxy-restart");
  });

  it("uses a separate-stream structured parent/child boundary and hard live authorization gate", async () => {
    const parent = await text("scripts/infra/Invoke-RisePalsCandidateRehearsal.ps1");
    const bootstrap = await text("scripts/infra/Invoke-RisePalsCandidateElevatedBootstrap.ps1");
    const child = await text("scripts/infra/Invoke-RisePalsCandidateRehearsalChild.ps1");
    const result = await text("scripts/infra/candidate-rehearsal-result.ps1");
    const transport = await text("scripts/infra/candidate-rehearsal-transport.ps1");
    const processBoundary = await text("scripts/infra/Test-RisePalsCandidateProcessBoundary.ps1");

    expect(parent).toContain("New-RisePalsCandidateCanonicalLaunchRequest");
    expect(parent).toContain("$start.Verb = [string]$launchRequest.verb");
    expect(parent).toContain("$process.ExitCode");
    expect(parent).toContain("Assert-RisePalsCandidateResult");
    expect(parent).not.toContain("RedirectStandardOutput");
    expect(parent).not.toContain("RedirectStandardError");
    expect(transport).toContain("[AllowEmptyString()]");
    expect(bootstrap).not.toContain("RedirectStandardOutput");
    expect(bootstrap).not.toContain("RedirectStandardError");
    expect(bootstrap).toContain('New-RisePalsBootstrapMarker -MarkerType "bootstrap-started"');
    expect(bootstrap).toContain('New-RisePalsBootstrapMarker -MarkerType "child-launch-attempted"');
    expect(bootstrap).not.toContain('New-RisePalsBootstrapMarker -MarkerType "child-started"');
    expect(child).toContain('New-RisePalsCandidateMarker -MarkerType "child-started"');
    expect(bootstrap).toContain("[Security.Cryptography.SHA256]::Create()");
    expect(bootstrap).toContain("ComputeHash");
    expect(bootstrap).not.toContain("Get-FileHash");
    expect(parent).toContain('$Mode -in @("Live", "ElevationProbe")');
    expect(transport).toContain('"-FutureAuthorizationId",');
    expect(child).toContain("-RedirectStandardOutput $stdoutPath");
    expect(child).toContain("-RedirectStandardError $stderrPath");
    expect(child).toContain("$process.ExitCode");
    expect(child).toContain("[IO.File]::Delete($capture)");
    expect(`${parent}\n${child}`).not.toContain("*>&1");
    expect(result).toContain("launcherScriptSha256");
    expect(result).toContain("bootstrapScriptSha256");
    expect(result).toContain("transportScriptSha256");
    expect(result).toContain("childScriptSha256");
    expect(result).toContain("ConsumedNonces");
    expect(result).toContain("Get-RisePalsCandidateResultDigest");
    expect(result).toContain("rawOutputPersisted");
    expect(transport).toContain("uac-not-launched");
    expect(transport).toContain("elevated-child-never-entered-bootstrap");
    expect(transport).toContain("bootstrap-entered-child-launch-not-attempted");
    expect(transport).toContain("child-launch-attempted-child-not-started");
    expect(transport).toContain("child-started-failed-before-live");
    expect(transport).toContain("live-started-failed");
    expect(transport).toContain("final-present-validated");
    expect(transport).toContain("final-invalid-or-inconsistent");
    expect(parent).toContain("Write-RisePalsCandidateDurableParentResultAtomic");
    expect(parent).toContain("Read-RisePalsCandidateDurableParentResult");
    expect(parent).toContain("Write-RisePalsCandidateDurableParentCheckpointAtomic");
    expect(parent).toContain("Read-RisePalsCandidateDurableParentCheckpoint");
    expect(parent.indexOf("Write-RisePalsCandidateDurableParentCheckpointAtomic")).toBeLessThan(
      parent.indexOf("transientCleanupAttempted = $true"),
    );
    expect(parent.indexOf("transientCleanupAttempted = $true")).toBeLessThan(
      parent.indexOf("Write-RisePalsCandidateDurableParentResultAtomic"),
    );
    expect(parent).toContain("RISE_PALS_CANDIDATE_PARENT_SUMMARY=");
    expect(parent).not.toContain("RISE_PALS_CANDIDATE_PARENT_RESULT=");
    expect(result).toContain("rise-pals-candidate-rehearsal-result-v2");
    expect(result).toContain("rise-pals-candidate-child-diagnostic-v2");
    expect(transport).toContain("rise-pals-candidate-parent-checkpoint-v4");
    expect(transport).toContain("rise-pals-candidate-parent-result-v6");
    expect(transport).toContain("rise-pals-candidate-launch-diagnostic-v1");
    expect(transport).toContain("Get-RisePalsCandidateLaunchExceptionEvidence");
    expect(transport).toContain("Get-RisePalsCandidateCanonicalArgumentDigest");
    expect(transport).toContain("ExpectedLaunchDiagnosticDigest");
    expect(parent).toContain("Get-RisePalsCandidateLauncherSignatureStatus");
    expect(parent).toContain("New-RisePalsCandidateLaunchDiagnostic");
    expect(transport).toContain("childDiagnostic");
    expect(result).toContain("cleanupResponsibilityTransferredToParent");
    expect(result).toContain("candidateServiceInstallationBegan");
    expect(result).toContain("directStopServiceReached");
    expect(result).toContain("not_reached");
    expect(result).toContain("not_applicable");
    expect(transport).toContain("durableCheckpointValidated");
    expect(transport).toContain("transientCleanupCompleted");
    expect(transport).toContain("remainingTransientRelativePaths");
    expect(processBoundary).toContain("Start-Process -FilePath $powerShell");
    expect(processBoundary).toContain("-WindowStyle Hidden -Wait -PassThru");
    expect(processBoundary).toContain("Assert-RisePalsCandidateParentCheckpoint");
    expect(processBoundary).toContain("Assert-RisePalsCandidateParentResult");
    expect(processBoundary).not.toContain("RedirectStandardOutput");
    expect(processBoundary).not.toContain("RedirectStandardError");
    expect(processBoundary).not.toContain("RISE_PALS_CANDIDATE_PARENT_SUMMARY=");
  });

  it("keeps ElevationProbe closed, non-mutating, and distinct from Live success", async () => {
    const parent = await text("scripts/infra/Invoke-RisePalsCandidateRehearsal.ps1");
    const transport = await text("scripts/infra/candidate-rehearsal-transport.ps1");
    const result = await text("scripts/infra/candidate-rehearsal-result.ps1");
    const probeChild = await text("scripts/infra/Invoke-RisePalsCandidateElevationProbeChild.ps1");
    const processBoundary = await text("scripts/infra/Test-RisePalsCandidateProcessBoundary.ps1");

    expect(parent.match(/New-RisePalsCandidateCanonicalLaunchRequest/gu)).toHaveLength(1);
    expect(parent.match(/Start-Process/gu)).toHaveLength(1);
    expect(transport).toContain("RP-TURN-019-R4-PROBE-[A-F0-9]{8}");
    expect(transport).toContain("RP-TURN-019-R4-LIVE-[A-F0-9]{8}");
    expect(transport).toContain("rise-pals-candidate-elevation-probe-diagnostic-v1");
    expect(transport).toContain("elevation-probe-success");
    expect(transport).toContain("ExpectedProbeDiagnosticDigest");
    expect(result).toContain('if ($Diagnostic.executionMode -eq "ElevationProbe")');
    expect(result).toContain('"not_applicable"');
    expect(probeChild).toContain('[ValidateSet("ElevationProbe")]');
    expect(probeChild).toContain("administratorRoleConfirmed");
    expect(probeChild).toContain("Get-RisePalsElevationProbeIntegrityLevel");
    expect(probeChild).toContain("-LiveSequenceInvoked $false");
    expect(probeChild).toContain("-HostMutationAttempted $false");
    expect(probeChild).not.toMatch(/Invoke-RisePalsCandidateLiveSequence/iu);
    expect(probeChild).not.toMatch(
      /(?:Get|Set|New|Start|Stop|Restart|Remove)-Service|OpenSCManager|CreateService|ChangeServiceConfig|ControlService|DeleteService/iu,
    );
    expect(probeChild).not.toContain("C:\\RisePals\\");
    expect(probeChild).not.toMatch(/node\.exe|RisePalsServiceHostCandidate/iu);
    expect(probeChild).not.toMatch(
      /New-NetFirewallRule|Set-NetFirewallRule|Remove-NetFirewallRule|New-SelfSignedCertificate|Import-Certificate|Restart-Computer|Stop-Computer/iu,
    );
    expect(processBoundary).toContain("elevation-probe-transport");
    expect(processBoundary).toContain("PASS (11 scenarios)");
  });

  it("wires exact stage failures and recursive cleanup refusal into the gated live source", async () => {
    const live = await text("scripts/infra/Invoke-RisePalsCandidateLiveSequence.ps1");
    const contract = await text("scripts/infra/candidate-rehearsal-contract.ps1");

    expect(live).toContain("Get-RisePalsCandidateFailureCodeForStage");
    expect(live).toContain("Assert-RisePalsCandidateTaskTreeInventory");
    expect(live).toContain("The elevated candidate preflight no longer matches");
    expect(contract).toContain("A candidate cleanup tree contains an unexpected child.");
    expect(contract).toContain("$pendingDirectories.Push($resolvedItem)");
  });

  it("uses a loopback-only synthetic fixture with synchronized three-chunk drain behavior", async () => {
    const fixture = await text("infra/windows-service-host/fixtures/node-service-fixture.mjs");
    const probe = await text("scripts/infra/candidate-rehearsal-probe.mjs");

    expect(fixture).toContain('server.listen(fixtureHttpPort, "127.0.0.1", onListening)');
    expect(fixture).toContain('request.url === "/health/stream"');
    expect(fixture).toContain('"Retry-After": "5"');
    expect(fixture).toContain('["chunk-1", "chunk-2", "chunk-3"]');
    expect(fixture).toContain('request.url === "/fixture/crash"');
    expect(probe).toContain('url.hostname !== "127.0.0.1"');
    expect(probe).toContain('url.port !== "3100"');
    expect(probe).toContain("exactChunks");
    expect(probe).not.toMatch(/authorization|cookie|token|secret/iu);
  });

  it("preserves accepted work and rejects concurrent new work after private drain", async () => {
    const pipeName = `rise-pals-r4-${randomUUID()}`;
    const pipePath = `\\\\.\\pipe\\${pipeName}`;
    const messages: Array<{ state: string; nonce: string; activeCount: number }> = [];
    let resolveMessage: (() => void) | undefined;
    const waitForState = async (state: string): Promise<void> => {
      const deadline = Date.now() + 5_000;
      while (!messages.some((message) => message.state === state)) {
        if (Date.now() >= deadline) throw new Error(`fixture did not reach ${state}`);
        await new Promise<void>((resolveWait) => {
          resolveMessage = resolveWait;
          setTimeout(resolveWait, 25);
        });
      }
    };

    let peer: import("node:net").Socket | undefined;
    let buffered = "";
    const server = createServer((socket) => {
      peer = socket;
      socket.setEncoding("utf8");
      socket.on("data", (chunk) => {
        buffered += chunk;
        while (buffered.includes("\n")) {
          const boundary = buffered.indexOf("\n");
          const line = buffered.slice(0, boundary);
          buffered = buffered.slice(boundary + 1);
          if (line) messages.push(JSON.parse(line));
          resolveMessage?.();
          resolveMessage = undefined;
        }
      });
    });
    await new Promise<void>((resolveListen, rejectListen) => {
      server.once("error", rejectListen);
      server.listen(pipePath, resolveListen);
    });
    const child = spawn(
      process.execPath,
      [
        resolve(repositoryRoot, "infra/windows-service-host/fixtures/node-service-fixture.mjs"),
        "normal",
        "--fixture-http-port",
        "3100",
        "--rise-pals-drain-pipe",
        pipeName,
      ],
      { stdio: "ignore", windowsHide: true },
    );

    try {
      await waitForState("Ready");
      const ready = await fetch("http://127.0.0.1:3100/health/ready");
      expect(ready.status).toBe(200);

      const accepted = await fetch("http://127.0.0.1:3100/health/stream");
      const reader = accepted.body?.getReader();
      expect(reader).toBeDefined();
      const first = await reader!.read();
      expect(new TextDecoder().decode(first.value)).toContain("chunk-1");

      const nonce = "0123456789abcdef0123456789abcdef";
      peer!.write(`${JSON.stringify({ version: 1, type: "command", nonce, state: "Draining" })}\n`);
      await waitForState("Draining");
      const rejected = await fetch("http://127.0.0.1:3100/health/stream");
      expect(rejected.status).toBe(503);
      expect(rejected.headers.get("retry-after")).toBe("5");

      let remaining = "";
      while (true) {
        const next = await reader!.read();
        if (next.done) break;
        remaining += new TextDecoder().decode(next.value);
      }
      expect(`chunk-1\n${remaining}`.trim().split(/\r?\n/u)).toEqual([
        "chunk-1",
        "chunk-2",
        "chunk-3",
      ]);
      await waitForState("Drained");
      peer!.write(`${JSON.stringify({ version: 1, type: "command", nonce, state: "Stopped" })}\n`);
      await waitForState("Stopped");
      const exitCode =
        child.exitCode ??
        (await new Promise<number | null>((resolveExit) => child.once("exit", resolveExit)));
      expect(exitCode).toBe(0);
    } finally {
      if (child.exitCode === null) child.kill();
      peer?.destroy();
      await new Promise<void>((resolveClose) => server.close(() => resolveClose()));
    }
  }, 20_000);

  it("passes the PowerShell 5.1 deterministic harness suite without elevation or host mutation", async () => {
    const powerShell = resolve(
      process.env.SystemRoot ?? "C:/Windows",
      "System32/WindowsPowerShell/v1.0/powershell.exe",
    );
    const suite = resolve(
      repositoryRoot,
      "scripts/infra/Test-RisePalsCandidateRehearsalHarness.ps1",
    );
    const moduleRoot = await createIncompatibleSecurityModuleRoot();
    try {
      const result = spawnSync(
        powerShell,
        [
          "-NoLogo",
          "-NoProfile",
          "-ExecutionPolicy",
          "Bypass",
          "-File",
          suite,
          "-RepositoryRoot",
          repositoryRoot,
          "-TestOnlyPowerShell7ModuleRoot",
          moduleRoot,
        ],
        {
          encoding: "utf8",
          timeout: 180_000,
          env: process.env,
        },
      );
      expect(result.error).toBeUndefined();
      expect(result.status, result.stderr).toBe(0);
      expect(result.stdout).toContain("Rise Pals candidate rehearsal harness suite PASS.");
    } finally {
      await rm(moduleRoot, { recursive: true, force: true });
    }
  }, 190_000);
});
