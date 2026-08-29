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

$launcherHash = Get-RisePalsSha256 -LiteralPath $PSCommandPath
$nonce = [guid]::NewGuid().ToString("N")
$plan = New-RisePalsCandidateInstallationPlan -Contract $contract -Nonce $nonce `
  -RepositoryHead $head -LauncherScriptSha256 $launcherHash
if ($Mode -eq "Plan") {
  $plan | ConvertTo-Json -Depth 8
  Write-Output "Rise Pals candidate rehearsal plan PASS; zero host mutation requested."
  return
}
if ($Mode -eq "Live" -and (
  $FutureAuthorizationId -notmatch "^RP-TURN-019-R4-LIVE-[A-F0-9]{8}$" -or
  -not $PSCmdlet.ShouldProcess(
    $script:RisePalsCandidateServiceName,
    "Launch the separately authorized candidate rehearsal child"
  )
)) {
  throw "Live candidate execution requires a separate exact-head authorization identifier."
}
if ($Mode -eq "Simulation" -and -not $PSCmdlet.ShouldProcess(
  $env:TEMP,
  "Run the non-elevated candidate launcher simulation"
)) {
  Write-Output "Rise Pals candidate launcher simulation dry-run PASS"
  return
}

$evidenceRoot = [IO.Path]::GetFullPath(
  (Join-Path ([IO.Path]::GetTempPath()) "risepals-candidate-launcher")
)
$invocationDirectory = Join-Path $evidenceRoot ("invocation-" + $nonce)
if ([IO.Directory]::Exists($invocationDirectory) -or [IO.File]::Exists($invocationDirectory)) {
  throw "The candidate invocation directory is not fresh."
}
[IO.Directory]::CreateDirectory($invocationDirectory) | Out-Null
$resultPath = Join-Path $invocationDirectory "result.json"
$child = Join-Path $PSScriptRoot "Invoke-RisePalsCandidateRehearsalChild.ps1"
$powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$startedAt = [DateTimeOffset]::UtcNow
$processExitCode = 86
$validated = $null
$consumed = @{}

try {
  $arguments = @(
    "-NoLogo",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (ConvertTo-RisePalsCandidateProcessArgument -Value $child),
    "-Mode",
    $Mode,
    "-SimulationScenario",
    $SimulationScenario,
    "-RepositoryHead",
    $head,
    "-LauncherScriptSha256",
    $launcherHash,
    "-InvocationNonce",
    $nonce,
    "-InvocationDirectory",
    (ConvertTo-RisePalsCandidateProcessArgument -Value $invocationDirectory)
  )
  if ($Mode -eq "Live") {
    $arguments += @(
      "-FutureAuthorizationId",
      $FutureAuthorizationId,
      "-CandidateExecutableSource",
      (ConvertTo-RisePalsCandidateProcessArgument -Value $CandidateExecutableSource),
      "-NodeExecutableSource",
      (ConvertTo-RisePalsCandidateProcessArgument -Value $NodeExecutableSource)
    )
  }
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
  $process = Start-Process @start
  $processExitCode = $process.ExitCode
  if (-not [IO.File]::Exists($resultPath)) {
    throw "The candidate child did not produce a structured result."
  }
  $resultText = [Text.UTF8Encoding]::new($false, $true).GetString(
    [IO.File]::ReadAllBytes($resultPath)
  )
  $validated = $resultText | ConvertFrom-Json
  [void](Assert-RisePalsCandidateResult -Result $validated -ExpectedNonce $nonce `
    -ExpectedHead $head -ExpectedLauncherScriptSha256 $launcherHash `
    -ObservedExitCode $processExitCode -InvocationStartedAtUtc $startedAt `
    -ConsumedNonces $consumed)
} catch {
  [Console]::Error.WriteLine(
    "Rise Pals candidate launcher failed closed (child exit code {0})." -f $processExitCode
  )
  exit 86
} finally {
  foreach ($name in @("result.json", "result.tmp", "stdout.log", "stderr.log")) {
    $path = Join-Path $invocationDirectory $name
    if ([IO.File]::Exists($path)) {
      [IO.File]::Delete($path)
    }
  }
  if ([IO.Directory]::Exists($invocationDirectory)) {
    [IO.Directory]::Delete($invocationDirectory, $false)
  }
  if ([IO.Directory]::Exists($evidenceRoot) -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Force).Count -eq 0) {
    [IO.Directory]::Delete($evidenceRoot, $false)
  }
}

Write-Output ("RISE_PALS_CANDIDATE_RESULT=" + ($validated | ConvertTo-Json -Depth 7 -Compress))
exit $processExitCode
