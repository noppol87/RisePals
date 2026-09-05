Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Get-RisePalsParentBuiltinSha256Bytes {
  param([byte[]]$Bytes)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace("-", "").ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Get-RisePalsParentBuiltinMarkerDigest {
  param([object]$Marker)
  $lines = @(
    "schemaVersion=$([string]$Marker.schemaVersion)",
    "authorizationId=$([string]$Marker.authorizationId)",
    "invocationNonce=$([string]$Marker.invocationNonce)",
    "repositoryHead=$([string]$Marker.repositoryHead)",
    "mode=$([string]$Marker.mode)",
    "outerSha256=$([string]$Marker.outerSha256)",
    "outerContractSha256=$([string]$Marker.outerContractSha256)",
    "innerTransportSha256=$([string]$Marker.innerTransportSha256)",
    "earlyContractSha256=$([string]$Marker.earlyContractSha256)",
    "securityBootstrapSha256=$([string]$Marker.securityBootstrapSha256)",
    "childSha256=$([string]$Marker.childSha256)",
    "diagnosticSha256=$([string]$Marker.diagnosticSha256)",
    "diagnosticContractSha256=$([string]$Marker.diagnosticContractSha256)",
    "inventorySha256=$([string]$Marker.inventorySha256)",
    "completedStages=$(@($Marker.completedStages) -join ',')",
    "lastCompletedStage=$([string]$Marker.lastCompletedStage)"
  )
  return Get-RisePalsParentBuiltinSha256Bytes -Bytes (
    [Text.UTF8Encoding]::new($false).GetBytes(($lines -join "`n") + "`n")
  )
}

function Get-RisePalsParentBuiltinEvidenceRoot {
  param([string]$Path)
  try {
    $exact = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $allowed = [IO.Path]::GetFullPath((Join-Path (
          [Environment]::GetFolderPath("MyDocuments")
        ) "Codex")).TrimEnd('\')
    if (-not $exact.StartsWith($allowed + "\", [StringComparison]::OrdinalIgnoreCase)) {
      return $null
    }
    $item = Get-Item -LiteralPath $exact -Force -ErrorAction Stop
    if (-not $item.PSIsContainer -or
      ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      @(Get-ChildItem -LiteralPath $exact -Force).Count -ne 0) {
      return $null
    }
    return $exact
  } catch {
    return $null
  }
}

function Write-RisePalsParentBuiltinMarker {
  param([object]$Marker, [string]$EvidenceRoot)
  $final = Join-Path $EvidenceRoot (
    "node-parent-entry-marker-{0}.json" -f [string]$Marker.invocationNonce
  )
  $temporary = $final + ".tmp"
  if ([IO.File]::Exists($final) -or [IO.File]::Exists($temporary)) {
    throw "parent-entry-path-exists"
  }
  [IO.File]::WriteAllText($temporary, ($Marker | ConvertTo-Json -Compress -Depth 8),
    [Text.UTF8Encoding]::new($false))
  [IO.File]::Move($temporary, $final)
  return $final
}

function Test-RisePalsParentRegularFile {
  param([string]$Path)
  try {
    $item = Get-Item -LiteralPath ([IO.Path]::GetFullPath($Path)) -Force -ErrorAction Stop
    return -not $item.PSIsContainer -and
      ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0
  } catch {
    return $false
  }
}

function Get-RisePalsParentResidueCounts {
  param([string]$EvidenceRoot)
  $transient = @(Get-ChildItem -LiteralPath $EvidenceRoot -Directory -Force -Recurse |
      Where-Object { $_.Name.StartsWith("transient-", [StringComparison]::Ordinal) }).Count
  $temporary = @(Get-ChildItem -LiteralPath $EvidenceRoot -File -Force -Recurse |
      Where-Object { $_.Name.EndsWith(".tmp", [StringComparison]::Ordinal) }).Count
  return [pscustomobject]@{ transient = $transient; temporary = $temporary }
}

$values = @{}
$structuralFailure = $false
if ($args.Count -eq 0 -or ($args.Count % 2) -ne 0) {
  $structuralFailure = $true
} else {
  for ($index = 0; $index -lt $args.Count; $index += 2) {
    $name = [string]$args[$index]
    $value = [string]$args[$index + 1]
    if ($name -cnotmatch "^--[A-Za-z][A-Za-z0-9]*$" -or $values.ContainsKey($name)) {
      $structuralFailure = $true
      break
    }
    $values[$name] = $value
  }
}
if ($structuralFailure) { exit 80 }

$hashArguments = [ordered]@{
  outerSha256 = "--ExpectedOuterSha256"
  outerContractSha256 = "--ExpectedOuterContractSha256"
  innerTransportSha256 = "--ExpectedInnerTransportSha256"
  earlyContractSha256 = "--ExpectedEarlyContractSha256"
  securityBootstrapSha256 = "--ExpectedSecurityBootstrapSha256"
  childSha256 = "--ExpectedChildSha256"
  diagnosticSha256 = "--ExpectedDiagnosticSha256"
  diagnosticContractSha256 = "--ExpectedDiagnosticContractSha256"
  inventorySha256 = "--ExpectedInventorySha256"
}
$minimumNames = @(
  "--AuthorizationId", "--InvocationNonce", "--RepositoryHead", "--Mode",
  "--EvidenceDirectory"
) + @($hashArguments.Values)
if (@($minimumNames | Where-Object { -not $values.ContainsKey($_) }).Count -gt 0 -or
  [string]$values["--AuthorizationId"] -cnotmatch "^[A-Z0-9-]{12,120}$" -or
  [string]$values["--InvocationNonce"] -cnotmatch "^[a-f0-9]{32}$" -or
  [string]$values["--RepositoryHead"] -cnotmatch "^[a-f0-9]{40}$") {
  exit 80
}
$hashes = @{}
foreach ($entry in $hashArguments.GetEnumerator()) {
  $value = [string]$values[$entry.Value]
  if ($value -cnotmatch "^[a-f0-9]{64}$") { exit 80 }
  $hashes[$entry.Key] = $value
}
$evidenceRoot = Get-RisePalsParentBuiltinEvidenceRoot `
  -Path ([string]$values["--EvidenceDirectory"])
if ($null -eq $evidenceRoot) { exit 82 }
$closedMode = if ([string]$values["--Mode"] -in @("PreflightOnly", "LiveReadOnly")) {
  [string]$values["--Mode"]
} else {
  "Unvalidated"
}
$marker = [pscustomobject][ordered]@{
  schemaVersion = "rise-pals-node-parent-entry-marker-v1"
  authorizationId = [string]$values["--AuthorizationId"]
  invocationNonce = [string]$values["--InvocationNonce"]
  repositoryHead = [string]$values["--RepositoryHead"]
  mode = $closedMode
  outerSha256 = [string]$hashes.outerSha256
  outerContractSha256 = [string]$hashes.outerContractSha256
  innerTransportSha256 = [string]$hashes.innerTransportSha256
  earlyContractSha256 = [string]$hashes.earlyContractSha256
  securityBootstrapSha256 = [string]$hashes.securityBootstrapSha256
  childSha256 = [string]$hashes.childSha256
  diagnosticSha256 = [string]$hashes.diagnosticSha256
  diagnosticContractSha256 = [string]$hashes.diagnosticContractSha256
  inventorySha256 = [string]$hashes.inventorySha256
  completedStages = @("parent-entry-received")
  lastCompletedStage = "parent-entry-received"
  markerDigest = $null
}
$marker.markerDigest = Get-RisePalsParentBuiltinMarkerDigest -Marker $marker
try {
  $markerPath = Write-RisePalsParentBuiltinMarker -Marker $marker -EvidenceRoot $evidenceRoot
} catch {
  exit 83
}

$outerContractPath = Join-Path $PSScriptRoot "node-destination-parent-entry-contract.psm1"
try {
  Import-Module -Name $outerContractPath -Force -ErrorAction Stop
  $marker = Read-RisePalsNodeParentMarker -Path $markerPath `
    -AuthorizationId $marker.authorizationId -InvocationNonce $marker.invocationNonce `
    -RepositoryHead $marker.repositoryHead -Hashes $hashes
} catch {
  exit 84
}

$requiredNames = @(
  "--Mode", "--AuthorizationId", "--InvocationNonce", "--RepositoryHead",
  "--InventoryPath", "--EvidenceDirectory", "--RepositoryRoot"
) + @($hashArguments.Values)
$simulationControlNames = @("--SimulationRoot", "--Scenario", "--SimulationFault")
$simulationControlInjected = @($simulationControlNames | Where-Object {
    $values.ContainsKey($_)
  }).Count -gt 0
$completed = @("parent-entry-received")
$failedStage = $null
$failureCategory = $null
$processCreated = $false
$childExitCode = $null
$nativeErrorCode = $null
$hResult = $null
$innerRequestPresent = $false
$innerRequestDigest = $null
$innerCheckpointPresent = $false
$innerCheckpointDigest = $null
$innerFinalPresent = $false
$innerFinalDigest = $null
$innerEvidenceRoot = $null
$earlyContractPath = Join-Path $PSScriptRoot "node-destination-early-transport.psm1"
$innerTransportPath = Join-Path $PSScriptRoot "Invoke-RisePalsNodeDestinationDiagnosticTransport.ps1"
$securityBootstrapPath = Join-Path $PSScriptRoot "windows-powershell-security-bootstrap.ps1"
$childPath = Join-Path $PSScriptRoot "Invoke-RisePalsNodeDestinationDiagnosticChild.ps1"
$diagnosticPath = Join-Path $PSScriptRoot "Invoke-RisePalsNodeDestinationDiagnostic.ps1"
$diagnosticContractPath = Join-Path $PSScriptRoot "node-destination-diagnostic-contract.psm1"
$outerPath = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)

$actualNames = @($values.Keys | Where-Object { $_ -notin $simulationControlNames } |
    Sort-Object -CaseSensitive)
$expectedNames = @($requiredNames | Sort-Object -CaseSensitive)
if (($actualNames -join "`n") -cne ($expectedNames -join "`n") -or
  @($requiredNames | Where-Object { [string]::IsNullOrWhiteSpace([string]$values[$_]) }).Count -gt 0) {
  $failedStage = "primitive-arguments-validated"
  $failureCategory = "primitive_argument_failure"
} else {
  $completed += "primitive-arguments-validated"
}

if ($null -eq $failedStage) {
  if (-not (Test-RisePalsParentRegularFile $earlyContractPath) -or
    (Get-RisePalsNodeParentSha256File -LiteralPath $earlyContractPath) -cne
      [string]$hashes.earlyContractSha256) {
    $failedStage = "early-contract-available"
    $failureCategory = "early_contract_failure"
  } else {
    try {
      Import-Module -Name $earlyContractPath -Force -ErrorAction Stop
      $completed += "early-contract-available"
    } catch {
      $failedStage = "early-contract-available"
      $failureCategory = "early_contract_failure"
    }
  }
}

if ($null -eq $failedStage) {
  if ([string]$values["--Mode"] -notin @("PreflightOnly", "LiveReadOnly") -or
    [string]$marker.mode -cne [string]$values["--Mode"] -or $simulationControlInjected) {
    $failedStage = "mode-validated"
    $failureCategory = "mode_validation_failure"
  } else {
    $completed += "mode-validated"
  }
}

$repository = $null
if ($null -eq $failedStage) {
  try {
    $repository = [IO.Path]::GetFullPath([string]$values["--RepositoryRoot"]).TrimEnd('\')
    $head = (& git -c ("safe.directory={0}" -f $repository.Replace("\", "/")) `
        -C $repository rev-parse HEAD 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $head -cne [string]$marker.repositoryHead) {
      throw "repository-binding"
    }
    $completed += "repository-head-validated"
  } catch {
    $failedStage = "repository-head-validated"
    $failureCategory = "repository_binding_failure"
  }
}

