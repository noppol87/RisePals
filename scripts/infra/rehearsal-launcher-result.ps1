Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RisePalsLauncherResultSchemaVersion = "rise-pals-elevated-rehearsal-result-v1"
$script:RisePalsLauncherResultProperties = @(
  "schemaVersion",
  "invocationNonce",
  "requestedRepositoryHead",
  "executionMode",
  "startedAtUtc",
  "completedAtUtc",
  "status",
  "childExitCode",
  "completedStages",
  "failedStage",
  "sanitizedFailureCode",
  "cleanupCompleted",
  "finalResourceCounts",
  "streamEvidence",
  "resultDigest"
)
$script:RisePalsLauncherResourceCountProperties = @(
  "rawCaptureFiles",
  "resultTemporaryFiles",
  "rootProcesses",
  "listeners",
  "enabledFirewallRules",
  "stagingChildren",
  "rehearsalChildren",
  "drainStateFiles",
  "atomicTemporaryFiles",
  "drainLockFiles",
  "syntheticCanaries"
)
$script:RisePalsLauncherStreamEvidenceProperties = @(
  "stdoutPresent",
  "stderrPresent",
  "streamsSeparated",
  "stdoutBytes",
  "stderrBytes"
)
$script:RisePalsLauncherSimulationCompletionStages = @(
  "native-process-started",
  "native-exit-observed",
  "stdout-captured",
  "stderr-captured",
  "raw-captures-removed"
)
$script:RisePalsLauncherLiveCompletionStages = @(
  "native-process-started",
  "native-exit-observed",
  "stdout-captured",
  "stderr-captured",
  "service-identity",
  "acl-model",
  "forward-switch",
  "automatic-rollback",
  "manual-rollback",
  "independent-restart",
  "graceful-stop",
  "bounded-crash-recovery",
  "certificate-reissue-reload",
  "secret-lifecycle-no-leak",
  "loopback-proxy-health",
  "final-cleanup",
  "raw-captures-removed"
)

function Assert-RisePalsLauncherPlainDirectory {
  param([Parameter(Mandatory = $true)][string]$Path)

  $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
  $current = $full
  while ($current) {
    $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
    if (-not $item.PSIsContainer -or
      ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "The launcher directory ancestry is not plain."
    }
    $current = [IO.Path]::GetDirectoryName($current)
  }
  return $full
}

