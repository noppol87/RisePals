import { readFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../..");

async function text(path: string): Promise<string> {
  return readFile(resolve(repositoryRoot, path), "utf8");
}

const productionLauncherScripts = [
  "scripts/infra/Invoke-RisePalsElevatedRehearsal.ps1",
  "scripts/infra/Invoke-RisePalsElevatedRehearsalChild.ps1",
  "scripts/infra/Invoke-RisePalsLauncherFixture.ps1",
  "scripts/infra/Invoke-RisePalsServiceStop.ps1",
  "scripts/infra/Invoke-RisePalsNonRebootRehearsal.ps1",
  "scripts/infra/rehearsal-launcher-result.ps1",
];

describe("versioned elevated-rehearsal launcher", () => {
  it("keeps the parent elevation boundary free of stream capture", async () => {
    const parent = await text("scripts/infra/Invoke-RisePalsElevatedRehearsal.ps1");
    const child = await text("scripts/infra/Invoke-RisePalsElevatedRehearsalChild.ps1");

    expect(parent).toContain('$startParameters.Verb = "RunAs"');
    expect(parent).toContain("$process.ExitCode");
    expect(parent).toContain("Assert-RisePalsLauncherResult");
    expect(parent).not.toContain("RedirectStandardOutput");
    expect(parent).not.toContain("RedirectStandardError");
    expect(child).not.toContain('Verb = "RunAs"');
    expect(child).toContain("-RedirectStandardOutput $stdoutPath");
    expect(child).toContain("-RedirectStandardError $stderrPath");
    expect(child).toContain("$nativeProcess.ExitCode");
    expect(child).toContain("Write-RisePalsLauncherResultAtomic");
  });

  it("defines a digest-bound private structured result with exact cleanup", async () => {
    const parent = await text("scripts/infra/Invoke-RisePalsElevatedRehearsal.ps1");
    const child = await text("scripts/infra/Invoke-RisePalsElevatedRehearsalChild.ps1");
    const result = await text("scripts/infra/rehearsal-launcher-result.ps1");

    for (const field of [
      "schemaVersion",
      "invocationNonce",
      "requestedRepositoryHead",
      "startedAtUtc",
      "completedAtUtc",
      "status",
      "childExitCode",
      "completedStages",
      "failedStage",
      "sanitizedFailureCode",
      "cleanupCompleted",
      "finalResourceCounts",
      "resultDigest",
    ]) {
      expect(result).toContain(`"${field}"`);
    }
    expect(result).toContain("[Security.Cryptography.SHA256]::Create()");
    expect(result).toContain("$algorithm.Dispose()");
    expect(result).toContain("[IO.FileMode]::CreateNew");
    expect(result).toContain("$stream.Flush($true)");
    expect(result).toContain("[IO.File]::Move($resolvedTemporary, $resolvedResult)");
    expect(parent).toContain("[IO.Directory]::Delete($invocationDirectory, $false)");
    expect(child).toContain("Protect-RisePalsLauncherEvidenceDirectory");
    expect(child).toContain("Remove-RisePalsLauncherExactFile");
  });

  it("contains none of the isolated prohibited native-output patterns", async () => {
    const patterns = (await text("tests/infra/fixtures/prohibited-launcher-patterns.txt"))
      .trim()
      .split(/\r?\n/u);
    for (const script of productionLauncherScripts) {
      const source = await text(script);
      for (const pattern of patterns) {
        expect(source, `${script} contains ${pattern}`).not.toContain(pattern);
      }
    }
  });

  it("passes all PowerShell 5.1 launcher simulations without elevation or host mutation", () => {
    const git = resolve(
      process.env.LOCALAPPDATA ?? "",
      "Programs/PortableGit-2.55.0.3/cmd/git.exe",
    );
    const headResult = spawnSync(
      git,
      [
        "-c",
        "safe.directory=C:/Codex PC SG2/Jeff/risepals",
        "-C",
        repositoryRoot,
        "rev-parse",
        "HEAD",
      ],
      { encoding: "utf8" },
    );
    expect(headResult.status).toBe(0);
    const head = headResult.stdout.trim();
    expect(head).toMatch(/^[a-f0-9]{40}$/u);

    const powerShell = resolve(
      process.env.SystemRoot ?? "C:/Windows",
      "System32/WindowsPowerShell/v1.0/powershell.exe",
    );
    const suite = resolve(
      repositoryRoot,
      "scripts/infra/Test-RisePalsElevatedRehearsalLauncher.ps1",
    );
    const simulation = spawnSync(
      powerShell,
      [
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        suite,
        "-ExpectedRepositoryHead",
        head,
        "-RepositoryRoot",
        repositoryRoot,
      ],
      { encoding: "utf8", timeout: 180_000 },
    );
    expect(simulation.error).toBeUndefined();
    expect(simulation.status, simulation.stderr).toBe(0);
    expect(simulation.stdout).toContain(
      "Rise Pals PowerShell 5.1 elevated-launcher simulation suite PASS (14 cases).",
    );
  }, 190_000);
});
