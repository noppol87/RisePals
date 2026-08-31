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
$transport = Join-Path $scripts "candidate-rehearsal-transport.ps1"
$child = Join-Path $scripts "Invoke-RisePalsCandidateRehearsalChild.ps1"
$powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$git = "C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
$safe = "safe.directory=C:/Codex PC SG2/Jeff/risepals"
$authorizationId = "RP-TURN-019-R4-DIAG1-SIMULATION"
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
        -ExpectedChildScriptSha256 $childHash -InvocationStartedAtUtc $startedAt `
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
      [void](Assert-RisePalsCandidateParentResult -Result $result `
        -ExpectedNonce $nonce -ExpectedAuthorizationId $authorizationId `
        -ExpectedHead $ExpectedRepositoryHead `
        -ExpectedLauncherScriptSha256 $launcherHash `
        -ExpectedBootstrapScriptSha256 $bootstrapHash `
        -ExpectedTransportScriptSha256 $transportHash `
        -ExpectedChildScriptSha256 $childHash `
        -ExpectedCheckpointFileName ([IO.Path]::GetFileName($checkpointPath)) `
        -ExpectedCheckpointDigest $expectedDigest -InvocationStartedAtUtc $startedAt `
        -ConsumedNonces @{})
      if ($result.overallStatus -ne [string]$scenario.Overall -or
        [bool]$result.transientCleanupCompleted -ne [bool]$scenario.Cleanup) {
        throw "Scenario $($scenario.Name) has an incorrect authoritative disposition."
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
  if ([IO.Directory]::Exists($taskRoot) -and
    @(Get-ChildItem -LiteralPath $taskRoot -Force).Count -eq 0) {
    [IO.Directory]::Delete($taskRoot, $false)
  }
}

$afterHost = Get-RisePalsProcessSuiteHostSnapshot
Assert-RisePalsProcessSuiteHostUnchanged -Before $beforeHost -After $afterHost
Assert-RisePalsProcessSuiteRepository
if ($scenarioResults.Count -ne 10 -or [IO.Directory]::Exists($taskRoot)) {
  throw "The process-boundary suite did not complete ten isolated scenarios cleanly."
}
Write-Output "Candidate separate-process boundary suite PASS (10 scenarios); stdout was not authoritative."
