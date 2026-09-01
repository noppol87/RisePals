[CmdletBinding()]
param(
  [string]$RepositoryRoot = "C:\Codex PC SG2\Jeff\risepals",
  [ValidateRange(0, 25)][int]$WorkerScenario = 0,
  [string]$WorkspaceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$scripts = Join-Path $repository "scripts\infra"
$contractPath = Join-Path $scripts "node-destination-diagnostic-contract.psm1"
$diagnosticPath = Join-Path $scripts "Invoke-RisePalsNodeDestinationDiagnostic.ps1"
Import-Module -Name $contractPath -Force -ErrorAction Stop

$scenarioNames = @(
  "complete-except-node",
  "complete-including-node",
  "version-directory-absent",
  "empty-version-directory",
  "additional-official-file-missing",
  "unexpected-file",
  "unexpected-directory",
  "content-mismatch",
  "object-type-mismatch",
  "root-reparse-point",
  "child-reparse-path-escape",
  "canonical-ancestry-failure",
  "controlled-access-denied",
  "rooted-inventory-path",
  "dot-component",
  "dot-dot-component",
  "empty-component",
  "duplicate-path",
  "invalid-file-hash",
  "invalid-record-property-set",
  "truncated-evidence",
  "digest-tampering",
  "initialized-values-falsely-measured",
  "inconsistent-node-repair",
  "unknown-classification"
)

function Assert-RisePalsNodeTest {
  param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Label)
  if (-not $Condition) { throw $Label }
}

function Assert-RisePalsNodeThrowsPredicate {
  param([Parameter(Mandatory = $true)][scriptblock]$Action, [Parameter(Mandatory = $true)][string]$Predicate)
  try {
    & $Action
  } catch {
    if ([string]$_.Exception.Message -like "$Predicate|*") { return }
    throw "Expected $Predicate but received a different controlled failure."
  }
  throw "Expected $Predicate rejection."
}

function Copy-RisePalsNodeJsonObject {
  param([Parameter(Mandatory = $true)][object]$Value)
  return (($Value | ConvertTo-Json -Depth 20 -Compress) | ConvertFrom-Json)
}

function Write-RisePalsNodeFixtureFile {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Value)
  $parent = Split-Path -Parent $Path
  [IO.Directory]::CreateDirectory($parent) | Out-Null
  [IO.File]::WriteAllText($Path, $Value, [Text.UTF8Encoding]::new($false))
}

function New-RisePalsNodeFixtureDistribution {
  param([Parameter(Mandatory = $true)][string]$Root)
  [IO.Directory]::CreateDirectory((Join-Path $Root "lib")) | Out-Null
  Write-RisePalsNodeFixtureFile -Path (Join-Path $Root "node.exe") -Value "synthetic-node-binary"
  Write-RisePalsNodeFixtureFile -Path (Join-Path $Root "node.dll") -Value "synthetic-node-library"
  Write-RisePalsNodeFixtureFile -Path (Join-Path $Root "lib\runtime.txt") -Value "synthetic-runtime"
  Write-RisePalsNodeFixtureFile -Path (Join-Path $Root "README.md") -Value "synthetic fixture only"
}

function Write-RisePalsNodeJson {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][object]$Value)
  [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
}

