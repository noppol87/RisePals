[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][ValidateSet("Simulation", "Live")][string]$Mode,
  [Parameter(Mandatory = $true)][string]$SimulationScenario,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$RepositoryHead,
  [Parameter(Mandatory = $true)][string]$AuthorizationId,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$LauncherScriptSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$BootstrapScriptSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$TransportScriptSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$ChildScriptSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce,
  [Parameter(Mandatory = $true)][string]$ResultRoot,
  [Parameter(Mandatory = $true)][string]$InvocationDirectory,
  [string]$FutureAuthorizationId = "",
  [string]$CandidateExecutableSource = "",
  [string]$NodeExecutableSource = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "candidate-rehearsal-contract.ps1")
. (Join-Path $PSScriptRoot "candidate-rehearsal-result.ps1")
. (Join-Path $PSScriptRoot "candidate-rehearsal-transport.ps1")

$directory = Assert-RisePalsCandidateInvocationDirectory -Path $InvocationDirectory `
  -ExpectedRoot $ResultRoot -InvocationNonce $InvocationNonce
$childStartedMarker = New-RisePalsCandidateMarker -MarkerType "child-started" `
  -InvocationNonce $InvocationNonce -AuthorizationId $AuthorizationId `
  -RepositoryHead $RepositoryHead -LauncherScriptSha256 $LauncherScriptSha256 `
  -BootstrapScriptSha256 $BootstrapScriptSha256 `
  -TransportScriptSha256 $TransportScriptSha256 `
  -ChildScriptSha256 $ChildScriptSha256 -SanitizedFailureCode $null
Write-RisePalsCandidateMarkerAtomic -Marker $childStartedMarker `
  -InvocationDirectory $directory
if (-not $PSCmdlet.ShouldProcess(
  $directory,
  ("Run the candidate {0} child" -f $Mode.ToLowerInvariant())
)) {
  Write-Output "Rise Pals candidate child dry-run PASS"
  return
}

$resultPath = Join-Path $directory "result.json"
$temporaryResultPath = Join-Path $directory "result.tmp"
$stdoutPath = Join-Path $directory "stdout.log"
$stderrPath = Join-Path $directory "stderr.log"
$liveStatePath = Join-Path $directory "live-state.json"
$started = [DateTimeOffset]::UtcNow

if ($Mode -eq "Simulation" -and $SimulationScenario -eq "MissingResult") {
  exit 9
}
if ($Mode -eq "Simulation" -and $SimulationScenario -eq "MalformedResult") {
  [IO.File]::WriteAllText($resultPath, "{malformed", [Text.UTF8Encoding]::new($false))
  exit 10
}
if ($Mode -eq "Simulation" -and $SimulationScenario -eq "PartialResult") {
  [IO.File]::WriteAllText(
    $resultPath,
    '{"schemaVersion":"partial"}',
    [Text.UTF8Encoding]::new($false)
  )
  exit 11
}

$powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$processArguments = @("-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File")
if ($Mode -eq "Simulation") {
  $fixture = Join-Path $PSScriptRoot "Invoke-RisePalsLauncherFixture.ps1"
  $fixtureScenario = if ($SimulationScenario -eq "NativeFailure") {
    "NativeFailure"
  } else {
    "NativeSuccess"
  }
  $processArguments += '"' + $fixture + '"'
  $processArguments += @("-Scenario", $fixtureScenario)
} else {
  if ($FutureAuthorizationId -notmatch "^RP-TURN-019-R4-LIVE-[A-F0-9]{8}$") {
    throw "The candidate live child lacks a separate authorization identifier."
  }
  $live = Join-Path $PSScriptRoot "Invoke-RisePalsCandidateLiveSequence.ps1"
  $processArguments += '"' + $live + '"'
  $processArguments += @(
    "-RepositoryHead",
    $RepositoryHead,
    "-InvocationNonce",
    $InvocationNonce,
    "-FutureAuthorizationId",
    $FutureAuthorizationId,
    "-CandidateExecutableSource",
    ('"' + $CandidateExecutableSource + '"'),
    "-NodeExecutableSource",
    ('"' + $NodeExecutableSource + '"'),
    "-StructuredStatePath",
    ('"' + $liveStatePath + '"')
  )
}

$liveMarker = New-RisePalsCandidateMarker -MarkerType "live-started" `
  -InvocationNonce $InvocationNonce -AuthorizationId $AuthorizationId `
  -RepositoryHead $RepositoryHead -LauncherScriptSha256 $LauncherScriptSha256 `
  -BootstrapScriptSha256 $BootstrapScriptSha256 `
  -TransportScriptSha256 $TransportScriptSha256 `
  -ChildScriptSha256 $ChildScriptSha256 -SanitizedFailureCode $null
Write-RisePalsCandidateMarkerAtomic -Marker $liveMarker -InvocationDirectory $directory
if ($Mode -eq "Simulation" -and $SimulationScenario -eq "MissingFinalAfterLive") {
  exit 12
}

$process = Start-Process -FilePath $powerShell -ArgumentList $processArguments `
  -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath `
  -WindowStyle Hidden -Wait -PassThru
$exitCode = $process.ExitCode
$process.Dispose()
$stdoutObserved = [IO.File]::Exists($stdoutPath) -and (Get-Item -LiteralPath $stdoutPath).Length -gt 0
$stderrObserved = [IO.File]::Exists($stderrPath) -and (Get-Item -LiteralPath $stderrPath).Length -gt 0
$status = if ($exitCode -eq 0) { "success" } else { "failure" }
$failedStage = if ($status -eq "failure") { "native-child" } else { $null }
$failureCode = if ($status -eq "failure") { "native-child-exit-nonzero" } else { $null }
$completedStages = @("child-started", "child-exit-observed", "streams-separated")
$finalState = New-RisePalsCandidateFinalState
$lifecycleEvidence = New-RisePalsCandidateLifecycleEvidence
$cleanupCompleted = $true

