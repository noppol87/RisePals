Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RisePalsNodeEarlyRequestSchema = "rise-pals-node-diagnostic-early-request-v1"
$script:RisePalsNodeEarlyMarkerSchema = "rise-pals-node-diagnostic-early-marker-v1"
$script:RisePalsNodeEarlyResultSchema = "rise-pals-node-diagnostic-early-result-v1"
$script:RisePalsNodeEarlyStages = @(
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
  "cleanup-complete"
)
$script:RisePalsNodeEarlyChildStages = @(
  "bootstrap-entered",
  "security-module-initialized",
  "contract-imported",
  "arguments-validated",
  "diagnostic-dispatched",
  "schema-v2-evidence-persisted"
)
$script:RisePalsNodeEarlyFailureCategories = @(
  "launch_failure",
  "bootstrap_entry_failure",
  "security_module_failure",
  "contract_import_failure",
  "argument_validation_failure",
  "evidence_directory_failure",
  "dispatch_failure",
  "child_exit_failure",
  "malformed_evidence",
  "binding_failure",
  "digest_failure",
  "ordering_failure",
  "replay_failure",
  "evidence_mismatch",
  "atomic_write_failure",
  "cleanup_failure",
  "final_result_failure"
)

function Get-RisePalsNodeEarlySha256Bytes {
  param([Parameter(Mandatory = $true)][byte[]]$Bytes)
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace(
      "-", ""
    ).ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
  }
}

