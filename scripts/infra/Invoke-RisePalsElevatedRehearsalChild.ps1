[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][ValidateSet("Live", "Simulation")][string]$Mode,
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
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$RequestedRepositoryHead,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9-]{36}$")][string]$InvocationNonce,
  [Parameter(Mandatory = $true)][string]$RepositoryRoot,
  [Parameter(Mandatory = $true)][string]$EvidenceRoot,
  [Parameter(Mandatory = $true)][string]$EvidenceDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "rehearsal-launcher-result.ps1")

function ConvertTo-RisePalsStructuredProcessArgument {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value.Contains('"')) {
    throw "A structured process argument contains a prohibited quote."
  }
  return '"' + $Value + '"'
}

function Assert-RisePalsLauncherEvidenceDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Directory,
    [Parameter(Mandatory = $true)][string]$Nonce
  )

  $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $resolvedDirectory = [IO.Path]::GetFullPath($Directory).TrimEnd(
    [IO.Path]::DirectorySeparatorChar
  )
  $expected = Join-Path $resolvedRoot ("invocation-" + $Nonce)
  if (-not $resolvedDirectory.Equals($expected, [StringComparison]::OrdinalIgnoreCase) -or
    -not [IO.Directory]::Exists($resolvedDirectory)) {
    throw "The launcher evidence directory is not the exact nonce-specific child."
  }
  $item = Get-Item -LiteralPath $resolvedDirectory -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "The launcher evidence directory must not be a reparse point."
  }
  return $resolvedDirectory
}

function Protect-RisePalsLauncherEvidenceDirectory {
  param([Parameter(Mandatory = $true)][string]$Directory)

  $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
  $approvedSids = @(
    $currentSid,
    [Security.Principal.SecurityIdentifier]::new("S-1-5-18"),
    [Security.Principal.SecurityIdentifier]::new("S-1-5-32-544")
  )
  $security = [Security.AccessControl.DirectorySecurity]::new()
  $security.SetAccessRuleProtection($true, $false)
  foreach ($sid in $approvedSids) {
    $rule = [Security.AccessControl.FileSystemAccessRule]::new(
      $sid,
      [Security.AccessControl.FileSystemRights]::FullControl,
      [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [Security.AccessControl.InheritanceFlags]::ObjectInherit,
      [Security.AccessControl.PropagationFlags]::None,
      [Security.AccessControl.AccessControlType]::Allow
    )
    [void]$security.AddAccessRule($rule)
  }
  [IO.Directory]::SetAccessControl($Directory, $security)

  $actual = [IO.Directory]::GetAccessControl(
    $Directory,
    [Security.AccessControl.AccessControlSections]::Access
  )
  if (-not $actual.AreAccessRulesProtected) {
    throw "The launcher evidence directory ACL is not protected."
  }
  $rules = @($actual.GetAccessRules(
    $true,
    $false,
    [Security.Principal.SecurityIdentifier]
  ))
  $expectedValues = @($approvedSids | ForEach-Object { $_.Value } | Sort-Object -Unique)
  if ($rules.Count -ne $expectedValues.Count) {
    throw "The launcher evidence directory has an unexpected ACE count."
  }
  foreach ($rule in $rules) {
    if ($rule.IdentityReference.Value -notin $expectedValues -or
      $rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
      [int]$rule.FileSystemRights -ne [int][Security.AccessControl.FileSystemRights]::FullControl -or
      $rule.IsInherited -or
      [int]$rule.InheritanceFlags -ne 3 -or
      [int]$rule.PropagationFlags -ne 0) {
      throw "The launcher evidence directory ACL is outside the exact approved boundary."
    }
  }
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
    throw "The launcher capture cleanup path is outside the exact evidence directory."
  }
  if ([IO.File]::Exists($resolvedPath)) {
    [IO.File]::Delete($resolvedPath)
  }
}

function Get-RisePalsLiveEvidence {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedHead,
    [Parameter(Mandatory = $true)][DateTimeOffset]$ChildStartedAtUtc
  )

  if (-not [IO.File]::Exists($Path)) {
    return $null
  }
  $evidence = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($evidence.schemaVersion -ne "rise-pals-non-reboot-rehearsal-v1" -or
    $evidence.orchestratorCommit -ne $ExpectedHead -or
    $evidence.sourceCommit -ne $ExpectedHead) {
    return $null
  }
  $started = ConvertFrom-RisePalsLauncherUtcTimestamp -Value $evidence.startedAtUtc `
    -Label "Live rehearsal start"
  if ($started -lt $ChildStartedAtUtc.AddSeconds(-5)) {
    return $null
  }
  return $evidence
}

$resolvedRepository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd(
  [IO.Path]::DirectorySeparatorChar
)
$resolvedEvidenceDirectory = Assert-RisePalsLauncherEvidenceDirectory -Root $EvidenceRoot `
  -Directory $EvidenceDirectory -Nonce $InvocationNonce
