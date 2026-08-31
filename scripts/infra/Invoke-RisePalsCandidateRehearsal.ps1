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
    "MissingFinalAfterLive"
  )][string]$SimulationScenario = "SuccessWithInformationalStderr",
  [string]$RepositoryRoot = "",
  [string]$EvidenceDirectory = "",
  [string]$FutureAuthorizationId = "",
  [string]$CandidateExecutableSource = "",
  [string]$NodeExecutableSource = ""
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
$nonce = [guid]::NewGuid().ToString("N")
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
$durableParentResultPath = Get-RisePalsCandidateDurableParentResultPath `
  -EvidenceDirectory $durableEvidenceDirectory -InvocationNonce $nonce
if ([IO.File]::Exists($durableParentResultPath) -or
  [IO.File]::Exists($durableParentResultPath + ".tmp")) {
  throw "The durable parent-result path is not fresh."
}
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
$durableResultValidated = $false
$transientCleanupCompleted = $false

try {
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
$parentResult = New-RisePalsCandidateParentResult -InvocationNonce $nonce `
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

try {
  [void](Assert-RisePalsCandidateParentResult -Result $parentResult `
    -ExpectedNonce $nonce -ExpectedAuthorizationId $authorizationId `
    -ExpectedHead $head -ExpectedLauncherScriptSha256 $launcherHash `
    -ExpectedBootstrapScriptSha256 $bootstrapHash `
    -ExpectedTransportScriptSha256 $transportHash `
    -ExpectedChildScriptSha256 $childHash -InvocationStartedAtUtc $startedAt `
    -ConsumedNonces @{})
  $writtenPath = Write-RisePalsCandidateDurableParentResultAtomic `
    -Result $parentResult -EvidenceDirectory $durableEvidenceDirectory -Mode $Mode
  $reopened = Read-RisePalsCandidateDurableParentResult -Path $writtenPath `
    -EvidenceDirectory $durableEvidenceDirectory -InvocationNonce $nonce -Mode $Mode
  [void](Assert-RisePalsCandidateParentResult -Result $reopened `
    -ExpectedNonce $nonce -ExpectedAuthorizationId $authorizationId `
    -ExpectedHead $head -ExpectedLauncherScriptSha256 $launcherHash `
    -ExpectedBootstrapScriptSha256 $bootstrapHash `
    -ExpectedTransportScriptSha256 $transportHash `
    -ExpectedChildScriptSha256 $childHash -InvocationStartedAtUtc $startedAt `
    -ConsumedNonces @{})
  $durableResultValidated = $true
} catch {
  $durableResultValidated = $false
  $returnCode = 86
}

if ($durableResultValidated -and $directoryInitialized) {
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

if ($durableResultValidated -and $transientCleanupCompleted -and
  $parentResult.status -eq "success") {
  $returnCode = 0
}

$summary = [ordered]@{
  durableResultPath = if ($durableResultValidated) { $durableParentResultPath } else { $null }
  durableResultDigest = if ($durableResultValidated) { $parentResult.resultDigest } else { $null }
  classification = $parentResult.classification
  status = if ($durableResultValidated -and $transientCleanupCompleted) {
    $parentResult.status
  } else {
    "failure"
  }
  durableResultValidated = $durableResultValidated
  transientCleanupCompleted = $transientCleanupCompleted
}
Write-Output ("RISE_PALS_CANDIDATE_PARENT_SUMMARY=" +
  ($summary | ConvertTo-Json -Depth 4 -Compress))

exit $returnCode