function Get-RisePalsNodeEarlySha256Text {
  param([Parameter(Mandatory = $true)][string]$Text)
  return Get-RisePalsNodeEarlySha256Bytes `
    -Bytes ([Text.UTF8Encoding]::new($false).GetBytes($Text))
}

function Get-RisePalsNodeEarlySha256File {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)
  return Get-RisePalsNodeEarlySha256Bytes -Bytes ([IO.File]::ReadAllBytes(
      [IO.Path]::GetFullPath($LiteralPath)
    ))
}

function Assert-RisePalsNodeEarlyExactProperties {
  param(
    [Parameter(Mandatory = $true)][object]$Value,
    [Parameter(Mandatory = $true)][string[]]$Names,
    [Parameter(Mandatory = $true)][string]$Predicate
  )
  $actual = @($Value.PSObject.Properties.Name | Sort-Object)
  $expected = @($Names | Sort-Object)
  if (($actual -join "|") -cne ($expected -join "|")) {
    throw $Predicate
  }
}

function Test-RisePalsNodeEarlyHash {
  param([object]$Value)
  return $Value -is [string] -and [string]$Value -cmatch "^[a-f0-9]{64}$"
}

function Test-RisePalsNodeEarlyInteger {
  param([object]$Value, [int64]$Minimum = 0, [int64]$Maximum = [int32]::MaxValue)
  if ($Value -isnot [byte] -and $Value -isnot [int16] -and $Value -isnot [int32] -and
    $Value -isnot [int64] -and $Value -isnot [uint16] -and $Value -isnot [uint32]) {
    return $false
  }
  $number = [int64]$Value
  return $number -ge $Minimum -and $number -le $Maximum
}

function Get-RisePalsNodeEarlyRequestDigest {
  param([Parameter(Mandatory = $true)][object]$Request)
  $copy = [ordered]@{
    schemaVersion = [string]$Request.schemaVersion
    authorizationId = [string]$Request.authorizationId
    invocationNonce = [string]$Request.invocationNonce
    repositoryHead = [string]$Request.repositoryHead
    launcherSha256 = [string]$Request.launcherSha256
    earlyContractSha256 = [string]$Request.earlyContractSha256
    securityBootstrapSha256 = [string]$Request.securityBootstrapSha256
    childSha256 = [string]$Request.childSha256
    diagnosticSha256 = [string]$Request.diagnosticSha256
    diagnosticContractSha256 = [string]$Request.diagnosticContractSha256
    inventorySha256 = [string]$Request.inventorySha256
    createdUtc = [string]$Request.createdUtc
  }
  return Get-RisePalsNodeEarlySha256Text -Text ($copy | ConvertTo-Json -Compress)
}

function New-RisePalsNodeEarlyRequest {
  param(
    [Parameter(Mandatory = $true)][string]$AuthorizationId,
    [Parameter(Mandatory = $true)][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][string]$LauncherSha256,
    [Parameter(Mandatory = $true)][string]$EarlyContractSha256,
    [Parameter(Mandatory = $true)][string]$SecurityBootstrapSha256,
    [Parameter(Mandatory = $true)][string]$ChildSha256,
    [Parameter(Mandatory = $true)][string]$DiagnosticSha256,
    [Parameter(Mandatory = $true)][string]$DiagnosticContractSha256,
    [Parameter(Mandatory = $true)][string]$InventorySha256,
    [datetime]$CreatedUtc = [datetime]::UtcNow
  )
  $request = [ordered]@{
    schemaVersion = $script:RisePalsNodeEarlyRequestSchema
    authorizationId = $AuthorizationId
    invocationNonce = $InvocationNonce
    repositoryHead = $RepositoryHead
    launcherSha256 = $LauncherSha256
    earlyContractSha256 = $EarlyContractSha256
    securityBootstrapSha256 = $SecurityBootstrapSha256
    childSha256 = $ChildSha256
    diagnosticSha256 = $DiagnosticSha256
    diagnosticContractSha256 = $DiagnosticContractSha256
    inventorySha256 = $InventorySha256
    createdUtc = $CreatedUtc.ToUniversalTime().ToString("o")
    requestDigest = ""
  }
  $request.requestDigest = Get-RisePalsNodeEarlyRequestDigest -Request $request
  return [pscustomobject]$request
}

function Assert-RisePalsNodeEarlyRequest {
  param(
    [Parameter(Mandatory = $true)][object]$Request,
    [Parameter(Mandatory = $true)][string]$ExpectedAuthorizationId,
    [Parameter(Mandatory = $true)][string]$ExpectedInvocationNonce,
    [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead,
    [Parameter(Mandatory = $true)][string]$ExpectedLauncherSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedEarlyContractSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedSecurityBootstrapSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedChildSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedDiagnosticSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedDiagnosticContractSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedInventorySha256,
    [datetime]$ValidationUtc = [datetime]::UtcNow,
    [ValidateRange(1, 900)][int]$MaximumAgeSeconds = 300
  )
  Assert-RisePalsNodeEarlyExactProperties -Value $Request -Names @(
    "schemaVersion", "authorizationId", "invocationNonce", "repositoryHead",
    "launcherSha256", "earlyContractSha256", "securityBootstrapSha256", "childSha256",
    "diagnosticSha256", "diagnosticContractSha256", "inventorySha256", "createdUtc",
    "requestDigest"
  ) -Predicate "early-request-property"
  if ([string]$Request.schemaVersion -cne $script:RisePalsNodeEarlyRequestSchema -or
    [string]$Request.authorizationId -cne $ExpectedAuthorizationId -or
    [string]$Request.invocationNonce -cne $ExpectedInvocationNonce -or
    [string]$Request.repositoryHead -cne $ExpectedRepositoryHead -or
    [string]$Request.launcherSha256 -cne $ExpectedLauncherSha256 -or
    [string]$Request.earlyContractSha256 -cne $ExpectedEarlyContractSha256 -or
    [string]$Request.securityBootstrapSha256 -cne $ExpectedSecurityBootstrapSha256 -or
    [string]$Request.childSha256 -cne $ExpectedChildSha256 -or
    [string]$Request.diagnosticSha256 -cne $ExpectedDiagnosticSha256 -or
    [string]$Request.diagnosticContractSha256 -cne $ExpectedDiagnosticContractSha256 -or
    [string]$Request.inventorySha256 -cne $ExpectedInventorySha256) {
    throw "early-request-binding"
  }
  foreach ($name in @(
    "launcherSha256", "earlyContractSha256", "securityBootstrapSha256", "childSha256",
    "diagnosticSha256", "diagnosticContractSha256", "inventorySha256", "requestDigest"
  )) {
    if (-not (Test-RisePalsNodeEarlyHash $Request.$name)) { throw "early-request-hash" }
  }
  $created = [datetime]::MinValue
  if (-not [datetime]::TryParseExact(
      [string]$Request.createdUtc, "o", [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::RoundtripKind, [ref]$created
    )) {
    throw "early-request-time"
  }
  $age = $ValidationUtc.ToUniversalTime() - $created.ToUniversalTime()
  if ($age.TotalSeconds -lt -30 -or $age.TotalSeconds -gt $MaximumAgeSeconds) {
    throw "early-request-stale"
  }
  if ([string]$Request.requestDigest -cne (Get-RisePalsNodeEarlyRequestDigest -Request $Request)) {
    throw "early-request-digest"
  }
  return $Request
}

function Get-RisePalsNodeEarlyMarkerDigest {
  param([Parameter(Mandatory = $true)][object]$Marker)
  $copy = [ordered]@{
    schemaVersion = [string]$Marker.schemaVersion
    authorizationId = [string]$Marker.authorizationId
    invocationNonce = [string]$Marker.invocationNonce
    repositoryHead = [string]$Marker.repositoryHead
    launcherSha256 = [string]$Marker.launcherSha256
    earlyContractSha256 = [string]$Marker.earlyContractSha256
    securityBootstrapSha256 = [string]$Marker.securityBootstrapSha256
    childSha256 = [string]$Marker.childSha256
    stage = [string]$Marker.stage
    ordinal = [int]$Marker.ordinal
    previousDigest = [string]$Marker.previousDigest
    schemaV2EvidenceDigest = if ($null -eq $Marker.schemaV2EvidenceDigest) {
      $null
    } else {
      [string]$Marker.schemaV2EvidenceDigest
    }
  }
  return Get-RisePalsNodeEarlySha256Text -Text ($copy | ConvertTo-Json -Compress)
}

function New-RisePalsNodeEarlyMarker {
  param(
    [Parameter(Mandatory = $true)][object]$Request,
    [Parameter(Mandatory = $true)][ValidateSet(
      "bootstrap-entered", "security-module-initialized", "contract-imported",
      "arguments-validated", "diagnostic-dispatched", "schema-v2-evidence-persisted"
    )][string]$Stage,
    [Parameter(Mandatory = $true)][string]$PreviousDigest,
    [string]$SchemaV2EvidenceDigest
  )
  $ordinal = [Array]::IndexOf([object[]]$script:RisePalsNodeEarlyStages, $Stage)
  $marker = [ordered]@{
    schemaVersion = $script:RisePalsNodeEarlyMarkerSchema
    authorizationId = [string]$Request.authorizationId
    invocationNonce = [string]$Request.invocationNonce
    repositoryHead = [string]$Request.repositoryHead
    launcherSha256 = [string]$Request.launcherSha256
    earlyContractSha256 = [string]$Request.earlyContractSha256
    securityBootstrapSha256 = [string]$Request.securityBootstrapSha256
    childSha256 = [string]$Request.childSha256
    stage = $Stage
    ordinal = $ordinal
    previousDigest = $PreviousDigest
    schemaV2EvidenceDigest = if ([string]::IsNullOrWhiteSpace($SchemaV2EvidenceDigest)) {
      $null
    } else {
      $SchemaV2EvidenceDigest
    }
    markerDigest = ""
  }
  $marker.markerDigest = Get-RisePalsNodeEarlyMarkerDigest -Marker $marker
  return [pscustomobject]$marker
}

function Assert-RisePalsNodeEarlyMarker {
  param(
    [Parameter(Mandatory = $true)][object]$Marker,
    [Parameter(Mandatory = $true)][object]$Request,
    [Parameter(Mandatory = $true)][string]$ExpectedStage,
    [Parameter(Mandatory = $true)][string]$ExpectedPreviousDigest
  )
  Assert-RisePalsNodeEarlyExactProperties -Value $Marker -Names @(
    "schemaVersion", "authorizationId", "invocationNonce", "repositoryHead",
    "launcherSha256", "earlyContractSha256", "securityBootstrapSha256", "childSha256",
    "stage", "ordinal", "previousDigest", "schemaV2EvidenceDigest", "markerDigest"
  ) -Predicate "early-marker-property"
  $ordinal = [Array]::IndexOf([object[]]$script:RisePalsNodeEarlyStages, $ExpectedStage)
  if ([string]$Marker.schemaVersion -cne $script:RisePalsNodeEarlyMarkerSchema -or
    [string]$Marker.authorizationId -cne [string]$Request.authorizationId -or
    [string]$Marker.invocationNonce -cne [string]$Request.invocationNonce -or
    [string]$Marker.repositoryHead -cne [string]$Request.repositoryHead -or
    [string]$Marker.launcherSha256 -cne [string]$Request.launcherSha256 -or
    [string]$Marker.earlyContractSha256 -cne [string]$Request.earlyContractSha256 -or
    [string]$Marker.securityBootstrapSha256 -cne [string]$Request.securityBootstrapSha256 -or
    [string]$Marker.childSha256 -cne [string]$Request.childSha256) {
    throw "early-marker-binding"
  }
  if ([string]$Marker.stage -cne $ExpectedStage -or [int]$Marker.ordinal -ne $ordinal -or
    [string]$Marker.previousDigest -cne $ExpectedPreviousDigest) {
    throw "early-marker-order"
  }
  if ($ExpectedStage -ceq "schema-v2-evidence-persisted") {
    if (-not (Test-RisePalsNodeEarlyHash $Marker.schemaV2EvidenceDigest)) {
      throw "early-marker-schema-digest"
    }
  } elseif ($null -ne $Marker.schemaV2EvidenceDigest) {
    throw "early-marker-schema-digest"
  }
  if (-not (Test-RisePalsNodeEarlyHash $Marker.markerDigest) -or
    [string]$Marker.markerDigest -cne (Get-RisePalsNodeEarlyMarkerDigest -Marker $Marker)) {
    throw "early-marker-digest"
  }
  return $Marker
}

function Get-RisePalsNodeEarlyResultDigest {
  param([Parameter(Mandatory = $true)][object]$Result)
  $copy = [ordered]@{
    schemaVersion = [string]$Result.schemaVersion
    recordType = [string]$Result.recordType
    authorizationId = [string]$Result.authorizationId
    invocationNonce = [string]$Result.invocationNonce
    repositoryHead = [string]$Result.repositoryHead
    launcherSha256 = [string]$Result.launcherSha256
    earlyContractSha256 = [string]$Result.earlyContractSha256
    securityBootstrapSha256 = [string]$Result.securityBootstrapSha256
    childSha256 = [string]$Result.childSha256
    diagnosticSha256 = [string]$Result.diagnosticSha256
    diagnosticContractSha256 = [string]$Result.diagnosticContractSha256
    requestDigest = [string]$Result.requestDigest
    processCreated = [bool]$Result.processCreated
    childExitCode = $Result.childExitCode
    completedStages = @($Result.completedStages)
    lastCompletedStage = $Result.lastCompletedStage
    firstFailedStage = $Result.firstFailedStage
    sanitizedFailureCategory = $Result.sanitizedFailureCategory
    nativeErrorCode = $Result.nativeErrorCode
    hResult = $Result.hResult
    schemaV2EvidencePresent = [bool]$Result.schemaV2EvidencePresent
    schemaV2EvidenceDigest = $Result.schemaV2EvidenceDigest
    cleanupAttempted = [bool]$Result.cleanupAttempted
    cleanupCompleted = [bool]$Result.cleanupCompleted
    transientResidueCount = [int]$Result.transientResidueCount
    temporaryResidueCount = [int]$Result.temporaryResidueCount
    checkpointDigest = $Result.checkpointDigest
  }
  return Get-RisePalsNodeEarlySha256Text -Text ($copy | ConvertTo-Json -Compress -Depth 8)
}

function New-RisePalsNodeEarlyResult {
  param(
    [Parameter(Mandatory = $true)][ValidateSet("checkpoint", "final")][string]$RecordType,
    [Parameter(Mandatory = $true)][object]$Request,
    [Parameter(Mandatory = $true)][bool]$ProcessCreated,
    [Nullable[int]]$ChildExitCode,
    [Parameter(Mandatory = $true)][string[]]$CompletedStages,
    [string]$FirstFailedStage,
    [string]$SanitizedFailureCategory,
    [Nullable[int]]$NativeErrorCode,
    [Nullable[int]]$HResult,
    [Parameter(Mandatory = $true)][bool]$SchemaV2EvidencePresent,
    [string]$SchemaV2EvidenceDigest,
    [Parameter(Mandatory = $true)][bool]$CleanupAttempted,
    [Parameter(Mandatory = $true)][bool]$CleanupCompleted,
    [ValidateRange(0, 100000)][int]$TransientResidueCount,
    [ValidateRange(0, 100000)][int]$TemporaryResidueCount,
    [string]$CheckpointDigest
  )
  $last = if ($CompletedStages.Count -eq 0) { $null } else { $CompletedStages[-1] }
  $result = [ordered]@{
    schemaVersion = $script:RisePalsNodeEarlyResultSchema
    recordType = $RecordType
    authorizationId = [string]$Request.authorizationId
    invocationNonce = [string]$Request.invocationNonce
    repositoryHead = [string]$Request.repositoryHead
    launcherSha256 = [string]$Request.launcherSha256
    earlyContractSha256 = [string]$Request.earlyContractSha256
    securityBootstrapSha256 = [string]$Request.securityBootstrapSha256
    childSha256 = [string]$Request.childSha256
    diagnosticSha256 = [string]$Request.diagnosticSha256
    diagnosticContractSha256 = [string]$Request.diagnosticContractSha256
    requestDigest = [string]$Request.requestDigest
    processCreated = $ProcessCreated
    childExitCode = if ($null -eq $ChildExitCode) { $null } else { [int]$ChildExitCode }
    completedStages = @($CompletedStages)
    lastCompletedStage = $last
    firstFailedStage = if ([string]::IsNullOrWhiteSpace($FirstFailedStage)) {
      $null
    } else {
      $FirstFailedStage
    }
    sanitizedFailureCategory = if ([string]::IsNullOrWhiteSpace($SanitizedFailureCategory)) {
      $null
    } else {
      $SanitizedFailureCategory
    }
    nativeErrorCode = if ($null -eq $NativeErrorCode) { $null } else { [int]$NativeErrorCode }
    hResult = if ($null -eq $HResult) { $null } else { [int]$HResult }
    schemaV2EvidencePresent = $SchemaV2EvidencePresent
    schemaV2EvidenceDigest = if ([string]::IsNullOrWhiteSpace($SchemaV2EvidenceDigest)) {
      $null
    } else {
      $SchemaV2EvidenceDigest
    }
    cleanupAttempted = $CleanupAttempted
    cleanupCompleted = $CleanupCompleted
    transientResidueCount = $TransientResidueCount
    temporaryResidueCount = $TemporaryResidueCount
    checkpointDigest = if ([string]::IsNullOrWhiteSpace($CheckpointDigest)) {
      $null
    } else {
      $CheckpointDigest
    }
    evidenceDigest = ""
  }
  $result.evidenceDigest = Get-RisePalsNodeEarlyResultDigest -Result $result
  return [pscustomobject]$result
}

function Assert-RisePalsNodeEarlyResult {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][object]$Request,
    [string]$ExpectedCheckpointDigest
  )
  Assert-RisePalsNodeEarlyExactProperties -Value $Result -Names @(
    "schemaVersion", "recordType", "authorizationId", "invocationNonce", "repositoryHead",
    "launcherSha256", "earlyContractSha256", "securityBootstrapSha256", "childSha256",
    "diagnosticSha256", "diagnosticContractSha256", "requestDigest", "processCreated",
    "childExitCode", "completedStages", "lastCompletedStage", "firstFailedStage",
    "sanitizedFailureCategory", "nativeErrorCode", "hResult", "schemaV2EvidencePresent",
    "schemaV2EvidenceDigest", "cleanupAttempted", "cleanupCompleted",
    "transientResidueCount", "temporaryResidueCount", "checkpointDigest", "evidenceDigest"
  ) -Predicate "early-result-property"
  if ([string]$Result.schemaVersion -cne $script:RisePalsNodeEarlyResultSchema -or
    [string]$Result.recordType -notin @("checkpoint", "final") -or
    [string]$Result.authorizationId -cne [string]$Request.authorizationId -or
    [string]$Result.invocationNonce -cne [string]$Request.invocationNonce -or
    [string]$Result.repositoryHead -cne [string]$Request.repositoryHead -or
    [string]$Result.launcherSha256 -cne [string]$Request.launcherSha256 -or
    [string]$Result.earlyContractSha256 -cne [string]$Request.earlyContractSha256 -or
    [string]$Result.securityBootstrapSha256 -cne [string]$Request.securityBootstrapSha256 -or
    [string]$Result.childSha256 -cne [string]$Request.childSha256 -or
    [string]$Result.diagnosticSha256 -cne [string]$Request.diagnosticSha256 -or
    [string]$Result.diagnosticContractSha256 -cne [string]$Request.diagnosticContractSha256 -or
    [string]$Result.requestDigest -cne [string]$Request.requestDigest) {
    throw "early-result-binding"
  }
  if ($Result.processCreated -isnot [bool] -or $Result.schemaV2EvidencePresent -isnot [bool] -or
    $Result.cleanupAttempted -isnot [bool] -or $Result.cleanupCompleted -isnot [bool]) {
    throw "early-result-type"
  }
  foreach ($name in @("childExitCode", "nativeErrorCode", "hResult")) {
    if ($null -ne $Result.$name -and
      -not (Test-RisePalsNodeEarlyInteger -Value $Result.$name `
          -Minimum ([int32]::MinValue) -Maximum ([int32]::MaxValue))) {
      throw "early-result-integer"
    }
  }
  foreach ($name in @("transientResidueCount", "temporaryResidueCount")) {
    if (-not (Test-RisePalsNodeEarlyInteger -Value $Result.$name -Maximum 100000)) {
      throw "early-result-integer"
    }
  }
  $stages = @($Result.completedStages)
  if ($stages.Count -lt 2 -or $stages[0] -cne "request-created" -or
    $stages[1] -cne "elevated-launch-attempted" -or
    @($stages | Select-Object -Unique).Count -ne $stages.Count) {
    throw "early-result-stages"
  }
  $previous = -1
  foreach ($stage in $stages) {
    $index = [Array]::IndexOf([object[]]$script:RisePalsNodeEarlyStages, [string]$stage)
    if ($index -lt 0 -or $index -le $previous) { throw "early-result-stages" }
    $previous = $index
  }
  if ([string]$Result.lastCompletedStage -cne [string]$stages[-1]) {
    throw "early-result-stages"
  }
  $hasProcess = "elevated-process-created" -in $stages
  $hasExit = "child-exited" -in $stages
  if ([bool]$Result.processCreated -ne $hasProcess -or $hasProcess -ne $hasExit -or
    ($hasProcess -and $null -eq $Result.childExitCode) -or
    (-not $hasProcess -and $null -ne $Result.childExitCode)) {
    throw "early-result-process"
  }
  $childStages = @($stages | Where-Object { $_ -in $script:RisePalsNodeEarlyChildStages })
  for ($index = 0; $index -lt $childStages.Count; $index++) {
    if ([string]$childStages[$index] -cne [string]$script:RisePalsNodeEarlyChildStages[$index]) {
      throw "early-result-stages"
    }
  }
  $failed = $Result.firstFailedStage
  $category = $Result.sanitizedFailureCategory
  if (($null -eq $failed) -ne ($null -eq $category)) { throw "early-result-failure" }
  if ($null -ne $failed -and
    ([string]$failed -notin $script:RisePalsNodeEarlyStages -or
      [string]$category -notin $script:RisePalsNodeEarlyFailureCategories)) {
    throw "early-result-failure"
  }
  $schemaStage = "schema-v2-evidence-persisted" -in $stages
  if ([bool]$Result.schemaV2EvidencePresent -ne $schemaStage -or
    ($schemaStage -and -not (Test-RisePalsNodeEarlyHash $Result.schemaV2EvidenceDigest)) -or
    (-not $schemaStage -and $null -ne $Result.schemaV2EvidenceDigest)) {
    throw "early-result-schema-v2"
  }
  if ([string]$Result.recordType -ceq "checkpoint") {
    if ([bool]$Result.cleanupAttempted -or [bool]$Result.cleanupCompleted -or
      "parent-reopened-result" -in $stages -or "cleanup-complete" -in $stages -or
      $null -ne $Result.checkpointDigest) {
      throw "early-result-checkpoint"
    }
  } else {
    if (-not [bool]$Result.cleanupAttempted -or
      "parent-reopened-result" -notin $stages -or
      [string]$Result.checkpointDigest -cne $ExpectedCheckpointDigest -or
      -not (Test-RisePalsNodeEarlyHash $Result.checkpointDigest)) {
      throw "early-result-final"
    }
    if ([bool]$Result.cleanupCompleted -ne ("cleanup-complete" -in $stages)) {
      throw "early-result-final"
    }
    if ([bool]$Result.cleanupCompleted -and
      ([int]$Result.transientResidueCount -ne 0 -or [int]$Result.temporaryResidueCount -ne 0)) {
      throw "early-result-cleanup"
    }
  }
  if (-not (Test-RisePalsNodeEarlyHash $Result.evidenceDigest) -or
    [string]$Result.evidenceDigest -cne (Get-RisePalsNodeEarlyResultDigest -Result $Result)) {
    throw "early-result-digest"
  }
  return $Result
}

