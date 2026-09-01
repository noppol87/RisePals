[CmdletBinding()]
param(
  [string]$RepositoryRoot = "C:\Codex PC SG2\Jeff\risepals",
  [ValidateRange(0, 45)][int]$WorkerScenario = 0,
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
  "unknown-classification",
  "directory-exists-false-is-not-absence",
  "explicit-version-not-found",
  "access-denied-root",
  "access-denied-tools",
  "access-denied-node",
  "access-denied-version",
  "access-denied-executable",
  "owner-read-then-acl-denied",
  "acl-deny-ace",
  "acl-unexpected-principal",
  "reparse-root",
  "reparse-tools",
  "reparse-node",
  "reparse-version",
  "descendant-after-failed-ancestor",
  "failure-provenance-persistence",
  "generic-controlled-failure-provenance",
  "complete-except-node-boundaries",
  "node-present-executable-boundary",
  "boundary-and-provenance-tamper"
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

function Assert-RisePalsNodeThrows {
  param([Parameter(Mandatory = $true)][scriptblock]$Action, [Parameter(Mandatory = $true)][string]$Label)
  try { & $Action } catch { return }
  throw $Label
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
  $protectedRoot = Join-Path $caseRoot "protected"
  $toolsRoot = Join-Path $protectedRoot "tools"
  $nodeRoot = Join-Path $toolsRoot "node"
  $destinationRoot = Join-Path $nodeRoot "24.18.1"
  $evidenceRoot = Join-Path $caseRoot "evidence"
  [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
  if ($Scenario -notin @(10, 36)) {
    [IO.Directory]::CreateDirectory($nodeRoot) | Out-Null
  }
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
    param([string]$Fault = "None", [string]$RootOverride = $protectedRoot)
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
        New-RisePalsNodeFixtureDistribution -Root (Join-Path $target "tools\node\24.18.1")
        [void](New-Item -ItemType Junction -Path $protectedRoot -Target $target -Force)
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
        New-RisePalsNodeFixtureDistribution -Root $destinationRoot
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
    $path = Join-Path $caseRoot "evidence.json"

    function Read-ScenarioEvidence {
      param([string]$Fault = "None", [switch]$LeaveVersionAbsent, [switch]$KeepExistingFixture)
      if (-not $LeaveVersionAbsent -and -not $KeepExistingFixture) {
        New-RisePalsNodeFixtureDistribution -Root $destinationRoot
      }
      $result = Invoke-TestDiagnostic -Fault $Fault
      return Read-RisePalsNodeEvidence -LiteralPath $result.evidencePath `
        -AuthorizationId $authorization -InvocationNonce $nonce -RepositoryHead $head `
        -ScriptSha256 $scriptHash -InventoryFileSha256 $inventoryHash
    }

    if ($Scenario -in 21..25) {
      $evidence = $null
      if ($Scenario -ne 21) { $evidence = Read-ScenarioEvidence }
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
    } elseif ($Scenario -eq 26) {
      $evidence = Read-ScenarioEvidence -LeaveVersionAbsent
      $evidence.boundaries[3].failedOperation = $null
      $evidence.boundaries[3].sanitizedErrorCategory = $null
      $evidence.evidenceDigest = Get-RisePalsNodeEvidenceDigest -Evidence $evidence
      Assert-RisePalsNodeThrowsPredicate -Predicate "evidence-boundary-state" -Action {
        Assert-RisePalsNodeEvidence -Evidence $evidence -AuthorizationId $authorization `
          -InvocationNonce $nonce -RepositoryHead $head -ScriptSha256 $scriptHash `
          -InventoryFileSha256 $inventoryHash
      }
    } elseif ($Scenario -eq 27) {
      $evidence = Read-ScenarioEvidence -LeaveVersionAbsent
      Assert-RisePalsNodeTest -Condition (
        $evidence.classification -ceq "version-directory-absent" -and
        $evidence.boundaries[3].disposition -ceq "absent" -and
        $evidence.boundaries[3].failedOperation -ceq "item-read" -and
        $evidence.boundaries[3].sanitizedErrorCategory -ceq "not_found" -and
        $evidence.boundaries[4].disposition -ceq "not_reached"
      ) -Label "Explicit version-directory not-found evidence was incomplete."
    } elseif ($Scenario -in 28..32) {
      New-RisePalsNodeFixtureDistribution -Root $destinationRoot
      $tokens = @("Root", "Tools", "Node", "Version", "Executable")
      $boundaryIndex = $Scenario - 28
      $evidence = Read-ScenarioEvidence -Fault ("AccessDenied{0}" -f $tokens[$boundaryIndex])
      Assert-RisePalsNodeTest -Condition (
        $evidence.classification -ceq "access-denied" -and
        $evidence.boundaries[$boundaryIndex].disposition -ceq "access_denied" -and
        $evidence.boundaries[$boundaryIndex].failedOperation -ceq "item-read" -and
        $evidence.boundaries[$boundaryIndex].sanitizedErrorCategory -ceq "access_denied" -and
        $evidence.failedBoundary -ceq $evidence.boundaries[$boundaryIndex].pathId
      ) -Label "Access denial did not retain its exact production-mapped boundary."
      foreach ($descendant in @($evidence.boundaries | Select-Object -Skip ($boundaryIndex + 1))) {
        Assert-RisePalsNodeTest -Condition ($descendant.disposition -ceq "not_reached") `
          -Label "A descendant was measured after access denial."
      }
    } elseif ($Scenario -eq 33) {
      $evidence = Read-ScenarioEvidence -Fault "AclDeniedVersion"
      Assert-RisePalsNodeTest -Condition (
        $evidence.classification -ceq "access-denied" -and
        $evidence.boundaries[3].ownerReadSucceeded -eq $true -and
        $evidence.boundaries[3].aclReadSucceeded -eq $false -and
        $evidence.boundaries[3].failedOperation -ceq "acl-read"
      ) -Label "Owner-success/ACL-denial evidence was not exact."
    } elseif ($Scenario -in 34..35) {
      $fault = if ($Scenario -eq 34) { "DenyAceVersion" } else { "UnexpectedAceVersion" }
      $evidence = Read-ScenarioEvidence -Fault $fault
      $countName = if ($Scenario -eq 34) { "denyAceCount" } else { "unexpectedAceCount" }
      Assert-RisePalsNodeTest -Condition (
        $evidence.classification -ceq "ACL-boundary-failure" -and
        [int]$evidence.boundaries[3].$countName -gt 0 -and
        $evidence.boundaries[3].failedOperation -ceq "acl-rule-validation"
      ) -Label "ACL policy evidence was incomplete."
    } elseif ($Scenario -in 36..39) {
      $boundaryIndex = $Scenario - 36
      $target = Join-Path $caseRoot ("reparse-target-{0}" -f $boundaryIndex)
      if ($boundaryIndex -eq 0) {
        New-RisePalsNodeFixtureDistribution -Root (Join-Path $target "tools\node\24.18.1")
        [void](New-Item -ItemType Junction -Path $protectedRoot -Target $target -Force)
      } elseif ($boundaryIndex -eq 1) {
        Remove-Item -LiteralPath $toolsRoot -Recurse -Force
        New-RisePalsNodeFixtureDistribution -Root (Join-Path $target "node\24.18.1")
        [void](New-Item -ItemType Junction -Path $toolsRoot -Target $target -Force)
      } elseif ($boundaryIndex -eq 2) {
        Remove-Item -LiteralPath $nodeRoot -Recurse -Force
        New-RisePalsNodeFixtureDistribution -Root (Join-Path $target "24.18.1")
        [void](New-Item -ItemType Junction -Path $nodeRoot -Target $target -Force)
      } else {
        New-RisePalsNodeFixtureDistribution -Root $target
        [void](New-Item -ItemType Junction -Path $destinationRoot -Target $target -Force)
      }
      $evidence = Read-ScenarioEvidence -KeepExistingFixture
      Assert-RisePalsNodeTest -Condition (
        $evidence.classification -ceq "reparse-point-present" -and
        $evidence.boundaries[$boundaryIndex].reparsePoint -eq $true -and
        $evidence.boundaries[$boundaryIndex].failedOperation -ceq "reparse-check"
      ) -Label "Directory reparse evidence was incomplete."
    } elseif ($Scenario -eq 40) {
      $evidence = Read-ScenarioEvidence -Fault "AccessDeniedRoot"
      $allowed = @(
        "S-1-5-18", "S-1-5-32-544", "S-1-5-32-545", "S-1-5-11", "S-1-3-0",
        [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
      )
      $evidence.boundaries[1] = Invoke-RisePalsNodeBoundaryProbe -PathId "tools-directory" `
        -LiteralPath $toolsRoot -ExpectedParent $protectedRoot -ExpectedType directory `
        -FaultToken Tools -AllowedPrincipalSids $allowed
      $evidence.evidenceDigest = Get-RisePalsNodeEvidenceDigest -Evidence $evidence
      Assert-RisePalsNodeThrowsPredicate -Predicate "evidence-boundary-state" -Action {
        Assert-RisePalsNodeEvidence -Evidence $evidence -AuthorizationId $authorization `
          -InvocationNonce $nonce -RepositoryHead $head -ScriptSha256 $scriptHash `
          -InventoryFileSha256 $inventoryHash
      }
    } elseif ($Scenario -eq 41) {
      $evidence = Read-ScenarioEvidence -Fault "AccessDeniedTools"
      Assert-RisePalsNodeTest -Condition (
        $evidence.firstFailedPredicate -ceq "boundary-tools" -and
        $evidence.failedBoundary -ceq "tools-directory" -and
        $evidence.failedOperation -ceq "item-read" -and
        $evidence.sanitizedErrorCategory -ceq "access_denied" -and
        $null -ne $evidence.hResult
      ) -Label "Failure provenance did not survive persistence and reopen."
    } elseif ($Scenario -eq 42) {
      $evidence = Read-ScenarioEvidence -Fault "ControlledFailureVersion"
      Assert-RisePalsNodeTest -Condition (
        $evidence.status -ceq "controlled-failure" -and
        $evidence.firstFailedPredicate -ceq "boundary-version" -and
        $evidence.failedBoundary -ceq "version-directory" -and
        $evidence.failedOperation -ceq "item-read" -and
        $evidence.sanitizedErrorCategory -ceq "io_error"
      ) -Label "Generic failure was collapsed into an unrelated evidence predicate."
    } elseif ($Scenario -eq 43) {
      New-RisePalsNodeFixtureDistribution -Root $destinationRoot
      [IO.File]::Delete((Join-Path $destinationRoot "node.exe"))
      $evidence = Read-ScenarioEvidence -KeepExistingFixture
      Assert-RisePalsNodeTest -Condition (
        @($evidence.boundaries).Count -eq 5 -and
        @($evidence.boundaries | Select-Object -First 4 | Where-Object {
            $_.disposition -cne "inspected"
          }).Count -eq 0 -and
        $evidence.boundaries[4].disposition -ceq "absent" -and
        $evidence.nodeExeOnlyRepairSafe -eq $true
      ) -Label "Complete-except-node did not retain five coherent boundaries."
    } elseif ($Scenario -eq 44) {
      $evidence = Read-ScenarioEvidence
      Assert-RisePalsNodeTest -Condition (
        $evidence.classification -ceq "node-already-present" -and
        $evidence.boundaries[4].disposition -ceq "inspected" -and
        $evidence.boundaries[4].objectType -ceq "file"
      ) -Label "Node-present evidence lacked an inspected executable boundary."
    } elseif ($Scenario -eq 45) {
      $evidence = Read-ScenarioEvidence -Fault "AccessDeniedVersion"
      $originalDigest = [string]$evidence.evidenceDigest
      $mutations = @(
        { param($value) $value.boundaries[3].failedOperation = "owner-read" },
        { param($value) $value.boundaries[3].hResult = [int]$value.boundaries[3].hResult + 1 },
        { param($value) $value.failedBoundary = "node-directory" },
        { param($value) $value.failedOperation = "owner-read" },
        { param($value) $value.completedPredicates = @("boundary-root", "boundary-root") }
      )
      foreach ($mutation in $mutations) {
        $tampered = Copy-RisePalsNodeJsonObject -Value $evidence
        & $mutation $tampered
        Assert-RisePalsNodeTest -Condition (
          (Get-RisePalsNodeEvidenceDigest -Evidence $tampered) -cne $originalDigest
        ) -Label "Boundary/provenance tampering did not change the canonical digest."
        Assert-RisePalsNodeThrows -Label "Tampered evidence was accepted." -Action {
          Assert-RisePalsNodeEvidence -Evidence $tampered -AuthorizationId $authorization `
            -InvocationNonce $nonce -RepositoryHead $head -ScriptSha256 $scriptHash `
            -InventoryFileSha256 $inventoryHash
        }
      }
      $duplicatePrefix = Copy-RisePalsNodeJsonObject -Value $evidence
      $duplicatePrefix.completedPredicates = @("boundary-root", "boundary-root")
      $duplicatePrefix.evidenceDigest = Get-RisePalsNodeEvidenceDigest -Evidence $duplicatePrefix
      Assert-RisePalsNodeThrowsPredicate -Predicate "evidence-schema" -Action {
        Assert-RisePalsNodeEvidence -Evidence $duplicatePrefix -AuthorizationId $authorization `
          -InvocationNonce $nonce -RepositoryHead $head -ScriptSha256 $scriptHash `
          -InventoryFileSha256 $inventoryHash
      }
      $disagreedProvenance = Copy-RisePalsNodeJsonObject -Value $evidence
      $disagreedProvenance.failedBoundary = "node-directory"
      $disagreedProvenance.evidenceDigest = Get-RisePalsNodeEvidenceDigest -Evidence $disagreedProvenance
      Assert-RisePalsNodeThrowsPredicate -Predicate "evidence-failure-provenance" -Action {
        Assert-RisePalsNodeEvidence -Evidence $disagreedProvenance -AuthorizationId $authorization `
          -InvocationNonce $nonce -RepositoryHead $head -ScriptSha256 $scriptHash `
          -InventoryFileSha256 $inventoryHash
      }
      $falseAclMeasurement = Copy-RisePalsNodeJsonObject -Value $evidence
      $falseAclMeasurement.boundaries[3].explicitAllowAceCount = 0
      $falseAclMeasurement.evidenceDigest = Get-RisePalsNodeEvidenceDigest -Evidence $falseAclMeasurement
      Assert-RisePalsNodeThrowsPredicate -Predicate "evidence-boundary-state" -Action {
        Assert-RisePalsNodeEvidence -Evidence $falseAclMeasurement -AuthorizationId $authorization `
          -InvocationNonce $nonce -RepositoryHead $head -ScriptSha256 $scriptHash `
          -InventoryFileSha256 $inventoryHash
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
  for ($scenario = 1; $scenario -le 45; $scenario++) {
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
    schemaVersion = "rise-pals-node-destination-harness-v2"
    processCount = $passed.Count
    powershell = $powershell51
    scenarios = $passed
  } | ConvertTo-Json -Depth 5
} finally {
  if ([IO.Directory]::Exists($workspace)) {
    Remove-Item -LiteralPath $workspace -Recurse -Force
  }
}
