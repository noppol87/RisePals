Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RisePalsCandidateResultSchema = "rise-pals-candidate-rehearsal-result-v1"
$script:RisePalsCandidateResultProperties = @(
  "schemaVersion",
  "invocationNonce",
  "repositoryHead",
  "launcherScriptSha256",
  "startedAtUtc",
  "completedAtUtc",
  "status",
  "childExitCode",
  "completedStages",
  "failedStage",
  "sanitizedFailureCode",
  "cleanupCompleted",
  "finalState",
  "streamEvidence",
  "resultDigest"
)
$script:RisePalsCandidateFinalStateProperties = @(
  "candidateState",
  "candidateStartMode",
  "candidateProcessId",
  "ownedJobProcesses",
  "retainedServiceExceptions",
  "relevantListeners",
  "rootProcesses",
  "temporaryChildren",
  "syntheticCanaries"
)
$script:RisePalsCandidateStreamProperties = @(
  "stdoutObserved",
  "stderrObserved",
  "streamsSeparated",
  "rawOutputPersisted"
)

function Assert-RisePalsCandidateExactPropertySet {
  param(
    [Parameter(Mandatory = $true)][object]$Value,
    [Parameter(Mandatory = $true)][string[]]$Expected,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if ($null -eq $Value) {
    throw "$Label is absent."
  }
  $actual = @($Value.PSObject.Properties.Name | Sort-Object)
  $wanted = @($Expected | Sort-Object)
  if (@(Compare-Object -ReferenceObject $wanted -DifferenceObject $actual).Count -ne 0) {
    throw "$Label has an unexpected property set."
  }
}

function ConvertTo-RisePalsCandidateCanonicalResult {
  param([Parameter(Mandatory = $true)][object]$Result)

  return [pscustomobject][ordered]@{
    schemaVersion = [string]$Result.schemaVersion
    invocationNonce = [string]$Result.invocationNonce
    repositoryHead = [string]$Result.repositoryHead
    launcherScriptSha256 = [string]$Result.launcherScriptSha256
    startedAtUtc = [string]$Result.startedAtUtc
    completedAtUtc = [string]$Result.completedAtUtc
    status = [string]$Result.status
    childExitCode = [int]$Result.childExitCode
    completedStages = @($Result.completedStages | ForEach-Object { [string]$_ })
    failedStage = if ($null -eq $Result.failedStage) { $null } else { [string]$Result.failedStage }
    sanitizedFailureCode = if ($null -eq $Result.sanitizedFailureCode) {
      $null
    } else {
      [string]$Result.sanitizedFailureCode
    }
    cleanupCompleted = [bool]$Result.cleanupCompleted
    finalState = [ordered]@{
      candidateState = [string]$Result.finalState.candidateState
      candidateStartMode = [string]$Result.finalState.candidateStartMode
      candidateProcessId = [int]$Result.finalState.candidateProcessId
      ownedJobProcesses = [int]$Result.finalState.ownedJobProcesses
      retainedServiceExceptions = [int]$Result.finalState.retainedServiceExceptions
      relevantListeners = [int]$Result.finalState.relevantListeners
      rootProcesses = [int]$Result.finalState.rootProcesses
      temporaryChildren = [int]$Result.finalState.temporaryChildren
      syntheticCanaries = [int]$Result.finalState.syntheticCanaries
    }
    streamEvidence = [ordered]@{
      stdoutObserved = [bool]$Result.streamEvidence.stdoutObserved
      stderrObserved = [bool]$Result.streamEvidence.stderrObserved
      streamsSeparated = [bool]$Result.streamEvidence.streamsSeparated
      rawOutputPersisted = [bool]$Result.streamEvidence.rawOutputPersisted
    }
  }
}

function Get-RisePalsCandidateResultDigest {
  param([Parameter(Mandatory = $true)][object]$Result)

  $canonical = ConvertTo-RisePalsCandidateCanonicalResult -Result $Result
  $json = $canonical | ConvertTo-Json -Depth 7 -Compress
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace(
      "-",
      ""
    ).ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
  }
}

function New-RisePalsCandidateFinalState {
  param(
    [string]$CandidateState = "Absent",
    [string]$CandidateStartMode = "Absent",
    [int]$CandidateProcessId = 0,
    [int]$OwnedJobProcesses = 0,
    [int]$RetainedServiceExceptions = 0,
    [int]$RelevantListeners = 0,
    [int]$RootProcesses = 0,
    [int]$TemporaryChildren = 0,
    [int]$SyntheticCanaries = 0
  )

  return [ordered]@{
    candidateState = $CandidateState
    candidateStartMode = $CandidateStartMode
    candidateProcessId = $CandidateProcessId
    ownedJobProcesses = $OwnedJobProcesses
    retainedServiceExceptions = $RetainedServiceExceptions
    relevantListeners = $RelevantListeners
    rootProcesses = $RootProcesses
    temporaryChildren = $TemporaryChildren
    syntheticCanaries = $SyntheticCanaries
  }
}