function Get-RisePalsNodeHarnessHead {
  $head = (& git -c ("safe.directory={0}" -f $repository.Replace("\", "/")) `
    -C $repository rev-parse HEAD 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or $head -cnotmatch "^[a-f0-9]{40}$") {
    throw "Repository HEAD unavailable."
  }
  return $head
}

function Invoke-RisePalsNodeWorkerScenario {
  param([Parameter(Mandatory = $true)][int]$Scenario, [Parameter(Mandatory = $true)][string]$Root)

  $caseRoot = Join-Path $Root ("case-{0:d2}" -f $Scenario)
  $sourceRoot = Join-Path $caseRoot "source"
  $destinationRoot = Join-Path $caseRoot "destination"
  $evidenceRoot = Join-Path $caseRoot "evidence"
  [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
  New-RisePalsNodeFixtureDistribution -Root $sourceRoot
  $official = New-RisePalsNodeInventory -Root $sourceRoot
  $inventoryPath = Join-Path $caseRoot "official-inventory.json"
  Write-RisePalsNodeJson -Path $inventoryPath -Value $official
  $head = Get-RisePalsNodeHarnessHead
  $scriptHash = Get-RisePalsNodeSha256File -LiteralPath $diagnosticPath
  $inventoryHash = Get-RisePalsNodeSha256File -LiteralPath $inventoryPath
  $nonce = ("{0:x32}" -f $Scenario)
  $authorization = "RP-TURN-019-R4-NODE-DIAG2-SIMULATION"

  function Invoke-TestDiagnostic {
    param([string]$Fault = "None", [string]$RootOverride = $destinationRoot)
    return & $diagnosticPath -Mode Simulation -AuthorizationId $authorization `
      -InvocationNonce $nonce -RepositoryHead $head -ExpectedScriptSha256 $scriptHash `
      -ExpectedInventorySha256 $inventoryHash `
      -InventoryPath $inventoryPath -EvidenceDirectory $evidenceRoot `
      -RepositoryRoot $repository -SimulationRoot $RootOverride -SimulationFault $Fault
  }

  function Assert-DiagnosticClassification {
    param([Parameter(Mandatory = $true)][string]$Expected, [bool]$RepairSafe = $false)
    $result = Invoke-TestDiagnostic
    $evidence = Read-RisePalsNodeEvidence -LiteralPath $result.evidencePath `
      -AuthorizationId $authorization -InvocationNonce $nonce -RepositoryHead $head `
      -ScriptSha256 $scriptHash -InventoryFileSha256 $inventoryHash
    Assert-RisePalsNodeTest -Condition ([string]$evidence.classification -ceq $Expected) `
      -Label "Unexpected classification for scenario $Scenario."
    Assert-RisePalsNodeTest -Condition ([bool]$evidence.nodeExeOnlyRepairSafe -eq $RepairSafe) `
      -Label "Unexpected repair disposition for scenario $Scenario."
  }

  if ($Scenario -in 1..13) {
    switch ($Scenario) {
      1 {
        New-RisePalsNodeFixtureDistribution -Root $destinationRoot
        [IO.File]::Delete((Join-Path $destinationRoot "node.exe"))
        Assert-DiagnosticClassification -Expected "complete-except-node" -RepairSafe $true
      }
      2 {
        New-RisePalsNodeFixtureDistribution -Root $destinationRoot
        Assert-DiagnosticClassification -Expected "node-already-present"
      }
      3 { Assert-DiagnosticClassification -Expected "version-directory-absent" }
      4 {
        [IO.Directory]::CreateDirectory($destinationRoot) | Out-Null
        Assert-DiagnosticClassification -Expected "version-directory-empty"
      }
      5 {
        New-RisePalsNodeFixtureDistribution -Root $destinationRoot
        [IO.File]::Delete((Join-Path $destinationRoot "node.exe"))
        [IO.File]::Delete((Join-Path $destinationRoot "node.dll"))
        Assert-DiagnosticClassification -Expected "additional-official-files-missing"
      }
      6 {
        New-RisePalsNodeFixtureDistribution -Root $destinationRoot
        Write-RisePalsNodeFixtureFile -Path (Join-Path $destinationRoot "unexpected.txt") -Value "extra"
        Assert-DiagnosticClassification -Expected "unexpected-object-present"
      }
      7 {
        New-RisePalsNodeFixtureDistribution -Root $destinationRoot
        [IO.Directory]::CreateDirectory((Join-Path $destinationRoot "unexpected-directory")) | Out-Null
        Assert-DiagnosticClassification -Expected "unexpected-object-present"
      }
      8 {
        New-RisePalsNodeFixtureDistribution -Root $destinationRoot
        Write-RisePalsNodeFixtureFile -Path (Join-Path $destinationRoot "node.dll") -Value "changed"
        Assert-DiagnosticClassification -Expected "file-content-mismatch"
      }
      9 {
        New-RisePalsNodeFixtureDistribution -Root $destinationRoot
        [IO.File]::Delete((Join-Path $destinationRoot "node.dll"))
        [IO.Directory]::CreateDirectory((Join-Path $destinationRoot "node.dll")) | Out-Null
        Assert-DiagnosticClassification -Expected "object-type-mismatch"
      }
      10 {
        $target = Join-Path $caseRoot "junction-target"
        New-RisePalsNodeFixtureDistribution -Root $target
        [void](New-Item -ItemType Junction -Path $destinationRoot -Target $target -Force)
        Assert-DiagnosticClassification -Expected "reparse-point-present"
      }
      11 {
        New-RisePalsNodeFixtureDistribution -Root $destinationRoot
        $outside = Join-Path $caseRoot "outside-target"
        [IO.Directory]::CreateDirectory($outside) | Out-Null
        [void](New-Item -ItemType Junction -Path (Join-Path $destinationRoot "escaped") `
          -Target $outside -Force)
        Assert-DiagnosticClassification -Expected "reparse-point-present"
      }
      12 {
        $result = Invoke-TestDiagnostic -Fault "CanonicalAncestryFailure"
        $evidence = Read-RisePalsNodeEvidence -LiteralPath $result.evidencePath `
          -AuthorizationId $authorization -InvocationNonce $nonce -RepositoryHead $head `
          -ScriptSha256 $scriptHash -InventoryFileSha256 $inventoryHash
        Assert-RisePalsNodeTest -Condition ($evidence.classification -ceq "canonical-ancestry-failure") `
          -Label "Canonical ancestry failure was not preserved."
      }
      13 {
        $result = Invoke-TestDiagnostic -Fault "AccessDenied"
        $evidence = Read-RisePalsNodeEvidence -LiteralPath $result.evidencePath `
          -AuthorizationId $authorization -InvocationNonce $nonce -RepositoryHead $head `
          -ScriptSha256 $scriptHash -InventoryFileSha256 $inventoryHash
        Assert-RisePalsNodeTest -Condition ($evidence.classification -ceq "access-denied") `
          -Label "Controlled access denial was not preserved."
      }
    }
  } elseif ($Scenario -in 14..20) {
    $invalid = Copy-RisePalsNodeJsonObject -Value $official
    $file = @($invalid.records | Where-Object { $_.type -ceq "file" })[0]
    $expectedPredicate = "inventory-relative-path"
    switch ($Scenario) {
      14 { $file.relativePath = "C:/rooted.txt" }
      15 { $file.relativePath = "." }
      16 { $file.relativePath = ".." }
      17 { $file.relativePath = "lib//empty.txt" }
      18 {
        $invalid.records += Copy-RisePalsNodeJsonObject -Value $invalid.records[0]
        $invalid.recordCount = @($invalid.records).Count
        $invalid.fileCount = @($invalid.records | Where-Object { $_.type -ceq "file" }).Count
        $invalid.directoryCount = @($invalid.records | Where-Object { $_.type -ceq "directory" }).Count
        $invalid.recordsDigest = Get-RisePalsNodeInventoryRecordsDigest -Records @($invalid.records)
        $expectedPredicate = "inventory-duplicate-path"
      }
      19 {
        $file.sha256 = "not-a-sha256"
        $expectedPredicate = "inventory-file-metadata"
      }
      20 {
        Add-Member -InputObject $file -NotePropertyName "unexpected" -NotePropertyValue $true
        $expectedPredicate = "inventory-record-property-set"
      }
    }
    if ($Scenario -in 14..17) {
      $invalid.recordsDigest = Get-RisePalsNodeInventoryRecordsDigest -Records @($invalid.records)
    }
    Write-RisePalsNodeJson -Path $inventoryPath -Value $invalid
    $inventoryHash = Get-RisePalsNodeSha256File -LiteralPath $inventoryPath
    Assert-RisePalsNodeThrowsPredicate -Predicate $expectedPredicate -Action { Invoke-TestDiagnostic }
  } else {
    New-RisePalsNodeFixtureDistribution -Root $destinationRoot
    $measurement = New-RisePalsNodeMeasurement -State measured -Inventory $official
    $comparison = Compare-RisePalsNodeInventories -Expected $official -Actual $official
    $boundary = [pscustomobject][ordered]@{
      state = "measured"; rootCanonical = $true; rootReparse = $false; ancestryValid = $true
      ownerReadSucceeded = $true; aclReadSucceeded = $true; accessDenied = $false
      protectedWritesAttempted = $false
    }
    $evidence = New-RisePalsNodeEvidence -AuthorizationId $authorization `
      -InvocationNonce $nonce -RepositoryHead $head -ScriptSha256 $scriptHash `
      -InventoryFileSha256 $inventoryHash `
      -Mode Simulation -Status complete -Classification "node-already-present" `
      -Source $measurement -Destination $measurement -Comparison $comparison -Boundary $boundary
    $path = Join-Path $caseRoot "evidence.json"
    switch ($Scenario) {
      21 {
        [IO.File]::WriteAllText($path, '{"schemaVersion":', [Text.UTF8Encoding]::new($false))
        Assert-RisePalsNodeThrowsPredicate -Predicate "evidence-json" -Action {
          Read-RisePalsNodeEvidence -LiteralPath $path -AuthorizationId $authorization `
            -InvocationNonce $nonce -RepositoryHead $head -ScriptSha256 $scriptHash `
            -InventoryFileSha256 $inventoryHash
        }
      }
      22 {
        $evidence.classification = "complete-except-node"
        Write-RisePalsNodeJson -Path $path -Value $evidence
        Assert-RisePalsNodeThrowsPredicate -Predicate "evidence-digest" -Action {
          Read-RisePalsNodeEvidence -LiteralPath $path -AuthorizationId $authorization `
            -InvocationNonce $nonce -RepositoryHead $head -ScriptSha256 $scriptHash `
            -InventoryFileSha256 $inventoryHash
        }
      }
      23 {
        $evidence.destination.state = "not_reached"
        $evidence.destination.recordCount = 0
        $evidence.destination.fileCount = 0
        $evidence.destination.directoryCount = 0
        $evidence.destination.recordsDigest = $null
        $evidence.evidenceDigest = Get-RisePalsNodeEvidenceDigest -Evidence $evidence
        Assert-RisePalsNodeThrowsPredicate -Predicate "evidence-measurement-state" -Action {
          Assert-RisePalsNodeEvidence -Evidence $evidence -AuthorizationId $authorization `
            -InvocationNonce $nonce -RepositoryHead $head -ScriptSha256 $scriptHash `
            -InventoryFileSha256 $inventoryHash
        }
      }
      24 {
        $evidence.nodeExeOnlyRepairSafe = $true
        $evidence.evidenceDigest = Get-RisePalsNodeEvidenceDigest -Evidence $evidence
        Assert-RisePalsNodeThrowsPredicate -Predicate "evidence-repair-state" -Action {
          Assert-RisePalsNodeEvidence -Evidence $evidence -AuthorizationId $authorization `
            -InvocationNonce $nonce -RepositoryHead $head -ScriptSha256 $scriptHash `
            -InventoryFileSha256 $inventoryHash
        }
      }
      25 {
        $evidence.classification = "not-reviewed"
        $evidence.evidenceDigest = Get-RisePalsNodeEvidenceDigest -Evidence $evidence
        Assert-RisePalsNodeThrowsPredicate -Predicate "evidence-classification" -Action {
          Assert-RisePalsNodeEvidence -Evidence $evidence -AuthorizationId $authorization `
            -InvocationNonce $nonce -RepositoryHead $head -ScriptSha256 $scriptHash `
            -InventoryFileSha256 $inventoryHash
        }
      }
    }
  }

  [IO.File]::WriteAllText((Join-Path $Root ("result-{0:d2}.txt" -f $Scenario)),
    "PASS", [Text.UTF8Encoding]::new($false))
}

if ($WorkerScenario -gt 0) {
  if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { throw "WorkspaceRoot is required." }
  $workspace = [IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\')
  $temporary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  if (-not $workspace.StartsWith($temporary + "\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "The worker workspace must remain below the temporary root."
  }
  Invoke-RisePalsNodeWorkerScenario -Scenario $WorkerScenario -Root $workspace
  exit 0
}

$powershell51 = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not [IO.File]::Exists($powershell51)) { throw "Windows PowerShell 5.1 is unavailable." }
$workspace = Join-Path ([IO.Path]::GetTempPath()) ("risepals-node-diagnostic-{0}" -f [Guid]::NewGuid().ToString("N"))
[IO.Directory]::CreateDirectory($workspace) | Out-Null
$passed = @()
try {
  for ($scenario = 1; $scenario -le 25; $scenario++) {
    $arguments = @(
      "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
      "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path),
      "-RepositoryRoot", ('"{0}"' -f $repository),
      "-WorkerScenario", [string]$scenario,
      "-WorkspaceRoot", ('"{0}"' -f $workspace)
    )
    $process = Start-Process -FilePath $powershell51 -ArgumentList $arguments `
      -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) {
      throw "Scenario $scenario failed in its isolated Windows PowerShell 5.1 process."
    }
    $resultPath = Join-Path $workspace ("result-{0:d2}.txt" -f $scenario)
    if (-not [IO.File]::Exists($resultPath) -or [IO.File]::ReadAllText($resultPath) -cne "PASS") {
      throw "Scenario $scenario did not leave its exact PASS marker."
    }
    $passed += [pscustomobject][ordered]@{ number = $scenario; name = $scenarioNames[$scenario - 1]; result = "PASS" }
  }
  [pscustomobject][ordered]@{
    schemaVersion = "rise-pals-node-destination-harness-v1"
    processCount = $passed.Count
    powershell = $powershell51
    scenarios = $passed
  } | ConvertTo-Json -Depth 5
} finally {
  if ([IO.Directory]::Exists($workspace)) {
    Remove-Item -LiteralPath $workspace -Recurse -Force
  }
}
