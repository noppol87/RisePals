[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$ExpectedRepositoryHead,
  [ValidateSet("Live", "Simulation")][string]$Mode = "Simulation",
  [ValidateSet(
    "NativeSuccess",
    "NativeFailure",
    "DualStreamSuccess",
    "MissingResult",
    "MalformedResult",
    "WrongNonce",
    "WrongRepositoryHead",
    "StaleTimestamp",
    "DigestMismatch",
    "ExitCodeDisagreement",
    "PartialAtomicResult",
    "CleanupFailure",
    "Privacy"
  )][string]$SimulationScenario = "NativeSuccess",
  [string]$RepositoryRoot = "",
  [string]$EvidenceRoot = "",
  [string]$SimulationResultDirectory = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "rehearsal-launcher-result.ps1")

# Optional test evidence reuses the existing result schema; Live cannot export it.
$reviewDirectory = $null
if ($SimulationResultDirectory) {
  if ($Mode -ne "Simulation" -or
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
      [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Simulation review evidence requires non-elevated Simulation."
  }
  $reviewDirectory = Assert-RisePalsSimulationReviewDirectory -Path $SimulationResultDirectory -RequireEmpty
}

function ConvertTo-RisePalsStructuredProcessArgument {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value.Contains('"')) {
    throw "A structured process argument contains a prohibited quote."
  }
  return '"' + $Value + '"'
}

function Remove-RisePalsLauncherExactFile {
  param(
    [Parameter(Mandatory = $true)][string]$Directory,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $resolvedDirectory = [IO.Path]::GetFullPath($Directory).TrimEnd(
    [IO.Path]::DirectorySeparatorChar
  )
  $resolvedPath = [IO.Path]::GetFullPath($Path)
  if (-not [IO.Path]::GetDirectoryName($resolvedPath).Equals(
    $resolvedDirectory,
    [StringComparison]::OrdinalIgnoreCase
  )) {
    throw "The launcher cleanup path is outside the exact invocation directory."
  }
  if ([IO.File]::Exists($resolvedPath)) {
    [IO.File]::Delete($resolvedPath)
  }
}

function Get-RisePalsGitExecutable {
  $portable = "C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
  if (-not [IO.File]::Exists($portable)) {
    throw "The pinned repository Git executable is absent."
  }
  return $portable
}

$repository = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
} else {
  [IO.Path]::GetFullPath($RepositoryRoot)
}
$approvedRepository = "C:\Codex PC SG2\Jeff\risepals"
if (-not $repository.TrimEnd([IO.Path]::DirectorySeparatorChar).Equals(
  $approvedRepository,
  [StringComparison]::OrdinalIgnoreCase
)) {
  throw "The launcher repository root is not the exact approved repository."
}

$git = Get-RisePalsGitExecutable
$safeDirectory = "safe.directory=C:/Codex PC SG2/Jeff/risepals"
$head = (& $git -c $safeDirectory -C $repository rev-parse HEAD).Trim()
$branch = (& $git -c $safeDirectory -C $repository branch --show-current).Trim()
$worktree = @(& $git -c $safeDirectory -C $repository status --porcelain --untracked-files=all)
if ($LASTEXITCODE -ne 0 -or $head -ne $ExpectedRepositoryHead -or
  $branch -ne "agent/windows-vps-infrastructure-readiness" -or $worktree.Count -ne 0) {
  throw "The exact clean RP-TURN-019 feature head is required."
}
if (-not $PSCmdlet.ShouldProcess(
  $repository,
  ("Launch the versioned {0} rehearsal child" -f $Mode.ToLowerInvariant())
)) {
  Write-Output "Rise Pals elevated-rehearsal launcher dry-run PASS"
  return
}

$approvedEvidenceRoot = [IO.Path]::GetFullPath(
  (Join-Path ([IO.Path]::GetTempPath()) "risepals-elevated-rehearsal")
).TrimEnd([IO.Path]::DirectorySeparatorChar)
$resolvedEvidenceRoot = if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
  $approvedEvidenceRoot
} else {
  [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
}
if (-not $resolvedEvidenceRoot.Equals(
  $approvedEvidenceRoot,
  [StringComparison]::OrdinalIgnoreCase
)) {
  throw "The launcher evidence root is not the exact approved temporary path."
}
$evidenceRootCreated = -not [IO.Directory]::Exists($resolvedEvidenceRoot)
if ($evidenceRootCreated) {
  [IO.Directory]::CreateDirectory($resolvedEvidenceRoot) | Out-Null
}
$rootItem = Get-Item -LiteralPath $resolvedEvidenceRoot -Force
if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
  throw "The launcher evidence root must not be a reparse point."
}
[void](Assert-RisePalsLauncherPlainDirectory -Path $resolvedEvidenceRoot)
if (@(Get-ChildItem -LiteralPath $resolvedEvidenceRoot -Force).Count -ne 0) {
  throw "The launcher evidence root contains a pre-existing object."
}