function New-RisePalsCandidateResult {
  param(
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$LauncherScriptSha256,
    [Parameter(Mandatory = $true)][string]$StartedAtUtc,
    [Parameter(Mandatory = $true)][string]$CompletedAtUtc,
    [Parameter(Mandatory = $true)][ValidateSet("success", "failure")][string]$Status,
    [Parameter(Mandatory = $true)][int]$ChildExitCode,
    [Parameter(Mandatory = $true)][string[]]$CompletedStages,
    [AllowNull()][string]$FailedStage,
    [AllowNull()][string]$SanitizedFailureCode,
    [Parameter(Mandatory = $true)][bool]$CleanupCompleted,
    [Parameter(Mandatory = $true)][object]$FinalState,
    [Parameter(Mandatory = $true)][object]$StreamEvidence
  )

  $result = [ordered]@{
    schemaVersion = $script:RisePalsCandidateResultSchema
    invocationNonce = $InvocationNonce
    repositoryHead = $RepositoryHead
    launcherScriptSha256 = $LauncherScriptSha256
    startedAtUtc = $StartedAtUtc
    completedAtUtc = $CompletedAtUtc
    status = $Status
    childExitCode = $ChildExitCode
    completedStages = @($CompletedStages)
    failedStage = if ([string]::IsNullOrWhiteSpace($FailedStage)) { $null } else { $FailedStage }
    sanitizedFailureCode = if ([string]::IsNullOrWhiteSpace($SanitizedFailureCode)) {
      $null
    } else {
      $SanitizedFailureCode
    }
    cleanupCompleted = $CleanupCompleted
    finalState = [pscustomobject]$FinalState
    streamEvidence = [pscustomobject]$StreamEvidence
    resultDigest = ""
  }
  $result.resultDigest = Get-RisePalsCandidateResultDigest -Result $result
  return [pscustomobject]$result
}

function Write-RisePalsCandidateResultAtomic {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][string]$ResultPath,
    [Parameter(Mandatory = $true)][string]$TemporaryPath
  )

  $exactResultPath = [IO.Path]::GetFullPath($ResultPath)
  $exactTemporaryPath = [IO.Path]::GetFullPath($TemporaryPath)
  if (-not [IO.Path]::GetDirectoryName($exactResultPath).Equals(
    [IO.Path]::GetDirectoryName($exactTemporaryPath),
    [StringComparison]::OrdinalIgnoreCase
  ) -or [IO.File]::Exists($exactResultPath) -or
    [IO.File]::Exists($exactTemporaryPath)) {
    throw "Candidate structured-result paths are not fresh and single-directory."
  }
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
    (($Result | ConvertTo-Json -Depth 7) + "`n")
  )
  $stream = [IO.FileStream]::new(
    $exactTemporaryPath,
    [IO.FileMode]::CreateNew,
    [IO.FileAccess]::Write,
    [IO.FileShare]::None
  )
  try {
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush($true)
  } finally {
    $stream.Dispose()
  }
  [IO.File]::Move($exactTemporaryPath, $exactResultPath)
}

function ConvertFrom-RisePalsCandidateUtc {
  param([Parameter(Mandatory = $true)][string]$Value)

  $parsed = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParseExact(
    $Value,
    "o",
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::None,
    [ref]$parsed
  ) -or $parsed.Offset -ne [TimeSpan]::Zero) {
    throw "A candidate result timestamp is not exact UTC."
  }
  return $parsed
}

