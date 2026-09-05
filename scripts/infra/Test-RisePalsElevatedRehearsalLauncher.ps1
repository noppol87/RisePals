[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$ExpectedRepositoryHead,
  [string]$RepositoryRoot = "",
  [switch]$NativeSuccessOnly,
  [ValidateRange(1, 10)][int]$Repetitions = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "rehearsal-launcher-result.ps1")
if ($PSVersionTable.PSEdition -cne "Desktop" -or $PSVersionTable.PSVersion.Major -ne 5 -or
  $PSVersionTable.PSVersion.Minor -ne 1 -or
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Launcher simulations require non-elevated Windows PowerShell 5.1."
}

function ConvertTo-RisePalsStructuredProcessArgument {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value.Contains('"')) {
    throw "A structured process argument contains a prohibited quote."
  }
  return '"' + $Value + '"'
}

function Invoke-RisePalsLauncherSimulation {
  param(
    [Parameter(Mandatory = $true)][string]$Scenario,
    [Parameter(Mandatory = $true)][int]$ExpectedExitCode,
    [Parameter(Mandatory = $true)][string]$Repository,
    [Parameter(Mandatory = $true)][string]$ExpectedHead,
    [Parameter(Mandatory = $true)][string]$SuiteDirectory
  )

  # Each process receives a fresh directory for the existing sanitized schema.
  # Native and outer stdout/stderr are never parsed or retained by this test.
  $reviewRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "risepals-launcher-review-" + [guid]::NewGuid().ToString("N")
  )
  if (Test-Path -LiteralPath $reviewRoot) { throw "Review directory collision." }
  [void][IO.Directory]::CreateDirectory($reviewRoot)
  $process = $null
  $exited = $false
  $started = [DateTimeOffset]::UtcNow
  try {
    [void](Assert-RisePalsSimulationReviewDirectory -Path $reviewRoot -RequireEmpty)
    $arguments = @("-NoLogo", "-NoProfile", "-NonInteractive", "-File",
      (ConvertTo-RisePalsStructuredProcessArgument (Join-Path $PSScriptRoot "Invoke-RisePalsElevatedRehearsal.ps1")),
      "-ExpectedRepositoryHead", $ExpectedHead, "-Mode", "Simulation",
      "-SimulationScenario", $Scenario, "-RepositoryRoot",
      (ConvertTo-RisePalsStructuredProcessArgument $Repository),
      "-SimulationResultDirectory", (ConvertTo-RisePalsStructuredProcessArgument $reviewRoot))
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = Join-Path $PSHOME "powershell.exe"
    $info.Arguments = $arguments -join " "
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    if (-not $process.Start()) { throw "Simulation process creation failed." }
    $outTask = $process.StandardOutput.BaseStream.CopyToAsync([IO.Stream]::Null)
    $errTask = $process.StandardError.BaseStream.CopyToAsync([IO.Stream]::Null)
    if (-not $process.WaitForExit(60000)) { throw "Simulation process exit unproven." }
    $exited = $true
    [void]$outTask.GetAwaiter().GetResult()
    [void]$errTask.GetAwaiter().GetResult()
    $observedExit = $process.ExitCode
    [void](Assert-RisePalsSimulationReviewDirectory -Path $reviewRoot)
    $files = @(Get-ChildItem -LiteralPath $reviewRoot -Force)
    if ($files.Count -gt 1) { throw "Ambiguous simulation result inventory." }
    $result = $null
    foreach ($file in $files) {
      if ($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
        $file.Name -cnotmatch '^result-([a-f0-9-]{36})\.json$' -or $file.Length -gt 16384) {
        throw "Invalid simulation result object."
      }
      $nonce = $Matches[1]
      $result = [Text.UTF8Encoding]::new($false, $true).GetString(
        [IO.File]::ReadAllBytes($file.FullName)) | ConvertFrom-Json
      [void](Assert-RisePalsLauncherResult -Result $result -ExpectedInvocationNonce $nonce `
        -ExpectedRepositoryHead $ExpectedHead -ObservedChildExitCode $observedExit `
        -InvocationStartedAtUtc $started)
      if ($result.executionMode -cne "simulation") { throw "Not simulation evidence." }
    }
    if ($observedExit -ne $ExpectedExitCode) {
      throw "$Scenario returned exit code $observedExit, expected $ExpectedExitCode."
    }
    $root = Join-Path ([IO.Path]::GetTempPath()) "risepals-elevated-rehearsal"
    if (Test-Path -LiteralPath $root) {
      [void](Assert-RisePalsLauncherPlainDirectory -Path $root)
      if (@(Get-ChildItem -LiteralPath $root -Force).Count -ne 0) {
        throw "Launcher invocation residue remains."
      }
    }
    return [pscustomobject]@{ scenario = $Scenario; exitCode = $observedExit; result = $result }
  } finally {
    if ($null -ne $process) { $process.Dispose() }
    if (-not $exited) { throw "Simulation exit unproven; review cleanup withheld." }
    [void](Assert-RisePalsSimulationReviewDirectory -Path $reviewRoot)
    $items = @(Get-ChildItem -LiteralPath $reviewRoot -Force)
    foreach ($item in $items) {
      if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
        $item.Name -cnotmatch '^result-[a-f0-9-]{36}\.json(\.tmp)?$') {
        throw "Unattributable simulation review cleanup object."
      }
    }
    foreach ($item in $items) { [IO.File]::Delete($item.FullName) }
    [IO.Directory]::Delete($reviewRoot, $false)
    if (Test-Path -LiteralPath $reviewRoot) { throw "Simulation review residue remains." }
  }
}
$repository = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
} else {
  [IO.Path]::GetFullPath($RepositoryRoot)
}
$suiteRoot = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-launcher-suite-" + [guid]::NewGuid().ToString("N")
)
[IO.Directory]::CreateDirectory($suiteRoot) | Out-Null
$evidenceRoot = Join-Path ([IO.Path]::GetTempPath()) "risepals-elevated-rehearsal"

