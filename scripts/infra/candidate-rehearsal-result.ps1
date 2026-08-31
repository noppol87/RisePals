Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RisePalsCandidateResultSchema = "rise-pals-candidate-rehearsal-result-v2"
$script:RisePalsCandidateChildDiagnosticSchema = "rise-pals-candidate-child-diagnostic-v2"
$script:RisePalsCandidateLiveStateSchema = "rise-pals-candidate-live-state-v2"
$script:RisePalsCandidateResultProperties = @(
  "schemaVersion",
  "invocationNonce",
  "authorizationId",
  "repositoryHead",
  "launcherScriptSha256",
  "bootstrapScriptSha256",
  "transportScriptSha256",
  "childScriptSha256",
  "startedAtUtc",
  "completedAtUtc",
  "executionMode",
  "status",
  "childExitCode",
  "completedStages",
  "failedStage",
  "sanitizedFailureCode",
  "cleanupCompleted",
  "lifecycleEvidence",
  "finalState",
  "streamEvidence",
  "resultDigest"
)
$script:RisePalsCandidateLifecycleEvidenceProperties = @(
  "liveHostMutationBegan",
  "candidateServiceInstallationBegan",
  "candidateServiceStartReached",
  "directStopServiceReached"
)
$script:RisePalsCandidateLiveStateProperties = @(
  "schemaVersion",
  "status",
  "completedStages",
  "failedStage",
  "sanitizedFailureCode",
  "cleanupCompleted",
  "lifecycleEvidence",
  "finalState"
)
$script:RisePalsCandidateFunctionalStageOrder = @(
  "preflight",
  "stage-immutable-inputs",
  "apply-exact-acls",
  "validate-candidate-config",
  "create-own-process-service",
  "configure-service-sid",
  "configure-preshutdown-timeout",
  "start-and-ready",
  "stream-first-byte",
  "direct-stop",
  "reject-new-work-during-drain",
  "complete-three-chunk-stream",
  "duplicate-stop",
  "verify-stop-checkpoints",
  "verify-preshutdown-registration",
  "verify-graceful-zero-job",
  "verify-timeout-cleanup",
  "verify-bounded-crash-restart",
  "verify-process-ownership",
  "verify-persistent-failure-terminal",
  "verify-retained-proxy-independence"
)
$script:RisePalsCandidateFunctionalGateMap = [ordered]@{
  protectedResiduePreflight = "preflight"
  immutableInputStaging = "stage-immutable-inputs"
  exactAclBoundary = "apply-exact-acls"
  candidateConfigValidation = "validate-candidate-config"
  candidateServiceInstallation = "create-own-process-service"
  serviceSidConfiguration = "configure-service-sid"
  preshutdownTimeoutConfiguration = "configure-preshutdown-timeout"
  serviceStartReadiness = "start-and-ready"
  streamFirstByte = "stream-first-byte"
  directStop = "direct-stop"
  drainNewWorkRejection = "reject-new-work-during-drain"
  acceptedStreamCompletion = "complete-three-chunk-stream"
  repeatedStop = "duplicate-stop"
  stopCheckpoints = "verify-stop-checkpoints"
  preshutdownRegistration = "verify-preshutdown-registration"
  gracefulZeroJob = "verify-graceful-zero-job"
  timeoutCleanup = "verify-timeout-cleanup"
  boundedCrashRestart = "verify-bounded-crash-restart"
  processOwnership = "verify-process-ownership"
  persistentFailureTerminal = "verify-persistent-failure-terminal"
  retainedProxyIndependence = "verify-retained-proxy-independence"
}
$script:RisePalsCandidateChildDiagnosticProperties = @(
  "schemaVersion",
  "executionMode",
  "childResultDigest",
  "childStatus",
  "sanitizedFailureCode",
  "failedStage",
  "completedStages",
  "functionalGates",
  "liveHostMutationBegan",
  "candidateServiceInstallationBegan",
  "candidateServiceStartReached",
  "directStopServiceReached",
  "childCleanupCompleted",
  "cleanupResponsibilityTransferredToParent",
  "diagnosticDigest"
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
    authorizationId = [string]$Result.authorizationId
    repositoryHead = [string]$Result.repositoryHead
    launcherScriptSha256 = [string]$Result.launcherScriptSha256
    bootstrapScriptSha256 = [string]$Result.bootstrapScriptSha256
    transportScriptSha256 = [string]$Result.transportScriptSha256
    childScriptSha256 = [string]$Result.childScriptSha256
    startedAtUtc = [string]$Result.startedAtUtc
    completedAtUtc = [string]$Result.completedAtUtc
    executionMode = [string]$Result.executionMode
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
    lifecycleEvidence = [ordered]@{
      liveHostMutationBegan = [bool]$Result.lifecycleEvidence.liveHostMutationBegan
      candidateServiceInstallationBegan = [bool]$Result.lifecycleEvidence.candidateServiceInstallationBegan
      candidateServiceStartReached = [bool]$Result.lifecycleEvidence.candidateServiceStartReached
      directStopServiceReached = [bool]$Result.lifecycleEvidence.directStopServiceReached
    }
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

function New-RisePalsCandidateLifecycleEvidence {
  param(
    [bool]$LiveHostMutationBegan = $false,
    [bool]$CandidateServiceInstallationBegan = $false,
    [bool]$CandidateServiceStartReached = $false,
    [bool]$DirectStopServiceReached = $false
  )

  return [ordered]@{
    liveHostMutationBegan = $LiveHostMutationBegan
    candidateServiceInstallationBegan = $CandidateServiceInstallationBegan
    candidateServiceStartReached = $CandidateServiceStartReached
    directStopServiceReached = $DirectStopServiceReached
  }
}

function New-RisePalsCandidateResult {
  param(
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][string]$AuthorizationId,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$LauncherScriptSha256,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$BootstrapScriptSha256,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$TransportScriptSha256,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$ChildScriptSha256,
    [Parameter(Mandatory = $true)][string]$StartedAtUtc,
    [Parameter(Mandatory = $true)][string]$CompletedAtUtc,
    [ValidateSet("Simulation", "Live")][string]$ExecutionMode = "Simulation",
    [Parameter(Mandatory = $true)][ValidateSet("success", "failure")][string]$Status,
    [Parameter(Mandatory = $true)][int]$ChildExitCode,
    [Parameter(Mandatory = $true)][string[]]$CompletedStages,
    [AllowNull()][string]$FailedStage,
    [AllowNull()][string]$SanitizedFailureCode,
    [Parameter(Mandatory = $true)][bool]$CleanupCompleted,
    [object]$LifecycleEvidence = (New-RisePalsCandidateLifecycleEvidence),
    [Parameter(Mandatory = $true)][object]$FinalState,
    [Parameter(Mandatory = $true)][object]$StreamEvidence
  )

  $result = [ordered]@{
    schemaVersion = $script:RisePalsCandidateResultSchema
    invocationNonce = $InvocationNonce
    authorizationId = $AuthorizationId
    repositoryHead = $RepositoryHead
    launcherScriptSha256 = $LauncherScriptSha256
    bootstrapScriptSha256 = $BootstrapScriptSha256
    transportScriptSha256 = $TransportScriptSha256
    childScriptSha256 = $ChildScriptSha256
    startedAtUtc = $StartedAtUtc
    completedAtUtc = $CompletedAtUtc
    executionMode = $ExecutionMode
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
    lifecycleEvidence = [pscustomobject]$LifecycleEvidence
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
    [Parameter(Mandatory = $true)][string]$ExpectedAuthorizationId,
    [Parameter(Mandatory = $true)][string]$ExpectedHead,
    [Parameter(Mandatory = $true)][string]$ExpectedLauncherScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedBootstrapScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedTransportScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedChildScriptSha256,
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
  Assert-RisePalsCandidateExactPropertySet -Value $Result.lifecycleEvidence `
    -Expected $script:RisePalsCandidateLifecycleEvidenceProperties `
    -Label "Candidate lifecycle evidence"

  if ($Result.schemaVersion -ne $script:RisePalsCandidateResultSchema -or
    $Result.executionMode -notin @("Simulation", "Live") -or
    $Result.invocationNonce -ne $ExpectedNonce -or
    $Result.invocationNonce -notmatch "^[a-f0-9]{32}$" -or
    $ConsumedNonces.ContainsKey($Result.invocationNonce)) {
    throw "The candidate result nonce is invalid or replayed."
  }
  if ($Result.repositoryHead -ne $ExpectedHead -or
    $Result.repositoryHead -notmatch "^[a-f0-9]{40}$" -or
    $Result.authorizationId -ne $ExpectedAuthorizationId -or
    $Result.launcherScriptSha256 -ne $ExpectedLauncherScriptSha256 -or
    $Result.bootstrapScriptSha256 -ne $ExpectedBootstrapScriptSha256 -or
    $Result.transportScriptSha256 -ne $ExpectedTransportScriptSha256 -or
    $Result.childScriptSha256 -ne $ExpectedChildScriptSha256 -or
    $Result.launcherScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Result.bootstrapScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Result.transportScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Result.childScriptSha256 -notmatch "^[a-f0-9]{64}$") {
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
  Assert-RisePalsCandidateCompletedStageSequence `
    -CompletedStages @($Result.completedStages) `
    -ExecutionMode ([string]$Result.executionMode) `
    -FailedStage $Result.failedStage
  $lifecycle = $Result.lifecycleEvidence
  if (([bool]$lifecycle.candidateServiceInstallationBegan -and
      -not [bool]$lifecycle.liveHostMutationBegan) -or
    ([bool]$lifecycle.candidateServiceStartReached -and
      -not [bool]$lifecycle.candidateServiceInstallationBegan) -or
    ([bool]$lifecycle.directStopServiceReached -and
      -not [bool]$lifecycle.candidateServiceStartReached) -or
    ($Result.executionMode -eq "Simulation" -and (
      [bool]$lifecycle.liveHostMutationBegan -or
      [bool]$lifecycle.candidateServiceInstallationBegan -or
      [bool]$lifecycle.candidateServiceStartReached -or
      [bool]$lifecycle.directStopServiceReached
    ))) {
    throw "Candidate lifecycle evidence is invalid or impossible."
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
  if ($json -match "(?i)(set-cookie|bearer[ ]|password|credential|request[ -]?body|@[a-z0-9.-]+\.[a-z]{2,}|(sk|pk)_(live|test)_)") {
    throw "The candidate structured result contains a prohibited privacy marker."
  }
  $ConsumedNonces[$Result.invocationNonce] = $true
  return $true
}

function Get-RisePalsCandidateFailureCodeMap {
  return [ordered]@{
    preflight = "preflight-rejected"
    "stage-immutable-inputs" = "stage-inputs-failed"
    "apply-exact-acls" = "acl-plan-rejected"
    "validate-candidate-config" = "config-validation-failed"
    "create-own-process-service" = "service-create-failed"
    "configure-service-sid" = "service-sid-failed"
    "configure-preshutdown-timeout" = "preshutdown-config-failed"
    "start-and-ready" = "readiness-timeout"
    "stream-first-byte" = "stream-synchronization-failed"
    "direct-stop" = "direct-stop-failed"
    "reject-new-work-during-drain" = "drain-rejection-failed"
    "complete-three-chunk-stream" = "stream-completion-failed"
    "duplicate-stop" = "duplicate-stop-failed"
    "verify-stop-checkpoints" = "checkpoint-proof-failed"
    "verify-preshutdown-registration" = "preshutdown-proof-failed"
    "verify-graceful-zero-job" = "owned-job-not-empty"
    "verify-timeout-cleanup" = "timeout-cleanup-failed"
    "verify-bounded-crash-restart" = "restart-bound-failed"
    "verify-process-ownership" = "process-ownership-failed"
    "verify-persistent-failure-terminal" = "terminal-failure-bound-failed"
    "verify-retained-proxy-independence" = "proxy-state-preservation-failed"
    cleanup = "cleanup-failed"
    "final-read-only-proof" = "final-proof-failed"
    "structured-live-state" = "missing-live-state"
    "child-finalization" = "child-finalization-failed"
    "native-child" = "native-child-exit-nonzero"
  }
}

function Assert-RisePalsCandidateCompletedStageSequence {
  param(
    [Parameter(Mandatory = $true)][string[]]$CompletedStages,
    [Parameter(Mandatory = $true)][ValidateSet("Simulation", "Live")][string]$ExecutionMode,
    [AllowNull()][string]$FailedStage
  )

  $wrapperPrefix = @("child-started", "child-exit-observed", "streams-separated")
  if ($CompletedStages.Count -lt 4 -or
    ($CompletedStages[0..2] -join "|") -ne ($wrapperPrefix -join "|") -or
    $CompletedStages[-1] -ne "raw-output-removed") {
    throw "Candidate completion stages do not have the exact child boundary."
  }
  $middle = @(if ($CompletedStages.Count -gt 4) {
    $CompletedStages[3..($CompletedStages.Count - 2)]
  })
  if ($ExecutionMode -eq "Simulation") {
    if ($middle.Count -ne 0 -or (
      -not [string]::IsNullOrWhiteSpace($FailedStage) -and
      $FailedStage -notin @("native-child", "cleanup")
    )) {
      throw "A simulation result contains live-only completion evidence."
    }
    return $true
  }

  $functional = @($middle | Where-Object {
    $_ -notin @("cleanup", "final-read-only-proof")
  })
  $expectedPrefix = @($script:RisePalsCandidateFunctionalStageOrder |
    Select-Object -First $functional.Count)
  if (($functional -join "|") -ne ($expectedPrefix -join "|") -or
    @($middle | Where-Object {
      $_ -notin @($script:RisePalsCandidateFunctionalStageOrder) -and
      $_ -notin @("cleanup", "final-read-only-proof")
    }).Count -ne 0) {
    throw "Live completion stages are unknown, reordered, or non-contiguous."
  }
  $suffix = @($middle | Select-Object -Skip $functional.Count)
  if ($suffix.Count -gt 0 -and ($suffix -join "|") -ne "cleanup|final-read-only-proof") {
    throw "Live cleanup stages are incomplete or reordered."
  }
  $allowedFailures = @($script:RisePalsCandidateFunctionalStageOrder) + @(
    "cleanup", "final-read-only-proof", "structured-live-state",
    "child-finalization", "native-child"
  )
  if (-not [string]::IsNullOrWhiteSpace($FailedStage) -and
    $FailedStage -notin $allowedFailures) {
    throw "The failed live stage is outside the fixed vocabulary."
  }
  return $true
}

function Assert-RisePalsCandidateLiveState {
  param([Parameter(Mandatory = $true)][object]$State)

  Assert-RisePalsCandidateExactPropertySet -Value $State `
    -Expected $script:RisePalsCandidateLiveStateProperties -Label "Candidate live state"
  Assert-RisePalsCandidateExactPropertySet -Value $State.finalState `
    -Expected $script:RisePalsCandidateFinalStateProperties -Label "Candidate live final state"
  Assert-RisePalsCandidateExactPropertySet -Value $State.lifecycleEvidence `
    -Expected $script:RisePalsCandidateLifecycleEvidenceProperties `
    -Label "Candidate live lifecycle evidence"
  if ($State.schemaVersion -ne $script:RisePalsCandidateLiveStateSchema -or
    $State.status -notin @("success", "failure") -or
    @($State.completedStages | Select-Object -Unique).Count -ne
      @($State.completedStages).Count) {
    throw "Candidate live state schema or stage identity is invalid."
  }
  $functional = @($State.completedStages | Where-Object {
    $_ -notin @("cleanup", "final-read-only-proof")
  })
  $expectedPrefix = @($script:RisePalsCandidateFunctionalStageOrder |
    Select-Object -First $functional.Count)
  $suffix = @($State.completedStages | Select-Object -Skip $functional.Count)
  if (($functional -join "|") -ne ($expectedPrefix -join "|") -or
    ($suffix.Count -gt 0 -and ($suffix -join "|") -ne "cleanup|final-read-only-proof")) {
    throw "Candidate live state stages are unknown, reordered, or impossible."
  }
  $failureMap = Get-RisePalsCandidateFailureCodeMap
  if ($State.status -eq "success") {
    if ($functional.Count -ne $script:RisePalsCandidateFunctionalStageOrder.Count -or
      ($suffix -join "|") -ne "cleanup|final-read-only-proof" -or
      $null -ne $State.failedStage -or $null -ne $State.sanitizedFailureCode -or
      -not [bool]$State.cleanupCompleted) {
      throw "A successful live state lacks mandatory stage or cleanup proof."
    }
  } else {
    if ($null -eq $State.failedStage -or
      -not $failureMap.Contains([string]$State.failedStage) -or
      [string]$State.sanitizedFailureCode -ne
        [string]$failureMap[[string]$State.failedStage]) {
      throw "A failed live state lacks an exact sanitized stage classification."
    }
  }
  $lifecycle = $State.lifecycleEvidence
  if (([bool]$lifecycle.candidateServiceInstallationBegan -and
      -not [bool]$lifecycle.liveHostMutationBegan) -or
    ([bool]$lifecycle.candidateServiceStartReached -and
      -not [bool]$lifecycle.candidateServiceInstallationBegan) -or
    ([bool]$lifecycle.directStopServiceReached -and
      -not [bool]$lifecycle.candidateServiceStartReached)) {
    throw "Candidate live lifecycle evidence is impossible."
  }
  return $true
}

function ConvertTo-RisePalsCandidateCanonicalChildDiagnostic {
  param([Parameter(Mandatory = $true)][object]$Diagnostic)

  $gates = [ordered]@{}
  foreach ($name in $script:RisePalsCandidateFunctionalGateMap.Keys) {
    $gates[$name] = [string]$Diagnostic.functionalGates.$name
  }
  return [pscustomobject][ordered]@{
    schemaVersion = [string]$Diagnostic.schemaVersion
    executionMode = [string]$Diagnostic.executionMode
    childResultDigest = if ($null -eq $Diagnostic.childResultDigest) { $null } else { [string]$Diagnostic.childResultDigest }
    childStatus = if ($null -eq $Diagnostic.childStatus) { $null } else { [string]$Diagnostic.childStatus }
    sanitizedFailureCode = if ($null -eq $Diagnostic.sanitizedFailureCode) { $null } else { [string]$Diagnostic.sanitizedFailureCode }
    failedStage = if ($null -eq $Diagnostic.failedStage) { $null } else { [string]$Diagnostic.failedStage }
    completedStages = @($Diagnostic.completedStages | ForEach-Object { [string]$_ })
    functionalGates = $gates
    liveHostMutationBegan = [bool]$Diagnostic.liveHostMutationBegan
    candidateServiceInstallationBegan = [bool]$Diagnostic.candidateServiceInstallationBegan
    candidateServiceStartReached = [bool]$Diagnostic.candidateServiceStartReached
    directStopServiceReached = [bool]$Diagnostic.directStopServiceReached
    childCleanupCompleted = [bool]$Diagnostic.childCleanupCompleted
    cleanupResponsibilityTransferredToParent = [bool]$Diagnostic.cleanupResponsibilityTransferredToParent
  }
}

function Get-RisePalsCandidateChildDiagnosticDigest {
  param([Parameter(Mandatory = $true)][object]$Diagnostic)

  $canonical = ConvertTo-RisePalsCandidateCanonicalChildDiagnostic -Diagnostic $Diagnostic
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

function New-RisePalsCandidateChildDiagnostic {
  param(
    [AllowNull()][object]$Result,
    [Parameter(Mandatory = $true)][ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$ExecutionMode,
    [Parameter(Mandatory = $true)][bool]$CleanupResponsibilityTransferredToParent
  )

  $hasResult = $null -ne $Result
  $completed = @(if ($hasResult -and $ExecutionMode -eq "Live") {
    $Result.completedStages | Where-Object {
      $_ -in @($script:RisePalsCandidateFunctionalStageOrder)
    }
  })
  $gates = [ordered]@{}
  foreach ($name in $script:RisePalsCandidateFunctionalGateMap.Keys) {
    $stage = [string]$script:RisePalsCandidateFunctionalGateMap[$name]
    $gates[$name] = if ($ExecutionMode -in @("Simulation", "ElevationProbe")) {
      "not_applicable"
    } elseif ($completed -contains $stage) {
      "passed"
    } elseif ($hasResult -and [string]$Result.failedStage -eq $stage) {
      "failed"
    } else {
      "not_reached"
    }
  }
  $lifecycle = if ($hasResult) {
    $Result.lifecycleEvidence
  } else {
    New-RisePalsCandidateLifecycleEvidence
  }
  $diagnostic = [ordered]@{
    schemaVersion = $script:RisePalsCandidateChildDiagnosticSchema
    executionMode = $ExecutionMode
    childResultDigest = if ($hasResult) { [string]$Result.resultDigest } else { $null }
    childStatus = if ($hasResult) { [string]$Result.status } else { $null }
    sanitizedFailureCode = if ($hasResult) { $Result.sanitizedFailureCode } else { $null }
    failedStage = if ($hasResult) { $Result.failedStage } else { $null }
    completedStages = $completed
    functionalGates = [pscustomobject]$gates
    liveHostMutationBegan = [bool]$lifecycle.liveHostMutationBegan
    candidateServiceInstallationBegan = [bool]$lifecycle.candidateServiceInstallationBegan
    candidateServiceStartReached = [bool]$lifecycle.candidateServiceStartReached
    directStopServiceReached = [bool]$lifecycle.directStopServiceReached
    childCleanupCompleted = if ($hasResult) { [bool]$Result.cleanupCompleted } else { $false }
    cleanupResponsibilityTransferredToParent = $CleanupResponsibilityTransferredToParent
    diagnosticDigest = ""
  }
  $diagnostic.diagnosticDigest = Get-RisePalsCandidateChildDiagnosticDigest `
    -Diagnostic $diagnostic
  return [pscustomobject]$diagnostic
}

function Assert-RisePalsCandidateChildDiagnostic {
  param([Parameter(Mandatory = $true)][object]$Diagnostic)

  Assert-RisePalsCandidateExactPropertySet -Value $Diagnostic `
    -Expected $script:RisePalsCandidateChildDiagnosticProperties `
    -Label "Candidate child diagnostic"
  Assert-RisePalsCandidateExactPropertySet -Value $Diagnostic.functionalGates `
    -Expected @($script:RisePalsCandidateFunctionalGateMap.Keys) `
    -Label "Candidate functional gates"
  $completed = @($Diagnostic.completedStages)
  $expectedPrefix = @($script:RisePalsCandidateFunctionalStageOrder |
    Select-Object -First $completed.Count)
  $lifecycleImpossible = (
    [bool]$Diagnostic.candidateServiceInstallationBegan -and
      -not [bool]$Diagnostic.liveHostMutationBegan
  ) -or (
    [bool]$Diagnostic.candidateServiceStartReached -and
      -not [bool]$Diagnostic.candidateServiceInstallationBegan
  ) -or (
    [bool]$Diagnostic.directStopServiceReached -and
      -not [bool]$Diagnostic.candidateServiceStartReached
  )
  if ($Diagnostic.schemaVersion -ne $script:RisePalsCandidateChildDiagnosticSchema -or
    $Diagnostic.executionMode -notin @("Simulation", "Live", "ElevationProbe") -or
    ($completed -join "|") -ne ($expectedPrefix -join "|") -or
    @($completed | Select-Object -Unique).Count -ne $completed.Count -or
    $lifecycleImpossible -or
    $Diagnostic.diagnosticDigest -ne (
      Get-RisePalsCandidateChildDiagnosticDigest -Diagnostic $Diagnostic
    )) {
    throw "Candidate child diagnostic schema, order, or digest is invalid."
  }
  $hasResult = $null -ne $Diagnostic.childResultDigest
  if (-not $hasResult) {
    if ($null -ne $Diagnostic.childStatus -or
      $null -ne $Diagnostic.sanitizedFailureCode -or
      $null -ne $Diagnostic.failedStage -or $completed.Count -ne 0 -or
      [bool]$Diagnostic.liveHostMutationBegan -or
      [bool]$Diagnostic.candidateServiceInstallationBegan -or
      [bool]$Diagnostic.candidateServiceStartReached -or
      [bool]$Diagnostic.directStopServiceReached -or
      [bool]$Diagnostic.childCleanupCompleted) {
      throw "An unavailable child diagnostic claims unvalidated child evidence."
    }
  } elseif ($Diagnostic.childResultDigest -notmatch "^[a-f0-9]{64}$" -or
    $Diagnostic.childStatus -notin @("success", "failure") -or
    ($Diagnostic.childStatus -eq "success" -and (
      $null -ne $Diagnostic.failedStage -or
      $null -ne $Diagnostic.sanitizedFailureCode -or
      -not [bool]$Diagnostic.childCleanupCompleted
    )) -or
    ($Diagnostic.childStatus -eq "failure" -and (
      [string]$Diagnostic.failedStage -notmatch "^[a-z0-9-]+$" -or
      [string]$Diagnostic.sanitizedFailureCode -notmatch "^[a-z0-9-]+$"
    ))) {
    throw "Candidate child diagnostic status and failure evidence are inconsistent."
  }
  if ($hasResult -and $Diagnostic.childStatus -eq "failure") {
    $failureMap = Get-RisePalsCandidateFailureCodeMap
    if (-not $failureMap.Contains([string]$Diagnostic.failedStage) -or
      [string]$Diagnostic.sanitizedFailureCode -ne
        [string]$failureMap[[string]$Diagnostic.failedStage]) {
      throw "Candidate child diagnostic failure provenance is not exact."
    }
  }
  foreach ($name in $script:RisePalsCandidateFunctionalGateMap.Keys) {
    $stage = [string]$script:RisePalsCandidateFunctionalGateMap[$name]
    $expected = if ($Diagnostic.executionMode -in @("Simulation", "ElevationProbe")) {
      "not_applicable"
    } elseif ($completed -contains $stage) {
      "passed"
    } elseif ($hasResult -and [string]$Diagnostic.failedStage -eq $stage) {
      "failed"
    } else {
      "not_reached"
    }
    if ([string]$Diagnostic.functionalGates.$name -ne $expected) {
      throw "A candidate functional gate is missing, extra, or inconsistent."
    }
  }
  if ($Diagnostic.executionMode -in @("Simulation", "ElevationProbe") -and (
    $completed.Count -ne 0 -or [bool]$Diagnostic.liveHostMutationBegan -or
    [bool]$Diagnostic.candidateServiceInstallationBegan -or
    [bool]$Diagnostic.candidateServiceStartReached -or
    [bool]$Diagnostic.directStopServiceReached
  )) {
    throw "A non-Live diagnostic claims a Live lifecycle transition."
  }
  if ($Diagnostic.executionMode -eq "Live") {
    $stageCount = $completed.Count
    $mutationExpected = $stageCount -ge 2 -or (
      $stageCount -eq 1 -and $Diagnostic.failedStage -eq "stage-immutable-inputs"
    )
    $installationExpected = $stageCount -ge 5 -or (
      $stageCount -eq 4 -and $Diagnostic.failedStage -eq "create-own-process-service"
    )
    $startExpected = $stageCount -ge 8 -or (
      $stageCount -eq 7 -and $Diagnostic.failedStage -eq "start-and-ready"
    )
    $stopExpected = $stageCount -ge 10 -or (
      $stageCount -eq 9 -and $Diagnostic.failedStage -eq "direct-stop"
    )
    if (([bool]$Diagnostic.liveHostMutationBegan -ne $mutationExpected) -or
      ([bool]$Diagnostic.candidateServiceInstallationBegan -ne $installationExpected) -or
      ([bool]$Diagnostic.candidateServiceStartReached -ne $startExpected) -or
      ([bool]$Diagnostic.directStopServiceReached -ne $stopExpected)) {
      throw "Candidate lifecycle booleans disagree with completed stages."
    }
    if ($hasResult -and $Diagnostic.childStatus -eq "failure" -and
      $Diagnostic.failedStage -in @($script:RisePalsCandidateFunctionalStageOrder)) {
      $expectedFailedStage = if ($stageCount -lt
        $script:RisePalsCandidateFunctionalStageOrder.Count) {
        [string]$script:RisePalsCandidateFunctionalStageOrder[$stageCount]
      } else {
        $null
      }
      if ($Diagnostic.failedStage -ne $expectedFailedStage) {
        throw "Candidate failed-stage evidence disagrees with its completion prefix."
      }
    }
  }
  return $true
}

function Test-RisePalsCandidateDiagnosticFunctionalSuccess {
  param([Parameter(Mandatory = $true)][object]$Diagnostic)

  [void](Assert-RisePalsCandidateChildDiagnostic -Diagnostic $Diagnostic)
  if ($Diagnostic.childStatus -ne "success" -or
    -not [bool]$Diagnostic.childCleanupCompleted) {
    return $false
  }
  if ($Diagnostic.executionMode -eq "Simulation") {
    return $true
  }
  if ($Diagnostic.executionMode -eq "ElevationProbe") {
    return $false
  }
  return @($script:RisePalsCandidateFunctionalGateMap.Keys | Where-Object {
    [string]$Diagnostic.functionalGates.$_ -ne "passed"
  }).Count -eq 0
}
