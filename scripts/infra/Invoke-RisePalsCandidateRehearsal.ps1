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
    "CleanupFailure"
  )][string]$SimulationScenario = "SuccessWithInformationalStderr",
  [string]$RepositoryRoot = "",
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
  param([Parameter(Mandatory = $true)][string]$Value)

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
$evidenceRoot = [IO.Path]::GetFullPath(
  (Join-Path ([IO.Path]::GetTempPath()) "risepals-candidate-launcher")
)
$invocationDirectory = Join-Path $evidenceRoot ("invocation-" + $nonce)
$resultPath = Join-Path $invocationDirectory "result.json"
$parentResultPath = Join-Path $invocationDirectory "parent-result.json"
$parentTemporaryPath = Join-Path $invocationDirectory "parent-result.json.tmp"
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
$childStarted = $false
$liveStarted = $false
$finalPresent = $false
$finalValidated = $false
$finalStatus = $null
$returnCode = 86

try {
  if (-not [IO.Directory]::Exists($evidenceRoot)) {
    [IO.Directory]::CreateDirectory($evidenceRoot) | Out-Null
  }
  $rootItem = Get-Item -LiteralPath $evidenceRoot -Force
  if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
    -not [string]::IsNullOrWhiteSpace([string]$rootItem.LinkType) -or
    [IO.Directory]::Exists($invocationDirectory) -or [IO.File]::Exists($invocationDirectory)) {
    throw "The candidate result root is linked or the invocation directory is not fresh."
  }
  [IO.Directory]::CreateDirectory($invocationDirectory) | Out-Null
  Protect-RisePalsCandidateInvocationDirectory -Path $invocationDirectory
  [void](Assert-RisePalsCandidateInvocationDirectory -Path $invocationDirectory `
    -ExpectedRoot $evidenceRoot -InvocationNonce $nonce)
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
      (ConvertTo-RisePalsCandidateProcessArgument -Value $evidenceRoot),
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
  $markerTimes = @()
  foreach ($markerType in @("bootstrap-started", "child-started", "live-started")) {
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
        $markerTimes += ConvertFrom-RisePalsCandidateUtc -Value ([string]$marker.recordedAtUtc)
        switch ($markerType) {
          "bootstrap-started" { $bootstrapStarted = $true }
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
    } catch {
      $evidenceInvalid = $true
    }
  }
  if ($bootstrapStarted) {
    $bootstrapEntered = $true
  }
  for ($index = 1; $index -lt $markerTimes.Count; $index++) {
    if ($markerTimes[$index] -lt $markerTimes[$index - 1]) {
      $evidenceInvalid = $true
    }
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
  -ChildStarted $childStarted -LiveStarted $liveStarted -FinalPresent $finalPresent `
  -FinalValidated $finalValidated -EvidenceInvalid $evidenceInvalid -FinalStatus $finalStatus
$parentResult = New-RisePalsCandidateParentResult -InvocationNonce $nonce `
  -AuthorizationId $authorizationId -RepositoryHead $head `
  -LauncherScriptSha256 $launcherHash -Classification $classification `
  -ProcessLaunched $processLaunched -ElevatedExitCode $processExitCode `
  -BootstrapStarted $bootstrapStarted -ChildStarted $childStarted `
  -LiveStarted $liveStarted -FinalValidated $finalValidated -FinalStatus $finalStatus
[void](Assert-RisePalsCandidateParentResult -Result $parentResult)
if ($directoryInitialized) {
  try {
    Write-RisePalsCandidateJsonAtomic -Value $parentResult -ResultPath $parentResultPath `
      -TemporaryPath $parentTemporaryPath
  } catch {
    $returnCode = 86
  }
}
if ($parentResult.status -eq "success") {
  $returnCode = 0
}

Write-Output (
  "RISE_PALS_CANDIDATE_PARENT_RESULT=" +
    ($parentResult | ConvertTo-Json -Depth 7 -Compress)
)

if ($directoryInitialized) {
  $allowedNames = @(
    "bootstrap-started.json",
    "bootstrap-started.json.tmp",
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
    "stderr.log",
    "parent-result.json",
    "parent-result.json.tmp"
  )
  $children = @(Get-ChildItem -LiteralPath $invocationDirectory -Force)
  if (@($children | Where-Object { $_.Name -notin $allowedNames }).Count -ne 0) {
    $returnCode = 86
  } else {
    foreach ($item in $children) {
      if (-not $item.PSIsContainer -and
        ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
        [IO.File]::Delete($item.FullName)
      }
    }
    if (@(Get-ChildItem -LiteralPath $invocationDirectory -Force).Count -eq 0) {
      [IO.Directory]::Delete($invocationDirectory, $false)
    }
    if ([IO.Directory]::Exists($evidenceRoot) -and
      @(Get-ChildItem -LiteralPath $evidenceRoot -Force).Count -eq 0) {
      [IO.Directory]::Delete($evidenceRoot, $false)
    }
  }
}

exit $returnCode
