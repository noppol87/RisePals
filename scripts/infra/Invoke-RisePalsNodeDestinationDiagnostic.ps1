[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Low")]
param(
  [ValidateSet("Simulation", "LiveReadOnly")][string]$Mode = "Simulation",
  [Parameter(Mandatory = $true)][ValidatePattern("^[A-Z0-9-]{12,120}$")][string]$AuthorizationId,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$RepositoryHead,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$ExpectedScriptSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$ExpectedInventorySha256,
  [Parameter(Mandatory = $true)][string]$InventoryPath,
  [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
  [string]$RepositoryRoot = "C:\Codex PC SG2\Jeff\risepals",
  [string]$SimulationRoot,
  [ValidateSet("None", "AccessDenied", "CanonicalAncestryFailure", "AclBoundaryFailure")]
  [string]$SimulationFault = "None"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$contractPath = Join-Path $PSScriptRoot "node-destination-diagnostic-contract.psm1"
Import-Module -Name $contractPath -Force -ErrorAction Stop

$scriptPath = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
$actualScriptHash = Get-RisePalsNodeSha256File -LiteralPath $scriptPath
if ($actualScriptHash -cne $ExpectedScriptSha256) {
  throw "The diagnostic script hash does not match the authorized binding."
}

$repository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$gitHead = (& git -c ("safe.directory={0}" -f $repository.Replace("\", "/")) `
  -C $repository rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $gitHead -cne $RepositoryHead) {
  throw "The repository HEAD does not match the authorized binding."
}

$protectedRoot = [IO.Path]::GetFullPath("C:\RisePals").TrimEnd('\')
$evidenceRoot = [IO.Path]::GetFullPath($EvidenceDirectory).TrimEnd('\')
if ($evidenceRoot.Equals($protectedRoot, [StringComparison]::OrdinalIgnoreCase) -or
  $evidenceRoot.StartsWith($protectedRoot + "\", [StringComparison]::OrdinalIgnoreCase)) {
  throw "Evidence must remain outside the protected Rise Pals root."
}
$allowedEvidenceBase = if ($Mode -ceq "Simulation") {
  [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
} else {
  [IO.Path]::GetFullPath((Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Codex")).TrimEnd('\')
}
if (-not $evidenceRoot.StartsWith($allowedEvidenceBase + "\", [StringComparison]::OrdinalIgnoreCase)) {
  throw "The evidence directory is outside its approved mode-specific boundary."
}
$evidenceRelative = $evidenceRoot.Substring($allowedEvidenceBase.Length + 1).Replace("\", "/")
[void](Resolve-RisePalsNodeRelativePath -ApprovedRoot $allowedEvidenceBase `
  -RelativePath $evidenceRelative)
$evidenceCursor = $allowedEvidenceBase
if ([IO.Directory]::Exists($evidenceCursor) -and
  (Test-RisePalsNodeReparsePoint -LiteralPath $evidenceCursor)) {
  throw "The evidence boundary contains a reparse point."
}
foreach ($component in $evidenceRelative.Split([char[]]@('/'), [StringSplitOptions]::None)) {
  $evidenceCursor = Join-Path $evidenceCursor $component
  if ((Test-Path -LiteralPath $evidenceCursor) -and
    (Test-RisePalsNodeReparsePoint -LiteralPath $evidenceCursor)) {
    throw "The evidence boundary contains a reparse point."
  }
}

$actualInventoryHash = Get-RisePalsNodeSha256File -LiteralPath $InventoryPath
if ($actualInventoryHash -cne $ExpectedInventorySha256) {
  throw "The official inventory file hash does not match the authorized binding."
}
$expected = Read-RisePalsNodeInventory -LiteralPath $InventoryPath -ApprovedRoot $repository
$sourceMeasurement = New-RisePalsNodeMeasurement -State measured -Inventory $expected
$destinationMeasurement = New-RisePalsNodeMeasurement -State not_reached -Inventory $null
$comparison = New-RisePalsNodeEmptyComparison
$classification = "unknown-controlled-failure"
$status = "controlled-failure"
$nodeExeOnlyRepairSafe = $false
$boundary = [pscustomobject][ordered]@{
  state = "not_reached"
  rootCanonical = $null
  rootReparse = $null
  ancestryValid = $null
  ownerReadSucceeded = $null
  aclReadSucceeded = $null
  accessDenied = $null
  protectedWritesAttempted = $false
}

try {
  if ($Mode -ceq "Simulation") {
    if ([string]::IsNullOrWhiteSpace($SimulationRoot)) {
      throw "SimulationRoot is required in Simulation mode."
    }
    $destinationRoot = [IO.Path]::GetFullPath($SimulationRoot).TrimEnd('\')
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if (-not $destinationRoot.StartsWith($temporaryRoot + "\", [StringComparison]::OrdinalIgnoreCase)) {
      throw "SimulationRoot must remain below the current temporary root."
    }
  } else {
    if ($SimulationFault -cne "None" -or -not [string]::IsNullOrEmpty($SimulationRoot)) {
      throw "Simulation controls are prohibited in LiveReadOnly mode."
    }
    $principal = [Security.Principal.WindowsPrincipal]::new(
      [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
      throw "LiveReadOnly requires a separately authorized elevated administrator process."
    }
    $destinationRoot = "C:\RisePals\tools\node\24.18.1"
    $exactBoundaries = @(
      "C:\RisePals",
      "C:\RisePals\tools",
      "C:\RisePals\tools\node",
      "C:\RisePals\tools\node\24.18.1",
      "C:\RisePals\tools\node\24.18.1\node.exe"
    )
    foreach ($path in $exactBoundaries) {
      [void][IO.Path]::GetFullPath($path)
    }
  }

  if ($SimulationFault -ceq "AccessDenied") {
    $classification = "access-denied"
    $boundary = [pscustomobject][ordered]@{
      state = "measured"; rootCanonical = $null; rootReparse = $null; ancestryValid = $null
      ownerReadSucceeded = $false; aclReadSucceeded = $false; accessDenied = $true
      protectedWritesAttempted = $false
    }
  } elseif ($SimulationFault -ceq "CanonicalAncestryFailure") {
    $classification = "canonical-ancestry-failure"
    $boundary = [pscustomobject][ordered]@{
      state = "measured"; rootCanonical = $false; rootReparse = $null; ancestryValid = $false
      ownerReadSucceeded = $null; aclReadSucceeded = $null; accessDenied = $false
      protectedWritesAttempted = $false
    }
  } elseif ($SimulationFault -ceq "AclBoundaryFailure") {
    $classification = "ACL-boundary-failure"
    $boundary = [pscustomobject][ordered]@{
      state = "measured"; rootCanonical = $true; rootReparse = $false; ancestryValid = $true
      ownerReadSucceeded = $true; aclReadSucceeded = $false; accessDenied = $false
      protectedWritesAttempted = $false
    }
  } elseif (-not [IO.Directory]::Exists($destinationRoot)) {
    $classification = "version-directory-absent"
    $boundary = [pscustomobject][ordered]@{
      state = "measured"; rootCanonical = $true; rootReparse = $null; ancestryValid = $true
      ownerReadSucceeded = $null; aclReadSucceeded = $null; accessDenied = $false
      protectedWritesAttempted = $false
    }
  } elseif (Test-RisePalsNodeReparsePoint -LiteralPath $destinationRoot) {
    $classification = "reparse-point-present"
    $boundary = [pscustomobject][ordered]@{
      state = "measured"; rootCanonical = $true; rootReparse = $true; ancestryValid = $false
      ownerReadSucceeded = $null; aclReadSucceeded = $null; accessDenied = $false
      protectedWritesAttempted = $false
    }
  } else {
    $boundary = [pscustomobject][ordered]@{
      state = "measured"; rootCanonical = $true; rootReparse = $false; ancestryValid = $true
      ownerReadSucceeded = $true; aclReadSucceeded = $true; accessDenied = $false
      protectedWritesAttempted = $false
    }
    if ($Mode -ceq "LiveReadOnly") {
      [void](Get-Acl -LiteralPath $destinationRoot -ErrorAction Stop)
      [void](Get-Item -LiteralPath $destinationRoot -Force -ErrorAction Stop).GetAccessControl().Owner
    }
    try {
      $actual = New-RisePalsNodeInventory -Root $destinationRoot
    } catch {
      if ([string]$_.Exception.Message -like "reparse-point-present|*") {
        $classification = "reparse-point-present"
        $boundary.ancestryValid = $false
      } else {
        throw
      }
    }
    if ($null -ne (Get-Variable -Name actual -ErrorAction SilentlyContinue)) {
      $destinationMeasurement = New-RisePalsNodeMeasurement -State measured -Inventory $actual
      $comparison = Compare-RisePalsNodeInventories -Expected $expected -Actual $actual
      if ([int]$actual.recordCount -eq 0) {
        $classification = "version-directory-empty"
      } elseif ([int]$comparison.typeMismatchCount -gt 0) {
        $classification = "object-type-mismatch"
      } elseif ([int]$comparison.contentMismatchCount -gt 0) {
        $classification = "file-content-mismatch"
      } elseif ([int]$comparison.unexpectedCount -gt 0) {
        $classification = "unexpected-object-present"
      } elseif ([int]$comparison.missingCount -gt 0) {
        if ([int]$comparison.missingCount -eq 1 -and
          @($comparison.missingPaths).Count -eq 1 -and
          [string]$comparison.missingPaths[0] -ceq "node.exe") {
          $classification = "complete-except-node"
          $nodeExeOnlyRepairSafe = $true
        } else {
          $classification = "additional-official-files-missing"
        }
      } else {
        $classification = "node-already-present"
      }
    }
  }
  $status = "complete"
} catch [UnauthorizedAccessException] {
  $classification = "access-denied"
  $status = "complete"
  $boundary = [pscustomobject][ordered]@{
    state = "measured"; rootCanonical = $null; rootReparse = $null; ancestryValid = $null
    ownerReadSucceeded = $false; aclReadSucceeded = $false; accessDenied = $true
    protectedWritesAttempted = $false
  }
} catch {
  $classification = "unknown-controlled-failure"
  $status = "controlled-failure"
  $destinationMeasurement = New-RisePalsNodeMeasurement -State not_reached -Inventory $null
  $comparison = New-RisePalsNodeEmptyComparison
  $nodeExeOnlyRepairSafe = $false
}

$evidence = New-RisePalsNodeEvidence -AuthorizationId $AuthorizationId `
  -InvocationNonce $InvocationNonce -RepositoryHead $RepositoryHead `
  -ScriptSha256 $actualScriptHash -InventoryFileSha256 $actualInventoryHash `
  -Mode $Mode -Status $status `
  -Classification $classification -CompletedPredicates @("inventory-json", "inventory-digest") `
  -FailedPredicate $(if ($status -ceq "controlled-failure") { "evidence-schema" } else { $null }) `
  -Source $sourceMeasurement -Destination $destinationMeasurement -Comparison $comparison `
  -Boundary $boundary -NodeExeOnlyRepairSafe $nodeExeOnlyRepairSafe
[void](Assert-RisePalsNodeEvidence -Evidence $evidence -AuthorizationId $AuthorizationId `
  -InvocationNonce $InvocationNonce -RepositoryHead $RepositoryHead -ScriptSha256 $actualScriptHash `
  -InventoryFileSha256 $actualInventoryHash)
if (-not $PSCmdlet.ShouldProcess($evidenceRoot, "persist sanitized Node destination diagnostic evidence")) {
  throw "Evidence persistence was not approved."
}
$evidencePath = Write-RisePalsNodeEvidenceAtomic -Evidence $evidence -EvidenceDirectory $evidenceRoot
[void](Read-RisePalsNodeEvidence -LiteralPath $evidencePath -AuthorizationId $AuthorizationId `
  -InvocationNonce $InvocationNonce -RepositoryHead $RepositoryHead -ScriptSha256 $actualScriptHash `
  -InventoryFileSha256 $actualInventoryHash)

[pscustomobject]@{
  evidencePath = $evidencePath
  classification = $classification
  status = $status
}
