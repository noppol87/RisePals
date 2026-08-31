[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$ExpectedRepositoryHead,
  [ValidateSet("Plan", "Simulation", "Live")][string]$Mode = "Plan",
  [ValidateSet(
    "SuccessWithInformationalStderr",
    "NativeFailure",
    "MissingResult",
    "MalformedResult",
    "StaleResult",
    "WrongNonce",
    "WrongHead",
    "WrongScriptHash",
    "DigestMismatch",
    "PartialResult",
    "CleanupFailure",
    "ChildProcessLaunchFailure",
    "ChildExitsBeforeStartMarker",
    "MissingFinalAfterLive",
    "TransientCleanupFailure",
    "CheckpointWriteInterruption",
    "FinalResultWriteInterruption"
  )][string]$SimulationScenario = "SuccessWithInformationalStderr",
  [string]$RepositoryRoot = "",
  [string]$EvidenceDirectory = "",
  [string]$FutureAuthorizationId = "",
  [string]$CandidateExecutableSource = "",
  [string]$NodeExecutableSource = "",
  [ValidatePattern("^$|^[a-f0-9]{32}$")][string]$SimulationInvocationNonce = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "candidate-rehearsal-contract.ps1")
. (Join-Path $PSScriptRoot "candidate-rehearsal-result.ps1")
. (Join-Path $PSScriptRoot "candidate-rehearsal-transport.ps1")

function Get-RisePalsCandidateGitExecutable {
  $portable = "C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
  if (-not [IO.File]::Exists($portable)) {
    throw "The pinned repository Git executable is absent."
  }
  return $portable
}

function ConvertTo-RisePalsCandidateProcessArgument {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Value
  )

  if ($Value.Contains('"')) {
    throw "A candidate process argument contains a prohibited quote."
  }
  return '"' + $Value + '"'
}

$repository = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  Get-RisePalsCandidateRepositoryRoot
} else {
  [IO.Path]::GetFullPath($RepositoryRoot)
}
$approvedRepository = "C:\Codex PC SG2\Jeff\risepals"
if (-not $repository.TrimEnd([IO.Path]::DirectorySeparatorChar).Equals(
  $approvedRepository,
  [StringComparison]::OrdinalIgnoreCase
)) {
  throw "The candidate launcher repository is not the exact approved repository."
}
$contract = Get-RisePalsCandidateContract -RepositoryRoot $repository
$git = Get-RisePalsCandidateGitExecutable
$safe = "safe.directory=C:/Codex PC SG2/Jeff/risepals"
$head = (& $git -c $safe -C $repository rev-parse HEAD).Trim()
$branch = (& $git -c $safe -C $repository branch --show-current).Trim()
$mainHead = (& $git -c $safe -C $repository rev-parse main).Trim()
$status = @(& $git -c $safe -C $repository status --porcelain --untracked-files=all)
$gitStatusExit = $LASTEXITCODE
$null = & $git -c $safe -C $repository check-ignore -q -- .env.local
$envIgnored = $LASTEXITCODE -eq 0
$envTracked = @(& $git -c $safe -C $repository ls-files -- .env.local).Count -ne 0
if ($gitStatusExit -ne 0 -or $head -ne $ExpectedRepositoryHead -or
  $branch -ne $contract.repository.branch -or $mainHead -ne $contract.repository.mainCommit -or
  $status.Count -ne 0 -or -not $envIgnored -or $envTracked) {
  throw "The exact clean candidate-rehearsal feature head is required."
}

$launcher = [IO.Path]::GetFullPath($PSCommandPath)
$bootstrap = Join-Path $PSScriptRoot "Invoke-RisePalsCandidateElevatedBootstrap.ps1"
$transport = Join-Path $PSScriptRoot "candidate-rehearsal-transport.ps1"
$child = Join-Path $PSScriptRoot "Invoke-RisePalsCandidateRehearsalChild.ps1"
$launcherHash = Get-RisePalsCandidateTransportSha256 -LiteralPath $launcher
$bootstrapHash = Get-RisePalsCandidateTransportSha256 -LiteralPath $bootstrap
$transportHash = Get-RisePalsCandidateTransportSha256 -LiteralPath $transport
$childHash = Get-RisePalsCandidateTransportSha256 -LiteralPath $child
$nonce = if ($Mode -eq "Simulation" -and
  -not [string]::IsNullOrWhiteSpace($SimulationInvocationNonce)) {
  $SimulationInvocationNonce
} else {
  [guid]::NewGuid().ToString("N")
}
if ($Mode -ne "Simulation" -and
  -not [string]::IsNullOrWhiteSpace($SimulationInvocationNonce)) {
  throw "A fixed invocation nonce is permitted only for an isolated simulation."
}
$plan = New-RisePalsCandidateInstallationPlan -Contract $contract -Nonce $nonce `
  -RepositoryHead $head -LauncherScriptSha256 $launcherHash
if ($Mode -eq "Plan") {
  $plan | ConvertTo-Json -Depth 8
  Write-Output "Rise Pals candidate rehearsal plan PASS; zero host mutation requested."
  return
}

$authorizationId = if ($Mode -eq "Simulation") {
  "RP-TURN-019-R4-DIAG1-SIMULATION"
} else {
  $FutureAuthorizationId
}
if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
  throw "Simulation and Live modes require an explicit durable evidence directory."
}
$durableEvidenceDirectory = Initialize-RisePalsCandidateEvidenceDirectory `
  -Path $EvidenceDirectory -Mode $Mode