function Assert-RisePalsSimulationReviewDirectory {
  param([Parameter(Mandatory = $true)][string]$Path, [switch]$RequireEmpty)

  $full = Assert-RisePalsLauncherPlainDirectory -Path $Path
  if (-not [IO.Path]::GetDirectoryName($full).Equals(
      [IO.Path]::GetTempPath().TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($full) -cnotmatch '^risepals-launcher-review-[a-f0-9]{32}$') {
    throw "The simulation review directory is outside its exact temporary boundary."
  }
  if ($RequireEmpty -and @(Get-ChildItem -LiteralPath $full -Force).Count -ne 0) {
    throw "The simulation review directory is not fresh."
  }
  return $full
}

function Assert-RisePalsLauncherExactPropertySet {
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

function ConvertTo-RisePalsLauncherCanonicalObject {
  param([Parameter(Mandatory = $true)][object]$Result)

  return [ordered]@{
    schemaVersion = [string]$Result.schemaVersion
    invocationNonce = [string]$Result.invocationNonce
    requestedRepositoryHead = [string]$Result.requestedRepositoryHead
    executionMode = [string]$Result.executionMode
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
    finalResourceCounts = [ordered]@{
      rawCaptureFiles = [int]$Result.finalResourceCounts.rawCaptureFiles
      resultTemporaryFiles = [int]$Result.finalResourceCounts.resultTemporaryFiles
      rootProcesses = [int]$Result.finalResourceCounts.rootProcesses
      listeners = [int]$Result.finalResourceCounts.listeners
      enabledFirewallRules = [int]$Result.finalResourceCounts.enabledFirewallRules
      stagingChildren = [int]$Result.finalResourceCounts.stagingChildren
      rehearsalChildren = [int]$Result.finalResourceCounts.rehearsalChildren
      drainStateFiles = [int]$Result.finalResourceCounts.drainStateFiles
      atomicTemporaryFiles = [int]$Result.finalResourceCounts.atomicTemporaryFiles
      drainLockFiles = [int]$Result.finalResourceCounts.drainLockFiles
      syntheticCanaries = [int]$Result.finalResourceCounts.syntheticCanaries
    }
    streamEvidence = [ordered]@{
      stdoutPresent = [bool]$Result.streamEvidence.stdoutPresent
      stderrPresent = [bool]$Result.streamEvidence.stderrPresent
      streamsSeparated = [bool]$Result.streamEvidence.streamsSeparated
      stdoutBytes = [int64]$Result.streamEvidence.stdoutBytes
      stderrBytes = [int64]$Result.streamEvidence.stderrBytes
    }
  }
}

function Get-RisePalsLauncherResultDigest {
  param([Parameter(Mandatory = $true)][object]$Result)

  $canonical = ConvertTo-RisePalsLauncherCanonicalObject -Result $Result
  $json = $canonical | ConvertTo-Json -Depth 6 -Compress
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = $algorithm.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
  }
}

function New-RisePalsLauncherResourceCounts {
  param(
    [int]$RawCaptureFiles = 0,
    [int]$ResultTemporaryFiles = 0,
    [int]$RootProcesses = 0,
    [int]$Listeners = 0,
    [int]$EnabledFirewallRules = 0,
    [int]$StagingChildren = 0,
    [int]$RehearsalChildren = 0,
    [int]$DrainStateFiles = 0,
    [int]$AtomicTemporaryFiles = 0,
    [int]$DrainLockFiles = 0,
    [int]$SyntheticCanaries = 0
  )

  return [ordered]@{
    rawCaptureFiles = $RawCaptureFiles
    resultTemporaryFiles = $ResultTemporaryFiles
    rootProcesses = $RootProcesses
    listeners = $Listeners
    enabledFirewallRules = $EnabledFirewallRules
    stagingChildren = $StagingChildren
    rehearsalChildren = $RehearsalChildren
    drainStateFiles = $DrainStateFiles
    atomicTemporaryFiles = $AtomicTemporaryFiles
    drainLockFiles = $DrainLockFiles
    syntheticCanaries = $SyntheticCanaries
  }
}

function New-RisePalsLauncherResult {
  param(
    [Parameter(Mandatory = $true)][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][string]$RequestedRepositoryHead,
    [Parameter(Mandatory = $true)][ValidateSet("live", "simulation")][string]$ExecutionMode,
    [Parameter(Mandatory = $true)][string]$StartedAtUtc,
    [Parameter(Mandatory = $true)][string]$CompletedAtUtc,
    [Parameter(Mandatory = $true)][ValidateSet("success", "failure")][string]$Status,
    [Parameter(Mandatory = $true)][int]$ChildExitCode,
    [Parameter(Mandatory = $true)][string[]]$CompletedStages,
    [AllowNull()][string]$FailedStage,
    [AllowNull()][string]$SanitizedFailureCode,
    [Parameter(Mandatory = $true)][bool]$CleanupCompleted,
    [Parameter(Mandatory = $true)][object]$FinalResourceCounts,
    [Parameter(Mandatory = $true)][object]$StreamEvidence
  )

  $result = [ordered]@{
    schemaVersion = $script:RisePalsLauncherResultSchemaVersion
    invocationNonce = $InvocationNonce
    requestedRepositoryHead = $RequestedRepositoryHead
    executionMode = $ExecutionMode
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
    finalResourceCounts = $FinalResourceCounts
    streamEvidence = $StreamEvidence
    resultDigest = ""
  }
  $result.resultDigest = Get-RisePalsLauncherResultDigest -Result $result
  return [pscustomobject]$result
}

function Write-RisePalsLauncherResultAtomic {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][string]$ResultPath,
    [Parameter(Mandatory = $true)][string]$TemporaryResultPath
  )

  $resolvedResult = [IO.Path]::GetFullPath($ResultPath)
  $resolvedTemporary = [IO.Path]::GetFullPath($TemporaryResultPath)
  $resultDirectory = [IO.Path]::GetDirectoryName($resolvedResult)
  if (-not [IO.Path]::GetDirectoryName($resolvedTemporary).Equals(
    $resultDirectory,
    [StringComparison]::OrdinalIgnoreCase
  )) {
    throw "The launcher result temporary file must share the exact result directory."
  }
  if ([IO.File]::Exists($resolvedResult) -or [IO.File]::Exists($resolvedTemporary)) {
    throw "The launcher result path already exists."
  }

  $json = ($Result | ConvertTo-Json -Depth 6) + "`n"
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
  $stream = [IO.FileStream]::new(
    $resolvedTemporary,
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
  [IO.File]::Move($resolvedTemporary, $resolvedResult)
}

