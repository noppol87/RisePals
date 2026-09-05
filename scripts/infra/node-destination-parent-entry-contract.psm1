Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RisePalsNodeParentMarkerSchema = "rise-pals-node-parent-entry-marker-v1"
$script:RisePalsNodeParentResultSchema = "rise-pals-node-parent-entry-result-v1"
$script:RisePalsNodeParentModes = @("PreflightOnly", "LiveReadOnly", "Unvalidated")
$script:RisePalsNodeParentStages = @(
  "parent-entry-received",
  "primitive-arguments-validated",
  "early-contract-available",
  "mode-validated",
  "repository-head-validated",
  "evidence-directory-validated",
  "inventory-path-validated",
  "committed-artifact-hashes-validated",
  "should-process-approved",
  "inner-request-created",
  "inner-transport-dispatched",
  "outer-parent-reopened-result",
  "cleanup-complete"
)
$script:RisePalsNodeParentCategories = @(
  "primitive_argument_failure",
  "parent_entry_persistence_failure",
  "early_contract_failure",
  "mode_validation_failure",
  "repository_binding_failure",
  "evidence_boundary_failure",
  "inventory_path_failure",
  "artifact_hash_failure",
  "approval_failure",
  "request_persistence_failure",
  "inner_transport_failure",
  "digest_failure",
  "ordering_failure",
  "replay_failure",
  "cleanup_failure",
  "final_result_failure"
)
$script:RisePalsNodeParentHashProperties = @(
  "outerSha256",
  "outerContractSha256",
  "innerTransportSha256",
  "earlyContractSha256",
  "securityBootstrapSha256",
  "childSha256",
  "diagnosticSha256",
  "diagnosticContractSha256",
  "inventorySha256"
)

function Get-RisePalsNodeParentSha256Bytes {
  param([Parameter(Mandatory = $true)][byte[]]$Bytes)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace("-", "").ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Get-RisePalsNodeParentSha256Text {
  param([Parameter(Mandatory = $true)][string]$Text)
  return Get-RisePalsNodeParentSha256Bytes -Bytes ([Text.UTF8Encoding]::new($false).GetBytes($Text))
}

function Get-RisePalsNodeParentSha256File {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)
  return Get-RisePalsNodeParentSha256Bytes -Bytes ([IO.File]::ReadAllBytes(
      [IO.Path]::GetFullPath($LiteralPath)
    ))
}

function Test-RisePalsNodeParentHash {
  param([AllowNull()][object]$Value)
  return $null -ne $Value -and [string]$Value -cmatch "^[a-f0-9]{64}$"
}

function Test-RisePalsNodeParentInteger {
  param(
    [AllowNull()][object]$Value,
    [int64]$Minimum = [int32]::MinValue,
    [int64]$Maximum = [int32]::MaxValue
  )
  if ($null -eq $Value) { return $false }
  $number = 0L
  if (-not [int64]::TryParse([string]$Value, [ref]$number)) { return $false }
  return $number -ge $Minimum -and $number -le $Maximum
}

function Assert-RisePalsNodeParentExactProperties {
  param(
    [Parameter(Mandatory = $true)][object]$Value,
    [Parameter(Mandatory = $true)][string[]]$Names,
    [Parameter(Mandatory = $true)][string]$Predicate
  )
  $actual = @($Value.PSObject.Properties.Name | Sort-Object -CaseSensitive)
  $expected = @($Names | Sort-Object -CaseSensitive)
  if (($actual -join "`n") -cne ($expected -join "`n")) { throw $Predicate }
}

function Get-RisePalsNodeParentMarkerDigest {
  param([Parameter(Mandatory = $true)][object]$Marker)
  $lines = @(
    "schemaVersion=$([string]$Marker.schemaVersion)",
    "authorizationId=$([string]$Marker.authorizationId)",
    "invocationNonce=$([string]$Marker.invocationNonce)",
    "repositoryHead=$([string]$Marker.repositoryHead)",
    "mode=$([string]$Marker.mode)"
  )
  foreach ($name in $script:RisePalsNodeParentHashProperties) {
    $lines += "$name=$([string]$Marker.$name)"
  }
  $lines += "completedStages=$(@($Marker.completedStages) -join ',')"
  $lines += "lastCompletedStage=$([string]$Marker.lastCompletedStage)"
  return Get-RisePalsNodeParentSha256Text -Text (($lines -join "`n") + "`n")
}

