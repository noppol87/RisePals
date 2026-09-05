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
  [ValidateSet(
    "None", "AccessDenied", "CanonicalAncestryFailure", "AclBoundaryFailure",
    "AccessDeniedRoot", "AccessDeniedTools", "AccessDeniedNode", "AccessDeniedVersion",
    "AccessDeniedExecutable", "OwnerDeniedVersion", "AclDeniedVersion", "DenyAceVersion",
    "UnexpectedAceVersion", "CanonicalAncestryFailureVersion", "ControlledFailureVersion"
  )]
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
$boundaries = @()
$completedPredicates = @()
$firstFailedPredicate = $null
$failedBoundary = $null
$failedOperation = $null
$sanitizedErrorCategory = $null
$nativeErrorCode = $null
$hResult = $null

if ($Mode -ceq "Simulation") {
  if ([string]::IsNullOrWhiteSpace($SimulationRoot)) {
    throw "SimulationRoot is required in Simulation mode."
  }
  $protectedDestinationRoot = [IO.Path]::GetFullPath($SimulationRoot).TrimEnd('\')
  $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  if (-not $protectedDestinationRoot.StartsWith(
      $temporaryRoot + "\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "SimulationRoot must remain below the current temporary root."
  }
  if ($SimulationFault -ceq "AccessDenied") { $SimulationFault = "AccessDeniedVersion" }
  if ($SimulationFault -ceq "CanonicalAncestryFailure") {
    $SimulationFault = "CanonicalAncestryFailureVersion"
  }
  if ($SimulationFault -ceq "AclBoundaryFailure") { $SimulationFault = "DenyAceVersion" }
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
  $protectedDestinationRoot = "C:\RisePals"
}

$allowedPrincipalSids = @("S-1-5-18", "S-1-5-32-544")
if ($Mode -ceq "Simulation") {
  $allowedPrincipalSids += @(
    "S-1-5-32-545", "S-1-5-11", "S-1-3-0",
    [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  )
  $simulationParentAcl = Get-Acl -LiteralPath (Split-Path -Parent $protectedDestinationRoot) `
    -ErrorAction Stop
  $allowedPrincipalSids += @($simulationParentAcl.GetAccessRules(
      $true, $true, [Security.Principal.SecurityIdentifier]
    ) | ForEach-Object { [string]$_.IdentityReference.Value })
} else {
  foreach ($account in @("NT SERVICE\RisePalsApp", "NT SERVICE\RisePalsProxy")) {
    try {
      $sid = ([Security.Principal.NTAccount]::new($account)).Translate(
        [Security.Principal.SecurityIdentifier]
      ).Value
      $allowedPrincipalSids += $sid
    } catch {
      # An unresolved retained-service SID remains outside the allowlist and is reported as unexpected.
    }
  }
}
$allowedPrincipalSids = @($allowedPrincipalSids | Select-Object -Unique)

if ($Mode -ceq "LiveReadOnly") {
  $toolsPath = "C:\RisePals\tools"
  $nodePath = "C:\RisePals\tools\node"
  $versionPath = "C:\RisePals\tools\node\24.18.1"
  $executablePath = "C:\RisePals\tools\node\24.18.1\node.exe"
} else {
  $toolsPath = Join-Path $protectedDestinationRoot "tools"
  $nodePath = Join-Path $toolsPath "node"
  $versionPath = Join-Path $nodePath "24.18.1"
  $executablePath = Join-Path $versionPath "node.exe"
}
$definitions = @(
  [pscustomobject][ordered]@{ pathId = "rise-pals-root"; stage = "boundary-root";
    token = "Root"; path = $protectedDestinationRoot; parent = $null; type = "directory" },
  [pscustomobject][ordered]@{ pathId = "tools-directory"; stage = "boundary-tools";
    token = "Tools"; path = $toolsPath; parent = $protectedDestinationRoot; type = "directory" },
  [pscustomobject][ordered]@{ pathId = "node-directory"; stage = "boundary-node";
    token = "Node"; path = $nodePath; parent = $toolsPath; type = "directory" },
  [pscustomobject][ordered]@{ pathId = "version-directory"; stage = "boundary-version";
    token = "Version"; path = $versionPath; parent = $nodePath; type = "directory" },
  [pscustomobject][ordered]@{ pathId = "node-executable"; stage = "boundary-executable";
    token = "Executable"; path = $executablePath; parent = $versionPath; type = "file" }
)

function Get-BoundaryFailurePredicate {
  param([Parameter(Mandatory = $true)][object]$Definition,
    [Parameter(Mandatory = $true)][object]$Result)
  switch ([string]$Result.failedOperation) {
    "item-read" { return [string]$Definition.stage }
    "owner-read" { return "boundary-owner" }
    "acl-read" { return "boundary-acl" }
    "acl-rule-validation" { return "boundary-acl" }
    "reparse-check" { return "boundary-reparse" }
    "canonical-path-validation" { return "boundary-canonical" }
    "parent-path-validation" { return "boundary-parent" }
    "volume-validation" { return "boundary-volume" }
    "filesystem-read" { return "boundary-volume" }
    "object-type-validation" { return "boundary-object-type" }
    default { return $null }
  }
}

$blocked = $false
for ($index = 0; $index -lt $definitions.Count; $index++) {
  $definition = $definitions[$index]
  if ($blocked) {
    $boundaries += New-RisePalsNodeBoundaryResult -PathId $definition.pathId
    continue
  }
  $result = Invoke-RisePalsNodeBoundaryProbe -PathId $definition.pathId `
    -LiteralPath $definition.path -ExpectedParent $definition.parent -ExpectedType $definition.type `
    -FaultToken $definition.token -SimulationFault $SimulationFault `
    -AllowedPrincipalSids $allowedPrincipalSids
  $boundaries += $result
  if ([string]$result.disposition -in @("inspected", "absent")) {
    $completedPredicates += [string]$definition.stage
  }
  if ($null -ne $result.failedOperation -and $null -eq $firstFailedPredicate) {
    $firstFailedPredicate = Get-BoundaryFailurePredicate -Definition $definition -Result $result
    $failedBoundary = [string]$result.pathId
    $failedOperation = [string]$result.failedOperation
    $sanitizedErrorCategory = [string]$result.sanitizedErrorCategory
    $nativeErrorCode = $result.nativeErrorCode
    $hResult = $result.hResult
  }
  $expectedType = if ($index -eq 4) { "file" } else { "directory" }
  $blocked = [string]$result.disposition -ne "inspected" -or
    [string]$result.objectType -cne $expectedType -or
    -not [bool]$result.canonicalPathMatched -or
    ($index -gt 0 -and -not [bool]$result.parentPathMatched) -or
    -not [bool]$result.sameVolume -or [bool]$result.reparsePoint -or
    -not [bool]$result.ancestryValid -or $result.ownerReadSucceeded -ne $true -or
    $result.aclReadSucceeded -ne $true -or [int]$result.denyAceCount -gt 0 -or
    [int]$result.unexpectedAceCount -gt 0
  if ($index -eq 4) { $blocked = $false }
}

$firstUnsafeBoundary = @($boundaries | Where-Object {
    [string]$_.disposition -in @("access_denied", "controlled_failure") -or
    ([string]$_.disposition -ceq "inspected" -and $null -ne $_.failedOperation)
  } | Select-Object -First 1)
$versionBoundary = $boundaries[3]
$executableBoundary = $boundaries[4]

if (@($boundaries | Where-Object { [string]$_.disposition -ceq "access_denied" }).Count -gt 0) {
  $classification = "access-denied"
  $status = "complete"
} elseif (@($boundaries | Where-Object { [string]$_.disposition -ceq "controlled_failure" }).Count -gt 0) {
  $classification = "unknown-controlled-failure"
  $status = "controlled-failure"
} elseif ($firstUnsafeBoundary.Count -gt 0) {
  $unsafe = $firstUnsafeBoundary[0]
  $status = "complete"
  if ([string]$unsafe.sanitizedErrorCategory -ceq "reparse_point") {
    $classification = "reparse-point-present"
  } elseif ([string]$unsafe.sanitizedErrorCategory -in @(
      "canonical_path", "parent_path", "volume_mismatch"
    )) {
    $classification = "canonical-ancestry-failure"
  } elseif ([string]$unsafe.sanitizedErrorCategory -ceq "object_type") {
    $classification = "object-type-mismatch"
  } elseif ([string]$unsafe.sanitizedErrorCategory -ceq "acl_policy") {
    $classification = "ACL-boundary-failure"
  } else {
    $classification = "unknown-controlled-failure"
    $status = "controlled-failure"
  }
} elseif ([string]$versionBoundary.disposition -ceq "absent") {
  $classification = "version-directory-absent"
  $status = "complete"
} elseif (@($boundaries | Select-Object -First 3 | Where-Object {
      [string]$_.disposition -ceq "absent"
    }).Count -gt 0) {
  $classification = "unknown-controlled-failure"
  $status = "controlled-failure"
} elseif ([string]$versionBoundary.disposition -ceq "inspected" -and
  [string]$executableBoundary.disposition -in @("inspected", "absent")) {
  try {
    $actual = New-RisePalsNodeInventory -Root $versionPath
    $destinationMeasurement = New-RisePalsNodeMeasurement -State measured -Inventory $actual
    $completedPredicates += "destination-inventory"
    $comparison = Compare-RisePalsNodeInventories -Expected $expected -Actual $actual
    $completedPredicates += "inventory-comparison"
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
    if ($null -eq $firstFailedPredicate -and $classification -notin @("node-already-present")) {
      $firstFailedPredicate = "inventory-comparison"
      $failedOperation = "inventory-comparison"
      $sanitizedErrorCategory = "inventory_mismatch"
    }
    $status = "complete"
  } catch {
    $facts = Get-RisePalsNodeExceptionFacts -Exception $_.Exception
    $status = "complete"
    if ([string]$_.Exception.Message -like "reparse-point-present|*") {
      $classification = "reparse-point-present"
      $sanitizedErrorCategory = "reparse_point"
    } elseif ($facts.category -ceq "access_denied") {
      $classification = "access-denied"
      $sanitizedErrorCategory = "access_denied"
    } else {
      $classification = "unknown-controlled-failure"
      $sanitizedErrorCategory = $facts.category
      $status = "controlled-failure"
    }
    $firstFailedPredicate = "destination-inventory"
    $failedBoundary = "version-directory"
    $failedOperation = "inventory-enumeration"
    $nativeErrorCode = $facts.nativeErrorCode
    $hResult = $facts.hResult
    $destinationMeasurement = New-RisePalsNodeMeasurement -State not_reached -Inventory $null
    $comparison = New-RisePalsNodeEmptyComparison
    $nodeExeOnlyRepairSafe = $false
  }
}

if (($completedPredicates -join "|") -ceq
  "boundary-root|boundary-tools|boundary-node|boundary-version|boundary-executable|destination-inventory|inventory-comparison") {
  $completedPredicates += "evidence-construction"
}

$evidence = New-RisePalsNodeEvidence -AuthorizationId $AuthorizationId `
  -InvocationNonce $InvocationNonce -RepositoryHead $RepositoryHead `
  -ScriptSha256 $actualScriptHash -InventoryFileSha256 $actualInventoryHash `
  -Mode $Mode -Status $status `
  -Classification $classification -CompletedPredicates $completedPredicates `
  -FirstFailedPredicate $firstFailedPredicate -FailedBoundary $failedBoundary `
  -FailedOperation $failedOperation -SanitizedErrorCategory $sanitizedErrorCategory `
  -NativeErrorCode $nativeErrorCode -HResult $hResult `
  -Source $sourceMeasurement -Destination $destinationMeasurement -Comparison $comparison `
  -Boundaries $boundaries -NodeExeOnlyRepairSafe $nodeExeOnlyRepairSafe
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