function Assert-RisePalsCandidateResult {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][string]$ExpectedNonce,
    [Parameter(Mandatory = $true)][string]$ExpectedHead,
    [Parameter(Mandatory = $true)][string]$ExpectedLauncherScriptSha256,
    [Parameter(Mandatory = $true)][int]$ObservedExitCode,
    [Parameter(Mandatory = $true)][DateTimeOffset]$InvocationStartedAtUtc,
    [Parameter(Mandatory = $true)][hashtable]$ConsumedNonces,
    [DateTimeOffset]$ValidationNowUtc = [DateTimeOffset]::UtcNow
  )

  Assert-RisePalsCandidateExactPropertySet -Value $Result `
    -Expected $script:RisePalsCandidateResultProperties -Label "Candidate result"
  Assert-RisePalsCandidateExactPropertySet -Value $Result.finalState `
    -Expected $script:RisePalsCandidateFinalStateProperties -Label "Candidate final state"
  Assert-RisePalsCandidateExactPropertySet -Value $Result.streamEvidence `
    -Expected $script:RisePalsCandidateStreamProperties -Label "Candidate stream evidence"

  if ($Result.schemaVersion -ne $script:RisePalsCandidateResultSchema -or
    $Result.invocationNonce -ne $ExpectedNonce -or
    $Result.invocationNonce -notmatch "^[a-f0-9]{32}$" -or
    $ConsumedNonces.ContainsKey($Result.invocationNonce)) {
    throw "The candidate result nonce is invalid or replayed."
  }
  if ($Result.repositoryHead -ne $ExpectedHead -or
    $Result.repositoryHead -notmatch "^[a-f0-9]{40}$" -or
    $Result.launcherScriptSha256 -ne $ExpectedLauncherScriptSha256 -or
    $Result.launcherScriptSha256 -notmatch "^[a-f0-9]{64}$") {
    throw "The candidate result provenance does not match the request."
  }
  $started = ConvertFrom-RisePalsCandidateUtc -Value ([string]$Result.startedAtUtc)
  $completed = ConvertFrom-RisePalsCandidateUtc -Value ([string]$Result.completedAtUtc)
  if ($started -lt $InvocationStartedAtUtc.AddSeconds(-2) -or
    $completed -lt $started -or $completed -gt $ValidationNowUtc.AddMinutes(1) -or
    ($completed - $started) -gt [TimeSpan]::FromMinutes(30)) {
    throw "The candidate result is stale or temporally incoherent."
  }
  if ([int]$Result.childExitCode -ne $ObservedExitCode) {
    throw "The candidate result disagrees with the explicit child exit code."
  }
  if ($Result.status -eq "success") {
    if ($ObservedExitCode -ne 0 -or $null -ne $Result.failedStage -or
      $null -ne $Result.sanitizedFailureCode -or -not [bool]$Result.cleanupCompleted) {
      throw "A successful candidate result is internally inconsistent."
    }
  } elseif ($Result.status -eq "failure") {
    if ($ObservedExitCode -eq 0 -or [string]$Result.failedStage -notmatch "^[a-z0-9-]+$" -or
      [string]$Result.sanitizedFailureCode -notmatch "^[a-z0-9-]+$") {
      throw "A failed candidate result is internally inconsistent."
    }
  } else {
    throw "The candidate result status is invalid."
  }
  if (@($Result.completedStages | Select-Object -Unique).Count -ne
    @($Result.completedStages).Count) {
    throw "Candidate completion stages are duplicated."
  }
  foreach ($property in $script:RisePalsCandidateFinalStateProperties[2..8]) {
    if ([int]$Result.finalState.$property -lt 0) {
      throw "A candidate final-state count is invalid."
    }
  }
  if (-not [bool]$Result.streamEvidence.streamsSeparated -or
    [bool]$Result.streamEvidence.rawOutputPersisted) {
    throw "Candidate native streams were merged or raw output was persisted."
  }
  if ([bool]$Result.cleanupCompleted -and (
    $Result.finalState.candidateState -ne "Absent" -or
    $Result.finalState.candidateStartMode -ne "Absent" -or
    [int]$Result.finalState.candidateProcessId -ne 0 -or
    [int]$Result.finalState.ownedJobProcesses -ne 0 -or
    [int]$Result.finalState.retainedServiceExceptions -ne 0 -or
    [int]$Result.finalState.relevantListeners -ne 0 -or
    [int]$Result.finalState.rootProcesses -ne 0 -or
    [int]$Result.finalState.temporaryChildren -ne 0 -or
    [int]$Result.finalState.syntheticCanaries -ne 0
  )) {
    throw "Candidate cleanup claims success with remaining state."
  }
  if ($Result.resultDigest -ne (Get-RisePalsCandidateResultDigest -Result $Result)) {
    throw "The candidate structured-result digest is invalid."
  }
  $json = $Result | ConvertTo-Json -Depth 7 -Compress
  if ($json -match "(?i)(authorization|set-cookie|bearer[ ]|password|credential|request[ -]?body|@[a-z0-9.-]+\.[a-z]{2,}|(sk|pk)_(live|test)_)") {
    throw "The candidate structured result contains a prohibited privacy marker."
  }
  $ConsumedNonces[$Result.invocationNonce] = $true
  return $true
}