function New-RisePalsNodeParentMarker {
  param(
    [Parameter(Mandatory = $true)][string]$AuthorizationId,
    [Parameter(Mandatory = $true)][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][ValidateSet("PreflightOnly", "LiveReadOnly", "Unvalidated")]
    [string]$Mode,
    [Parameter(Mandatory = $true)][hashtable]$Hashes
  )
  $marker = [pscustomobject][ordered]@{
    schemaVersion = $script:RisePalsNodeParentMarkerSchema
    authorizationId = $AuthorizationId
    invocationNonce = $InvocationNonce
    repositoryHead = $RepositoryHead
    mode = $Mode
    outerSha256 = [string]$Hashes.outerSha256
    outerContractSha256 = [string]$Hashes.outerContractSha256
    innerTransportSha256 = [string]$Hashes.innerTransportSha256
    earlyContractSha256 = [string]$Hashes.earlyContractSha256
    securityBootstrapSha256 = [string]$Hashes.securityBootstrapSha256
    childSha256 = [string]$Hashes.childSha256
    diagnosticSha256 = [string]$Hashes.diagnosticSha256
    diagnosticContractSha256 = [string]$Hashes.diagnosticContractSha256
    inventorySha256 = [string]$Hashes.inventorySha256
    completedStages = @("parent-entry-received")
    lastCompletedStage = "parent-entry-received"
    markerDigest = $null
  }
  $marker.markerDigest = Get-RisePalsNodeParentMarkerDigest -Marker $marker
  return $marker
}

