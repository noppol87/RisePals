import { spawnSync } from "node:child_process";
import { mkdir, mkdtemp, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../..");
const powershell51 = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";

async function createPowerShell7FirstModulePath(): Promise<{
  moduleRoot: string;
  mixedModulePath: string;
}> {
  const moduleRoot = await mkdtemp(join(tmpdir(), "risepals-powershell7-modules-"));
  const moduleDirectory = join(moduleRoot, "Microsoft.PowerShell.Security");
  await mkdir(moduleDirectory);
  await writeFile(
    join(moduleDirectory, "Microsoft.PowerShell.Security.psd1"),
    [
      "@{",
      "  RootModule = 'Microsoft.PowerShell.Security.dll'",
      "  ModuleVersion = '99.0.0'",
      "  GUID = '125f5c1c-1f0d-4f42-897a-815e69e741ae'",
      "  PowerShellVersion = '7.0'",
      "  CmdletsToExport = @('Get-Acl')",
      "}",
      "",
    ].join("\n"),
    "utf8",
  );
  return {
    moduleRoot,
    mixedModulePath: [moduleRoot, process.env.PSModulePath]
      .filter((entry): entry is string => Boolean(entry))
      .join(";"),
  };
}

async function text(relativePath: string): Promise<string> {
  return readFile(resolve(repositoryRoot, relativePath), "utf8");
}

describe("repository-owned Node destination diagnostic", () => {
  it("keeps the future LiveReadOnly path read-only and bound to exact protected paths", async () => {
    const source = await text("scripts/infra/Invoke-RisePalsNodeDestinationDiagnostic.ps1");
    const contract = await text("scripts/infra/node-destination-diagnostic-contract.psm1");
    const bootstrap = await text("scripts/infra/windows-powershell-security-bootstrap.ps1");
    const probeStart = contract.indexOf("function Invoke-RisePalsNodeBoundaryProbe");
    const probeEnd = contract.indexOf("function Get-RisePalsNodeEvidenceDigest", probeStart);
    const protectedProbe = contract.slice(probeStart, probeEnd);

    expect(source).toContain('[ValidateSet("Simulation", "LiveReadOnly")][string]$Mode');
    for (const path of [
      "C:\\RisePals",
      "C:\\RisePals\\tools",
      "C:\\RisePals\\tools\\node",
      "C:\\RisePals\\tools\\node\\24.18.1",
      "C:\\RisePals\\tools\\node\\24.18.1\\node.exe",
    ]) {
      expect(source).toContain(`"${path}"`);
    }
    expect(source).not.toMatch(
      /\b(?:Start-Process|Remove-Item|Copy-Item|Move-Item|Rename-Item|Set-Acl|takeown|icacls|sc\.exe|netsh|Restart-Computer|Stop-Process)\b/iu,
    );
    expect(source).not.toMatch(/\bRunAs\b/u);
    expect(source).not.toMatch(/&\s*\$?destinationRoot|node\.exe\s+["']/u);
    expect(source).toContain("Evidence must remain outside the protected Rise Pals root.");
    expect(source).toContain("ExpectedInventorySha256");
    expect(source).toContain("The evidence boundary contains a reparse point.");
    expect(contract).toContain("Initialize-RisePalsWindowsPowerShellSecurityModule");
    expect(bootstrap).toContain("Join-Path $PSHOME");
    expect(bootstrap).toContain(
      '"Modules\\Microsoft.PowerShell.Security\\Microsoft.PowerShell.Security.psd1"',
    );
    expect(bootstrap).toContain("Assert-RisePalsWindowsPowerShell51Runtime");
    expect(bootstrap).toContain(
      "Import-Module -Name $boundary.manifestPath -Force -Global -PassThru",
    );
    expect(bootstrap).toContain('-Module "Microsoft.PowerShell.Security"');
    expect(bootstrap).toContain("[IO.FileAttributes]::ReparsePoint");
    expect(bootstrap).not.toMatch(/\$env:PSModulePath\s*=/u);
    expect(protectedProbe).toContain("Get-Item -LiteralPath $exactPath -Force -ErrorAction Stop");
    expect(protectedProbe).toContain("Get-Acl -LiteralPath $exactPath -ErrorAction Stop");
    expect(protectedProbe).not.toContain("Directory.Exists");
    expect(protectedProbe).not.toContain("Test-Path");
    expect(protectedProbe).not.toMatch(
      /\b(?:Set-Acl|Remove-Item|Copy-Item|Move-Item|Rename-Item|Start-Process|Stop-Process)\b/iu,
    );
  });

  it("uses component and canonical ancestry validation rather than a relative-path regex", async () => {
    const contract = await text("scripts/infra/node-destination-diagnostic-contract.psm1");
    const start = contract.indexOf("function Resolve-RisePalsNodeRelativePath");
    const end = contract.indexOf("function Get-RisePalsNodeInventoryRecordsDigest", start);
    const validator = contract.slice(start, end);

    expect(validator).toContain("[IO.Path]::IsPathRooted");
    expect(validator).toContain("[StringSplitOptions]::None");
    expect(validator).toContain("[IO.Path]::GetFullPath");
    expect(validator).toContain("[StringComparison]::OrdinalIgnoreCase");
    expect(validator).toContain("GetInvalidFileNameChars");
    expect(validator).toContain("Test-RisePalsNodeReparsePoint");
    expect(validator).not.toMatch(/-(?:c?not)?match\b/iu);
  });

  it("defines closed inventory, evidence and classification contracts", async () => {
    const contract = await text("scripts/infra/node-destination-diagnostic-contract.psm1");
    for (const classification of [
      "version-directory-absent",
      "version-directory-empty",
      "complete-except-node",
      "additional-official-files-missing",
      "unexpected-object-present",
      "file-content-mismatch",
      "object-type-mismatch",
      "reparse-point-present",
      "canonical-ancestry-failure",
      "ACL-boundary-failure",
      "access-denied",
      "node-already-present",
      "unknown-controlled-failure",
    ]) {
      expect(contract).toContain(`"${classification}"`);
    }
    expect(contract).toContain("Assert-RisePalsNodeExactProperties");
    expect(contract).toContain("inventory-duplicate-path");
    expect(contract).toContain("inventory-record-property-set");
    expect(contract).toContain("inventoryFileSha256");
    expect(contract).toContain("rise-pals-node-destination-diagnostic-v2");
    for (const property of [
      "pathId",
      "disposition",
      "objectType",
      "owner",
      "accessRulesProtected",
      "explicitAllowAceCount",
      "inheritedAllowAceCount",
      "denyAceCount",
      "unexpectedAceCount",
      "resolvedAcePrincipals",
      "failedOperation",
      "sanitizedErrorCategory",
      "nativeErrorCode",
      "hResult",
      "protectedWritesAttempted",
    ]) {
      expect(contract).toContain(`"${property}"`);
    }
    for (const stage of [
      "boundary-root",
      "boundary-tools",
      "boundary-node",
      "boundary-version",
      "boundary-executable",
      "boundary-owner",
      "boundary-acl",
      "boundary-reparse",
      "destination-inventory",
      "inventory-comparison",
      "evidence-construction",
      "evidence-persistence",
      "evidence-reopen",
    ]) {
      expect(contract).toContain(`"${stage}"`);
    }
    expect(contract).toContain("evidence-measurement-state");
    expect(contract).toContain("evidence-repair-state");
    expect(contract).toContain("evidence-digest");
    expect(contract).toContain("Write-RisePalsNodeEvidenceAtomic");
    expect(contract).toContain("Read-RisePalsNodeEvidence");
  });

  it("passes PowerShell 5.1 AST validation for every diagnostic script", () => {
    const command = [
      "$files=@(",
      "'scripts\\infra\\node-destination-diagnostic-contract.psm1',",
      "'scripts\\infra\\Invoke-RisePalsNodeDestinationDiagnostic.ps1',",
      "'scripts\\infra\\Test-RisePalsNodeDestinationDiagnostic.ps1',",
      "'scripts\\infra\\node-destination-early-transport.psm1',",
      "'scripts\\infra\\Invoke-RisePalsNodeDestinationDiagnosticChild.ps1',",
      "'scripts\\infra\\Invoke-RisePalsNodeDestinationDiagnosticTransport.ps1',",
      "'scripts\\infra\\Test-RisePalsNodeDestinationEarlyTransport.ps1',",
      "'scripts\\infra\\windows-powershell-security-bootstrap.ps1',",
      "'scripts\\infra\\candidate-rehearsal-transport.ps1',",
      "'scripts\\infra\\Invoke-RisePalsCandidateLiveSequence.ps1'",
      ");",
      "foreach($file in $files){",
      "$tokens=$null;$errors=$null;",
      "[void][Management.Automation.Language.Parser]::ParseFile((Resolve-Path -LiteralPath $file),[ref]$tokens,[ref]$errors);",
      "if($errors.Count -ne 0){exit 41}",
      "}",
    ].join("");
    const result = spawnSync(powershell51, ["-NoLogo", "-NoProfile", "-Command", command], {
      cwd: repositoryRoot,
      encoding: "utf8",
      windowsHide: true,
      timeout: 30_000,
    });
    expect(result.status, `${result.stdout}\n${result.stderr}`).toBe(0);
  });

  it("keeps exact Get-Acl available after the initializer returns under a real mixed module path", async () => {
    const fixture = await createPowerShell7FirstModulePath();
    const helper = resolve(
      repositoryRoot,
      "scripts/infra/windows-powershell-security-bootstrap.ps1",
    );
    const expectedManifest = resolve(
      process.env.SystemRoot ?? "C:/Windows",
      "System32/WindowsPowerShell/v1.0/Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1",
    );
    const environment = { ...process.env, PSModulePath: fixture.mixedModulePath };
    try {
      const command = [
        `$ErrorActionPreference='Stop';$env:PSModulePath='${fixture.moduleRoot};'+$env:PSModulePath;. '${helper}';`,
        "function Invoke-SyntheticConsumer {[void](Initialize-RisePalsWindowsPowerShellSecurityModule)};",
        "Invoke-SyntheticConsumer;",
        "$PSModuleAutoLoadingPreference='None';",
        "$command=Get-Command -Name 'Get-Acl' -CommandType Cmdlet -ErrorAction Stop;",
        "[void](Get-Acl -LiteralPath $env:TEMP -ErrorAction Stop);",
        "[Console]::Out.WriteLine(($env:PSModulePath -split ';')[0]);",
        "[Console]::Out.WriteLine($command.ModuleName);",
        "[Console]::Out.WriteLine($command.Module.Path);",
        "[Console]::Out.WriteLine($command.Module.ModuleBase);",
      ].join("");
      const result = spawnSync(
        powershell51,
        ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", command],
        { cwd: repositoryRoot, encoding: "utf8", env: environment, windowsHide: true },
      );
      expect(result.status, `${result.stdout}\n${result.stderr}`).toBe(0);
      const outputLines = result.stdout.trim().split(/\r?\n/u);
      expect(outputLines).toHaveLength(4);
      const [firstModuleRoot = "", moduleName = "", manifestPath = "", moduleBase = ""] =
        outputLines;
      expect(firstModuleRoot.toLowerCase()).toBe(fixture.moduleRoot.toLowerCase());
      expect(moduleName).toBe("Microsoft.PowerShell.Security");
      expect(manifestPath.toLowerCase()).toBe(expectedManifest.toLowerCase());
      expect(moduleBase.toLowerCase()).toMatch(
        /^c:\\windows\\system32\\windowspowershell\\v1\.0(?:\\|$)/u,
      );
    } finally {
      await rm(fixture.moduleRoot, { recursive: true, force: true });
    }
  });

  it("passes all 45 simulations in separate hidden Windows PowerShell 5.1 processes", async () => {
    const fixture = await createPowerShell7FirstModulePath();
    try {
      const result = spawnSync(
        powershell51,
        [
          "-NoLogo",
          "-NoProfile",
          "-NonInteractive",
          "-ExecutionPolicy",
          "Bypass",
          "-File",
          resolve(repositoryRoot, "scripts/infra/Test-RisePalsNodeDestinationDiagnostic.ps1"),
          "-RepositoryRoot",
          repositoryRoot,
          "-TestOnlyPowerShell7ModuleRoot",
          fixture.moduleRoot,
        ],
        {
          cwd: repositoryRoot,
          encoding: "utf8",
          env: { ...process.env, PSModulePath: fixture.mixedModulePath },
          windowsHide: true,
          timeout: 300_000,
        },
      );
      expect(result.status, `${result.stdout}\n${result.stderr}`).toBe(0);
      const report = JSON.parse(result.stdout) as {
        processCount: number;
        powerShell7FirstModuleRootApplied: boolean;
        bootstrapFailureScenarios: Array<{
          number: number;
          exitCode: number;
          bootstrapStage: string;
          sanitizedCategory: string;
          captureRemoved: boolean;
        }>;
        syntheticCaptureResidue: number;
        scenarios: Array<{ number: number; name: string; result: string }>;
      };
      expect(report.processCount).toBe(45);
      expect(report.powerShell7FirstModuleRootApplied).toBe(true);
      expect(report.bootstrapFailureScenarios).toEqual([
        {
          number: 1,
          exitCode: 61,
          bootstrapStage: "manifest-item",
          sanitizedCategory: "not_found",
          captureRemoved: true,
        },
        {
          number: 2,
          exitCode: 61,
          bootstrapStage: "manifest-reparse",
          sanitizedCategory: "reparse_point",
          captureRemoved: true,
        },
        {
          number: 3,
          exitCode: 61,
          bootstrapStage: "manifest-path",
          sanitizedCategory: "outside_pshome",
          captureRemoved: true,
        },
        {
          number: 4,
          exitCode: 61,
          bootstrapStage: "module-identity",
          sanitizedCategory: "module_mismatch",
          captureRemoved: true,
        },
        {
          number: 5,
          exitCode: 61,
          bootstrapStage: "command-resolution",
          sanitizedCategory: "command_mismatch",
          captureRemoved: true,
        },
      ]);
      expect(report.syntheticCaptureResidue).toBe(0);
      expect(report.scenarios).toHaveLength(45);
      expect(report.scenarios.map(({ number }) => number)).toEqual(
        Array.from({ length: 45 }, (_, index) => index + 1),
      );
      expect(new Set(report.scenarios.map(({ name }) => name)).size).toBe(45);
      expect(
        report.scenarios.every(({ result: scenarioResult }) => scenarioResult === "PASS"),
      ).toBe(true);
    } finally {
      await rm(fixture.moduleRoot, { recursive: true, force: true });
    }
  }, 300_000);

  it("defines a closed digest-bound early transport without changing schema-v2", async () => {
    const early = await text("scripts/infra/node-destination-early-transport.psm1");
    const parent = await text(
      "scripts/infra/Invoke-RisePalsNodeDestinationDiagnosticTransport.ps1",
    );
    const child = await text("scripts/infra/Invoke-RisePalsNodeDestinationDiagnosticChild.ps1");
    for (const stage of [
      "request-created",
      "elevated-launch-attempted",
      "elevated-process-created",
      "bootstrap-entered",
      "security-module-initialized",
      "contract-imported",
      "arguments-validated",
      "diagnostic-dispatched",
      "schema-v2-evidence-persisted",
      "child-exited",
      "parent-reopened-result",
      "cleanup-complete",
    ]) {
      expect(early).toContain(`"${stage}"`);
    }
    for (const property of [
      "authorizationId",
      "invocationNonce",
      "repositoryHead",
      "launcherSha256",
      "securityBootstrapSha256",
      "childSha256",
      "processCreated",
      "childExitCode",
      "firstFailedStage",
      "sanitizedFailureCategory",
      "nativeErrorCode",
      "hResult",
      "schemaV2EvidencePresent",
      "schemaV2EvidenceDigest",
      "cleanupAttempted",
      "cleanupCompleted",
      "transientResidueCount",
      "temporaryResidueCount",
      "evidenceDigest",
    ]) {
      expect(early).toContain(property);
    }
    expect(parent).toContain("Write-RisePalsNodeEarlyRequestAtomic");
    expect(parent).toContain("Read-RisePalsNodeEarlyRequest");
    expect(parent).toContain("Write-RisePalsNodeEarlyResultAtomic");
    expect(parent).toContain("Read-RisePalsNodeEarlyResult");
    expect(parent).toContain("-Verb RunAs");
    expect(parent).toContain('if ($Mode -ceq "LiveReadOnly")');
    expect(parent).not.toContain(".env.local");
    expect(child.indexOf("node-destination-early-transport.psm1")).toBeLessThan(
      child.indexOf("node-destination-diagnostic-contract.psm1"),
    );
    expect(child).toContain("bootstrap-entered");
    expect(child).toContain("schema-v2-evidence-persisted");
    expect(child).not.toContain("Write-Output");
    expect(child).not.toContain("Write-Error");
    expect(early).not.toMatch(/(?:exceptionMessage|stackTrace|commandLine|rawStdout|rawStderr)/u);
  });

  it("passes all 16 durable early-transport simulations in hidden Windows PowerShell 5.1 processes", async () => {
    const fixture = await createPowerShell7FirstModulePath();
    try {
      const result = spawnSync(
        powershell51,
        [
          "-NoLogo",
          "-NoProfile",
          "-NonInteractive",
          "-ExecutionPolicy",
          "Bypass",
          "-File",
          resolve(repositoryRoot, "scripts/infra/Test-RisePalsNodeDestinationEarlyTransport.ps1"),
          "-RepositoryRoot",
          repositoryRoot,
          "-TestOnlyPowerShell7ModuleRoot",
          fixture.moduleRoot,
        ],
        {
          cwd: repositoryRoot,
          encoding: "utf8",
          env: { ...process.env, PSModulePath: fixture.mixedModulePath },
          windowsHide: true,
          timeout: 300_000,
        },
      );
      expect(result.status, `${result.stdout}\n${result.stderr}`).toBe(0);
      const report = JSON.parse(result.stdout) as {
        processCount: number;
        powerShell7FirstModuleRootApplied: boolean;
        temporaryWorkspaceRemovedAfterReport: boolean;
        scenarios: Array<{
          number: number;
          name: string;
          independentReopen: boolean;
          digestValidated: boolean;
          bindingVariantsRejected: number;
          staleRequestRejected: boolean;
        }>;
      };
      expect(report.processCount).toBe(16);
      expect(report.powerShell7FirstModuleRootApplied).toBe(true);
      expect(report.temporaryWorkspaceRemovedAfterReport).toBe(true);
      expect(report.scenarios).toHaveLength(16);
      expect(report.scenarios.map(({ number }) => number)).toEqual(
        Array.from({ length: 16 }, (_, index) => index + 1),
      );
      expect(new Set(report.scenarios.map(({ name }) => name)).size).toBe(16);
      expect(
        report.scenarios.every(
          ({ independentReopen, digestValidated }) => independentReopen && digestValidated,
        ),
      ).toBe(true);
      expect(report.scenarios[10]?.bindingVariantsRejected).toBe(3);
      expect(report.scenarios[11]?.staleRequestRejected).toBe(true);
    } finally {
      await rm(fixture.moduleRoot, { recursive: true, force: true });
    }
  }, 300_000);

  it("is not imported by application client routes or components", async () => {
    const roots = ["src/app", "src/components"];
    const candidates: string[] = [];
    for (const root of roots) {
      const walk = async (directory: string): Promise<void> => {
        for (const entry of await readdir(resolve(repositoryRoot, directory), {
          withFileTypes: true,
        })) {
          const relative = `${directory}/${entry.name}`;
          if (entry.isDirectory()) await walk(relative);
          else if (/\.(?:ts|tsx|js|jsx)$/u.test(entry.name)) candidates.push(relative);
        }
      };
      await walk(root);
    }
    const combined = (await Promise.all(candidates.map((candidate) => text(candidate)))).join("\n");
    expect(combined).not.toContain("node-destination-diagnostic");
    expect(combined).not.toContain("Invoke-RisePalsNodeDestinationDiagnostic");
  });
});
