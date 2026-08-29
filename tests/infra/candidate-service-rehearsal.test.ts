import { spawn, spawnSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { createServer } from "node:net";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../..");

async function text(relativePath: string): Promise<string> {
  return readFile(resolve(repositoryRoot, relativePath), "utf8");
}

describe("repository-only candidate service rehearsal harness", () => {
  it("pins the accepted candidate identity, executable, schema and dependency manifest", async () => {
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
      authorization: Record<string, boolean>;
    };

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
      executableLength: 73_606_931,
      executableSha256: "04e18bae3d0165118aa54676210a0425ee8a220cf33b9a6e17c29462093b985f",
      authenticode: "NotSigned",
      schemaLength: 1_672,
      schemaSha256: "64cd256addecd8489228f3ecfa6658d43eef897681326ffcd3bfd53c832a2b32",
      dependencyManifestLength: 5_116,
      dependencyManifestSha256: "6603b54d0abe79711b700b992bbff5de85ea04e74d6fc5d8ff245a3599b138d7",
    });
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
      "verify-preshutdown-checkpoints",
      "verify-graceful-zero-job",
      "verify-timeout-cleanup",
      "verify-bounded-crash-restart",
      "verify-persistent-failure-terminal",
      "verify-independent-proxy-restart",
      "verify-process-ownership",
      "cleanup",
      "final-read-only-proof",
    ]);
    expect(contract.sanitizedFailureCodes).toHaveLength(contract.rehearsalStages.length);
    expect(new Set(contract.sanitizedFailureCodes).size).toBe(
      contract.sanitizedFailureCodes.length,
    );
  });

  it("uses a separate-stream structured parent/child boundary and hard live authorization gate", async () => {
    const parent = await text("scripts/infra/Invoke-RisePalsCandidateRehearsal.ps1");
    const child = await text("scripts/infra/Invoke-RisePalsCandidateRehearsalChild.ps1");
    const result = await text("scripts/infra/candidate-rehearsal-result.ps1");

    expect(parent).toContain('$start.Verb = "RunAs"');
    expect(parent).toContain("$process.ExitCode");
    expect(parent).toContain("Assert-RisePalsCandidateResult");
    expect(parent).not.toContain("RedirectStandardOutput");
    expect(parent).not.toContain("RedirectStandardError");
    expect(parent).toContain('if ($Mode -eq "Live")');
    expect(parent).toContain('$arguments += @(\n      "-FutureAuthorizationId"');
    expect(child).toContain("-RedirectStandardOutput $stdoutPath");
    expect(child).toContain("-RedirectStandardError $stderrPath");
    expect(child).toContain("$process.ExitCode");
    expect(child).toContain("[IO.File]::Delete($capture)");
    expect(`${parent}\n${child}`).not.toContain("*>&1");
    expect(result).toContain("launcherScriptSha256");
    expect(result).toContain("ConsumedNonces");
    expect(result).toContain("Get-RisePalsCandidateResultDigest");
    expect(result).toContain("rawOutputPersisted");
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

  it("passes the PowerShell 5.1 deterministic harness suite without elevation or host mutation", () => {
    const powerShell = resolve(
      process.env.SystemRoot ?? "C:/Windows",
      "System32/WindowsPowerShell/v1.0/powershell.exe",
    );
    const suite = resolve(
      repositoryRoot,
      "scripts/infra/Test-RisePalsCandidateRehearsalHarness.ps1",
    );
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
      ],
      { encoding: "utf8", timeout: 180_000 },
    );
    expect(result.error).toBeUndefined();
    expect(result.status, result.stderr).toBe(0);
    expect(result.stdout).toContain("Rise Pals candidate rehearsal harness suite PASS.");
  }, 190_000);
});
