[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$ExpectedRepositoryHead,
  [string]$RepositoryRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

  $powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
  $launcher = Join-Path $PSScriptRoot "Invoke-RisePalsElevatedRehearsal.ps1"
  $stdoutPath = Join-Path $SuiteDirectory ($Scenario + ".stdout.log")
  $stderrPath = Join-Path $SuiteDirectory ($Scenario + ".stderr.log")
  foreach ($path in @($stdoutPath, $stderrPath)) {
    if ([IO.File]::Exists($path)) {
      [IO.File]::Delete($path)
    }
  }
  $arguments = @(
    "-NoLogo",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (ConvertTo-RisePalsStructuredProcessArgument -Value $launcher),
    "-ExpectedRepositoryHead",
    $ExpectedHead,
    "-Mode",
    "Simulation",
    "-SimulationScenario",
    $Scenario,
    "-RepositoryRoot",
    (ConvertTo-RisePalsStructuredProcessArgument -Value $Repository)
  )
  $process = Start-Process -FilePath $powerShell -ArgumentList $arguments `
    -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath `
    -WindowStyle Hidden -Wait -PassThru
  $stdout = if ([IO.File]::Exists($stdoutPath)) {
    Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8
  } else {
    ""
  }
  $stderr = if ([IO.File]::Exists($stderrPath)) {
    Get-Content -LiteralPath $stderrPath -Raw -Encoding UTF8
  } else {
    ""
  }
  foreach ($path in @($stdoutPath, $stderrPath)) {
    if ([IO.File]::Exists($path)) {
      [IO.File]::Delete($path)
    }
  }
  if ($process.ExitCode -ne $ExpectedExitCode) {
    throw "$Scenario returned exit code $($process.ExitCode), expected $ExpectedExitCode."
  }
  $resultLine = @($stdout -split "`r?`n" | Where-Object {
    $_.StartsWith("RISE_PALS_LAUNCHER_RESULT=", [StringComparison]::Ordinal)
  })
  $result = $null
  if ($resultLine.Count -eq 1) {
    $json = $resultLine[0].Substring("RISE_PALS_LAUNCHER_RESULT=".Length)
    $result = $json | ConvertFrom-Json
  } elseif ($resultLine.Count -gt 1) {
    throw "$Scenario emitted multiple structured launcher results."
  }
  return [pscustomobject]@{
    scenario = $Scenario
    exitCode = $process.ExitCode
    stdout = $stdout
    stderr = $stderr
    result = $result
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
    if ($null -ne $invalid.result -or
      $invalid.stderr -notmatch "failed closed \(child exit code [0-9]+\)") {
      throw "$scenario did not fail closed through the generic launcher boundary."
    }
    Write-Output ($scenario + " rejection PASS")
  }

  $cleanupFailure = Invoke-RisePalsLauncherSimulation -Scenario "CleanupFailure" `
    -ExpectedExitCode 13 -Repository $repository -ExpectedHead $ExpectedRepositoryHead `
    -SuiteDirectory $suiteRoot
  if ($null -eq $cleanupFailure.result -or $cleanupFailure.result.cleanupCompleted -or
    $cleanupFailure.result.finalResourceCounts.rawCaptureFiles -ne 1 -or
    $cleanupFailure.stderr -notmatch "controlled capture residue count 1") {
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
    [IO.Directory]::Delete($suiteRoot, $true)
  }
}
