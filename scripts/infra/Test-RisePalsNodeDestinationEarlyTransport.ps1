[CmdletBinding()]
param(
  [string]$RepositoryRoot = "C:\Codex PC SG2\Jeff\risepals",
  [ValidateRange(0, 16)][int]$WorkerScenario = 0,
  [string]$WorkspaceRoot,
  [string]$TestOnlyPowerShell7ModuleRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$scripts = Join-Path $repository "scripts\infra"
$earlyContractPath = Join-Path $scripts "node-destination-early-transport.psm1"
$diagnosticContractPath = Join-Path $scripts "node-destination-diagnostic-contract.psm1"
$transportPath = Join-Path $scripts "Invoke-RisePalsNodeDestinationDiagnosticTransport.ps1"
$powershell51 = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

if (-not [string]::IsNullOrWhiteSpace($TestOnlyPowerShell7ModuleRoot)) {
  $moduleRoot = [IO.Path]::GetFullPath($TestOnlyPowerShell7ModuleRoot).TrimEnd('\')
  $manifest = Join-Path $moduleRoot `
    "Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1"
  if (-not $moduleRoot.StartsWith($temporaryRoot + "\", [StringComparison]::OrdinalIgnoreCase) -or
    -not [IO.File]::Exists($manifest)) {
    throw "The test-only mixed module-path fixture is invalid."
  }
  $env:PSModulePath = $moduleRoot + ";" + $env:PSModulePath
}

Import-Module -Name $earlyContractPath -Force -ErrorAction Stop
Import-Module -Name $diagnosticContractPath -Force -ErrorAction Stop

$scenarioNames = @(
  "Success", "LaunchFailure", "BootstrapEntryFailure", "SecurityModuleFailure",
  "ContractImportFailure", "ArgumentValidationFailure",
  "EvidenceDirectoryValidationFailure", "DiagnosticPreDispatchFailure",
  "ChildNonzeroBeforeEvidence", "MalformedEarlyRecord", "WrongBinding",
  "StaleOrReplay", "EarlySchemaDigestMismatch", "InterruptedAtomicWrite",
  "CleanupFailure", "FinalResultPersistenceFailure"
)
$expectations = @(
  [pscustomobject]@{ process = $true; exit = 0; stage = $null; category = $null; schema = $true; cleanup = $true },
  [pscustomobject]@{ process = $false; exit = $null; stage = "elevated-process-created"; category = "launch_failure"; schema = $false; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 71; stage = "bootstrap-entered"; category = "bootstrap_entry_failure"; schema = $false; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 72; stage = "security-module-initialized"; category = "security_module_failure"; schema = $false; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 73; stage = "contract-imported"; category = "contract_import_failure"; schema = $false; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 74; stage = "arguments-validated"; category = "argument_validation_failure"; schema = $false; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 75; stage = "diagnostic-dispatched"; category = "evidence_directory_failure"; schema = $false; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 76; stage = "diagnostic-dispatched"; category = "dispatch_failure"; schema = $false; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 78; stage = "schema-v2-evidence-persisted"; category = "child_exit_failure"; schema = $false; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 0; stage = "bootstrap-entered"; category = "malformed_evidence"; schema = $false; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 0; stage = "bootstrap-entered"; category = "binding_failure"; schema = $false; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 0; stage = "schema-v2-evidence-persisted"; category = "replay_failure"; schema = $true; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 0; stage = "schema-v2-evidence-persisted"; category = "evidence_mismatch"; schema = $false; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 79; stage = "bootstrap-entered"; category = "atomic_write_failure"; schema = $false; cleanup = $true },
  [pscustomobject]@{ process = $true; exit = 0; stage = "cleanup-complete"; category = "cleanup_failure"; schema = $true; cleanup = $false },
  [pscustomobject]@{ process = $true; exit = 0; stage = "parent-reopened-result"; category = "final_result_failure"; schema = $true; cleanup = $true }
)

function Assert-RisePalsNodeEarlyTest {
  param([bool]$Condition, [string]$Label)
  if (-not $Condition) { throw $Label }
}

function Test-RisePalsNodeEarlyControlledRejection {
  param([scriptblock]$Action)
  try {
    & $Action
  } catch {
    return $true
  }
  return $false
}

function Write-RisePalsNodeEarlyFixtureFile {
  param([string]$Path, [string]$Value)
  [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
  [IO.File]::WriteAllText($Path, $Value, [Text.UTF8Encoding]::new($false))
}

function New-RisePalsNodeEarlyFixtureDistribution {
  param([string]$Root)
  [IO.Directory]::CreateDirectory((Join-Path $Root "lib")) | Out-Null
  Write-RisePalsNodeEarlyFixtureFile -Path (Join-Path $Root "node.exe") `
    -Value "synthetic-node-binary"
  Write-RisePalsNodeEarlyFixtureFile -Path (Join-Path $Root "node.dll") `
    -Value "synthetic-node-library"
  Write-RisePalsNodeEarlyFixtureFile -Path (Join-Path $Root "lib\runtime.txt") `
    -Value "synthetic-runtime"
  Write-RisePalsNodeEarlyFixtureFile -Path (Join-Path $Root "README.md") `
    -Value "synthetic fixture only"
}

function Get-RisePalsNodeEarlyHarnessHead {
  $head = (& git -c ("safe.directory={0}" -f $repository.Replace("\", "/")) `
    -C $repository rev-parse HEAD 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or $head -cnotmatch "^[a-f0-9]{40}$") {
    throw "Repository HEAD unavailable."
  }
  return $head
}

function Invoke-RisePalsNodeEarlyWorker {
  param([int]$Number, [string]$Root)
  $caseRoot = Join-Path $Root ("case-{0:d2}" -f $Number)
  $sourceRoot = Join-Path $caseRoot "source"
  $simulationRoot = Join-Path $caseRoot "destination"
  $destinationVersion = Join-Path $simulationRoot "tools\node\24.18.1"
  $evidenceRoot = Join-Path $caseRoot "evidence"
  [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
  New-RisePalsNodeEarlyFixtureDistribution -Root $sourceRoot
  New-RisePalsNodeEarlyFixtureDistribution -Root $destinationVersion
  [IO.Directory]::CreateDirectory($evidenceRoot) | Out-Null
  $inventory = New-RisePalsNodeInventory -Root $sourceRoot
  $inventoryPath = Join-Path $caseRoot "official-inventory.json"
  [IO.File]::WriteAllText($inventoryPath, ($inventory | ConvertTo-Json -Depth 12),
    [Text.UTF8Encoding]::new($false))
  $head = Get-RisePalsNodeEarlyHarnessHead
  $nonce = "{0:x32}" -f $Number
  $authorization = "RP-TURN-019-R4-NODE-DIAG4-SIMULATION"
  $scenario = [string]$scenarioNames[$Number - 1]
  $expected = $expectations[$Number - 1]

  $transport = & $transportPath -Mode Simulation -AuthorizationId $authorization `
    -InvocationNonce $nonce -RepositoryHead $head -InventoryPath $inventoryPath `
    -EvidenceDirectory $evidenceRoot -RepositoryRoot $repository `
    -SimulationRoot $simulationRoot -Scenario $scenario -ReturnResult

  $request = Read-RisePalsNodeEarlyRequest -Path $transport.requestPath `
    -ExpectedAuthorizationId $authorization -ExpectedInvocationNonce $nonce `
    -ExpectedRepositoryHead $head `
    -ExpectedLauncherSha256 $transport.request.launcherSha256 `
    -ExpectedEarlyContractSha256 $transport.request.earlyContractSha256 `
    -ExpectedSecurityBootstrapSha256 $transport.request.securityBootstrapSha256 `
    -ExpectedChildSha256 $transport.request.childSha256 `
    -ExpectedDiagnosticSha256 $transport.request.diagnosticSha256 `
    -ExpectedDiagnosticContractSha256 $transport.request.diagnosticContractSha256 `
    -ExpectedInventorySha256 $transport.request.inventorySha256
  $checkpoint = Read-RisePalsNodeEarlyResult -Path $transport.checkpointPath `
    -Request $request
  $result = Read-RisePalsNodeEarlyResult -Path $transport.resultPath -Request $request `
    -ExpectedCheckpointDigest $checkpoint.evidenceDigest

  Assert-RisePalsNodeEarlyTest -Condition ([bool]$result.processCreated -eq $expected.process) `
    -Label "Scenario $Number process-created mismatch."
  $exitMatches = if ($null -eq $expected.exit) {
    $null -eq $result.childExitCode
  } else {
    [int]$result.childExitCode -eq [int]$expected.exit
  }
  Assert-RisePalsNodeEarlyTest -Condition $exitMatches `
    -Label "Scenario $Number child-exit mismatch."
  Assert-RisePalsNodeEarlyTest `
    -Condition ([string]$result.firstFailedStage -ceq [string]$expected.stage) `
    -Label "Scenario $Number failed-stage mismatch."
  Assert-RisePalsNodeEarlyTest `
    -Condition ([string]$result.sanitizedFailureCategory -ceq [string]$expected.category) `
    -Label "Scenario $Number failure-category mismatch."
  Assert-RisePalsNodeEarlyTest `
    -Condition ([bool]$result.schemaV2EvidencePresent -eq [bool]$expected.schema) `
    -Label "Scenario $Number schema-v2 disposition mismatch."
  Assert-RisePalsNodeEarlyTest `
    -Condition ([bool]$result.cleanupCompleted -eq [bool]$expected.cleanup) `
    -Label "Scenario $Number cleanup disposition mismatch."
  Assert-RisePalsNodeEarlyTest `
    -Condition (Test-RisePalsNodeEarlyHash $result.evidenceDigest) `
    -Label "Scenario $Number result digest was invalid."
  if ([bool]$expected.cleanup) {
    Assert-RisePalsNodeEarlyTest -Condition ([int]$result.transientResidueCount -eq 0 -and
      [int]$result.temporaryResidueCount -eq 0) `
      -Label "Scenario $Number retained unexpected residue."
  } else {
    Assert-RisePalsNodeEarlyTest -Condition ([int]$result.transientResidueCount -gt 0) `
      -Label "Scenario $Number did not expose its controlled cleanup residue."
  }
  if ([bool]$expected.schema) {
    $schema = Read-RisePalsNodeEvidence -LiteralPath $transport.schemaV2EvidencePath `
      -AuthorizationId $authorization -InvocationNonce $nonce -RepositoryHead $head `
      -ScriptSha256 $request.diagnosticSha256 `
      -InventoryFileSha256 $request.inventorySha256
    Assert-RisePalsNodeEarlyTest `
      -Condition ([string]$schema.evidenceDigest -ceq [string]$result.schemaV2EvidenceDigest) `
      -Label "Scenario $Number schema-v2 digest mismatch."
  }
  $bindingVariantsRejected = 0
  if ($Number -eq 11) {
    foreach ($mutation in @(
        [pscustomobject]@{ name = "invocationNonce"; value = "ffffffffffffffffffffffffffffffff" },
        [pscustomobject]@{ name = "repositoryHead"; value = "ffffffffffffffffffffffffffffffffffffffff" },
        [pscustomobject]@{ name = "childSha256"; value = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" }
      )) {
      $copy = (($request | ConvertTo-Json -Compress -Depth 8) | ConvertFrom-Json)
      $copy.($mutation.name) = $mutation.value
      $copy.requestDigest = Get-RisePalsNodeEarlyRequestDigest -Request $copy
      if (Test-RisePalsNodeEarlyControlledRejection -Action {
          [void](Assert-RisePalsNodeEarlyRequest -Request $copy `
              -ExpectedAuthorizationId $authorization -ExpectedInvocationNonce $nonce `
              -ExpectedRepositoryHead $head `
              -ExpectedLauncherSha256 $request.launcherSha256 `
              -ExpectedEarlyContractSha256 $request.earlyContractSha256 `
              -ExpectedSecurityBootstrapSha256 $request.securityBootstrapSha256 `
              -ExpectedChildSha256 $request.childSha256 `
              -ExpectedDiagnosticSha256 $request.diagnosticSha256 `
              -ExpectedDiagnosticContractSha256 $request.diagnosticContractSha256 `
              -ExpectedInventorySha256 $request.inventorySha256)
        }) {
        $bindingVariantsRejected++
      }
    }
    Assert-RisePalsNodeEarlyTest -Condition ($bindingVariantsRejected -eq 3) `
      -Label "Scenario 11 did not reject nonce, head and child-script hash independently."
  }
  $staleRequestRejected = $false
  if ($Number -eq 12) {
    $stale = New-RisePalsNodeEarlyRequest -AuthorizationId $authorization `
      -InvocationNonce $nonce -RepositoryHead $head `
      -LauncherSha256 $request.launcherSha256 `
      -EarlyContractSha256 $request.earlyContractSha256 `
      -SecurityBootstrapSha256 $request.securityBootstrapSha256 `
      -ChildSha256 $request.childSha256 -DiagnosticSha256 $request.diagnosticSha256 `
      -DiagnosticContractSha256 $request.diagnosticContractSha256 `
      -InventorySha256 $request.inventorySha256 -CreatedUtc ([datetime]::UtcNow.AddMinutes(-10))
    $staleRequestRejected = Test-RisePalsNodeEarlyControlledRejection -Action {
      [void](Assert-RisePalsNodeEarlyRequest -Request $stale `
          -ExpectedAuthorizationId $authorization -ExpectedInvocationNonce $nonce `
          -ExpectedRepositoryHead $head `
          -ExpectedLauncherSha256 $request.launcherSha256 `
          -ExpectedEarlyContractSha256 $request.earlyContractSha256 `
          -ExpectedSecurityBootstrapSha256 $request.securityBootstrapSha256 `
          -ExpectedChildSha256 $request.childSha256 `
          -ExpectedDiagnosticSha256 $request.diagnosticSha256 `
          -ExpectedDiagnosticContractSha256 $request.diagnosticContractSha256 `
          -ExpectedInventorySha256 $request.inventorySha256 `
          -ValidationUtc ([datetime]::UtcNow) -MaximumAgeSeconds 300)
    }
    Assert-RisePalsNodeEarlyTest -Condition $staleRequestRejected `
      -Label "Scenario 12 did not reject the stale request."
  }
  $report = [pscustomobject][ordered]@{
    schemaVersion = "rise-pals-node-early-transport-simulation-v1"
    number = $Number
    name = $scenario
    processCreated = [bool]$result.processCreated
    childExitCode = $result.childExitCode
    firstFailedStage = $result.firstFailedStage
    sanitizedFailureCategory = $result.sanitizedFailureCategory
    schemaV2EvidencePresent = [bool]$result.schemaV2EvidencePresent
    cleanupCompleted = [bool]$result.cleanupCompleted
    transientResidueCount = [int]$result.transientResidueCount
    temporaryResidueCount = [int]$result.temporaryResidueCount
    independentReopen = $true
    digestValidated = $true
    bindingVariantsRejected = $bindingVariantsRejected
    staleRequestRejected = $staleRequestRejected
  }
  $reportPath = Join-Path $Root ("report-{0:d2}.json" -f $Number)
  [IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Compress),
    [Text.UTF8Encoding]::new($false))
}

if ($WorkerScenario -gt 0) {
  if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { throw "WorkspaceRoot is required." }
  $workspace = [IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\')
  if (-not $workspace.StartsWith($temporaryRoot + "\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "The worker workspace must remain beneath the temporary root."
  }
  Invoke-RisePalsNodeEarlyWorker -Number $WorkerScenario -Root $workspace
  exit 0
}

if (-not [IO.File]::Exists($powershell51)) { throw "Windows PowerShell 5.1 is unavailable." }
$workspace = Join-Path ([IO.Path]::GetTempPath()) `
  ("risepals-node-early-transport-{0}" -f [Guid]::NewGuid().ToString("N"))