try {
  if ($NativeSuccessOnly) {
    $nonces = @()
    for ($iteration = 1; $iteration -le $Repetitions; $iteration++) {
      $item = Invoke-RisePalsLauncherSimulation -Scenario "NativeSuccess" -ExpectedExitCode 0 `
        -Repository $repository -ExpectedHead $ExpectedRepositoryHead -SuiteDirectory $suiteRoot
      if ($null -eq $item.result -or $item.result.status -cne "success" -or
        -not $item.result.cleanupCompleted -or $item.result.streamEvidence.stdoutBytes -le 0 -or
        $item.result.streamEvidence.stderrBytes -le 0 -or
        -not $item.result.streamEvidence.streamsSeparated -or
        $item.result.invocationNonce -cin $nonces) { throw "NativeSuccess evidence incomplete." }
      foreach ($property in $script:RisePalsLauncherResourceCountProperties) {
        if ($item.result.finalResourceCounts.$property -ne 0) { throw "NativeSuccess residue." }
      }
      $nonces += $item.result.invocationNonce
      Write-Output ("NativeSuccess {0}/{1} PASS; exit=0; native-stages=complete; result=reopened/validated; stdoutBytes={2}; stderrBytes={3}; resultDigest={4}; residue=0" -f
        $iteration, $Repetitions, $item.result.streamEvidence.stdoutBytes,
        $item.result.streamEvidence.stderrBytes, $item.result.resultDigest)
    }
    return
  }
  $success = Invoke-RisePalsLauncherSimulation -Scenario "NativeSuccess" `
    -ExpectedExitCode 0 -Repository $repository -ExpectedHead $ExpectedRepositoryHead `
    -SuiteDirectory $suiteRoot
  if ($null -eq $success.result -or $success.result.status -ne "success" -or
    -not $success.result.streamEvidence.stdoutPresent -or
    -not $success.result.streamEvidence.stderrPresent) {
    throw "NativeSuccess did not classify informational stderr as success."
  }
  Write-Output "Native success with informational stderr PASS"

  $failure = Invoke-RisePalsLauncherSimulation -Scenario "NativeFailure" `
    -ExpectedExitCode 7 -Repository $repository -ExpectedHead $ExpectedRepositoryHead `
    -SuiteDirectory $suiteRoot
  if ($null -eq $failure.result -or $failure.result.status -ne "failure" -or
    $failure.result.childExitCode -ne 7) {
    throw "NativeFailure did not preserve the native exit code."
  }
  Write-Output "Native exit-code failure classification PASS"

  $dual = Invoke-RisePalsLauncherSimulation -Scenario "DualStreamSuccess" `
    -ExpectedExitCode 0 -Repository $repository -ExpectedHead $ExpectedRepositoryHead `
    -SuiteDirectory $suiteRoot
  if ($null -eq $dual.result -or -not $dual.result.streamEvidence.streamsSeparated -or
    $dual.result.streamEvidence.stdoutBytes -le 0 -or
    $dual.result.streamEvidence.stderrBytes -le 0) {
    throw "DualStreamSuccess did not preserve separate stream evidence."
  }
  Write-Output "Dual-stream success separation PASS"

  foreach ($scenario in @(
    "MissingResult",
    "MalformedResult",
    "WrongNonce",
    "WrongRepositoryHead",
    "StaleTimestamp",
    "DigestMismatch",
    "ExitCodeDisagreement",
    "PartialAtomicResult"
  )) {
    $invalid = Invoke-RisePalsLauncherSimulation -Scenario $scenario `
      -ExpectedExitCode 86 -Repository $repository -ExpectedHead $ExpectedRepositoryHead `
      -SuiteDirectory $suiteRoot
    if ($null -ne $invalid.result) {
      throw "$scenario did not fail closed through the generic launcher boundary."
    }
    Write-Output ($scenario + " rejection PASS")
  }

  $cleanupFailure = Invoke-RisePalsLauncherSimulation -Scenario "CleanupFailure" `
    -ExpectedExitCode 13 -Repository $repository -ExpectedHead $ExpectedRepositoryHead `
    -SuiteDirectory $suiteRoot
  if ($null -eq $cleanupFailure.result -or $cleanupFailure.result.cleanupCompleted -or
    $cleanupFailure.result.finalResourceCounts.rawCaptureFiles -ne 1) {
    throw "CleanupFailure did not report the controlled residue count."
  }
  Write-Output "Raw capture cleanup failure PASS"

  $privacy = Invoke-RisePalsLauncherSimulation -Scenario "Privacy" `
    -ExpectedExitCode 0 -Repository $repository -ExpectedHead $ExpectedRepositoryHead `
    -SuiteDirectory $suiteRoot
  $privacyJson = $privacy.result | ConvertTo-Json -Depth 6 -Compress
  foreach ($prohibited in @(
    "PRIVATE-MARKER-STDOUT",
    "person@example.invalid",
    "Authorization:",
    "request-body-fixture"
  )) {
    if ($privacyJson.Contains($prohibited)) {
      throw "The sanitized result retained a prohibited fixture value."
    }
  }
  Write-Output "Sanitized result privacy PASS"

  $repeatOne = Invoke-RisePalsLauncherSimulation -Scenario "NativeSuccess" `
    -ExpectedExitCode 0 -Repository $repository -ExpectedHead $ExpectedRepositoryHead `
    -SuiteDirectory $suiteRoot
  $repeatTwo = Invoke-RisePalsLauncherSimulation -Scenario "NativeSuccess" `
    -ExpectedExitCode 0 -Repository $repository -ExpectedHead $ExpectedRepositoryHead `
    -SuiteDirectory $suiteRoot
  if ($repeatOne.result.invocationNonce -eq $repeatTwo.result.invocationNonce) {
    throw "Repeated simulation reused a prior invocation nonce."
  }
  if ([IO.Directory]::Exists($evidenceRoot) -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Force).Count -ne 0) {
    throw "Repeated simulation left a nonce-specific evidence directory."
  }
  Write-Output "Repeated invocation replay prevention PASS"
  Write-Output "Rise Pals PowerShell 5.1 elevated-launcher simulation suite PASS (14 cases)."
} finally {
  if ([IO.Directory]::Exists($suiteRoot)) {
    $suiteItem = Get-Item -LiteralPath $suiteRoot -Force
    if (($suiteItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "The simulation suite cleanup target is a reparse point."
    }
    if (@(Get-ChildItem -LiteralPath $suiteRoot -Force).Count -ne 0) {
      throw "Unexpected suite residue; cleanup refused."
    }
    [IO.Directory]::Delete($suiteRoot, $false)
  }
}