if (-not $PSCmdlet.ShouldProcess(
  $resolvedEvidenceDirectory,
  ("Run the structured {0} rehearsal child" -f $Mode.ToLowerInvariant())
)) {
  Write-Output "Rise Pals elevated-rehearsal child dry-run PASS"
  return
}
Protect-RisePalsLauncherEvidenceDirectory -Directory $resolvedEvidenceDirectory

$resultPath = Join-Path $resolvedEvidenceDirectory "result.json"
$temporaryResultPath = Join-Path $resolvedEvidenceDirectory ("result." + $InvocationNonce + ".tmp")
$stdoutPath = Join-Path $resolvedEvidenceDirectory "native.stdout.log"
$stderrPath = Join-Path $resolvedEvidenceDirectory "native.stderr.log"
$startedAt = [DateTimeOffset]::UtcNow

if ($Mode -eq "Simulation" -and $SimulationScenario -eq "MissingResult") {
  exit 9
}
if ($Mode -eq "Simulation" -and $SimulationScenario -eq "MalformedResult") {
  [IO.File]::WriteAllText($temporaryResultPath, "{malformed", [Text.UTF8Encoding]::new($false))
  [IO.File]::Move($temporaryResultPath, $resultPath)
  exit 10
}
if ($Mode -eq "Simulation" -and $SimulationScenario -eq "PartialAtomicResult") {
  [IO.File]::WriteAllText($resultPath, '{"schemaVersion":"partial"', [Text.UTF8Encoding]::new($false))
  exit 11
}

$powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$nativeArguments = @("-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File")
if ($Mode -eq "Live") {
  $rehearsal = Join-Path $PSScriptRoot "Invoke-RisePalsNonRebootRehearsal.ps1"
  $nativeArguments += ConvertTo-RisePalsStructuredProcessArgument -Value $rehearsal
  $nativeArguments += @(
    "-RepositoryRoot",
    (ConvertTo-RisePalsStructuredProcessArgument -Value $resolvedRepository),
    "-LauncherAuthorized",
    "-LauncherInvocationNonce",
    $InvocationNonce
  )
} else {
  $fixture = Join-Path $PSScriptRoot "Invoke-RisePalsLauncherFixture.ps1"
  $fixtureScenario = switch ($SimulationScenario) {
    "NativeFailure" { "NativeFailure" }
    "DualStreamSuccess" { "DualStreamSuccess" }
    "Privacy" { "Privacy" }
    default { "NativeSuccess" }
  }
  $nativeArguments += ConvertTo-RisePalsStructuredProcessArgument -Value $fixture
  $nativeArguments += @("-Scenario", $fixtureScenario)
}

$nativeProcess = Start-Process -FilePath $powerShell -ArgumentList $nativeArguments `
  -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath `
  -WindowStyle Hidden -Wait -PassThru
$nativeExitCode = $nativeProcess.ExitCode
$stdoutBytes = if ([IO.File]::Exists($stdoutPath)) { (Get-Item -LiteralPath $stdoutPath).Length } else { 0 }
$stderrBytes = if ([IO.File]::Exists($stderrPath)) { (Get-Item -LiteralPath $stderrPath).Length } else { 0 }
$stages = @("native-process-started", "native-exit-observed", "stdout-captured", "stderr-captured")
$status = if ($nativeExitCode -eq 0) { "success" } else { "failure" }
$childExitCode = $nativeExitCode
$failedStage = if ($status -eq "failure") { "native-process" } else { $null }
$failureCode = if ($status -eq "failure") { "native-command-exit-nonzero" } else { $null }
$resourceCounts = New-RisePalsLauncherResourceCounts