[IO.Directory]::CreateDirectory($workspace) | Out-Null
$reports = @()
try {
  for ($number = 1; $number -le 16; $number++) {
    $arguments = @(
      "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
      "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path),
      "-RepositoryRoot", ('"{0}"' -f $repository),
      "-WorkerScenario", [string]$number,
      "-WorkspaceRoot", ('"{0}"' -f $workspace)
    )
    if (-not [string]::IsNullOrWhiteSpace($TestOnlyPowerShell7ModuleRoot)) {
      $arguments += @(
        "-TestOnlyPowerShell7ModuleRoot", ('"{0}"' -f $moduleRoot)
      )
    }
    $process = Start-Process -FilePath $powershell51 -ArgumentList $arguments `
      -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) {
      throw "Early transport scenario $number failed in its isolated process."
    }
    $reportPath = Join-Path $workspace ("report-{0:d2}.json" -f $number)
    if (-not [IO.File]::Exists($reportPath)) {
      throw "Early transport scenario $number did not persist its report."
    }
    $report = [IO.File]::ReadAllText($reportPath) | ConvertFrom-Json -ErrorAction Stop
    Assert-RisePalsNodeEarlyExactProperties -Value $report -Names @(
      "schemaVersion", "number", "name", "processCreated", "childExitCode",
      "firstFailedStage", "sanitizedFailureCategory", "schemaV2EvidencePresent",
      "cleanupCompleted", "transientResidueCount", "temporaryResidueCount",
      "independentReopen", "digestValidated", "bindingVariantsRejected",
      "staleRequestRejected"
    ) -Predicate "simulation-report-property"
    if ([int]$report.number -ne $number -or
      [string]$report.name -cne [string]$scenarioNames[$number - 1] -or
      -not [bool]$report.independentReopen -or -not [bool]$report.digestValidated) {
      throw "Early transport scenario $number report failed closed validation."
    }
    if (($number -eq 11 -and [int]$report.bindingVariantsRejected -ne 3) -or
      ($number -ne 11 -and [int]$report.bindingVariantsRejected -ne 0) -or
      ($number -eq 12 -and -not [bool]$report.staleRequestRejected) -or
      ($number -ne 12 -and [bool]$report.staleRequestRejected)) {
      throw "Early transport scenario $number binding/staleness evidence was invalid."
    }
    $reports += $report
  }
  [pscustomobject][ordered]@{
    schemaVersion = "rise-pals-node-early-transport-harness-v1"
    processCount = $reports.Count
    powerShell = $powershell51
    powerShell7FirstModuleRootApplied = -not [string]::IsNullOrWhiteSpace(
      $TestOnlyPowerShell7ModuleRoot
    )
    temporaryWorkspaceRemovedAfterReport = $true
    scenarios = $reports
  } | ConvertTo-Json -Depth 6
} finally {
  if ([IO.Directory]::Exists($workspace)) {
    Remove-Item -LiteralPath $workspace -Recurse -Force
  }
}
