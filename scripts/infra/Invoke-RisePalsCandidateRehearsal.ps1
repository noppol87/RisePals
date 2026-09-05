[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$ExpectedRepositoryHead,
  [ValidateSet(
    "Plan", "Simulation", "Live", "ElevationProbe"
  )][string]$Mode = "Plan",
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
$rehearsalChild = Join-Path $PSScriptRoot "Invoke-RisePalsCandidateRehearsalChild.ps1"
$probeChild = Join-Path $PSScriptRoot "Invoke-RisePalsCandidateElevationProbeChild.ps1"
$child = if ($Mode -eq "ElevationProbe") { $probeChild } else { $rehearsalChild }
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
  "RP-TURN-019-R4-DIAG2-SIMULATION"
} else {
  $FutureAuthorizationId
}
[void](Assert-RisePalsCandidateModeAuthorization -ExecutionMode $Mode `
  -AuthorizationId $authorizationId)
if ($Mode -eq "ElevationProbe" -and (
    -not [string]::IsNullOrWhiteSpace($CandidateExecutableSource) -or
    -not [string]::IsNullOrWhiteSpace($NodeExecutableSource)
  )) {
  throw "ElevationProbe cannot receive candidate or Node executable sources."
}
if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
  throw "Simulation, Live, and ElevationProbe modes require an explicit durable evidence directory."
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
$resultName = if ($Mode -eq "ElevationProbe") { "probe-result.json" } else { "result.json" }
$resultPath = Join-Path $invocationDirectory $resultName
$powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$launchVerb = if ($Mode -in @("Live", "ElevationProbe")) { "RunAs" } else { "None" }
$launcherExecutableExists = [IO.File]::Exists($powerShell)
$launcherSignatureStatus = Get-RisePalsCandidateLauncherSignatureStatus `
  -LiteralPath $powerShell
$emptyArgumentDigest = Get-RisePalsCandidateCanonicalArgumentDigest -Arguments @()
$launchDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
  -LaunchAttempted $false -ProcessCreated $false `
  -LaunchDisposition "not-launched" -SanitizedLaunchFailureCode "none" `
  -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
  -LauncherExecutableExists $launcherExecutableExists `
  -LauncherSignatureStatus $launcherSignatureStatus -LaunchVerb $launchVerb `
  -ArgumentCount 0 -CanonicalArgumentDigest $emptyArgumentDigest
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
$childDiagnostic = $null
$probeDiagnostic = $null

try {
  if (-not $resultPathFresh) {
    throw "The authoritative durable parent-result path is not fresh."
  }
  if (-not $checkpointPathFresh) {
    $launchDisposition = "launch-failure"
    $launchDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
      -LaunchAttempted $false -ProcessCreated $false `
      -LaunchDisposition $launchDisposition `
      -SanitizedLaunchFailureCode "malformed-launch-request" `
      -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
      -LauncherExecutableExists $launcherExecutableExists `
      -LauncherSignatureStatus $launcherSignatureStatus -LaunchVerb $launchVerb `
      -ArgumentCount 0 -CanonicalArgumentDigest $emptyArgumentDigest
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
  if ($Mode -in @("Live", "ElevationProbe")) {
    $launchTarget = if ($Mode -eq "Live") {
      $script:RisePalsCandidateServiceName
    } else {
      "Windows PowerShell elevation boundary"
    }
    $launchAction = if ($Mode -eq "Live") {
      "Launch the separately authorized candidate rehearsal bootstrap"
    } else {
      "Launch the separately authorized non-mutating elevation probe"
    }
    if (-not $PSCmdlet.ShouldProcess($launchTarget, $launchAction)) {
      $shouldLaunch = $false
    }
  }
  if ($Mode -eq "Simulation" -and -not $PSCmdlet.ShouldProcess(
    $invocationDirectory,
    "Run the non-elevated candidate transport simulation"
  )) {
    $shouldLaunch = $false
  }

  if ($shouldLaunch) {
    $launchRequest = New-RisePalsCandidateCanonicalLaunchRequest `
      -ExecutionMode $Mode -SimulationScenario $SimulationScenario `
      -RepositoryRoot $repository -RepositoryHead $head `
      -AuthorizationId $authorizationId -InvocationNonce $nonce `
      -ResultRoot $transientRoot -InvocationDirectory $invocationDirectory `
      -LauncherScriptPath $launcher -LauncherScriptSha256 $launcherHash `
      -BootstrapScriptPath $bootstrap -BootstrapScriptSha256 $bootstrapHash `
      -TransportScriptPath $transport -TransportScriptSha256 $transportHash `
      -ChildScriptPath $child -ChildScriptSha256 $childHash `
      -CandidateExecutableSource $CandidateExecutableSource `
      -NodeExecutableSource $NodeExecutableSource
    $arguments = @($launchRequest.arguments)
    $argumentDigest = [string]$launchRequest.canonicalArgumentDigest
    $start = @{
      FilePath = [string]$launchRequest.filePath
      ArgumentList = $arguments
      WindowStyle = [string]$launchRequest.windowStyle
      Wait = [bool]$launchRequest.waitRequested
      PassThru = [bool]$launchRequest.passThruRequested
    }
    if ($launchRequest.verb -eq "RunAs") {
      $start.Verb = [string]$launchRequest.verb
    }
      if (-not $launcherExecutableExists) {
        $launchDisposition = "launch-failure"
        $launchDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
          -LaunchAttempted $false -ProcessCreated $false `
          -LaunchDisposition $launchDisposition `
          -SanitizedLaunchFailureCode "launcher-target-not-found" `
          -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
          -LauncherExecutableExists $false `
          -LauncherSignatureStatus $launcherSignatureStatus -LaunchVerb $launchVerb `
          -ArgumentCount $arguments.Count -CanonicalArgumentDigest $argumentDigest
      } elseif ($launcherSignatureStatus -ne "valid") {
        $launchDisposition = "launch-failure"
        $preflightFailureCode = if ($launcherSignatureStatus -eq "unavailable") {
          "launcher-access-denied"
        } else {
          "shell-execute-failed"
        }
        $launchDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
          -LaunchAttempted $false -ProcessCreated $false `
          -LaunchDisposition $launchDisposition `
          -SanitizedLaunchFailureCode $preflightFailureCode `
          -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
          -LauncherExecutableExists $true `
          -LauncherSignatureStatus $launcherSignatureStatus -LaunchVerb $launchVerb `
          -ArgumentCount $arguments.Count -CanonicalArgumentDigest $argumentDigest
      } else {
        try {
          $process = Start-Process @start
          if ($null -eq $process -or $process -isnot [Diagnostics.Process]) {
            $launchDisposition = "launch-failure"
            $launchDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
              -LaunchAttempted $true -ProcessCreated $false `
              -LaunchDisposition $launchDisposition `
              -SanitizedLaunchFailureCode "process-start-failed" `
              -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
              -LauncherExecutableExists $true `
              -LauncherSignatureStatus $launcherSignatureStatus -LaunchVerb $launchVerb `
              -ArgumentCount $arguments.Count -CanonicalArgumentDigest $argumentDigest
          } else {
            $processLaunched = $true
            $launchDisposition = "launched"
            $processExitCode = [int]$process.ExitCode
            $launchDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
              -LaunchAttempted $true -ProcessCreated $true `
              -LaunchDisposition $launchDisposition `
              -SanitizedLaunchFailureCode "none" `
              -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
              -LauncherExecutableExists $true `
              -LauncherSignatureStatus $launcherSignatureStatus -LaunchVerb $launchVerb `
              -ArgumentCount $arguments.Count -CanonicalArgumentDigest $argumentDigest
          }
        } catch {
          $exceptionEvidence = Get-RisePalsCandidateLaunchExceptionEvidence `
            -ErrorRecord $_
          $failureCode = Get-RisePalsCandidateSanitizedLaunchFailureCode `
            -NativeErrorCode $exceptionEvidence.nativeErrorCode
          $launchDisposition = if ($exceptionEvidence.nativeErrorCode -eq 1223) {
            "cancelled"
          } else {
            "launch-failure"
          }
          $launchDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
            -LaunchAttempted $true -ProcessCreated $false `
            -LaunchDisposition $launchDisposition `
            -SanitizedLaunchFailureCode $failureCode `
            -NativeErrorCode $exceptionEvidence.nativeErrorCode `
            -HResult $exceptionEvidence.hResult `
            -ExceptionDepth $exceptionEvidence.exceptionDepth `
            -Provenance $exceptionEvidence.provenance `
            -LauncherExecutableExists $true `
            -LauncherSignatureStatus $launcherSignatureStatus -LaunchVerb $launchVerb `
            -ArgumentCount $arguments.Count -CanonicalArgumentDigest $argumentDigest
        }
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
        -InvocationDirectory $invocationDirectory -ExpectedName $resultName
      if ($Mode -eq "ElevationProbe") {
        [void](Assert-RisePalsCandidateProbeDiagnostic -Diagnostic $validated)
        if (($validated.probeStatus -eq "success" -and $processExitCode -ne 0) -or
          ($validated.probeStatus -eq "failure" -and $processExitCode -eq 0)) {
          throw "The probe diagnostic disagrees with the elevated child exit code."
        }
        $probeDiagnostic = $validated
        $finalStatus = [string]$validated.probeStatus
        $childDiagnostic = New-RisePalsCandidateChildDiagnostic -Result $null `
          -ExecutionMode ElevationProbe `
          -CleanupResponsibilityTransferredToParent $true
      } else {
        [void](Assert-RisePalsCandidateResult -Result $validated -ExpectedNonce $nonce `
          -ExpectedAuthorizationId $authorizationId -ExpectedHead $head `
          -ExpectedLauncherScriptSha256 $launcherHash `
          -ExpectedBootstrapScriptSha256 $bootstrapHash `
          -ExpectedTransportScriptSha256 $transportHash `
          -ExpectedChildScriptSha256 $childHash -ObservedExitCode $processExitCode `
          -InvocationStartedAtUtc $startedAt -ConsumedNonces @{})
        $finalStatus = [string]$validated.status
        $childDiagnostic = New-RisePalsCandidateChildDiagnostic -Result $validated `
          -ExecutionMode $Mode -CleanupResponsibilityTransferredToParent $true
      }
      $finalValidated = $true
      [void](Assert-RisePalsCandidateChildDiagnostic -Diagnostic $childDiagnostic)
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
    "result.json",
    "probe-result.json"
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
    $launchDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
      -LaunchAttempted $false -ProcessCreated $false `
      -LaunchDisposition $launchDisposition `
      -SanitizedLaunchFailureCode "malformed-launch-request" `
      -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
      -LauncherExecutableExists $launcherExecutableExists `
      -LauncherSignatureStatus $launcherSignatureStatus -LaunchVerb $launchVerb `
      -ArgumentCount 0 -CanonicalArgumentDigest $emptyArgumentDigest
  }
  $evidenceInvalid = $true
}

if ($null -eq $childDiagnostic) {
  $childDiagnostic = New-RisePalsCandidateChildDiagnostic -Result $null `
    -ExecutionMode $Mode `
    -CleanupResponsibilityTransferredToParent $directoryInitialized
  [void](Assert-RisePalsCandidateChildDiagnostic -Diagnostic $childDiagnostic)
}

$classification = Resolve-RisePalsCandidateParentClassification `
  -ExecutionMode $Mode -LaunchDisposition $launchDisposition `
  -BootstrapEntered $bootstrapEntered `
  -ChildLaunchAttempted $childLaunchAttempted -ChildStarted $childStarted `
  -LiveStarted $liveStarted -FinalPresent $finalPresent `
  -FinalValidated $finalValidated -EvidenceInvalid $evidenceInvalid `
  -FinalStatus $finalStatus -ProbeDiagnostic $probeDiagnostic
$parentCheckpoint = New-RisePalsCandidateParentCheckpoint -InvocationNonce $nonce `
  -AuthorizationId $authorizationId -RepositoryHead $head `
  -LauncherScriptSha256 $launcherHash -BootstrapScriptSha256 $bootstrapHash `
  -TransportScriptSha256 $transportHash -ChildScriptSha256 $childHash `
  -ExecutionMode $Mode `
  -LaunchDisposition $launchDisposition -Classification $classification `
  -ProcessLaunched $processLaunched -ElevatedExitCode $processExitCode `
  -BootstrapEntered $bootstrapEntered -BootstrapStarted $bootstrapStarted `
  -BootstrapFailurePresent $bootstrapFailurePresent `
  -ChildLaunchAttempted $childLaunchAttempted -ChildStarted $childStarted `
  -LiveStarted $liveStarted -FinalPresent $finalPresent `
  -FinalValidated $finalValidated -FinalStatus $finalStatus `
  -ChildDiagnostic $childDiagnostic -LaunchDiagnostic $launchDiagnostic `
  -ProbeDiagnostic $probeDiagnostic

$probeDiagnosticDigest = if ($null -eq $probeDiagnostic) {
  $null
} else {
  [string]$probeDiagnostic.probeDigest
}

if ($checkpointPathFresh -and $resultPathFresh) {
  try {
    [void](Assert-RisePalsCandidateParentCheckpoint -Checkpoint $parentCheckpoint `
      -ExpectedNonce $nonce -ExpectedAuthorizationId $authorizationId `
      -ExpectedHead $head -ExpectedLauncherScriptSha256 $launcherHash `
      -ExpectedBootstrapScriptSha256 $bootstrapHash `
      -ExpectedTransportScriptSha256 $transportHash `
      -ExpectedChildScriptSha256 $childHash -ExpectedExecutionMode $Mode `
      -ExpectedLaunchDiagnosticDigest ([string]$launchDiagnostic.diagnosticDigest) `
      -ExpectedProbeDiagnosticDigest $probeDiagnosticDigest `
      -InvocationStartedAtUtc $startedAt `
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
      -ExpectedChildScriptSha256 $childHash -ExpectedExecutionMode $Mode `
      -ExpectedLaunchDiagnosticDigest ([string]$launchDiagnostic.diagnosticDigest) `
      -ExpectedProbeDiagnosticDigest $probeDiagnosticDigest `
      -InvocationStartedAtUtc $startedAt `
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
    "probe-result.json",
    "probe-result.tmp",
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
    -ExpectedCheckpointDigest $checkpointDigest `
    -ExpectedChildDiagnosticDigest ([string]$parentCheckpoint.childDiagnostic.diagnosticDigest) `
    -ExpectedLaunchDiagnosticDigest ([string]$parentCheckpoint.launchDiagnostic.diagnosticDigest) `
    -ExpectedProbeDiagnosticDigest $probeDiagnosticDigest `
    -ExpectedExecutionMode $Mode `
    -InvocationStartedAtUtc $startedAt `
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
      -ExpectedCheckpointDigest $checkpointDigest `
      -ExpectedChildDiagnosticDigest ([string]$parentCheckpoint.childDiagnostic.diagnosticDigest) `
      -ExpectedLaunchDiagnosticDigest ([string]$parentCheckpoint.launchDiagnostic.diagnosticDigest) `
      -ExpectedProbeDiagnosticDigest $probeDiagnosticDigest `
      -ExpectedExecutionMode $Mode `
      -InvocationStartedAtUtc $startedAt `
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
  childDiagnosticDigest = [string]$parentResult.childDiagnostic.diagnosticDigest
}
Write-Output ("RISE_PALS_CANDIDATE_PARENT_SUMMARY=" +
  ($summary | ConvertTo-Json -Depth 4 -Compress))

exit $returnCode
