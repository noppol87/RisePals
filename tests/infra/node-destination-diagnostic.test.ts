import { spawnSync } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../..");
const powershell51 = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";

async function text(relativePath: string): Promise<string> {
  return readFile(resolve(repositoryRoot, relativePath), "utf8");
}

describe("repository-owned Node destination diagnostic", () => {
  it("keeps the future LiveReadOnly path read-only and bound to exact protected paths", async () => {
    const source = await text("scripts/infra/Invoke-RisePalsNodeDestinationDiagnostic.ps1");
    const contract = await text("scripts/infra/node-destination-diagnostic-contract.psm1");
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
      "'scripts\\infra\\Test-RisePalsNodeDestinationDiagnostic.ps1'",
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

  it("passes all 45 simulations in separate hidden Windows PowerShell 5.1 processes", () => {
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
      ],
      {
        cwd: repositoryRoot,
        encoding: "utf8",
        windowsHide: true,
        timeout: 300_000,
      },
    );
    expect(result.status, `${result.stdout}\n${result.stderr}`).toBe(0);
    const report = JSON.parse(result.stdout) as {
      processCount: number;
      scenarios: Array<{ number: number; name: string; result: string }>;
    };
    expect(report.processCount).toBe(45);
    expect(report.scenarios).toHaveLength(45);
    expect(report.scenarios.map(({ number }) => number)).toEqual(
      Array.from({ length: 45 }, (_, index) => index + 1),
    );
    expect(new Set(report.scenarios.map(({ name }) => name)).size).toBe(45);
    expect(report.scenarios.every(({ result: scenarioResult }) => scenarioResult === "PASS")).toBe(
      true,
    );
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