$durableParentCheckpointPath = Get-RisePalsCandidateDurableParentCheckpointPath `
  -EvidenceDirectory $durableEvidenceDirectory -InvocationNonce $nonce
$durableParentResultPath = Get-RisePalsCandidateDurableParentResultPath `
  -EvidenceDirectory $durableEvidenceDirectory -InvocationNonce $nonce
$checkpointPathFresh = -not [IO.File]::Exists($durableParentCheckpointPath) -and
  -not [IO.File]::Exists($durableParentCheckpointPath + ".tmp")
$resultPathFresh = -not [IO.File]::Exists($durableParentResultPath) -and
  -not [IO.File]::Exists($durableParentResultPath + ".tmp")
$transientRoot = [IO.Path]::GetFullPath(
  (Join-Path ([IO.Path]::GetTempPath()) "risepals-candidate-launcher")
)
$invocationDirectory = Join-Path $transientRoot ("invocation-" + $nonce)
$resultPath = Join-Path $invocationDirectory "result.json"
$powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$startedAt = [DateTimeOffset]::UtcNow
$launchDisposition = "not-launched"
$processLaunched = $false
$processExitCode = -1
$directoryInitialized = $false
$evidenceInvalid = $false
$bootstrapStarted = $false
$bootstrapEntered = $false
$bootstrapFailurePresent = $false
$childLaunchAttempted = $false
$childStarted = $false
$liveStarted = $false
$finalPresent = $false
$finalValidated = $false
$finalStatus = $null
$returnCode = 86
$durableCheckpointValidated = $false
$authoritativeResultValidated = $false
$transientCleanupAttempted = $false
$transientCleanupCompleted = $false
$invocationDirectoryAbsent = $false
$remainingTransientRelativePaths = @()
$remainingTransientObjectCount = 0
$remainingTemporaryObjectCount = 0
$parentCheckpoint = $null