if ($null -eq $failedStage) {
  try {
    $expectedMarkerName = Split-Path -Leaf $markerPath
    $evidenceRoot = Assert-RisePalsNodeParentEvidenceDirectory -Path $evidenceRoot `
      -AllowedChildNames @($expectedMarkerName)
    $completed += "evidence-directory-validated"
  } catch {
    $failedStage = "evidence-directory-validated"
    $failureCategory = "evidence_boundary_failure"
  }
}

$inventoryPath = $null
if ($null -eq $failedStage) {
  try {
    $inventoryPath = [IO.Path]::GetFullPath([string]$values["--InventoryPath"])
    if (-not (Test-RisePalsParentRegularFile $inventoryPath) -or
      $inventoryPath.StartsWith("C:\RisePals\", [StringComparison]::OrdinalIgnoreCase)) {
      throw "inventory-path"
    }
    $completed += "inventory-path-validated"
  } catch {
    $failedStage = "inventory-path-validated"
    $failureCategory = "inventory_path_failure"
  }
}

if ($null -eq $failedStage) {
  $paths = [ordered]@{
    outerSha256 = $outerPath
    outerContractSha256 = $outerContractPath
    innerTransportSha256 = $innerTransportPath
    earlyContractSha256 = $earlyContractPath
    securityBootstrapSha256 = $securityBootstrapPath
    childSha256 = $childPath
    diagnosticSha256 = $diagnosticPath
    diagnosticContractSha256 = $diagnosticContractPath
    inventorySha256 = $inventoryPath
  }
  try {
    foreach ($entry in $paths.GetEnumerator()) {
      if (-not (Test-RisePalsParentRegularFile $entry.Value) -or
        (Get-RisePalsNodeParentSha256File -LiteralPath $entry.Value) -cne
          [string]$hashes[$entry.Key]) {
        throw "artifact-hash"
      }
    }
    $completed += "committed-artifact-hashes-validated"
  } catch {
    $failedStage = "committed-artifact-hashes-validated"
    $failureCategory = "artifact_hash_failure"
  }
}

if ($null -eq $failedStage) {
  if (-not (Test-RisePalsNodeParentApproval -Target $evidenceRoot `
      -Action ("Run the {0} Node parent pre-request chain" -f [string]$marker.mode) `
      -Confirm:$false)) {
    $failedStage = "should-process-approved"
    $failureCategory = "approval_failure"
  } else {
    $completed += "should-process-approved"
  }
}

$innerRequestPath = $null
if ($null -eq $failedStage) {
  try {
    $innerEvidenceRoot = Join-Path $evidenceRoot ("inner-{0}" -f [string]$marker.invocationNonce)
    if ([IO.Directory]::Exists($innerEvidenceRoot)) { throw "inner-replay" }
    [IO.Directory]::CreateDirectory($innerEvidenceRoot) | Out-Null
    $innerItem = Get-Item -LiteralPath $innerEvidenceRoot -Force -ErrorAction Stop
    if (($innerItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      @(Get-ChildItem -LiteralPath $innerEvidenceRoot -Force).Count -ne 0) {
      throw "inner-boundary"
    }
    $innerRequest = New-RisePalsNodeEarlyRequest -AuthorizationId $marker.authorizationId `
      -InvocationNonce $marker.invocationNonce -RepositoryHead $marker.repositoryHead `
      -LauncherSha256 $marker.innerTransportSha256 `
      -EarlyContractSha256 $marker.earlyContractSha256 `
      -SecurityBootstrapSha256 $marker.securityBootstrapSha256 `
      -ChildSha256 $marker.childSha256 -DiagnosticSha256 $marker.diagnosticSha256 `
      -DiagnosticContractSha256 $marker.diagnosticContractSha256 `
      -InventorySha256 $marker.inventorySha256
    $innerRequestPath = Write-RisePalsNodeEarlyRequestAtomic -Request $innerRequest `
      -EvidenceDirectory $innerEvidenceRoot
    $innerRequest = Read-RisePalsNodeEarlyRequest -Path $innerRequestPath `
      -ExpectedAuthorizationId $marker.authorizationId `
      -ExpectedInvocationNonce $marker.invocationNonce `
      -ExpectedRepositoryHead $marker.repositoryHead `
      -ExpectedLauncherSha256 $marker.innerTransportSha256 `
      -ExpectedEarlyContractSha256 $marker.earlyContractSha256 `
      -ExpectedSecurityBootstrapSha256 $marker.securityBootstrapSha256 `
      -ExpectedChildSha256 $marker.childSha256 `
      -ExpectedDiagnosticSha256 $marker.diagnosticSha256 `
      -ExpectedDiagnosticContractSha256 $marker.diagnosticContractSha256 `
      -ExpectedInventorySha256 $marker.inventorySha256
    $innerRequestPresent = $true
    $innerRequestDigest = [string]$innerRequest.requestDigest
    $completed += "inner-request-created"
  } catch {
    $failedStage = "inner-request-created"
    $failureCategory = "request_persistence_failure"
  }
}

if ($null -eq $failedStage -and [string]$marker.mode -ceq "LiveReadOnly") {
  $completed += "inner-transport-dispatched"
  try {
    [void](& $innerTransportPath -Mode LiveReadOnly -Scenario Success `
        -AuthorizationId $marker.authorizationId -InvocationNonce $marker.invocationNonce `
        -RepositoryHead $marker.repositoryHead -InventoryPath $inventoryPath `
        -EvidenceDirectory $innerEvidenceRoot -RepositoryRoot $repository `
        -PrevalidatedRequestPath $innerRequestPath -Confirm:$false)
    $innerCheckpointPath = Get-RisePalsNodeEarlyCheckpointPath `
      -EvidenceDirectory $innerEvidenceRoot -InvocationNonce $marker.invocationNonce
    $innerResultPath = Get-RisePalsNodeEarlyResultPath `
      -EvidenceDirectory $innerEvidenceRoot -InvocationNonce $marker.invocationNonce
    $innerCheckpoint = Read-RisePalsNodeEarlyResult -Path $innerCheckpointPath `
      -Request $innerRequest
    $innerFinal = Read-RisePalsNodeEarlyResult -Path $innerResultPath `
      -Request $innerRequest -ExpectedCheckpointDigest $innerCheckpoint.evidenceDigest
    $innerCheckpointPresent = $true
    $innerCheckpointDigest = [string]$innerCheckpoint.evidenceDigest
    $innerFinalPresent = $true
    $innerFinalDigest = [string]$innerFinal.evidenceDigest
    $processCreated = [bool]$innerFinal.processCreated
    $childExitCode = $innerFinal.childExitCode
    if ($null -ne $innerFinal.firstFailedStage) {
      $failedStage = "inner-transport-dispatched"
      $failureCategory = "inner_transport_failure"
      $nativeErrorCode = $innerFinal.nativeErrorCode
      $hResult = $innerFinal.hResult
    }
  } catch {
    $failedStage = "inner-transport-dispatched"
    $failureCategory = "inner_transport_failure"
  }
}

$checkpoint = New-RisePalsNodeParentResult -RecordType checkpoint -Marker $marker `
  -CompletedStages $completed -FirstFailedStage $failedStage `
  -SanitizedFailureCategory $failureCategory -ProcessCreated $processCreated `
  -ChildExitCode $childExitCode -NativeErrorCode $nativeErrorCode -HResult $hResult `
  -InnerRequestPresent $innerRequestPresent -InnerRequestDigest $innerRequestDigest `
  -InnerCheckpointPresent $innerCheckpointPresent -InnerCheckpointDigest $innerCheckpointDigest `
  -InnerFinalPresent $innerFinalPresent -InnerFinalDigest $innerFinalDigest
$checkpointPath = Write-RisePalsNodeParentResultAtomic -Result $checkpoint `
  -EvidenceDirectory $evidenceRoot
$checkpoint = Read-RisePalsNodeParentResult -Path $checkpointPath -Marker $marker
$completed += "outer-parent-reopened-result"

$cleanupAttempted = $true
$counts = Get-RisePalsParentResidueCounts -EvidenceRoot $evidenceRoot
$cleanupCompleted = [int]$counts.transient -eq 0 -and [int]$counts.temporary -eq 0
if ($cleanupCompleted) {
  $completed += "cleanup-complete"
} else {
  $failedStage = "cleanup-complete"
  $failureCategory = "cleanup_failure"
}
$final = New-RisePalsNodeParentResult -RecordType final -Marker $marker `
  -CompletedStages $completed -FirstFailedStage $failedStage `
  -SanitizedFailureCategory $failureCategory -ProcessCreated $processCreated `
  -ChildExitCode $childExitCode -NativeErrorCode $nativeErrorCode -HResult $hResult `
  -InnerRequestPresent $innerRequestPresent -InnerRequestDigest $innerRequestDigest `
  -InnerCheckpointPresent $innerCheckpointPresent -InnerCheckpointDigest $innerCheckpointDigest `
  -InnerFinalPresent $innerFinalPresent -InnerFinalDigest $innerFinalDigest `
  -CleanupAttempted $cleanupAttempted -CleanupCompleted $cleanupCompleted `
  -TransientResidueCount $counts.transient -TemporaryResidueCount $counts.temporary `
  -CheckpointDigest $checkpoint.evidenceDigest
$finalPath = Write-RisePalsNodeParentResultAtomic -Result $final `
  -EvidenceDirectory $evidenceRoot
$final = Read-RisePalsNodeParentResult -Path $finalPath -Marker $marker `
  -ExpectedCheckpointDigest $checkpoint.evidenceDigest

if ($null -eq $final.firstFailedStage) { exit 0 }
exit 90