function Assert-RisePalsNodeEarlyEvidenceDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][ValidateSet("Simulation", "LiveReadOnly")][string]$Mode,
    [switch]$RequireEmpty
  )
  $exact = [IO.Path]::GetFullPath($Path).TrimEnd('\')
  $allowed = if ($Mode -ceq "Simulation") {
    [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  } else {
    [IO.Path]::GetFullPath((Join-Path (
          [Environment]::GetFolderPath("MyDocuments")
        ) "Codex")).TrimEnd('\')
  }
  if (-not $exact.StartsWith($allowed + "\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "early-evidence-boundary"
  }
  $item = Get-Item -LiteralPath $exact -Force -ErrorAction Stop
  if (-not $item.PSIsContainer -or
    ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "early-evidence-reparse"
  }
  if ($RequireEmpty -and @(Get-ChildItem -LiteralPath $exact -Force).Count -ne 0) {
    throw "early-evidence-not-empty"
  }
  return $exact
}

function Write-RisePalsNodeEarlyJsonAtomic {
  param(
    [Parameter(Mandatory = $true)][object]$Value,
    [Parameter(Mandatory = $true)][string]$FinalPath,
    [switch]$InterruptBeforeMove
  )
  $final = [IO.Path]::GetFullPath($FinalPath)
  $temporary = $final + ".tmp"
  if ([IO.File]::Exists($final) -or [IO.File]::Exists($temporary)) {
    throw "early-atomic-path-exists"
  }
  $json = $Value | ConvertTo-Json -Compress -Depth 12
  [IO.File]::WriteAllText($temporary, $json, [Text.UTF8Encoding]::new($false))
  if ($InterruptBeforeMove) { throw "early-atomic-interrupted" }
  [IO.File]::Move($temporary, $final)
  return $final
}

function Read-RisePalsNodeEarlyJson {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)
  try {
    $bytes = [IO.File]::ReadAllBytes([IO.Path]::GetFullPath($LiteralPath))
    $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    return $text | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "early-json-invalid"
  }
}

function Get-RisePalsNodeEarlyRequestPath {
  param([string]$EvidenceDirectory, [string]$InvocationNonce)
  return Join-Path $EvidenceDirectory ("node-early-request-{0}.json" -f $InvocationNonce)
}

function Get-RisePalsNodeEarlyCheckpointPath {
  param([string]$EvidenceDirectory, [string]$InvocationNonce)
  return Join-Path $EvidenceDirectory ("node-early-checkpoint-{0}.json" -f $InvocationNonce)
}

function Get-RisePalsNodeEarlyResultPath {
  param([string]$EvidenceDirectory, [string]$InvocationNonce)
  return Join-Path $EvidenceDirectory ("node-early-result-{0}.json" -f $InvocationNonce)
}

function Get-RisePalsNodeEarlyFallbackPath {
  param([string]$EvidenceDirectory, [string]$InvocationNonce)
  return Join-Path $EvidenceDirectory ("node-early-failure-{0}.json" -f $InvocationNonce)
}

function Write-RisePalsNodeEarlyRequestAtomic {
  param([object]$Request, [string]$EvidenceDirectory)
  $path = Get-RisePalsNodeEarlyRequestPath -EvidenceDirectory $EvidenceDirectory `
    -InvocationNonce $Request.invocationNonce
  return Write-RisePalsNodeEarlyJsonAtomic -Value $Request -FinalPath $path
}

function Read-RisePalsNodeEarlyRequest {
  param(
    [string]$Path,
    [string]$ExpectedAuthorizationId,
    [string]$ExpectedInvocationNonce,
    [string]$ExpectedRepositoryHead,
    [string]$ExpectedLauncherSha256,
    [string]$ExpectedEarlyContractSha256,
    [string]$ExpectedSecurityBootstrapSha256,
    [string]$ExpectedChildSha256,
    [string]$ExpectedDiagnosticSha256,
    [string]$ExpectedDiagnosticContractSha256,
    [string]$ExpectedInventorySha256,
    [datetime]$ValidationUtc = [datetime]::UtcNow
  )
  $value = Read-RisePalsNodeEarlyJson -LiteralPath $Path
  return Assert-RisePalsNodeEarlyRequest -Request $value `
    -ExpectedAuthorizationId $ExpectedAuthorizationId `
    -ExpectedInvocationNonce $ExpectedInvocationNonce `
    -ExpectedRepositoryHead $ExpectedRepositoryHead `
    -ExpectedLauncherSha256 $ExpectedLauncherSha256 `
    -ExpectedEarlyContractSha256 $ExpectedEarlyContractSha256 `
    -ExpectedSecurityBootstrapSha256 $ExpectedSecurityBootstrapSha256 `
    -ExpectedChildSha256 $ExpectedChildSha256 `
    -ExpectedDiagnosticSha256 $ExpectedDiagnosticSha256 `
    -ExpectedDiagnosticContractSha256 $ExpectedDiagnosticContractSha256 `
    -ExpectedInventorySha256 $ExpectedInventorySha256 -ValidationUtc $ValidationUtc
}

function Write-RisePalsNodeEarlyMarkerAtomic {
  param([object]$Marker, [string]$TransientDirectory, [switch]$InterruptBeforeMove)
  $name = "marker-{0:d2}-{1}.json" -f [int]$Marker.ordinal, [string]$Marker.stage
  return Write-RisePalsNodeEarlyJsonAtomic -Value $Marker `
    -FinalPath (Join-Path $TransientDirectory $name) `
    -InterruptBeforeMove:$InterruptBeforeMove
}

function Write-RisePalsNodeEarlyResultAtomic {
  param(
    [object]$Result,
    [string]$EvidenceDirectory,
    [switch]$Fallback,
    [switch]$InterruptBeforeMove
  )
  $path = if ($Result.recordType -ceq "checkpoint") {
    Get-RisePalsNodeEarlyCheckpointPath -EvidenceDirectory $EvidenceDirectory `
      -InvocationNonce $Result.invocationNonce
  } elseif ($Fallback) {
    Get-RisePalsNodeEarlyFallbackPath -EvidenceDirectory $EvidenceDirectory `
      -InvocationNonce $Result.invocationNonce
  } else {
    Get-RisePalsNodeEarlyResultPath -EvidenceDirectory $EvidenceDirectory `
      -InvocationNonce $Result.invocationNonce
  }
  return Write-RisePalsNodeEarlyJsonAtomic -Value $Result -FinalPath $path `
    -InterruptBeforeMove:$InterruptBeforeMove
}

function Read-RisePalsNodeEarlyResult {
  param([string]$Path, [object]$Request, [string]$ExpectedCheckpointDigest)
  $value = Read-RisePalsNodeEarlyJson -LiteralPath $Path
  return Assert-RisePalsNodeEarlyResult -Result $value -Request $Request `
    -ExpectedCheckpointDigest $ExpectedCheckpointDigest
}

function Read-RisePalsNodeEarlyMarkerChain {
  param(
    [Parameter(Mandatory = $true)][string]$TransientDirectory,
    [Parameter(Mandatory = $true)][object]$Request,
    [string]$ExpectedSchemaV2EvidenceDigest
  )
  $directory = [IO.Path]::GetFullPath($TransientDirectory)
  $items = @(Get-ChildItem -LiteralPath $directory -Force)
  if (@($items | Where-Object { $_.PSIsContainer -or
        ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 }).Count -ne 0) {
    return [pscustomobject]@{ valid = $false; stages = @(); firstFailedStage = "bootstrap-entered";
      category = "malformed_evidence"; schemaV2EvidenceDigest = $null }
  }
  $temporary = @($items | Where-Object { $_.Name -like "*.tmp" })
  if ($temporary.Count -gt 0) {
    return [pscustomobject]@{ valid = $false; stages = @(); firstFailedStage = "bootstrap-entered";
      category = "atomic_write_failure"; schemaV2EvidenceDigest = $null }
  }
  $files = @($items | Where-Object { $_.Name -like "marker-*.json" } | Sort-Object Name)
  if ($files.Count -ne $items.Count) {
    return [pscustomobject]@{ valid = $false; stages = @(); firstFailedStage = "bootstrap-entered";
      category = "replay_failure"; schemaV2EvidenceDigest = $null }
  }
  $stages = @()
  $previous = [string]$Request.requestDigest
  $schemaDigest = $null
  for ($index = 0; $index -lt $files.Count; $index++) {
    if ($index -ge $script:RisePalsNodeEarlyChildStages.Count) {
      return [pscustomobject]@{ valid = $false; stages = $stages;
        firstFailedStage = "schema-v2-evidence-persisted"; category = "replay_failure";
        schemaV2EvidenceDigest = $schemaDigest }
    }
    $stage = [string]$script:RisePalsNodeEarlyChildStages[$index]
    try {
      $marker = Read-RisePalsNodeEarlyJson -LiteralPath $files[$index].FullName
      [void](Assert-RisePalsNodeEarlyMarker -Marker $marker -Request $Request `
          -ExpectedStage $stage -ExpectedPreviousDigest $previous)
    } catch {
      $category = switch -Wildcard ([string]$_.Exception.Message) {
        "early-marker-binding*" { "binding_failure" }
        "early-marker-digest*" { "digest_failure" }
        "early-marker-order*" { "ordering_failure" }
        "early-marker-schema-digest*" { "evidence_mismatch" }
        default { "malformed_evidence" }
      }
      return [pscustomobject]@{ valid = $false; stages = $stages; firstFailedStage = $stage;
        category = $category; schemaV2EvidenceDigest = $schemaDigest }
    }
    $stages += $stage
    $previous = [string]$marker.markerDigest
    if ($stage -ceq "schema-v2-evidence-persisted") {
      $schemaDigest = [string]$marker.schemaV2EvidenceDigest
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($ExpectedSchemaV2EvidenceDigest) -and
    $null -ne $schemaDigest -and $schemaDigest -cne $ExpectedSchemaV2EvidenceDigest) {
    return [pscustomobject]@{ valid = $false; stages = @($stages | Select-Object -First 5);
      firstFailedStage = "schema-v2-evidence-persisted"; category = "evidence_mismatch";
      schemaV2EvidenceDigest = $null }
  }
  return [pscustomobject]@{ valid = $true; stages = $stages; firstFailedStage = $null;
    category = $null; schemaV2EvidenceDigest = $schemaDigest }
}

Export-ModuleMember -Function @(
  "Get-RisePalsNodeEarlySha256Bytes",
  "Get-RisePalsNodeEarlySha256Text",
  "Get-RisePalsNodeEarlySha256File",
  "Assert-RisePalsNodeEarlyExactProperties",
  "Test-RisePalsNodeEarlyHash",
  "Test-RisePalsNodeEarlyInteger",
  "Get-RisePalsNodeEarlyRequestDigest",
  "New-RisePalsNodeEarlyRequest",
  "Assert-RisePalsNodeEarlyRequest",
  "Get-RisePalsNodeEarlyMarkerDigest",
  "New-RisePalsNodeEarlyMarker",
  "Assert-RisePalsNodeEarlyMarker",
  "Get-RisePalsNodeEarlyResultDigest",
  "New-RisePalsNodeEarlyResult",
  "Assert-RisePalsNodeEarlyResult",
  "Assert-RisePalsNodeEarlyEvidenceDirectory",
  "Write-RisePalsNodeEarlyJsonAtomic",
  "Read-RisePalsNodeEarlyJson",
  "Get-RisePalsNodeEarlyRequestPath",
  "Get-RisePalsNodeEarlyCheckpointPath",
  "Get-RisePalsNodeEarlyResultPath",
  "Get-RisePalsNodeEarlyFallbackPath",
  "Write-RisePalsNodeEarlyRequestAtomic",
  "Read-RisePalsNodeEarlyRequest",
  "Write-RisePalsNodeEarlyMarkerAtomic",
  "Write-RisePalsNodeEarlyResultAtomic",
  "Read-RisePalsNodeEarlyResult",
  "Read-RisePalsNodeEarlyMarkerChain"
)