try {
  if (-not $resultPathFresh) {
    throw "The authoritative durable parent-result path is not fresh."
  }
  if (-not $checkpointPathFresh) {
    $launchDisposition = "launch-failure"
    $evidenceInvalid = $true
  } else {
  if (-not [IO.Directory]::Exists($transientRoot)) {
    [IO.Directory]::CreateDirectory($transientRoot) | Out-Null
  }
  $rootItem = Get-Item -LiteralPath $transientRoot -Force
  if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
    -not [string]::IsNullOrWhiteSpace([string]$rootItem.LinkType) -or
    [IO.Directory]::Exists($invocationDirectory) -or [IO.File]::Exists($invocationDirectory)) {
    throw "The candidate result root is linked or the invocation directory is not fresh."
  }
  [IO.Directory]::CreateDirectory($invocationDirectory) | Out-Null
  Protect-RisePalsCandidateInvocationDirectory -Path $invocationDirectory
  [void](Assert-RisePalsCandidateInvocationDirectory -Path $invocationDirectory `
    -ExpectedRoot $transientRoot -InvocationNonce $nonce)
  $directoryInitialized = $true

  $shouldLaunch = $true
  if ($Mode -eq "Live" -and (
    $authorizationId -notmatch "^RP-TURN-019-R4-LIVE-[A-F0-9]{8}$" -or
    -not $PSCmdlet.ShouldProcess(
      $script:RisePalsCandidateServiceName,
      "Launch the separately authorized candidate rehearsal bootstrap"
    )
  )) {
    $shouldLaunch = $false
  }
  if ($Mode -eq "Simulation" -and -not $PSCmdlet.ShouldProcess(
    $invocationDirectory,
    "Run the non-elevated candidate transport simulation"
  )) {
    $shouldLaunch = $false
  }

  if ($shouldLaunch) {
    $arguments = @(
      "-NoLogo",
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      (ConvertTo-RisePalsCandidateProcessArgument -Value $bootstrap),
      "-Mode",
      $Mode,
      "-SimulationScenario",
      $SimulationScenario,
      "-RepositoryRoot",
      (ConvertTo-RisePalsCandidateProcessArgument -Value $repository),
      "-RepositoryHead",
      $head,
      "-AuthorizationId",
      $authorizationId,
      "-InvocationNonce",
      $nonce,
      "-ResultRoot",
      (ConvertTo-RisePalsCandidateProcessArgument -Value $transientRoot),
      "-InvocationDirectory",
      (ConvertTo-RisePalsCandidateProcessArgument -Value $invocationDirectory),
      "-LauncherScriptPath",
      (ConvertTo-RisePalsCandidateProcessArgument -Value $launcher),
      "-LauncherScriptSha256",
      $launcherHash,
      "-BootstrapScriptSha256",
      $bootstrapHash,
      "-TransportScriptPath",
      (ConvertTo-RisePalsCandidateProcessArgument -Value $transport),
      "-TransportScriptSha256",
      $transportHash,
      "-ChildScriptPath",
      (ConvertTo-RisePalsCandidateProcessArgument -Value $child),
      "-ChildScriptSha256",
      $childHash,
      "-FutureAuthorizationId",
      (ConvertTo-RisePalsCandidateProcessArgument -Value $FutureAuthorizationId),
      "-CandidateExecutableSource",
      (ConvertTo-RisePalsCandidateProcessArgument -Value $CandidateExecutableSource),
      "-NodeExecutableSource",
      (ConvertTo-RisePalsCandidateProcessArgument -Value $NodeExecutableSource)
    )
    $start = @{
      FilePath = $powerShell
      ArgumentList = $arguments
      WindowStyle = "Hidden"
      Wait = $true
      PassThru = $true
    }
    if ($Mode -eq "Live") {
      $start.Verb = "RunAs"
    }
    try {
      $process = Start-Process @start
      $processLaunched = $true
      $launchDisposition = "launched"
      $processExitCode = [int]$process.ExitCode
    } catch {
      $nativeCode = 0
      if ($_.Exception.PSObject.Properties.Name -contains "NativeErrorCode") {
        $nativeCode = [int]$_.Exception.NativeErrorCode
      }
      $launchDisposition = if ($nativeCode -eq 1223) { "cancelled" } else { "launch-failure" }
    }
  }

  $consumedMarkers = @{}
  $markerTimes = @{}
  foreach ($markerType in @(
    "bootstrap-started",
    "child-launch-attempted",
    "child-started",
    "live-started"
  )) {
    $markerPath = Join-Path $invocationDirectory ($markerType + ".json")
    if ([IO.File]::Exists($markerPath)) {
      try {
        $marker = Read-RisePalsCandidateTransportJson -Path $markerPath `
          -InvocationDirectory $invocationDirectory -ExpectedName ($markerType + ".json")
        [void](Assert-RisePalsCandidateMarker -Marker $marker -ExpectedType $markerType `
          -ExpectedNonce $nonce -ExpectedAuthorizationId $authorizationId `
          -ExpectedHead $head -ExpectedLauncherScriptSha256 $launcherHash `
          -ExpectedBootstrapScriptSha256 $bootstrapHash `
          -ExpectedTransportScriptSha256 $transportHash `
          -ExpectedChildScriptSha256 $childHash -InvocationStartedAtUtc $startedAt `
          -ConsumedMarkers $consumedMarkers)
        $markerTimes[$markerType] = ConvertFrom-RisePalsCandidateUtc `
          -Value ([string]$marker.recordedAtUtc)
        switch ($markerType) {
          "bootstrap-started" { $bootstrapStarted = $true }
          "child-launch-attempted" { $childLaunchAttempted = $true }
          "child-started" { $childStarted = $true }
          "live-started" { $liveStarted = $true }
        }
      } catch {
        $evidenceInvalid = $true
      }
    }
  }
  $failureMarkerPath = Join-Path $invocationDirectory "bootstrap-failure.json"
  if ([IO.File]::Exists($failureMarkerPath)) {
    $bootstrapFailurePresent = $true
    try {
      $failureMarker = Read-RisePalsCandidateTransportJson -Path $failureMarkerPath `
        -InvocationDirectory $invocationDirectory -ExpectedName "bootstrap-failure.json"
      [void](Assert-RisePalsCandidateMarker -Marker $failureMarker `
        -ExpectedType "bootstrap-failure" -ExpectedNonce $nonce `
        -ExpectedAuthorizationId $authorizationId -ExpectedHead $head `
        -ExpectedLauncherScriptSha256 $launcherHash `
        -ExpectedBootstrapScriptSha256 $bootstrapHash `
        -ExpectedTransportScriptSha256 $transportHash `
        -ExpectedChildScriptSha256 $childHash -InvocationStartedAtUtc $startedAt `
        -ConsumedMarkers $consumedMarkers)
      $bootstrapEntered = $true
      $markerTimes["bootstrap-failure"] = ConvertFrom-RisePalsCandidateUtc `
        -Value ([string]$failureMarker.recordedAtUtc)
    } catch {
      $evidenceInvalid = $true
    }
  }
  if ($bootstrapStarted) {
    $bootstrapEntered = $true
  }
  try {
    [void](Assert-RisePalsCandidateMarkerOrdering -MarkerTimes $markerTimes)
  } catch {
    $evidenceInvalid = $true
  }

  $finalPresent = [IO.File]::Exists($resultPath)
  if ($finalPresent -and $bootstrapFailurePresent) {
    $evidenceInvalid = $true
  }
  if ($finalPresent) {
    try {
      $validated = Read-RisePalsCandidateTransportJson -Path $resultPath `
        -InvocationDirectory $invocationDirectory -ExpectedName "result.json"
      [void](Assert-RisePalsCandidateResult -Result $validated -ExpectedNonce $nonce `
        -ExpectedAuthorizationId $authorizationId -ExpectedHead $head `
        -ExpectedLauncherScriptSha256 $launcherHash `
        -ExpectedBootstrapScriptSha256 $bootstrapHash `
        -ExpectedTransportScriptSha256 $transportHash `
        -ExpectedChildScriptSha256 $childHash -ObservedExitCode $processExitCode `
        -InvocationStartedAtUtc $startedAt -ConsumedNonces @{})
      $finalValidated = $true
      $finalStatus = [string]$validated.status
    } catch {
      $evidenceInvalid = $true
    }
  }
  $preParentAllowed = @(
    "bootstrap-started.json",
    "child-launch-attempted.json",
    "child-started.json",
    "live-started.json",
    "bootstrap-failure.json",
    "result.json"
  )
  if (@(Get-ChildItem -LiteralPath $invocationDirectory -Force | Where-Object {
    $_.PSIsContainer -or $_.Name -notin $preParentAllowed
  }).Count -ne 0) {
    $evidenceInvalid = $true
  }
  }
} catch {
  if ($launchDisposition -eq "not-launched") {
    $launchDisposition = "launch-failure"
  }
  $evidenceInvalid = $true
}

$classification = Resolve-RisePalsCandidateParentClassification `
  -LaunchDisposition $launchDisposition -BootstrapEntered $bootstrapEntered `
  -ChildLaunchAttempted $childLaunchAttempted -ChildStarted $childStarted `
  -LiveStarted $liveStarted -FinalPresent $finalPresent `
  -FinalValidated $finalValidated -EvidenceInvalid $evidenceInvalid -FinalStatus $finalStatus
$parentCheckpoint = New-RisePalsCandidateParentCheckpoint -InvocationNonce $nonce `
  -AuthorizationId $authorizationId -RepositoryHead $head `
  -LauncherScriptSha256 $launcherHash -BootstrapScriptSha256 $bootstrapHash `
  -TransportScriptSha256 $transportHash -ChildScriptSha256 $childHash `
  -LaunchDisposition $launchDisposition -Classification $classification `
  -ProcessLaunched $processLaunched -ElevatedExitCode $processExitCode `
  -BootstrapEntered $bootstrapEntered -BootstrapStarted $bootstrapStarted `
  -BootstrapFailurePresent $bootstrapFailurePresent `
  -ChildLaunchAttempted $childLaunchAttempted -ChildStarted $childStarted `
  -LiveStarted $liveStarted -FinalPresent $finalPresent `
  -FinalValidated $finalValidated -FinalStatus $finalStatus

if ($checkpointPathFresh -and $resultPathFresh) {
  try {
    [void](Assert-RisePalsCandidateParentCheckpoint -Checkpoint $parentCheckpoint `
      -ExpectedNonce $nonce -ExpectedAuthorizationId $authorizationId `
      -ExpectedHead $head -ExpectedLauncherScriptSha256 $launcherHash `
      -ExpectedBootstrapScriptSha256 $bootstrapHash `
      -ExpectedTransportScriptSha256 $transportHash `
      -ExpectedChildScriptSha256 $childHash -InvocationStartedAtUtc $startedAt `
      -ConsumedNonces @{})
    if ($Mode -eq "Simulation" -and
      $SimulationScenario -eq "CheckpointWriteInterruption") {
      [IO.File]::WriteAllText(
        $durableParentCheckpointPath + ".tmp",
        '{"schemaVersion":"interrupted-checkpoint"}',
        [Text.UTF8Encoding]::new($false)
      )
    }
    $writtenCheckpointPath = Write-RisePalsCandidateDurableParentCheckpointAtomic `
      -Checkpoint $parentCheckpoint -EvidenceDirectory $durableEvidenceDirectory -Mode $Mode
    $reopenedCheckpoint = Read-RisePalsCandidateDurableParentCheckpoint `
      -Path $writtenCheckpointPath -EvidenceDirectory $durableEvidenceDirectory `
      -InvocationNonce $nonce -Mode $Mode
    [void](Assert-RisePalsCandidateParentCheckpoint -Checkpoint $reopenedCheckpoint `
      -ExpectedNonce $nonce -ExpectedAuthorizationId $authorizationId `
      -ExpectedHead $head -ExpectedLauncherScriptSha256 $launcherHash `
      -ExpectedBootstrapScriptSha256 $bootstrapHash `
      -ExpectedTransportScriptSha256 $transportHash `
      -ExpectedChildScriptSha256 $childHash -InvocationStartedAtUtc $startedAt `
      -ConsumedNonces @{})
    $parentCheckpoint = $reopenedCheckpoint
    $durableCheckpointValidated = $true
  } catch {
    $durableCheckpointValidated = $false
    $returnCode = 86
  }
}

if ($durableCheckpointValidated -and $directoryInitialized) {
  $transientCleanupAttempted = $true
  $allowedNames = @(
    "bootstrap-started.json",
    "bootstrap-started.json.tmp",
    "child-launch-attempted.json",
    "child-launch-attempted.json.tmp",
    "child-started.json",
    "child-started.json.tmp",
    "live-started.json",
    "live-started.json.tmp",
    "bootstrap-failure.json",
    "bootstrap-failure.json.tmp",
    "result.json",
    "result.tmp",
    "live-state.json",
    "stdout.log",
    "stderr.log"
  )
  try {
    if ($Mode -eq "Simulation" -and
      $SimulationScenario -eq "TransientCleanupFailure") {
      [IO.Directory]::CreateDirectory(
        (Join-Path $invocationDirectory "simulated-cleanup-residue")
      ) | Out-Null
    }
    $children = @(Get-ChildItem -LiteralPath $invocationDirectory -Force)
    if (@($children | Where-Object {
      $_.PSIsContainer -or $_.Name -notin $allowedNames -or
      ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
    }).Count -ne 0) {
      throw "The transient invocation contains an unexpected cleanup object."
    }
    foreach ($item in $children) {
      if (-not $item.PSIsContainer) {
        [IO.File]::Delete($item.FullName)
      }
    }
    if (@(Get-ChildItem -LiteralPath $invocationDirectory -Force).Count -eq 0) {
      [IO.Directory]::Delete($invocationDirectory, $false)
    }
    if ([IO.Directory]::Exists($transientRoot) -and
      @(Get-ChildItem -LiteralPath $transientRoot -Force).Count -eq 0) {
      [IO.Directory]::Delete($transientRoot, $false)
    }
    $transientCleanupCompleted = -not [IO.Directory]::Exists($invocationDirectory)
  } catch {
    $transientCleanupCompleted = $false
    $returnCode = 86
  }
}

$invocationDirectoryAbsent = -not [IO.Directory]::Exists($invocationDirectory) -and
  -not [IO.File]::Exists($invocationDirectory)
if (-not $invocationDirectoryAbsent) {
  try {
    $remainingItems = @(Get-ChildItem -LiteralPath $invocationDirectory -Force)
    $remainingTransientRelativePaths = @($remainingItems | ForEach-Object {
      if ($_.Name -match "^[a-z0-9][a-z0-9.-]{0,127}$" -and
        -not $_.Name.Contains("..")) {
        $_.Name
      } else {
        "unexpected-object"
      }
    } | Sort-Object -Unique)
    $remainingTransientObjectCount = $remainingItems.Count
    $remainingTemporaryObjectCount = @($remainingItems | Where-Object {
      $_.Name.EndsWith(".tmp", [StringComparison]::OrdinalIgnoreCase)
    }).Count
  } catch {
    $remainingTransientRelativePaths = @("unreadable-residue")
    $remainingTransientObjectCount = 1
    $remainingTemporaryObjectCount = 0
  }
}

$checkpointFileName = [IO.Path]::GetFileName($durableParentCheckpointPath)
$checkpointDigest = if ($durableCheckpointValidated) {
  [string]$parentCheckpoint.checkpointDigest
} else {
  $null
}
$parentResult = New-RisePalsCandidateParentResult -Checkpoint $parentCheckpoint `
  -CheckpointFileName $checkpointFileName -CheckpointDigest $checkpointDigest `
  -DurableCheckpointValidated $durableCheckpointValidated `
  -TransientCleanupAttempted $transientCleanupAttempted `
  -TransientCleanupCompleted $transientCleanupCompleted `
  -InvocationDirectoryAbsent $invocationDirectoryAbsent `
  -RemainingTransientObjectCount $remainingTransientObjectCount `
  -RemainingTemporaryObjectCount $remainingTemporaryObjectCount `
  -RemainingTransientRelativePaths $remainingTransientRelativePaths

if ($resultPathFresh) {
  try {
    [void](Assert-RisePalsCandidateParentResult -Result $parentResult `
    -ExpectedNonce $nonce -ExpectedAuthorizationId $authorizationId `
    -ExpectedHead $head -ExpectedLauncherScriptSha256 $launcherHash `
    -ExpectedBootstrapScriptSha256 $bootstrapHash `
    -ExpectedTransportScriptSha256 $transportHash `
    -ExpectedChildScriptSha256 $childHash -ExpectedCheckpointFileName $checkpointFileName `
    -ExpectedCheckpointDigest $checkpointDigest -InvocationStartedAtUtc $startedAt `
    -ConsumedNonces @{})
    if ($Mode -eq "Simulation" -and
      $SimulationScenario -eq "FinalResultWriteInterruption") {
      [IO.File]::WriteAllText(
        $durableParentResultPath + ".tmp",
        '{"schemaVersion":"interrupted-final-result"}',
        [Text.UTF8Encoding]::new($false)
      )
    }
    $writtenResultPath = Write-RisePalsCandidateDurableParentResultAtomic `
      -Result $parentResult -EvidenceDirectory $durableEvidenceDirectory -Mode $Mode
    $reopenedResult = Read-RisePalsCandidateDurableParentResult -Path $writtenResultPath `
      -EvidenceDirectory $durableEvidenceDirectory -InvocationNonce $nonce -Mode $Mode
    [void](Assert-RisePalsCandidateParentResult -Result $reopenedResult `
      -ExpectedNonce $nonce -ExpectedAuthorizationId $authorizationId `
      -ExpectedHead $head -ExpectedLauncherScriptSha256 $launcherHash `
      -ExpectedBootstrapScriptSha256 $bootstrapHash `
      -ExpectedTransportScriptSha256 $transportHash `
      -ExpectedChildScriptSha256 $childHash -ExpectedCheckpointFileName $checkpointFileName `
      -ExpectedCheckpointDigest $checkpointDigest -InvocationStartedAtUtc $startedAt `
      -ConsumedNonces @{})
    $parentResult = $reopenedResult
    $authoritativeResultValidated = $true
  } catch {
    $authoritativeResultValidated = $false
    $returnCode = 86
  }
}

if ($authoritativeResultValidated -and $parentResult.overallStatus -eq "success") {
  $returnCode = 0
}

$summary = [ordered]@{
  checkpointPath = if ($durableCheckpointValidated) { $durableParentCheckpointPath } else { $null }
  resultPath = if ($authoritativeResultValidated) { $durableParentResultPath } else { $null }
  status = if ($authoritativeResultValidated) { $parentResult.overallStatus } else { "failure" }
  durableCheckpointValidated = $durableCheckpointValidated
  authoritativeResultValidated = $authoritativeResultValidated
  transientCleanupCompleted = $transientCleanupCompleted
}
Write-Output ("RISE_PALS_CANDIDATE_PARENT_SUMMARY=" +
  ($summary | ConvertTo-Json -Depth 4 -Compress))

exit $returnCode