if ($Mode -eq "Live") {
  $liveEvidencePath = "C:\RisePals\logs\deploy\non-reboot-rehearsal.json"
  $liveEvidence = Get-RisePalsLiveEvidence -Path $liveEvidencePath `
    -ExpectedHead $RequestedRepositoryHead -ChildStartedAtUtc $startedAt
  if ($null -eq $liveEvidence) {
    $status = "failure"
    $childExitCode = if ($nativeExitCode -eq 0) { 21 } else { $nativeExitCode }
    $failedStage = "live-evidence"
    $failureCode = "missing-or-mismatched-live-evidence"
  } else {
    $stageMap = [ordered]@{
      serviceIdentity = "service-identity"
      aclModel = "acl-model"
      forwardSwitch = "forward-switch"
      automaticRollback = "automatic-rollback"
      manualRollback = "manual-rollback"
      independentRestart = "independent-restart"
      gracefulStop = "graceful-stop"
      boundedCrashRecovery = "bounded-crash-recovery"
      certificateReissueAndReload = "certificate-reissue-reload"
      secretLifecycleAndNoLeak = "secret-lifecycle-no-leak"
      loopbackProxyHealth = "loopback-proxy-health"
    }
    foreach ($entry in $stageMap.GetEnumerator()) {
      if ([bool]$liveEvidence.($entry.Key)) {
        $stages += $entry.Value
      }
    }
    $resourceCounts = New-RisePalsLauncherResourceCounts `
      -RootProcesses ([int]$liveEvidence.finalRootProcessCount) `
      -Listeners ([int]$liveEvidence.finalListenerCount) `
      -EnabledFirewallRules ([int]$liveEvidence.finalEnabledFirewallRuleCount) `
      -StagingChildren ([int]$liveEvidence.finalStagingChildCount) `
      -RehearsalChildren ([int]$liveEvidence.finalRehearsalChildCount) `
      -DrainStateFiles ([int]$liveEvidence.finalDrainStateCount) `
      -AtomicTemporaryFiles ([int]$liveEvidence.finalAtomicTemporaryCount) `
      -DrainLockFiles ([int]$liveEvidence.finalDrainLockCount) `
      -SyntheticCanaries ([int]$liveEvidence.finalSyntheticCanaryCount)
    if ($liveEvidence.finalServiceState -eq "Stopped/Disabled" -and
      @($script:RisePalsLauncherResourceCountProperties | Where-Object {
        $_ -notin @("rawCaptureFiles", "resultTemporaryFiles") -and
          $resourceCounts.$_ -ne 0
      }).Count -eq 0) {
      $stages += "final-cleanup"
    }
    if (-not [bool]$liveEvidence.completed -or $nativeExitCode -ne 0) {
      $status = "failure"
      $childExitCode = if ($nativeExitCode -eq 0) { 22 } else { $nativeExitCode }
      $failedStage = "live-rehearsal"
      $failureCode = "live-rehearsal-incomplete"
    }
  }
}

$cleanupCompleted = $true
if ($Mode -eq "Simulation" -and $SimulationScenario -eq "CleanupFailure") {
  Remove-RisePalsLauncherExactFile -Directory $resolvedEvidenceDirectory -Path $stderrPath
  $cleanupCompleted = $false
  $status = "failure"
  $childExitCode = 13
  $failedStage = "capture-cleanup"
  $failureCode = "raw-capture-cleanup-failed"
  $resourceCounts.rawCaptureFiles = 1
} else {
  Remove-RisePalsLauncherExactFile -Directory $resolvedEvidenceDirectory -Path $stdoutPath
  Remove-RisePalsLauncherExactFile -Directory $resolvedEvidenceDirectory -Path $stderrPath
  $stages += "raw-captures-removed"
}

$streamEvidence = [ordered]@{
  stdoutPresent = $stdoutBytes -gt 0
  stderrPresent = $stderrBytes -gt 0
  streamsSeparated = -not $stdoutPath.Equals($stderrPath, [StringComparison]::OrdinalIgnoreCase)
  stdoutBytes = [int64]$stdoutBytes
  stderrBytes = [int64]$stderrBytes
}
$completedAt = [DateTimeOffset]::UtcNow
$resultNonce = if ($SimulationScenario -eq "WrongNonce") {
  [guid]::NewGuid().ToString("D")
} else {
  $InvocationNonce
}
$resultHead = if ($SimulationScenario -eq "WrongRepositoryHead") {
  "0000000000000000000000000000000000000000"
} else {
  $RequestedRepositoryHead
}
$resultStartedAt = if ($SimulationScenario -eq "StaleTimestamp") {
  $startedAt.AddDays(-1).ToString("o")
} else {
  $startedAt.ToString("o")
}
if ($SimulationScenario -eq "ExitCodeDisagreement") {
  $status = "failure"
  $childExitCode = 7
  $failedStage = "native-process"
  $failureCode = "native-command-exit-nonzero"
}

$result = New-RisePalsLauncherResult -InvocationNonce $resultNonce `
  -RequestedRepositoryHead $resultHead -ExecutionMode $Mode.ToLowerInvariant() `
  -StartedAtUtc $resultStartedAt -CompletedAtUtc $completedAt.ToString("o") `
  -Status $status -ChildExitCode $childExitCode -CompletedStages $stages `
  -FailedStage $failedStage -SanitizedFailureCode $failureCode `
  -CleanupCompleted $cleanupCompleted -FinalResourceCounts $resourceCounts `
  -StreamEvidence $streamEvidence
if ($SimulationScenario -eq "DigestMismatch") {
  $result.resultDigest = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
}
Write-RisePalsLauncherResultAtomic -Result $result -ResultPath $resultPath `
  -TemporaryResultPath $temporaryResultPath

if ($SimulationScenario -eq "ExitCodeDisagreement") {
  exit 0
}
exit $childExitCode