if ($Mode -eq "Live") {
  . (Join-Path $PSScriptRoot "Invoke-RisePalsCandidateLiveSequence.ps1") -EarlyContractOnly `
    -RepositoryHead $RepositoryHead -InvocationNonce $InvocationNonce -FutureAuthorizationId $FutureAuthorizationId
  $earlyRecords=@(); $earlyValid=$false
  try {
    $earlyBinding=New-RisePalsEarlyBinding $FutureAuthorizationId $InvocationNonce $RepositoryHead Live
    $earlyRecords=Read-RisePalsEarlyChain $directory $earlyBinding $started
    $earlyValid=$true
  } catch { $earlyValid=$false }
  if (-not $earlyValid -or $earlyRecords.Count -eq 0) {
    $status="failure"; $exitCode=if ($exitCode -eq 0) { 24 } else { $exitCode }
    $failedStage=if ($earlyValid) { "early-live-entry" } else { "early-live-validation" }
    $failureCode=if ($earlyValid) { "live-process-exit-before-entry-evidence" } else { "early-live-evidence-invalid" }
    $cleanupCompleted=$false
  } elseif (-not [IO.File]::Exists($liveStatePath)) {
    $status = "failure"
    $exitCode = if ($exitCode -eq 0) { 21 } else { $exitCode }
    $failedStage = "structured-live-state"
    $failureCode = "missing-live-state"
    $cleanupCompleted = $false
  } else {
    $liveState = $null
    try {
      if ($earlyRecords.Count -ne 9 -or $earlyRecords[-1].liveStateDigest -cne (Get-RisePalsEarlyHash -Path $liveStatePath)) {
        throw "Authoritative Live state lacks its completed early binding."
      }
      $liveState = [Text.UTF8Encoding]::new($false, $true).GetString(
        [IO.File]::ReadAllBytes($liveStatePath)
      ) | ConvertFrom-Json
      [void](Assert-RisePalsCandidateLiveState -State $liveState)
      $finalState = $liveState.finalState
      $lifecycleEvidence = $liveState.lifecycleEvidence
      $cleanupCompleted = [bool]$liveState.cleanupCompleted
      $completedStages += @($liveState.completedStages)
    } catch {
      $status = "failure"
      $exitCode = if ($exitCode -eq 0) { 22 } else { $exitCode }
      $failedStage = "child-finalization"
      $failureCode = "child-finalization-failed"
      $cleanupCompleted = $false
    }
    if ($null -ne $liveState -and $failedStage -ne "child-finalization" -and
      $liveState.status -ne "success") {
      $status = "failure"
      $exitCode = if ($exitCode -eq 0) { 22 } else { $exitCode }
      $failedStage = [string]$liveState.failedStage
      $failureCode = [string]$liveState.sanitizedFailureCode
    }
  }
}

foreach ($capture in @($stdoutPath, $stderrPath)) {
  if ([IO.File]::Exists($capture)) {
    [IO.File]::Delete($capture)
  }
}
$completedStages += "raw-output-removed"

if ($Mode -eq "Simulation") {
  switch ($SimulationScenario) {
    "StaleResult" { $started = $started.AddHours(-2) }
    "WrongNonce" { $InvocationNonce = [guid]::NewGuid().ToString("N") }
    "WrongHead" { $RepositoryHead = "0000000000000000000000000000000000000000" }
    "WrongScriptHash" {
      $LauncherScriptSha256 = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    }
    "CleanupFailure" {
      $status = "failure"
      $exitCode = 13
      $failedStage = "cleanup"
      $failureCode = "cleanup-failed"
      $cleanupCompleted = $false
      $finalState = New-RisePalsCandidateFinalState -TemporaryChildren 1
    }
  }
}

$streamEvidence = [ordered]@{
  stdoutObserved = [bool]$stdoutObserved
  stderrObserved = [bool]$stderrObserved
  streamsSeparated = $true
  rawOutputPersisted = $false
}
$result = New-RisePalsCandidateResult -InvocationNonce $InvocationNonce `
  -AuthorizationId $AuthorizationId -RepositoryHead $RepositoryHead `
  -LauncherScriptSha256 $LauncherScriptSha256 `
  -BootstrapScriptSha256 $BootstrapScriptSha256 `
  -TransportScriptSha256 $TransportScriptSha256 `
  -ChildScriptSha256 $ChildScriptSha256 `
  -StartedAtUtc $started.ToString("o") `
  -CompletedAtUtc ([DateTimeOffset]::UtcNow.ToString("o")) -Status $status `
  -ExecutionMode $Mode `
  -ChildExitCode $exitCode -CompletedStages $completedStages -FailedStage $failedStage `
  -SanitizedFailureCode $failureCode -CleanupCompleted $cleanupCompleted `
  -LifecycleEvidence $lifecycleEvidence -FinalState $finalState `
  -StreamEvidence $streamEvidence
if ($Mode -eq "Simulation" -and $SimulationScenario -eq "DigestMismatch") {
  $result.resultDigest = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
}
Write-RisePalsCandidateResultAtomic -Result $result -ResultPath $resultPath `
  -TemporaryPath $temporaryResultPath
exit $exitCode
