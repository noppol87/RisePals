[CmdletBinding()]
param(
  [string]$RepositoryRoot = "C:\Codex PC SG2\Jeff\risepals",
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")]
  [string]$ExpectedRepositoryHead
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repository = [IO.Path]::GetFullPath($RepositoryRoot)
$approvedRepository = "C:\Codex PC SG2\Jeff\risepals"
if (-not $repository.TrimEnd([IO.Path]::DirectorySeparatorChar).Equals(
  $approvedRepository,
  [StringComparison]::OrdinalIgnoreCase
)) {
  throw "The process-boundary suite requires the exact approved repository."
}

$scripts = Join-Path $repository "scripts\infra"
. (Join-Path $scripts "candidate-rehearsal-result.ps1")
. (Join-Path $scripts "candidate-rehearsal-transport.ps1")
$parent = Join-Path $scripts "Invoke-RisePalsCandidateRehearsal.ps1"
$bootstrap = Join-Path $scripts "Invoke-RisePalsCandidateElevatedBootstrap.ps1"
$resultScript = Join-Path $scripts "candidate-rehearsal-result.ps1"
$transport = Join-Path $scripts "candidate-rehearsal-transport.ps1"
$child = Join-Path $scripts "Invoke-RisePalsCandidateRehearsalChild.ps1"
$probeChild = Join-Path $scripts "Invoke-RisePalsCandidateElevationProbeChild.ps1"
$probeFixture = Join-Path $repository `
  "tests\infra\fixtures\Invoke-RisePalsCandidateProbeTransportFixture.ps1"
$powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$git = "C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
$safe = "safe.directory=C:/Codex PC SG2/Jeff/risepals"
$authorizationId = "RP-TURN-019-R4-DIAG2-SIMULATION"
$transientRoot = [IO.Path]::GetFullPath(
  (Join-Path ([IO.Path]::GetTempPath()) "risepals-candidate-launcher")
)

function ConvertTo-RisePalsProcessSuiteArgument {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

  if ($Value.Contains('"')) {
    throw "A process-suite argument contains a prohibited quote."
  }
  return '"' + $Value + '"'
}

function Get-RisePalsProcessSuiteHostSnapshot {
  $services = @(Get-CimInstance Win32_Service -Filter "Name LIKE 'RisePals%'" |
    Select-Object Name, State, StartMode, ProcessId, PathName |
    Sort-Object Name)
  $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalPort -in @(80, 443, 2019, 3100, 8080, 8443) } |
    Select-Object LocalAddress, LocalPort, OwningProcess |
    Sort-Object LocalPort, LocalAddress, OwningProcess)
  $processes = @(Get-CimInstance Win32_Process |
    Where-Object {
      -not [string]::IsNullOrWhiteSpace([string]$_.ExecutablePath) -and
      [IO.Path]::GetFullPath([string]$_.ExecutablePath).StartsWith(
        "C:\RisePals\",
        [StringComparison]::OrdinalIgnoreCase
      )
    } | Select-Object ProcessId, ExecutablePath | Sort-Object ProcessId)
  return [pscustomobject][ordered]@{
    services = $services
    listeners = $listeners
    processesUnderRisePals = $processes
  }
}

function Assert-RisePalsProcessSuiteHostUnchanged {
  param(
    [Parameter(Mandatory = $true)][object]$Before,
    [Parameter(Mandatory = $true)][object]$After
  )

  if (($Before | ConvertTo-Json -Depth 8 -Compress) -ne
    ($After | ConvertTo-Json -Depth 8 -Compress) -or
    @($After.listeners).Count -ne 0 -or
    @($After.processesUnderRisePals).Count -ne 0) {
    throw "A process-boundary simulation changed the protected host snapshot."
  }
}

function Remove-RisePalsProcessSuiteTree {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedParent
  )

  $exact = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $parent = [IO.Path]::GetFullPath($ExpectedParent).TrimEnd(
    [IO.Path]::DirectorySeparatorChar
  )
  if (-not $exact.StartsWith(
    $parent + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
  )) {
    throw "A process-suite cleanup path escaped its exact task root."
  }
  if (-not [IO.Directory]::Exists($exact)) {
    return
  }
  $rootItem = Get-Item -LiteralPath $exact -Force
  if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
    -not [string]::IsNullOrWhiteSpace([string]$rootItem.LinkType)) {
    throw "A process-suite cleanup root is linked."
  }
  $items = @(Get-ChildItem -LiteralPath $exact -Force -Recurse)
  if (@($items | Where-Object {
    ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
    -not [string]::IsNullOrWhiteSpace([string]$_.LinkType)
  }).Count -ne 0) {
    throw "A process-suite cleanup tree contains a linked object."
  }
  foreach ($file in @($items | Where-Object { -not $_.PSIsContainer })) {
    [IO.File]::Delete($file.FullName)
  }
  foreach ($directory in @($items | Where-Object { $_.PSIsContainer } |
    Sort-Object { $_.FullName.Length } -Descending)) {
    [IO.Directory]::Delete($directory.FullName, $false)
  }
  [IO.Directory]::Delete($exact, $false)
}

function Assert-RisePalsProcessSuiteRepository {
  $head = (& $git -c $safe -C $repository rev-parse HEAD).Trim()
  $branch = (& $git -c $safe -C $repository branch --show-current).Trim()
  $main = (& $git -c $safe -C $repository rev-parse main).Trim()
  $status = @(& $git -c $safe -C $repository status --porcelain --untracked-files=all)
  $null = & $git -c $safe -C $repository check-ignore -q -- .env.local
  $ignored = $LASTEXITCODE -eq 0
  $tracked = @(& $git -c $safe -C $repository ls-files -- .env.local).Count -ne 0
  if ($head -ne $ExpectedRepositoryHead -or
    $branch -ne "agent/windows-vps-infrastructure-readiness" -or
    $main -ne "cd45e7356e902afbf3aafec0bdf8286dbccff7ad" -or
    $status.Count -ne 0 -or -not $ignored -or $tracked) {
    throw "The process-boundary suite requires the exact clean committed feature head."
  }
}

Assert-RisePalsProcessSuiteRepository
$launcherHash = Get-RisePalsCandidateTransportSha256 -LiteralPath $parent
$bootstrapHash = Get-RisePalsCandidateTransportSha256 -LiteralPath $bootstrap
$transportHash = Get-RisePalsCandidateTransportSha256 -LiteralPath $transport
$childHash = Get-RisePalsCandidateTransportSha256 -LiteralPath $child
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
  [IO.Path]::DirectorySeparatorChar
)
$taskRoot = Join-Path $tempRoot (
  "risepals-candidate-process-suite-" + [guid]::NewGuid().ToString("N")
)
[IO.Directory]::CreateDirectory($taskRoot) | Out-Null
$beforeHost = Get-RisePalsProcessSuiteHostSnapshot
$scenarioResults = @()
$invocationPaths = @()
$probeDirectory = $null

$scenarios = @(
  @{ Name = "success"; ParentScenario = "SuccessWithInformationalStderr"; Exit = 0; Checkpoint = $true; Result = $true; Cleanup = $true; Overall = "success" },
  @{ Name = "launch-failure"; ParentScenario = "ChildProcessLaunchFailure"; Exit = 86; Checkpoint = $true; Result = $true; Cleanup = $true; Overall = "failure" },
  @{ Name = "before-child-marker"; ParentScenario = "ChildExitsBeforeStartMarker"; Exit = 86; Checkpoint = $true; Result = $true; Cleanup = $true; Overall = "failure" },
  @{ Name = "before-live"; ParentScenario = "MissingResult"; Exit = 86; Checkpoint = $true; Result = $true; Cleanup = $true; Overall = "failure" },
  @{ Name = "live-without-final"; ParentScenario = "MissingFinalAfterLive"; Exit = 86; Checkpoint = $true; Result = $true; Cleanup = $true; Overall = "failure" },
  @{ Name = "invalid-final"; ParentScenario = "MalformedResult"; Exit = 86; Checkpoint = $true; Result = $true; Cleanup = $true; Overall = "failure" },
  @{ Name = "cleanup-failure"; ParentScenario = "TransientCleanupFailure"; Exit = 86; Checkpoint = $true; Result = $true; Cleanup = $false; Overall = "failure" },
  @{ Name = "checkpoint-interruption"; ParentScenario = "CheckpointWriteInterruption"; Exit = 86; Checkpoint = $false; Result = $true; Cleanup = $false; Overall = "failure" },
  @{ Name = "final-interruption"; ParentScenario = "FinalResultWriteInterruption"; Exit = 86; Checkpoint = $true; Result = $false; Cleanup = $true; Overall = "failure" },
  @{ Name = "preexisting-checkpoint"; ParentScenario = "SuccessWithInformationalStderr"; Exit = 86; Checkpoint = $false; Result = $true; Cleanup = $false; Overall = "failure"; Preexisting = $true }
)

try {
  foreach ($scenario in $scenarios) {
    $nonce = [guid]::NewGuid().ToString("N")
    $invocation = Join-Path $transientRoot ("invocation-" + $nonce)
    $invocationPaths += $invocation
    $evidence = Join-Path $taskRoot ([string]$scenario.Name)
    $directory = Initialize-RisePalsCandidateEvidenceDirectory `
      -Path $evidence -Mode Simulation
    $checkpointPath = Get-RisePalsCandidateDurableParentCheckpointPath `
      -EvidenceDirectory $directory -InvocationNonce $nonce
    $resultPath = Get-RisePalsCandidateDurableParentResultPath `
      -EvidenceDirectory $directory -InvocationNonce $nonce
    $preexistingBytes = $null
    if ($scenario.ContainsKey("Preexisting")) {
      $preexistingBytes = [Text.UTF8Encoding]::new($false).GetBytes("{}")
      [IO.File]::WriteAllBytes($checkpointPath, $preexistingBytes)
    }
    $startedAt = [DateTimeOffset]::UtcNow
    $arguments = @(
      "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
      (ConvertTo-RisePalsProcessSuiteArgument -Value $parent),
      "-ExpectedRepositoryHead", $ExpectedRepositoryHead,
      "-Mode", "Simulation",
      "-SimulationScenario", [string]$scenario.ParentScenario,
      "-RepositoryRoot", (ConvertTo-RisePalsProcessSuiteArgument -Value $repository),
      "-EvidenceDirectory", (ConvertTo-RisePalsProcessSuiteArgument -Value $directory),
      "-SimulationInvocationNonce", $nonce
    )
    $process = Start-Process -FilePath $powerShell -ArgumentList $arguments `
      -WindowStyle Hidden -Wait -PassThru
    if ([int]$process.ExitCode -ne [int]$scenario.Exit) {
      throw "Scenario $($scenario.Name) returned an unexpected parent exit code."
    }

    $checkpoint = $null
    if ([bool]$scenario.Checkpoint) {
      $checkpoint = Read-RisePalsCandidateDurableParentCheckpoint -Path $checkpointPath `
        -EvidenceDirectory $directory -InvocationNonce $nonce -Mode Simulation
      [void](Assert-RisePalsCandidateParentCheckpoint -Checkpoint $checkpoint `
        -ExpectedNonce $nonce -ExpectedAuthorizationId $authorizationId `
        -ExpectedHead $ExpectedRepositoryHead `
        -ExpectedLauncherScriptSha256 $launcherHash `
        -ExpectedBootstrapScriptSha256 $bootstrapHash `
        -ExpectedTransportScriptSha256 $transportHash `
        -ExpectedChildScriptSha256 $childHash `
        -ExpectedLaunchDiagnosticDigest ([string]$checkpoint.launchDiagnostic.diagnosticDigest) `
        -InvocationStartedAtUtc $startedAt `
        -ConsumedNonces @{})
    } elseif ($scenario.ContainsKey("Preexisting")) {
      if (-not [IO.File]::Exists($checkpointPath) -or
        -not [Linq.Enumerable]::SequenceEqual(
          [byte[]]$preexistingBytes,
          [byte[]][IO.File]::ReadAllBytes($checkpointPath)
        )) {
        throw "The pre-existing checkpoint was changed or replaced."
      }
    } elseif ([IO.File]::Exists($checkpointPath)) {
      throw "An interrupted checkpoint unexpectedly produced a final checkpoint."
    }

    if ([bool]$scenario.Result) {
      $result = Read-RisePalsCandidateDurableParentResult -Path $resultPath `
        -EvidenceDirectory $directory -InvocationNonce $nonce -Mode Simulation
      $expectedDigest = if ($null -ne $checkpoint) {
        [string]$checkpoint.checkpointDigest
      } else {
        $null
      }
      $expectedChildDiagnosticDigest = if ($null -ne $checkpoint) {
        [string]$checkpoint.childDiagnostic.diagnosticDigest
      } else {
        [string]$result.childDiagnostic.diagnosticDigest
      }
      $expectedLaunchDiagnosticDigest = if ($null -ne $checkpoint) {
        [string]$checkpoint.launchDiagnostic.diagnosticDigest
      } else {
        [string]$result.launchDiagnostic.diagnosticDigest
      }
      [void](Assert-RisePalsCandidateParentResult -Result $result `
        -ExpectedNonce $nonce -ExpectedAuthorizationId $authorizationId `
        -ExpectedHead $ExpectedRepositoryHead `
        -ExpectedLauncherScriptSha256 $launcherHash `
        -ExpectedBootstrapScriptSha256 $bootstrapHash `
        -ExpectedTransportScriptSha256 $transportHash `
        -ExpectedChildScriptSha256 $childHash `
        -ExpectedCheckpointFileName ([IO.Path]::GetFileName($checkpointPath)) `
        -ExpectedCheckpointDigest $expectedDigest `
        -ExpectedLaunchDiagnosticDigest $expectedLaunchDiagnosticDigest `
        -ExpectedChildDiagnosticDigest $expectedChildDiagnosticDigest `
        -InvocationStartedAtUtc $startedAt `
        -ConsumedNonces @{})
      if ($result.overallStatus -ne [string]$scenario.Overall -or
        [bool]$result.transientCleanupCompleted -ne [bool]$scenario.Cleanup) {
        throw "Scenario $($scenario.Name) has an incorrect authoritative disposition."
      }
      if ($null -ne $checkpoint -and
        $result.launchDiagnostic.diagnosticDigest -ne
          $checkpoint.launchDiagnostic.diagnosticDigest) {
        throw "Scenario $($scenario.Name) changed launch evidence between records."
      }
      if ($scenario.Name -eq "success" -and (
        $result.launchDiagnostic.launchDisposition -ne "launched" -or
        -not [bool]$result.launchDiagnostic.processCreated
      )) {
        throw "The successful process-boundary scenario lacks created-process evidence."
      }
      if ($scenario.Name -eq "cleanup-failure" -and (
        [int]$result.remainingTransientObjectCount -eq 0 -or
        @($result.remainingTransientRelativePaths) -notcontains "simulated-cleanup-residue"
      )) {
        throw "The cleanup-failure receipt omitted its sanitized residue evidence."
      }
    } elseif ([IO.File]::Exists($resultPath)) {
      throw "An interrupted final write unexpectedly produced a final result."
    }

    if ([bool]$scenario.Cleanup -and
      ([IO.Directory]::Exists($invocation) -or [IO.File]::Exists($invocation))) {
      throw "Scenario $($scenario.Name) left transient invocation resources."
    }
    $scenarioResults += [pscustomobject]@{
      scenario = [string]$scenario.Name
      exitCode = [int]$process.ExitCode
      checkpointExpected = [bool]$scenario.Checkpoint
      resultExpected = [bool]$scenario.Result
    }

    if ([IO.Directory]::Exists($invocation)) {
      Remove-RisePalsProcessSuiteTree -Path $invocation -ExpectedParent $transientRoot
    }
    Remove-RisePalsProcessSuiteTree -Path $directory -ExpectedParent $taskRoot
    Write-Output ("Process-boundary simulation PASS: " + [string]$scenario.Name)
  }

  $probeNonce = [guid]::NewGuid().ToString("N")
  $probeAuthorization = "RP-TURN-019-R4-PROBE-A1B2C3D4"
  $probeDirectory = Join-Path $taskRoot "elevation-probe"
  [IO.Directory]::CreateDirectory($probeDirectory) | Out-Null
  $probeCheckpointPath = Join-Path $probeDirectory `
    ("candidate-parent-checkpoint-" + $probeNonce + ".json")
  $probeResultPath = Join-Path $probeDirectory `
    ("candidate-parent-result-" + $probeNonce + ".json")
  $probeChildHash = Get-RisePalsCandidateTransportSha256 -LiteralPath $probeChild
  $probeStartedAt = [DateTimeOffset]::UtcNow
  $probeArguments = @(
    "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    (ConvertTo-RisePalsProcessSuiteArgument -Value $probeFixture),
    "-ResultScriptPath", (ConvertTo-RisePalsProcessSuiteArgument -Value $resultScript),
    "-TransportScriptPath", (ConvertTo-RisePalsProcessSuiteArgument -Value $transport),
    "-CheckpointPath", (ConvertTo-RisePalsProcessSuiteArgument -Value $probeCheckpointPath),
    "-ResultPath", (ConvertTo-RisePalsProcessSuiteArgument -Value $probeResultPath),
    "-InvocationNonce", $probeNonce,
    "-RepositoryHead", $ExpectedRepositoryHead,
    "-LauncherScriptSha256", $launcherHash,
    "-BootstrapScriptSha256", $bootstrapHash,
    "-TransportScriptSha256", $transportHash,
    "-ChildScriptSha256", $probeChildHash
  )
  $probeProcess = Start-Process -FilePath $powerShell -ArgumentList $probeArguments `
    -WindowStyle Hidden -Wait -PassThru
  if ([int]$probeProcess.ExitCode -ne 0 -or
    -not [IO.File]::Exists($probeCheckpointPath) -or
    -not [IO.File]::Exists($probeResultPath)) {
    throw "The hidden ElevationProbe transport process did not produce both records."
  }
  $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
  $probeCheckpoint = $strictUtf8.GetString(
    [IO.File]::ReadAllBytes($probeCheckpointPath)
  ) | ConvertFrom-Json
  $probeResult = $strictUtf8.GetString(
    [IO.File]::ReadAllBytes($probeResultPath)
  ) | ConvertFrom-Json
  [void](Assert-RisePalsCandidateParentCheckpoint -Checkpoint $probeCheckpoint `
    -ExpectedNonce $probeNonce -ExpectedAuthorizationId $probeAuthorization `
    -ExpectedHead $ExpectedRepositoryHead `
    -ExpectedLauncherScriptSha256 $launcherHash `
    -ExpectedBootstrapScriptSha256 $bootstrapHash `
    -ExpectedTransportScriptSha256 $transportHash `
    -ExpectedChildScriptSha256 $probeChildHash `
    -ExpectedLaunchDiagnosticDigest $probeCheckpoint.launchDiagnostic.diagnosticDigest `
    -ExpectedProbeDiagnosticDigest $probeCheckpoint.probeDiagnostic.probeDigest `
    -ExpectedExecutionMode ElevationProbe -InvocationStartedAtUtc $probeStartedAt `
    -ConsumedNonces @{})
  [void](Assert-RisePalsCandidateParentResult -Result $probeResult `
    -ExpectedNonce $probeNonce -ExpectedAuthorizationId $probeAuthorization `
    -ExpectedHead $ExpectedRepositoryHead `
    -ExpectedLauncherScriptSha256 $launcherHash `
    -ExpectedBootstrapScriptSha256 $bootstrapHash `
    -ExpectedTransportScriptSha256 $transportHash `
    -ExpectedChildScriptSha256 $probeChildHash `
    -ExpectedCheckpointFileName ([IO.Path]::GetFileName($probeCheckpointPath)) `
    -ExpectedCheckpointDigest $probeCheckpoint.checkpointDigest `
    -ExpectedLaunchDiagnosticDigest $probeCheckpoint.launchDiagnostic.diagnosticDigest `
    -ExpectedChildDiagnosticDigest $probeCheckpoint.childDiagnostic.diagnosticDigest `
    -ExpectedProbeDiagnosticDigest $probeCheckpoint.probeDiagnostic.probeDigest `
    -ExpectedExecutionMode ElevationProbe -InvocationStartedAtUtc $probeStartedAt `
    -ConsumedNonces @{})
  if ($probeResult.overallStatus -ne "success" -or
    $probeResult.functionalClassification -ne "elevation-probe-success" -or
    $probeResult.probeDiagnostic.probeDigest -ne
      $probeCheckpoint.probeDiagnostic.probeDigest -or
    [bool]$probeResult.liveStarted) {
    throw "The hidden ElevationProbe transport records are inconsistent."
  }
  $scenarioResults += [pscustomobject]@{
    scenario = "elevation-probe-transport"
    exitCode = [int]$probeProcess.ExitCode
    checkpointExpected = $true
    resultExpected = $true
  }
  Remove-RisePalsProcessSuiteTree -Path $probeDirectory -ExpectedParent $taskRoot
  $probeDirectory = $null
  Write-Output "Process-boundary simulation PASS: elevation-probe-transport"
} finally {
  foreach ($invocation in $invocationPaths) {
    if ([IO.Directory]::Exists($invocation)) {
      Remove-RisePalsProcessSuiteTree -Path $invocation -ExpectedParent $transientRoot
    }
  }
  foreach ($scenario in $scenarios) {
    $path = Join-Path $taskRoot ([string]$scenario.Name)
    if ([IO.Directory]::Exists($path)) {
      Remove-RisePalsProcessSuiteTree -Path $path -ExpectedParent $taskRoot
    }
  }
  if ($null -ne $probeDirectory -and [IO.Directory]::Exists($probeDirectory)) {
    Remove-RisePalsProcessSuiteTree -Path $probeDirectory -ExpectedParent $taskRoot
  }
  if ([IO.Directory]::Exists($taskRoot) -and
    @(Get-ChildItem -LiteralPath $taskRoot -Force).Count -eq 0) {
    [IO.Directory]::Delete($taskRoot, $false)
  }
}

$afterHost = Get-RisePalsProcessSuiteHostSnapshot
Assert-RisePalsProcessSuiteHostUnchanged -Before $beforeHost -After $afterHost
Assert-RisePalsProcessSuiteRepository
if ($scenarioResults.Count -ne 11 -or [IO.Directory]::Exists($taskRoot)) {
  throw "The process-boundary suite did not complete eleven isolated scenarios cleanly."
}
Write-Output "Candidate separate-process boundary suite PASS (11 scenarios); stdout was not authoritative."