$nonce = [guid]::NewGuid().ToString("D")
$invocationDirectory = Join-Path $resolvedEvidenceRoot ("invocation-" + $nonce)
if ([IO.Directory]::Exists($invocationDirectory) -or [IO.File]::Exists($invocationDirectory)) {
  throw "The collision-resistant launcher invocation directory already exists."
}
[IO.Directory]::CreateDirectory($invocationDirectory) | Out-Null
$resultPath = Join-Path $invocationDirectory "result.json"
$temporaryResultPath = Join-Path $invocationDirectory ("result." + $nonce + ".tmp")
$stdoutPath = Join-Path $invocationDirectory "native.stdout.log"
$stderrPath = Join-Path $invocationDirectory "native.stderr.log"
$cleanupResiduePath = Join-Path $invocationDirectory "cleanup-residue.test"
$invocationStartedAt = [DateTimeOffset]::UtcNow
$processExitCode = 86
$finalExitCode = 86
$validatedResult = $null
$validationSucceeded = $false
$process = $null

try {
  $child = Join-Path $PSScriptRoot "Invoke-RisePalsElevatedRehearsalChild.ps1"
  $powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
  $arguments = @(
    "-NoLogo",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (ConvertTo-RisePalsStructuredProcessArgument -Value $child),
    "-Mode",
    $Mode,
    "-SimulationScenario",
    $SimulationScenario,
    "-RequestedRepositoryHead",
    $ExpectedRepositoryHead,
    "-InvocationNonce",
    $nonce,
    "-RepositoryRoot",
    (ConvertTo-RisePalsStructuredProcessArgument -Value $repository),
    "-EvidenceRoot",
    (ConvertTo-RisePalsStructuredProcessArgument -Value $resolvedEvidenceRoot),
    "-EvidenceDirectory",
    (ConvertTo-RisePalsStructuredProcessArgument -Value $invocationDirectory)
  )
  $startParameters = @{
    FilePath = $powerShell
    ArgumentList = $arguments
    WindowStyle = "Hidden"
    Wait = $true
    PassThru = $true
  }
  if ($Mode -eq "Live") {
    $startParameters.Verb = "RunAs"
  }
  $process = Start-Process @startParameters
  $processExitCode = $process.ExitCode

  if (-not [IO.File]::Exists($resultPath)) {
    throw "The elevated child did not write a result artifact."
  }
  $resultBytes = [IO.File]::ReadAllBytes($resultPath)
  $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
  $resultText = $strictUtf8.GetString($resultBytes)
  $validatedResult = $resultText | ConvertFrom-Json
  [void](Assert-RisePalsLauncherResult -Result $validatedResult `
    -ExpectedInvocationNonce $nonce -ExpectedRepositoryHead $ExpectedRepositoryHead `
    -ObservedChildExitCode $processExitCode -InvocationStartedAtUtc $invocationStartedAt)
  if ($reviewDirectory) {
    [void](Assert-RisePalsSimulationReviewDirectory -Path $reviewDirectory -RequireEmpty)
    $reviewPath = Join-Path $reviewDirectory ("result-" + $nonce + ".json")
    Write-RisePalsLauncherResultAtomic -Result $validatedResult -ResultPath $reviewPath `
      -TemporaryResultPath ($reviewPath + ".tmp")
    $review = $strictUtf8.GetString([IO.File]::ReadAllBytes($reviewPath)) | ConvertFrom-Json
    [void](Assert-RisePalsLauncherResult -Result $review -ExpectedInvocationNonce $nonce `
      -ExpectedRepositoryHead $ExpectedRepositoryHead -ObservedChildExitCode $processExitCode `
      -InvocationStartedAtUtc $invocationStartedAt)
    if ($review.resultDigest -cne $validatedResult.resultDigest) {
      throw "Simulation review result differs from the validated child result."
    }
  }
  $validationSucceeded = $true
  $finalExitCode = $processExitCode
} catch {
  $validationSucceeded = $false
  $finalExitCode = 86
} finally {
  if ($null -ne $process) { $process.Dispose() }
  [void](Assert-RisePalsLauncherPlainDirectory -Path $invocationDirectory)
  $allowedNames = @("result.json", ("result." + $nonce + ".tmp"),
    "native.stdout.log", "native.stderr.log", "cleanup-residue.test")
  foreach ($item in @(Get-ChildItem -LiteralPath $invocationDirectory -Force)) {
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      $item.Name -cnotin $allowedNames) { throw "Unattributable launcher cleanup object." }
  }
  foreach ($path in @(
    $resultPath,
    $temporaryResultPath,
    $stdoutPath,
    $stderrPath,
    $cleanupResiduePath
  )) {
    Remove-RisePalsLauncherExactFile -Directory $invocationDirectory -Path $path
  }
  if ([IO.Directory]::Exists($invocationDirectory)) {
    [IO.Directory]::Delete($invocationDirectory, $false)
  }
  if ($evidenceRootCreated -and [IO.Directory]::Exists($resolvedEvidenceRoot) -and
    @(Get-ChildItem -LiteralPath $resolvedEvidenceRoot -Force).Count -eq 0) {
    [IO.Directory]::Delete($resolvedEvidenceRoot, $false)
  }
}

if (-not $validationSucceeded) {
  [Console]::Error.WriteLine(
    "Rise Pals rehearsal launcher failed closed (child exit code {0}); no console stream was parsed." -f
      $processExitCode
  )
  exit $finalExitCode
}

$sanitizedJson = $validatedResult | ConvertTo-Json -Depth 6 -Compress
Write-Output ("RISE_PALS_LAUNCHER_RESULT=" + $sanitizedJson)
if (-not $validatedResult.cleanupCompleted) {
  [Console]::Error.WriteLine(
    "Rise Pals rehearsal launcher reported controlled capture residue count {0}." -f
      $validatedResult.finalResourceCounts.rawCaptureFiles
  )
}
exit $finalExitCode