function Assert-RisePalsNodeParentMarker {
  param(
    [Parameter(Mandatory = $true)][object]$Marker,
    [Parameter(Mandatory = $true)][string]$AuthorizationId,
    [Parameter(Mandatory = $true)][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][hashtable]$Hashes
  )
  Assert-RisePalsNodeParentExactProperties -Value $Marker -Predicate "parent-marker-properties" `
    -Names @(
      "schemaVersion", "authorizationId", "invocationNonce", "repositoryHead", "mode",
      "outerSha256", "outerContractSha256", "innerTransportSha256", "earlyContractSha256",
      "securityBootstrapSha256", "childSha256", "diagnosticSha256",
      "diagnosticContractSha256", "inventorySha256", "completedStages",
      "lastCompletedStage", "markerDigest"
    )
  if ([string]$Marker.schemaVersion -cne $script:RisePalsNodeParentMarkerSchema -or
    [string]$Marker.authorizationId -cne $AuthorizationId -or
    [string]$Marker.invocationNonce -cne $InvocationNonce -or
    [string]$Marker.repositoryHead -cne $RepositoryHead -or
    [string]$Marker.mode -notin $script:RisePalsNodeParentModes -or
    (@($Marker.completedStages) -join "|") -cne "parent-entry-received" -or
    [string]$Marker.lastCompletedStage -cne "parent-entry-received") {
    throw "parent-marker-binding"
  }
  foreach ($name in $script:RisePalsNodeParentHashProperties) {
    if (-not (Test-RisePalsNodeParentHash $Marker.$name) -or
      [string]$Marker.$name -cne [string]$Hashes[$name]) {
      throw "parent-marker-binding"
    }
  }
  if (-not (Test-RisePalsNodeParentHash $Marker.markerDigest) -or
    [string]$Marker.markerDigest -cne (Get-RisePalsNodeParentMarkerDigest -Marker $Marker)) {
    throw "parent-marker-digest"
  }
  return $Marker
}

function Get-RisePalsNodeParentResultDigest {
  param([Parameter(Mandatory = $true)][object]$Result)
  $nullable = {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return "-" }
    return [string]$Value
  }
  $lines = @(
    "schemaVersion=$([string]$Result.schemaVersion)",
    "recordType=$([string]$Result.recordType)",
    "authorizationId=$([string]$Result.authorizationId)",
    "invocationNonce=$([string]$Result.invocationNonce)",
    "repositoryHead=$([string]$Result.repositoryHead)",
    "mode=$([string]$Result.mode)"
  )
  foreach ($name in $script:RisePalsNodeParentHashProperties) {
    $lines += "$name=$([string]$Result.$name)"
  }
  $lines += @(
    "entryMarkerDigest=$([string]$Result.entryMarkerDigest)",
    "processCreated=$([bool]$Result.processCreated)",
    "childExitCode=$(& $nullable $Result.childExitCode)",
    "completedStages=$(@($Result.completedStages) -join ',')",
    "lastCompletedStage=$([string]$Result.lastCompletedStage)",
    "firstFailedStage=$(& $nullable $Result.firstFailedStage)",
    "sanitizedFailureCategory=$(& $nullable $Result.sanitizedFailureCategory)",
    "nativeErrorCode=$(& $nullable $Result.nativeErrorCode)",
    "hResult=$(& $nullable $Result.hResult)",
    "innerRequestPresent=$([bool]$Result.innerRequestPresent)",
    "innerRequestDigest=$(& $nullable $Result.innerRequestDigest)",
    "innerCheckpointPresent=$([bool]$Result.innerCheckpointPresent)",
    "innerCheckpointDigest=$(& $nullable $Result.innerCheckpointDigest)",
    "innerFinalPresent=$([bool]$Result.innerFinalPresent)",
    "innerFinalDigest=$(& $nullable $Result.innerFinalDigest)",
    "cleanupAttempted=$([bool]$Result.cleanupAttempted)",
    "cleanupCompleted=$([bool]$Result.cleanupCompleted)",
    "transientResidueCount=$([int64]$Result.transientResidueCount)",
    "temporaryResidueCount=$([int64]$Result.temporaryResidueCount)",
    "checkpointDigest=$(& $nullable $Result.checkpointDigest)"
  )
  return Get-RisePalsNodeParentSha256Text -Text (($lines -join "`n") + "`n")
}

function New-RisePalsNodeParentResult {
  param(
    [Parameter(Mandatory = $true)][ValidateSet("checkpoint", "final")][string]$RecordType,
    [Parameter(Mandatory = $true)][object]$Marker,
    [Parameter(Mandatory = $true)][string[]]$CompletedStages,
    [AllowNull()][object]$FirstFailedStage,
    [AllowNull()][object]$SanitizedFailureCategory,
    [bool]$ProcessCreated = $false,
    [AllowNull()][object]$ChildExitCode,
    [AllowNull()][object]$NativeErrorCode,
    [AllowNull()][object]$HResult,
    [bool]$InnerRequestPresent = $false,
    [AllowNull()][object]$InnerRequestDigest,
    [bool]$InnerCheckpointPresent = $false,
    [AllowNull()][object]$InnerCheckpointDigest,
    [bool]$InnerFinalPresent = $false,
    [AllowNull()][object]$InnerFinalDigest,
    [bool]$CleanupAttempted = $false,
    [bool]$CleanupCompleted = $false,
    [int64]$TransientResidueCount = 0,
    [int64]$TemporaryResidueCount = 0,
    [AllowNull()][object]$CheckpointDigest
  )
  $last = if ($CompletedStages.Count -gt 0) { [string]$CompletedStages[-1] } else { $null }
  $result = [pscustomobject][ordered]@{
    schemaVersion = $script:RisePalsNodeParentResultSchema
    recordType = $RecordType
    authorizationId = [string]$Marker.authorizationId
    invocationNonce = [string]$Marker.invocationNonce
    repositoryHead = [string]$Marker.repositoryHead
    mode = [string]$Marker.mode
    outerSha256 = [string]$Marker.outerSha256
    outerContractSha256 = [string]$Marker.outerContractSha256
    innerTransportSha256 = [string]$Marker.innerTransportSha256
    earlyContractSha256 = [string]$Marker.earlyContractSha256
    securityBootstrapSha256 = [string]$Marker.securityBootstrapSha256
    childSha256 = [string]$Marker.childSha256
    diagnosticSha256 = [string]$Marker.diagnosticSha256
    diagnosticContractSha256 = [string]$Marker.diagnosticContractSha256
    inventorySha256 = [string]$Marker.inventorySha256
    entryMarkerDigest = [string]$Marker.markerDigest
    processCreated = $ProcessCreated
    childExitCode = $ChildExitCode
    completedStages = @($CompletedStages)
    lastCompletedStage = $last
    firstFailedStage = $FirstFailedStage
    sanitizedFailureCategory = $SanitizedFailureCategory
    nativeErrorCode = $NativeErrorCode
    hResult = $HResult
    innerRequestPresent = $InnerRequestPresent
    innerRequestDigest = $InnerRequestDigest
    innerCheckpointPresent = $InnerCheckpointPresent
    innerCheckpointDigest = $InnerCheckpointDigest
    innerFinalPresent = $InnerFinalPresent
    innerFinalDigest = $InnerFinalDigest
    cleanupAttempted = $CleanupAttempted
    cleanupCompleted = $CleanupCompleted
    transientResidueCount = $TransientResidueCount
    temporaryResidueCount = $TemporaryResidueCount
    checkpointDigest = $CheckpointDigest
    evidenceDigest = $null
  }
  $result.evidenceDigest = Get-RisePalsNodeParentResultDigest -Result $result
  return $result
}

function Assert-RisePalsNodeParentResult {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][object]$Marker,
    [AllowNull()][string]$ExpectedCheckpointDigest
  )
  Assert-RisePalsNodeParentExactProperties -Value $Result -Predicate "parent-result-properties" `
    -Names @(
      "schemaVersion", "recordType", "authorizationId", "invocationNonce", "repositoryHead",
      "mode", "outerSha256", "outerContractSha256", "innerTransportSha256",
      "earlyContractSha256", "securityBootstrapSha256", "childSha256", "diagnosticSha256",
      "diagnosticContractSha256", "inventorySha256", "entryMarkerDigest", "processCreated",
      "childExitCode", "completedStages", "lastCompletedStage", "firstFailedStage",
      "sanitizedFailureCategory", "nativeErrorCode", "hResult", "innerRequestPresent",
      "innerRequestDigest", "innerCheckpointPresent", "innerCheckpointDigest",
      "innerFinalPresent", "innerFinalDigest", "cleanupAttempted", "cleanupCompleted",
      "transientResidueCount", "temporaryResidueCount", "checkpointDigest", "evidenceDigest"
    )
  if ([string]$Result.schemaVersion -cne $script:RisePalsNodeParentResultSchema -or
    [string]$Result.recordType -notin @("checkpoint", "final") -or
    [string]$Result.authorizationId -cne [string]$Marker.authorizationId -or
    [string]$Result.invocationNonce -cne [string]$Marker.invocationNonce -or
    [string]$Result.repositoryHead -cne [string]$Marker.repositoryHead -or
    [string]$Result.mode -cne [string]$Marker.mode -or
    [string]$Result.entryMarkerDigest -cne [string]$Marker.markerDigest) {
    throw "parent-result-binding"
  }
  foreach ($name in $script:RisePalsNodeParentHashProperties) {
    if ([string]$Result.$name -cne [string]$Marker.$name) { throw "parent-result-binding" }
  }
  $stages = @($Result.completedStages)
  $seen = @{}
  $lastIndex = -1
  foreach ($stage in $stages) {
    $index = [Array]::IndexOf($script:RisePalsNodeParentStages, [string]$stage)
    if ($index -lt 0 -or $index -le $lastIndex -or $seen.ContainsKey([string]$stage)) {
      throw "parent-result-ordering"
    }
    $seen[[string]$stage] = $true
    $lastIndex = $index
  }
  $expectedLast = if ($stages.Count -gt 0) { [string]$stages[-1] } else { $null }
  if ([string]$Result.lastCompletedStage -cne [string]$expectedLast -or
    ($stages.Count -gt 0 -and [string]$stages[0] -cne "parent-entry-received")) {
    throw "parent-result-ordering"
  }
  if ([string]$Result.mode -ceq "PreflightOnly" -and
    "inner-transport-dispatched" -in $stages) {
    throw "parent-result-preflight"
  }
  if ("inner-request-created" -in $stages) {
    if (-not [bool]$Result.innerRequestPresent -or
      -not (Test-RisePalsNodeParentHash $Result.innerRequestDigest)) {
      throw "parent-result-inner-request"
    }
  } elseif ([bool]$Result.innerRequestPresent -or $null -ne $Result.innerRequestDigest) {
    throw "parent-result-inner-request"
  }
  if ("inner-transport-dispatched" -in $stages) {
    if ([string]$Result.mode -cne "LiveReadOnly") { throw "parent-result-inner-transport" }
  } elseif ([bool]$Result.innerCheckpointPresent -or [bool]$Result.innerFinalPresent -or
    $null -ne $Result.innerCheckpointDigest -or $null -ne $Result.innerFinalDigest) {
    throw "parent-result-inner-transport"
  }
  foreach ($pair in @(
      @([bool]$Result.innerCheckpointPresent, $Result.innerCheckpointDigest),
      @([bool]$Result.innerFinalPresent, $Result.innerFinalDigest)
    )) {
    if (($pair[0] -and -not (Test-RisePalsNodeParentHash $pair[1])) -or
      (-not $pair[0] -and $null -ne $pair[1])) {
      throw "parent-result-inner-transport"
    }
  }
  if (-not (Test-RisePalsNodeParentInteger $Result.transientResidueCount 0 100000) -or
    -not (Test-RisePalsNodeParentInteger $Result.temporaryResidueCount 0 100000)) {
    throw "parent-result-count"
  }
  $failed = $Result.firstFailedStage
  $category = $Result.sanitizedFailureCategory
  if (($null -eq $failed) -ne ($null -eq $category) -or
    ($null -ne $failed -and [string]$failed -notin $script:RisePalsNodeParentStages) -or
    ($null -ne $category -and [string]$category -notin $script:RisePalsNodeParentCategories)) {
    throw "parent-result-failure"
  }
  $failureMap = @{
    "parent-entry-received" = @("parent_entry_persistence_failure", "digest_failure")
    "primitive-arguments-validated" = @("primitive_argument_failure", "ordering_failure")
    "early-contract-available" = @("early_contract_failure", "digest_failure")
    "mode-validated" = @("mode_validation_failure")
    "repository-head-validated" = @("repository_binding_failure")
    "evidence-directory-validated" = @("evidence_boundary_failure", "replay_failure")
    "inventory-path-validated" = @("inventory_path_failure")
    "committed-artifact-hashes-validated" = @("artifact_hash_failure", "digest_failure")
    "should-process-approved" = @("approval_failure")
    "inner-request-created" = @("request_persistence_failure", "digest_failure", "replay_failure")
    "inner-transport-dispatched" = @("inner_transport_failure")
    "outer-parent-reopened-result" = @("final_result_failure", "digest_failure", "ordering_failure", "replay_failure")
    "cleanup-complete" = @("cleanup_failure", "final_result_failure")
  }
  if ($null -ne $failed -and
    (-not $failureMap.ContainsKey([string]$failed) -or
      [string]$category -notin $failureMap[[string]$failed])) {
    throw "parent-result-failure"
  }
  if ($null -ne $Result.nativeErrorCode -or $null -ne $Result.hResult) {
    if ([string]$category -notin @("parent_entry_persistence_failure", "inner_transport_failure") -or
      ($null -ne $Result.nativeErrorCode -and
        -not (Test-RisePalsNodeParentInteger $Result.nativeErrorCode 0 [int32]::MaxValue)) -or
      ($null -ne $Result.hResult -and
        -not (Test-RisePalsNodeParentInteger $Result.hResult [int32]::MinValue [int32]::MaxValue))) {
      throw "parent-result-native"
    }
  }
  if ([string]$Result.recordType -ceq "checkpoint") {
    if ($null -ne $Result.checkpointDigest -or [bool]$Result.cleanupAttempted -or
      [bool]$Result.cleanupCompleted -or "outer-parent-reopened-result" -in $stages -or
      "cleanup-complete" -in $stages) {
      throw "parent-result-checkpoint"
    }
  } else {
    if (-not (Test-RisePalsNodeParentHash $Result.checkpointDigest) -or
      [string]$Result.checkpointDigest -cne $ExpectedCheckpointDigest -or
      "outer-parent-reopened-result" -notin $stages -or
      -not [bool]$Result.cleanupAttempted) {
      throw "parent-result-final"
    }
    if ([bool]$Result.cleanupCompleted) {
      if ("cleanup-complete" -notin $stages -or [int64]$Result.transientResidueCount -ne 0 -or
        [int64]$Result.temporaryResidueCount -ne 0 -or
        [string]$category -ceq "cleanup_failure") {
        throw "parent-result-cleanup"
      }
    } elseif ([string]$category -cne "cleanup_failure") {
      throw "parent-result-cleanup"
    }
  }
  if ($null -eq $failed -and [string]$Result.recordType -ceq "final") {
    $preflightStages = @($script:RisePalsNodeParentStages | Where-Object {
        $_ -cne "inner-transport-dispatched"
      })
    $required = if ([string]$Result.mode -ceq "PreflightOnly") {
      $preflightStages
    } elseif ([string]$Result.mode -ceq "LiveReadOnly") {
      $script:RisePalsNodeParentStages
    } else {
      @()
    }
    if (($stages -join "|") -cne ($required -join "|") -or
      -not [bool]$Result.innerRequestPresent -or -not [bool]$Result.cleanupCompleted) {
      throw "parent-result-success"
    }
    if ([string]$Result.mode -ceq "PreflightOnly") {
      if ([bool]$Result.processCreated -or $null -ne $Result.childExitCode -or
        [bool]$Result.innerCheckpointPresent -or [bool]$Result.innerFinalPresent) {
        throw "parent-result-preflight"
      }
    } elseif (-not [bool]$Result.processCreated -or [int]$Result.childExitCode -ne 0 -or
      -not [bool]$Result.innerCheckpointPresent -or -not [bool]$Result.innerFinalPresent) {
      throw "parent-result-success"
    }
  }
  if (-not (Test-RisePalsNodeParentHash $Result.evidenceDigest) -or
    [string]$Result.evidenceDigest -cne (Get-RisePalsNodeParentResultDigest -Result $Result)) {
    throw "parent-result-digest"
  }
  return $Result
}

function Assert-RisePalsNodeParentEvidenceDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string[]]$AllowedChildNames = @()
  )
  $exact = [IO.Path]::GetFullPath($Path).TrimEnd('\')
  $allowed = [IO.Path]::GetFullPath((Join-Path (
        [Environment]::GetFolderPath("MyDocuments")
      ) "Codex")).TrimEnd('\')
  if (-not $exact.StartsWith($allowed + "\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "parent-evidence-boundary"
  }
  $relative = $exact.Substring($allowed.Length + 1)
  $cursor = $allowed
  foreach ($component in $relative.Split([char[]]@('\'), [StringSplitOptions]::RemoveEmptyEntries)) {
    if ($component -in @(".", "..")) { throw "parent-evidence-boundary" }
    $cursor = Join-Path $cursor $component
    $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
    if (-not $item.PSIsContainer -or
      ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "parent-evidence-reparse"
    }
  }
  $children = @(Get-ChildItem -LiteralPath $exact -Force)
  $actual = @($children | ForEach-Object { $_.Name } | Sort-Object -CaseSensitive)
  $expected = @($AllowedChildNames | Sort-Object -CaseSensitive)
  if (($actual -join "`n") -cne ($expected -join "`n")) {
    throw "parent-evidence-not-fresh"
  }
  foreach ($child in $children) {
    if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "parent-evidence-reparse"
    }
  }
  return $exact
}

function Write-RisePalsNodeParentJsonAtomic {
  param(
    [Parameter(Mandatory = $true)][object]$Value,
    [Parameter(Mandatory = $true)][string]$FinalPath,
    [switch]$InterruptBeforeMove
  )
  $final = [IO.Path]::GetFullPath($FinalPath)
  $temporary = $final + ".tmp"
  if ([IO.File]::Exists($final) -or [IO.File]::Exists($temporary)) {
    throw "parent-atomic-path-exists"
  }
  [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Compress -Depth 12),
    [Text.UTF8Encoding]::new($false))
  if ($InterruptBeforeMove) { throw "parent-atomic-interrupted" }
  [IO.File]::Move($temporary, $final)
  return $final
}

function Read-RisePalsNodeParentJson {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)
  try {
    $bytes = [IO.File]::ReadAllBytes([IO.Path]::GetFullPath($LiteralPath))
    return [Text.UTF8Encoding]::new($false, $true).GetString($bytes) |
      ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "parent-json-invalid"
  }
}

function Get-RisePalsNodeParentMarkerPath {
  param([string]$EvidenceDirectory, [string]$InvocationNonce)
  return Join-Path $EvidenceDirectory ("node-parent-entry-marker-{0}.json" -f $InvocationNonce)
}

function Get-RisePalsNodeParentCheckpointPath {
  param([string]$EvidenceDirectory, [string]$InvocationNonce)
  return Join-Path $EvidenceDirectory ("node-parent-checkpoint-{0}.json" -f $InvocationNonce)
}

function Get-RisePalsNodeParentResultPath {
  param([string]$EvidenceDirectory, [string]$InvocationNonce)
  return Join-Path $EvidenceDirectory ("node-parent-result-{0}.json" -f $InvocationNonce)
}

function Write-RisePalsNodeParentMarkerAtomic {
  param([object]$Marker, [string]$EvidenceDirectory, [switch]$InterruptBeforeMove)
  return Write-RisePalsNodeParentJsonAtomic -Value $Marker `
    -FinalPath (Get-RisePalsNodeParentMarkerPath -EvidenceDirectory $EvidenceDirectory `
      -InvocationNonce $Marker.invocationNonce) -InterruptBeforeMove:$InterruptBeforeMove
}