function ConvertFrom-RisePalsLauncherUtcTimestamp {
  param(
    [Parameter(Mandatory = $true)][string]$Value,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $parsed = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParseExact(
    $Value,
    "o",
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::None,
    [ref]$parsed
  ) -or $parsed.Offset -ne [TimeSpan]::Zero) {
    throw "$Label must be an exact UTC round-trip timestamp."
  }
  return $parsed
}

function Assert-RisePalsLauncherResultPrivacy {
  param([Parameter(Mandatory = $true)][object]$Result)

  $json = $Result | ConvertTo-Json -Depth 6 -Compress
  foreach ($pattern in @(
    "(?i)authorization",
    "(?i)set-cookie",
    "(?i)bearer[ ]",
    "(?i)password",
    "(?i)credential",
    "(?i)request[ -]?body",
    "(?i)x-forwarded-",
    "(?i)[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}",
    "(?i)(sk|pk)_(live|test)_"
  )) {
    if ($json -match $pattern) {
      throw "The launcher result contains a prohibited privacy marker."
    }
  }
}

function Assert-RisePalsLauncherResult {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][string]$ExpectedInvocationNonce,
    [Parameter(Mandatory = $true)][string]$ExpectedRepositoryHead,
    [Parameter(Mandatory = $true)][int]$ObservedChildExitCode,
    [Parameter(Mandatory = $true)][DateTimeOffset]$InvocationStartedAtUtc,
    [DateTimeOffset]$ValidationNowUtc = [DateTimeOffset]::UtcNow
  )

  Assert-RisePalsLauncherExactPropertySet -Value $Result `
    -Expected $script:RisePalsLauncherResultProperties -Label "Launcher result"
  Assert-RisePalsLauncherExactPropertySet -Value $Result.finalResourceCounts `
    -Expected $script:RisePalsLauncherResourceCountProperties -Label "Final resource counts"
  Assert-RisePalsLauncherExactPropertySet -Value $Result.streamEvidence `
    -Expected $script:RisePalsLauncherStreamEvidenceProperties -Label "Stream evidence"

  if ($Result.schemaVersion -ne $script:RisePalsLauncherResultSchemaVersion) {
    throw "The launcher result schema version is unsupported."
  }
  $nonce = [guid]::Empty
  if (-not [guid]::TryParseExact([string]$Result.invocationNonce, "D", [ref]$nonce) -or
    -not ([string]$Result.invocationNonce).Equals(
      $ExpectedInvocationNonce,
      [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "The launcher result invocation nonce is invalid."
  }
  if ([string]$Result.requestedRepositoryHead -notmatch "^[a-f0-9]{40}$" -or
    $Result.requestedRepositoryHead -ne $ExpectedRepositoryHead) {
    throw "The launcher result repository head does not match the request."
  }
  if ($Result.executionMode -notin @("live", "simulation")) {
    throw "The launcher result execution mode is invalid."
  }

  $started = ConvertFrom-RisePalsLauncherUtcTimestamp -Value $Result.startedAtUtc `
    -Label "Launcher start"
  $completed = ConvertFrom-RisePalsLauncherUtcTimestamp -Value $Result.completedAtUtc `
    -Label "Launcher completion"
  if ($started -lt $InvocationStartedAtUtc.AddSeconds(-5) -or
    $started -gt $ValidationNowUtc.AddMinutes(1) -or
    $completed -lt $started -or
    $completed -gt $ValidationNowUtc.AddMinutes(1) -or
    ($completed - $started) -gt [TimeSpan]::FromMinutes(45)) {
    throw "The launcher result timestamps are stale or incoherent."
  }

  if ($Result.childExitCode -isnot [int] -or
    [int]$Result.childExitCode -ne $ObservedChildExitCode) {
    throw "The launcher child exit code disagrees with the process result."
  }
  if ($Result.status -eq "success") {
    if ($Result.childExitCode -ne 0 -or $null -ne $Result.failedStage -or
      $null -ne $Result.sanitizedFailureCode -or -not $Result.cleanupCompleted) {
      throw "A successful launcher result is internally inconsistent."
    }
  } elseif ($Result.status -eq "failure") {
    if ($Result.childExitCode -eq 0 -or
      [string]::IsNullOrWhiteSpace([string]$Result.failedStage) -or
      [string]$Result.failedStage -notmatch "^[a-z0-9-]+$" -or
      [string]::IsNullOrWhiteSpace([string]$Result.sanitizedFailureCode) -or
      [string]$Result.sanitizedFailureCode -notmatch "^[a-z0-9-]+$") {
      throw "A failed launcher result is internally inconsistent."
    }
  } else {
    throw "The launcher result status is invalid."
  }

  $stages = @($Result.completedStages)
  if (@($stages | Where-Object { $_ -isnot [string] -or $_ -notmatch "^[a-z0-9-]+$" }).Count -ne 0 -or
    @($stages | Select-Object -Unique).Count -ne $stages.Count) {
    throw "The launcher completion stages are invalid or ambiguous."
  }
  if ($Result.status -eq "success") {
    $required = if ($Result.executionMode -eq "live") {
      $script:RisePalsLauncherLiveCompletionStages
    } else {
      $script:RisePalsLauncherSimulationCompletionStages
    }
    if (@($required | Where-Object { $_ -notin $stages }).Count -ne 0) {
      throw "A successful launcher result is missing a required completion marker."
    }
  }

  foreach ($property in $script:RisePalsLauncherResourceCountProperties) {
    $value = $Result.finalResourceCounts.$property
    if ($value -isnot [int] -or $value -lt 0) {
      throw "A final resource count is invalid."
    }
  }
  foreach ($property in @("stdoutPresent", "stderrPresent", "streamsSeparated")) {
    if ($Result.streamEvidence.$property -isnot [bool]) {
      throw "A stream evidence flag is invalid."
    }
  }
  foreach ($property in @("stdoutBytes", "stderrBytes")) {
    $value = $Result.streamEvidence.$property
    if (($value -isnot [int]) -and ($value -isnot [long]) -or $value -lt 0) {
      throw "A stream evidence byte count is invalid."
    }
  }
  if (-not $Result.streamEvidence.streamsSeparated) {
    throw "The launcher did not preserve separate native streams."
  }
  if ($Result.cleanupCompleted -and
    ($Result.finalResourceCounts.rawCaptureFiles -ne 0 -or
      $Result.finalResourceCounts.resultTemporaryFiles -ne 0)) {
    throw "The launcher claims cleanup with capture residue."
  }

  if ([string]$Result.resultDigest -notmatch "^[a-f0-9]{64}$" -or
    $Result.resultDigest -ne (Get-RisePalsLauncherResultDigest -Result $Result)) {
    throw "The launcher result digest is invalid."
  }
  Assert-RisePalsLauncherResultPrivacy -Result $Result
  return $true
}