function Read-RisePalsNodeParentMarker {
  param(
    [string]$Path,
    [string]$AuthorizationId,
    [string]$InvocationNonce,
    [string]$RepositoryHead,
    [hashtable]$Hashes
  )
  $value = Read-RisePalsNodeParentJson -LiteralPath $Path
  return Assert-RisePalsNodeParentMarker -Marker $value -AuthorizationId $AuthorizationId `
    -InvocationNonce $InvocationNonce -RepositoryHead $RepositoryHead -Hashes $Hashes
}

function Write-RisePalsNodeParentResultAtomic {
  param(
    [object]$Result,
    [string]$EvidenceDirectory,
    [switch]$InterruptBeforeMove
  )
  $path = if ([string]$Result.recordType -ceq "checkpoint") {
    Get-RisePalsNodeParentCheckpointPath -EvidenceDirectory $EvidenceDirectory `
      -InvocationNonce $Result.invocationNonce
  } else {
    Get-RisePalsNodeParentResultPath -EvidenceDirectory $EvidenceDirectory `
      -InvocationNonce $Result.invocationNonce
  }
  return Write-RisePalsNodeParentJsonAtomic -Value $Result -FinalPath $path `
    -InterruptBeforeMove:$InterruptBeforeMove
}

function Read-RisePalsNodeParentResult {
  param(
    [string]$Path,
    [object]$Marker,
    [AllowNull()][string]$ExpectedCheckpointDigest
  )
  $value = Read-RisePalsNodeParentJson -LiteralPath $Path
  return Assert-RisePalsNodeParentResult -Result $value -Marker $Marker `
    -ExpectedCheckpointDigest $ExpectedCheckpointDigest
}

function Test-RisePalsNodeParentApproval {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Low")]
  param(
    [Parameter(Mandatory = $true)][string]$Target,
    [Parameter(Mandatory = $true)][string]$Action
  )
  return $PSCmdlet.ShouldProcess($Target, $Action)
}

Export-ModuleMember -Function @(
  "Get-RisePalsNodeParentSha256Bytes",
  "Get-RisePalsNodeParentSha256Text",
  "Get-RisePalsNodeParentSha256File",
  "Test-RisePalsNodeParentHash",
  "Test-RisePalsNodeParentInteger",
  "Assert-RisePalsNodeParentExactProperties",
  "Get-RisePalsNodeParentMarkerDigest",
  "New-RisePalsNodeParentMarker",
  "Assert-RisePalsNodeParentMarker",
  "Get-RisePalsNodeParentResultDigest",
  "New-RisePalsNodeParentResult",
  "Assert-RisePalsNodeParentResult",
  "Assert-RisePalsNodeParentEvidenceDirectory",
  "Write-RisePalsNodeParentJsonAtomic",
  "Read-RisePalsNodeParentJson",
  "Get-RisePalsNodeParentMarkerPath",
  "Get-RisePalsNodeParentCheckpointPath",
  "Get-RisePalsNodeParentResultPath",
  "Write-RisePalsNodeParentMarkerAtomic",
  "Read-RisePalsNodeParentMarker",
  "Write-RisePalsNodeParentResultAtomic",
  "Read-RisePalsNodeParentResult",
  "Test-RisePalsNodeParentApproval"
)
