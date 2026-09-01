[CmdletBinding()]
param(
  [string]$RepositoryRoot = "C:\Codex PC SG2\Jeff\risepals",
  [string]$TestOnlyPowerShell7ModuleRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if (-not [string]::IsNullOrWhiteSpace($TestOnlyPowerShell7ModuleRoot)) {
  $testModuleRoot = [IO.Path]::GetFullPath($TestOnlyPowerShell7ModuleRoot).TrimEnd('\')
  $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  $testManifest = Join-Path $testModuleRoot `
    "Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1"
  if (-not $testModuleRoot.StartsWith(
      $temporaryRoot + "\", [StringComparison]::OrdinalIgnoreCase) -or
    -not [IO.Directory]::Exists($testModuleRoot) -or -not [IO.File]::Exists($testManifest)) {
    throw "The test-only PowerShell 7 module root is invalid."
  }
  $env:PSModulePath = $testModuleRoot + ";" + $env:PSModulePath
}
$repository = [IO.Path]::GetFullPath($RepositoryRoot)
$scripts = Join-Path $repository "scripts\infra"
. (Join-Path $scripts "candidate-rehearsal-contract.ps1")
. (Join-Path $scripts "candidate-rehearsal-result.ps1")
. (Join-Path $scripts "candidate-rehearsal-transport.ps1")

function Assert-RisePalsCandidateThrows {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Action,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $threw = $false
  try {
    & $Action
  } catch {
    $threw = $true
  }
  if (-not $threw) {
    throw "$Label was not rejected."
  }
}

function Copy-RisePalsCandidateContract {
  param([Parameter(Mandatory = $true)][object]$Contract)

  return (($Contract | ConvertTo-Json -Depth 20 -Compress) | ConvertFrom-Json)
}

function New-RisePalsCandidateValidRepositorySnapshot {
  param([Parameter(Mandatory = $true)][object]$Contract)

  return [pscustomobject]@{
    branch = [string]$Contract.repository.branch
    head = "1111111111111111111111111111111111111111"
    mainHead = [string]$Contract.repository.mainCommit
    clean = $true
    envLocalIgnored = $true
    envLocalTracked = $false
  }
}

function New-RisePalsCandidateValidHostSnapshot {
  param([Parameter(Mandatory = $true)][object]$Contract)

  return [pscustomobject]@{
    candidateServiceExists = $false
    unexpectedRisePalsServices = @()
    retainedServices = @($Contract.retainedServices | ForEach-Object {
      [pscustomobject][ordered]@{
        name = [string]$_.serviceName
        serviceType = [string]$_.serviceType
        startName = [string]$_.virtualAccount
        pathName = [string]$_.pathName
        executablePath = [string]$_.executablePath
        executableLength = [int64]$_.executableLength
        executableSha256 = [string]$_.executableSha256
        state = [string]$_.expectedState
        startMode = [string]$_.expectedStartMode
        processId = [int]$_.expectedProcessId
      }
    })
    relevantListeners = @()
    processesUnderRoot = @()
    unexpectedPaths = @()
    reparsePaths = @()
    unexpectedAclEntries = @()
    candidateExecutableLength = [int64]$Contract.prototype.executableLength
    candidateExecutableSha256 = [string]$Contract.prototype.executableSha256
    candidateAuthenticode = "NotSigned"
  }
}

function New-RisePalsCandidateValidResult {
  param(
    [string]$Nonce = "0123456789abcdef0123456789abcdef",
    [string]$AuthorizationId = "RP-TURN-019-R4-DIAG2-SIMULATION",
    [string]$Head = "1111111111111111111111111111111111111111",
    [string]$ScriptHash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    [string]$BootstrapHash = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    [string]$TransportHash = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    [string]$ChildHash = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
    [string]$Status = "success",
    [int]$ExitCode = 0,
    [bool]$CleanupCompleted = $true,
    [object]$FinalState = (New-RisePalsCandidateFinalState)
  )

  $now = [DateTimeOffset]::UtcNow
  return New-RisePalsCandidateResult -InvocationNonce $Nonce `
    -AuthorizationId $AuthorizationId -RepositoryHead $Head `
    -LauncherScriptSha256 $ScriptHash -BootstrapScriptSha256 $BootstrapHash `
    -TransportScriptSha256 $TransportHash `
    -ChildScriptSha256 $ChildHash -StartedAtUtc $now.ToString("o") `
    -CompletedAtUtc $now.AddMilliseconds(10).ToString("o") -Status $Status `
    -ChildExitCode $ExitCode -CompletedStages @(
      "child-started", "child-exit-observed", "streams-separated", "raw-output-removed"
    ) `
    -FailedStage $(if ($Status -eq "failure") { "native-child" } else { $null }) `
    -SanitizedFailureCode $(if ($Status -eq "failure") { "native-child-exit-nonzero" } else { $null }) `
    -CleanupCompleted $CleanupCompleted -FinalState $FinalState -StreamEvidence ([ordered]@{
      stdoutObserved = $true
      stderrObserved = $true
      streamsSeparated = $true
      rawOutputPersisted = $false
    })
}

function New-RisePalsCandidateValidMarker {
  param(
    [string]$MarkerType = "bootstrap-started",
    [AllowNull()][string]$FailureCode,
    [DateTimeOffset]$RecordedAtUtc = [DateTimeOffset]::UtcNow
  )

  return New-RisePalsCandidateMarker -MarkerType $MarkerType `
    -InvocationNonce "0123456789abcdef0123456789abcdef" `
    -AuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
    -RepositoryHead "1111111111111111111111111111111111111111" `
    -LauncherScriptSha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" `
    -BootstrapScriptSha256 "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" `
    -TransportScriptSha256 "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc" `
    -ChildScriptSha256 "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd" `
    -SanitizedFailureCode $FailureCode -RecordedAtUtc $RecordedAtUtc
}

function New-RisePalsCandidateValidLaunchDiagnostic {
  param(
    [ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$ExecutionMode = "Simulation",
    [string[]]$Arguments = @("-NoLogo", "-NoProfile")
  )

  return New-RisePalsCandidateLaunchDiagnostic `
    -LaunchAttempted $true -ProcessCreated $true `
    -LaunchDisposition launched -SanitizedLaunchFailureCode none `
    -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
    -LauncherExecutableExists $true -LauncherSignatureStatus valid `
    -LaunchVerb $(if ($ExecutionMode -in @("Live", "ElevationProbe")) {
      "RunAs"
    } else {
      "None"
    }) `
    -ArgumentCount $Arguments.Count `
    -CanonicalArgumentDigest (Get-RisePalsCandidateCanonicalArgumentDigest `
      -Arguments $Arguments)
}

function New-RisePalsCandidateValidProbeDiagnostic {
  return New-RisePalsCandidateProbeDiagnostic -ProbeStatus success `
    -FailedStage $null -SanitizedFailureCode $null `
    -ElevatedChildEntered $true -AdministratorRoleConfirmed $true `
    -IntegrityLevel high -RepositoryHeadMatched $true `
    -AuthorizationMatched $true -InvocationNonceMatched $true `
    -LauncherHashMatched $true -BootstrapHashMatched $true `
    -TransportHashMatched $true -ChildHashMatched $true `
    -LiveSequenceInvoked $false -HostMutationAttempted $false
}

function New-RisePalsCandidateSyntheticLiveResult {
  param(
    [int]$CompletedFunctionalStageCount,
    [AllowNull()][string]$FailedStage,
    [bool]$CleanupCompleted = $true,
    [ValidateSet("success", "failure")][string]$Status = "failure"
  )

  $completed = @($script:RisePalsCandidateFunctionalStageOrder |
    Select-Object -First $CompletedFunctionalStageCount)
  $resultStages = @("child-started", "child-exit-observed", "streams-separated") +
    $completed
  if ($CleanupCompleted) {
    $resultStages += @("cleanup", "final-read-only-proof")
  }
  $resultStages += "raw-output-removed"
  $failureMap = Get-RisePalsCandidateFailureCodeMap
  $failureCode = if ($Status -eq "failure") {
    [string]$failureMap[$FailedStage]
  } else {
    $null
  }
  $mutation = $CompletedFunctionalStageCount -ge 2 -or (
    $CompletedFunctionalStageCount -eq 1 -and $FailedStage -eq "stage-immutable-inputs"
  )
  $install = $CompletedFunctionalStageCount -ge 5 -or (
    $CompletedFunctionalStageCount -eq 4 -and $FailedStage -eq "create-own-process-service"
  )
  $start = $CompletedFunctionalStageCount -ge 8 -or (
    $CompletedFunctionalStageCount -eq 7 -and $FailedStage -eq "start-and-ready"
  )
  $stop = $CompletedFunctionalStageCount -ge 10 -or (
    $CompletedFunctionalStageCount -eq 9 -and $FailedStage -eq "direct-stop"
  )
  $lifecycle = New-RisePalsCandidateLifecycleEvidence `
    -LiveHostMutationBegan $mutation `
    -CandidateServiceInstallationBegan $install `
    -CandidateServiceStartReached $start `
    -DirectStopServiceReached $stop
  $now = [DateTimeOffset]::UtcNow
  return New-RisePalsCandidateResult `
    -InvocationNonce "0123456789abcdef0123456789abcdef" `
    -AuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
    -RepositoryHead ("1" * 40) -LauncherScriptSha256 ("a" * 64) `
    -BootstrapScriptSha256 ("b" * 64) -TransportScriptSha256 ("c" * 64) `
    -ChildScriptSha256 ("d" * 64) -StartedAtUtc $now.ToString("o") `
    -CompletedAtUtc $now.AddMilliseconds(10).ToString("o") `
    -ExecutionMode Live -Status $Status `
    -ChildExitCode $(if ($Status -eq "success") { 0 } else { 23 }) `
    -CompletedStages $resultStages -FailedStage $FailedStage `
    -SanitizedFailureCode $failureCode -CleanupCompleted $CleanupCompleted `
    -LifecycleEvidence $lifecycle `
    -FinalState $(if ($CleanupCompleted) {
      New-RisePalsCandidateFinalState
    } else {
      New-RisePalsCandidateFinalState -TemporaryChildren 1
    }) `
    -StreamEvidence ([ordered]@{
      stdoutObserved = $true
      stderrObserved = $false
      streamsSeparated = $true
      rawOutputPersisted = $false
    })
}

function New-RisePalsCandidateValidParentCheckpoint {
  param(
    [string]$Nonce = "0123456789abcdef0123456789abcdef",
    [string]$AuthorizationId = "RP-TURN-019-R4-DIAG2-SIMULATION",
    [string]$Head = "1111111111111111111111111111111111111111"
  )

  $childResult = New-RisePalsCandidateValidResult -Nonce $Nonce `
    -AuthorizationId $AuthorizationId -Head $Head
  $diagnostic = New-RisePalsCandidateChildDiagnostic -Result $childResult `
    -ExecutionMode Simulation -CleanupResponsibilityTransferredToParent $true
  $launchDiagnostic = New-RisePalsCandidateValidLaunchDiagnostic
  return New-RisePalsCandidateParentCheckpoint -InvocationNonce $Nonce `
    -AuthorizationId $AuthorizationId -RepositoryHead $Head `
    -LauncherScriptSha256 ("a" * 64) -BootstrapScriptSha256 ("b" * 64) `
    -TransportScriptSha256 ("c" * 64) -ChildScriptSha256 ("d" * 64) `
    -ExecutionMode Simulation `
    -LaunchDiagnostic $launchDiagnostic `
    -LaunchDisposition "launched" -Classification "final-present-validated" `
    -ProcessLaunched $true -ElevatedExitCode 0 -BootstrapEntered $true `
    -BootstrapStarted $true -BootstrapFailurePresent $false `
    -ChildLaunchAttempted $true -ChildStarted $true -LiveStarted $true `
    -FinalPresent $true -FinalValidated $true -FinalStatus "success" `
    -ChildDiagnostic $diagnostic
}

$launchArguments = @("-NoLogo", "-NoProfile", "-File", '"candidate.ps1"')
$validLaunchDiagnostic = New-RisePalsCandidateValidLaunchDiagnostic `
  -Arguments $launchArguments
[void](Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $validLaunchDiagnostic)
if ($validLaunchDiagnostic.argumentCount -ne $launchArguments.Count -or
  $validLaunchDiagnostic.canonicalArgumentDigest -ne
    (Get-RisePalsCandidateCanonicalArgumentDigest -Arguments $launchArguments)) {
  throw "The successful launch diagnostic did not bind the canonical argument shape."
}

$outerCancellation = [ComponentModel.Win32Exception]::new(1223)
$outerCancellationEvidence = Get-RisePalsCandidateLaunchExceptionEvidence `
  -Exception $outerCancellation
$innerCancellation = [Exception]::new(
  "synthetic-wrapper",
  [ComponentModel.Win32Exception]::new(1223)
)
$innerCancellationEvidence = Get-RisePalsCandidateLaunchExceptionEvidence `
  -Exception $innerCancellation
foreach ($evidence in @($outerCancellationEvidence, $innerCancellationEvidence)) {
  if ($evidence.nativeErrorCode -ne 1223 -or
    (Get-RisePalsCandidateSanitizedLaunchFailureCode `
      -NativeErrorCode $evidence.nativeErrorCode) -ne "uac-cancelled") {
    throw "UAC cancellation was not detected across the bounded exception chain."
  }
  $cancelledDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
    -LaunchAttempted $true -ProcessCreated $false -LaunchDisposition cancelled `
    -SanitizedLaunchFailureCode uac-cancelled `
    -NativeErrorCode $evidence.nativeErrorCode -HResult $evidence.hResult `
    -ExceptionDepth $evidence.exceptionDepth -LauncherExecutableExists $true `
    -LauncherSignatureStatus valid -LaunchVerb RunAs `
    -ArgumentCount $launchArguments.Count `
    -CanonicalArgumentDigest (Get-RisePalsCandidateCanonicalArgumentDigest `
      -Arguments $launchArguments)
  [void](Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $cancelledDiagnostic)
  $serializedCancellation = $cancelledDiagnostic | ConvertTo-Json -Depth 5 -Compress
  if ($serializedCancellation.Contains("synthetic-wrapper") -or
    $serializedCancellation.Contains("Win32Exception") -or
    $serializedCancellation.Contains("System.Exception")) {
    throw "A launch diagnostic retained prohibited exception text or type evidence."
  }
}

$nativeFailureCases = @(
  @{ Native = 2; Code = "launcher-target-not-found" },
  @{ Native = 5; Code = "launcher-access-denied" },
  @{ Native = 31; Code = "shell-execute-failed" },
  @{ Native = 8; Code = "process-start-failed" },
  @{ Native = 87; Code = "malformed-launch-request" },
  @{ Native = 9999; Code = "launcher-exception-unknown" }
)
foreach ($case in $nativeFailureCases) {
  if ((Get-RisePalsCandidateSanitizedLaunchFailureCode `
      -NativeErrorCode $case.Native) -ne $case.Code) {
    throw "A native launch failure did not map to its fixed classification."
  }
  $mappedDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
    -LaunchAttempted $true -ProcessCreated $false `
    -LaunchDisposition launch-failure -SanitizedLaunchFailureCode $case.Code `
    -NativeErrorCode $case.Native -HResult -2147467259 -ExceptionDepth 1 `
    -LauncherExecutableExists $true -LauncherSignatureStatus valid `
    -LaunchVerb RunAs -ArgumentCount $launchArguments.Count `
    -CanonicalArgumentDigest (Get-RisePalsCandidateCanonicalArgumentDigest `
      -Arguments $launchArguments)
  [void](Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $mappedDiagnostic)
}
if ((Get-RisePalsCandidateSanitizedLaunchFailureCode -NativeErrorCode $null) -ne
  "launcher-exception-unknown") {
  throw "A launch exception without a native code was not closed to unknown."
}
$noNativeEvidence = Get-RisePalsCandidateLaunchExceptionEvidence `
  -Exception ([Exception]::new("synthetic-no-native"))
$noNativeDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
  -LaunchAttempted $true -ProcessCreated $false -LaunchDisposition launch-failure `
  -SanitizedLaunchFailureCode launcher-exception-unknown `
  -NativeErrorCode $null -HResult $noNativeEvidence.hResult `
  -ExceptionDepth $noNativeEvidence.exceptionDepth -LauncherExecutableExists $true `
  -LauncherSignatureStatus valid -LaunchVerb RunAs `
  -ArgumentCount $launchArguments.Count `
  -CanonicalArgumentDigest (Get-RisePalsCandidateCanonicalArgumentDigest `
    -Arguments $launchArguments)
[void](Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $noNativeDiagnostic)

$preflightDiagnostics = @(
  (New-RisePalsCandidateLaunchDiagnostic -LaunchAttempted $false `
    -ProcessCreated $false -LaunchDisposition launch-failure `
    -SanitizedLaunchFailureCode launcher-target-not-found `
    -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
    -LauncherExecutableExists $false -LauncherSignatureStatus unavailable `
    -LaunchVerb RunAs -ArgumentCount $launchArguments.Count `
    -CanonicalArgumentDigest (Get-RisePalsCandidateCanonicalArgumentDigest `
      -Arguments $launchArguments)),
  (New-RisePalsCandidateLaunchDiagnostic -LaunchAttempted $false `
    -ProcessCreated $false -LaunchDisposition launch-failure `
    -SanitizedLaunchFailureCode launcher-access-denied `
    -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
    -LauncherExecutableExists $true -LauncherSignatureStatus unavailable `
    -LaunchVerb RunAs -ArgumentCount $launchArguments.Count `
    -CanonicalArgumentDigest (Get-RisePalsCandidateCanonicalArgumentDigest `
      -Arguments $launchArguments)),
  (New-RisePalsCandidateLaunchDiagnostic -LaunchAttempted $false `
    -ProcessCreated $false -LaunchDisposition launch-failure `
    -SanitizedLaunchFailureCode shell-execute-failed `
    -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
    -LauncherExecutableExists $true -LauncherSignatureStatus invalid `
    -LaunchVerb RunAs -ArgumentCount $launchArguments.Count `
    -CanonicalArgumentDigest (Get-RisePalsCandidateCanonicalArgumentDigest `
      -Arguments $launchArguments)),
  (New-RisePalsCandidateLaunchDiagnostic -LaunchAttempted $false `
    -ProcessCreated $false -LaunchDisposition launch-failure `
    -SanitizedLaunchFailureCode malformed-launch-request `
    -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
    -LauncherExecutableExists $true -LauncherSignatureStatus valid `
    -LaunchVerb RunAs -ArgumentCount 0 `
    -CanonicalArgumentDigest (Get-RisePalsCandidateCanonicalArgumentDigest `
      -Arguments @())),
  (New-RisePalsCandidateLaunchDiagnostic -LaunchAttempted $true `
    -ProcessCreated $false -LaunchDisposition launch-failure `
    -SanitizedLaunchFailureCode process-start-failed `
    -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
    -LauncherExecutableExists $true -LauncherSignatureStatus valid `
    -LaunchVerb RunAs -ArgumentCount $launchArguments.Count `
    -CanonicalArgumentDigest (Get-RisePalsCandidateCanonicalArgumentDigest `
      -Arguments $launchArguments))
)
foreach ($diagnostic in $preflightDiagnostics) {
  [void](Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $diagnostic)
}
$inconsistentPreflight = New-RisePalsCandidateLaunchDiagnostic `
  -LaunchAttempted $false -ProcessCreated $false `
  -LaunchDisposition launch-failure `
  -SanitizedLaunchFailureCode launcher-access-denied `
  -NativeErrorCode $null -HResult $null -ExceptionDepth 0 `
  -LauncherExecutableExists $true -LauncherSignatureStatus valid `
  -LaunchVerb RunAs -ArgumentCount $launchArguments.Count `
  -CanonicalArgumentDigest (Get-RisePalsCandidateCanonicalArgumentDigest `
    -Arguments $launchArguments)
Assert-RisePalsCandidateThrows -Label "Inconsistent launch preflight facts" -Action {
  Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $inconsistentPreflight
}

foreach ($tamper in @("missing-property", "extra-property", "argument-digest", "diagnostic-digest", "process-created", "string-boolean")) {
  $invalidLaunchDiagnostic = Copy-RisePalsCandidateContract `
    -Contract $validLaunchDiagnostic
  switch ($tamper) {
    "missing-property" {
      $invalidLaunchDiagnostic.PSObject.Properties.Remove("argumentCount")
    }
    "extra-property" {
      $invalidLaunchDiagnostic | Add-Member -NotePropertyName rawArguments `
        -NotePropertyValue @("prohibited")
    }
    "argument-digest" { $invalidLaunchDiagnostic.canonicalArgumentDigest = "f" * 64 }
    "diagnostic-digest" { $invalidLaunchDiagnostic.diagnosticDigest = "f" * 64 }
    "process-created" { $invalidLaunchDiagnostic.processCreated = $false }
    "string-boolean" { $invalidLaunchDiagnostic.launchAttempted = "true" }
  }
  Assert-RisePalsCandidateThrows -Label ("Launch diagnostic " + $tamper) -Action {
    Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $invalidLaunchDiagnostic
  }
}

$failureLaunchDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
  -LaunchAttempted $true -ProcessCreated $false -LaunchDisposition launch-failure `
  -SanitizedLaunchFailureCode launcher-access-denied `
  -NativeErrorCode 5 -HResult -2147467259 -ExceptionDepth 1 `
  -LauncherExecutableExists $true -LauncherSignatureStatus valid `
  -LaunchVerb RunAs -ArgumentCount $launchArguments.Count `
  -CanonicalArgumentDigest (Get-RisePalsCandidateCanonicalArgumentDigest `
    -Arguments $launchArguments)
[void](Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $failureLaunchDiagnostic)
$emptyLiveChildDiagnostic = New-RisePalsCandidateChildDiagnostic -Result $null `
  -ExecutionMode Live -CleanupResponsibilityTransferredToParent $true
$failureClaimingStages = New-RisePalsCandidateParentCheckpoint `
  -InvocationNonce "abcdefabcdefabcdefabcdefabcdefab" `
  -AuthorizationId "RP-TURN-019-R4-DIAG3-SIMULATION" `
  -RepositoryHead ("1" * 40) -LauncherScriptSha256 ("a" * 64) `
  -BootstrapScriptSha256 ("b" * 64) -TransportScriptSha256 ("c" * 64) `
  -ChildScriptSha256 ("d" * 64) -ExecutionMode Live `
  -LaunchDiagnostic $failureLaunchDiagnostic `
  -LaunchDisposition launch-failure -Classification elevated-process-launch-failure `
  -ProcessLaunched $false -ElevatedExitCode -1 -BootstrapEntered $true `
  -BootstrapStarted $true -BootstrapFailurePresent $false `
  -ChildLaunchAttempted $true -ChildStarted $false -LiveStarted $false `
  -FinalPresent $false -FinalValidated $false -FinalStatus $null `
  -ChildDiagnostic $emptyLiveChildDiagnostic
Assert-RisePalsCandidateThrows -Label "Launch failure claiming a later stage" -Action {
  Assert-RisePalsCandidateParentCheckpoint -Checkpoint $failureClaimingStages `
    -ExpectedNonce "abcdefabcdefabcdefabcdefabcdefab" `
    -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG3-SIMULATION" `
    -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
    -ExpectedBootstrapScriptSha256 ("b" * 64) `
    -ExpectedTransportScriptSha256 ("c" * 64) `
    -ExpectedChildScriptSha256 ("d" * 64) `
    -ExpectedLaunchDiagnosticDigest $failureLaunchDiagnostic.diagnosticDigest `
    -ExpectedExecutionMode Live -InvocationStartedAtUtc ([DateTimeOffset]::UtcNow.AddMinutes(-1)) `
    -ConsumedNonces @{}
}
Write-Output "Authenticated closed elevated-launch diagnostic unit simulations PASS"

$probeNonce = "fedcba9876543210fedcba9876543210"
$probeAuthorization = "RP-TURN-019-R4-PROBE-A1B2C3D4"
$liveAuthorization = "RP-TURN-019-R4-LIVE-A1B2C3D4"
$canonicalLaunchValues = @{
  SimulationScenario = "success"
  RepositoryRoot = $repository
  RepositoryHead = ("1" * 40)
  InvocationNonce = $probeNonce
  ResultRoot = (Join-Path ([IO.Path]::GetTempPath()) "risepals-probe-builder")
  InvocationDirectory = (Join-Path ([IO.Path]::GetTempPath()) "risepals-probe-builder\invocation")
  LauncherScriptPath = (Join-Path $scripts "Invoke-RisePalsCandidateRehearsal.ps1")
  LauncherScriptSha256 = ("a" * 64)
  BootstrapScriptPath = (Join-Path $scripts "Invoke-RisePalsCandidateElevatedBootstrap.ps1")
  BootstrapScriptSha256 = ("b" * 64)
  TransportScriptPath = (Join-Path $scripts "candidate-rehearsal-transport.ps1")
  TransportScriptSha256 = ("c" * 64)
  ChildScriptPath = (Join-Path $scripts "Invoke-RisePalsCandidateElevationProbeChild.ps1")
  ChildScriptSha256 = ("d" * 64)
  CandidateExecutableSource = ""
  NodeExecutableSource = ""
}
$liveLaunchRequest = New-RisePalsCandidateCanonicalLaunchRequest `
  @canonicalLaunchValues -ExecutionMode Live -AuthorizationId $liveAuthorization
$probeLaunchRequest = New-RisePalsCandidateCanonicalLaunchRequest `
  @canonicalLaunchValues -ExecutionMode ElevationProbe -AuthorizationId $probeAuthorization
if ($liveLaunchRequest.filePath -ne $probeLaunchRequest.filePath -or
  $liveLaunchRequest.verb -ne "RunAs" -or $probeLaunchRequest.verb -ne "RunAs" -or
  $liveLaunchRequest.windowStyle -ne $probeLaunchRequest.windowStyle -or
  $liveLaunchRequest.waitRequested -ne $probeLaunchRequest.waitRequested -or
  $liveLaunchRequest.passThruRequested -ne $probeLaunchRequest.passThruRequested -or
  $liveLaunchRequest.argumentCount -ne $probeLaunchRequest.argumentCount) {
  throw "Live and ElevationProbe do not share one canonical RunAs launch shape."
}
$normalizedLiveArguments = @($liveLaunchRequest.arguments)
$normalizedProbeArguments = @($probeLaunchRequest.arguments)
foreach ($flag in @("-Mode", "-AuthorizationId", "-FutureAuthorizationId")) {
  $liveIndex = [Array]::IndexOf($normalizedLiveArguments, $flag)
  $probeIndex = [Array]::IndexOf($normalizedProbeArguments, $flag)
  if ($liveIndex -lt 0 -or $probeIndex -ne $liveIndex) {
    throw "A canonical mode-bound launch argument is missing or reordered."
  }
  $normalizedLiveArguments[$liveIndex + 1] = "<mode-bound>"
  $normalizedProbeArguments[$probeIndex + 1] = "<mode-bound>"
}
if (@(Compare-Object -ReferenceObject $normalizedLiveArguments `
    -DifferenceObject $normalizedProbeArguments -SyncWindow 0).Count -ne 0) {
  throw "Live and ElevationProbe canonical launch machinery diverged."
}
Assert-RisePalsCandidateThrows -Label "Live accepting probe authorization" -Action {
  Assert-RisePalsCandidateModeAuthorization -ExecutionMode Live `
    -AuthorizationId $probeAuthorization
}
Assert-RisePalsCandidateThrows -Label "Probe accepting Live authorization" -Action {
  Assert-RisePalsCandidateModeAuthorization -ExecutionMode ElevationProbe `
    -AuthorizationId $liveAuthorization
}

$validProbeDiagnostic = New-RisePalsCandidateValidProbeDiagnostic
[void](Assert-RisePalsCandidateProbeDiagnostic -Diagnostic $validProbeDiagnostic)
foreach ($property in @(
    "repositoryHeadMatched", "authorizationMatched", "invocationNonceMatched",
    "launcherHashMatched", "bootstrapHashMatched", "transportHashMatched",
    "childHashMatched"
  )) {
  $failureParameters = @{
    ProbeStatus = "failure"
    FailedStage = "probe-entry-validation"
    SanitizedFailureCode = "probe-provenance-mismatch"
    ElevatedChildEntered = $true
    AdministratorRoleConfirmed = $true
    IntegrityLevel = "high"
    RepositoryHeadMatched = $true
    AuthorizationMatched = $true
    InvocationNonceMatched = $true
    LauncherHashMatched = $true
    BootstrapHashMatched = $true
    TransportHashMatched = $true
    ChildHashMatched = $true
    LiveSequenceInvoked = $false
    HostMutationAttempted = $false
  }
  $failureParameters[$property.Substring(0, 1).ToUpperInvariant() + $property.Substring(1)] = $false
  $provenanceFailure = New-RisePalsCandidateProbeDiagnostic @failureParameters
  if (Test-RisePalsCandidateProbeDiagnosticSuccess -Diagnostic $provenanceFailure) {
    throw "A probe provenance mismatch qualified as success."
  }
}
$insufficientProbeDiagnostic = New-RisePalsCandidateProbeDiagnostic `
  -ProbeStatus failure -FailedStage probe-elevation-validation `
  -SanitizedFailureCode probe-insufficient-elevation `
  -ElevatedChildEntered $true -AdministratorRoleConfirmed $false `
  -IntegrityLevel insufficient -RepositoryHeadMatched $true `
  -AuthorizationMatched $true -InvocationNonceMatched $true `
  -LauncherHashMatched $true -BootstrapHashMatched $true `
  -TransportHashMatched $true -ChildHashMatched $true
foreach ($tamper in @("missing-property", "extra-property", "digest", "live", "mutation")) {
  $invalidProbe = Copy-RisePalsCandidateContract -Contract $validProbeDiagnostic
  switch ($tamper) {
    "missing-property" { $invalidProbe.PSObject.Properties.Remove("integrityLevel") }
    "extra-property" { $invalidProbe | Add-Member -NotePropertyName accountName -NotePropertyValue "prohibited" }
    "digest" { $invalidProbe.probeDigest = "f" * 64 }
    "live" {
      $invalidProbe.liveSequenceInvoked = $true
      $invalidProbe.probeDigest = Get-RisePalsCandidateProbeDiagnosticDigest -Diagnostic $invalidProbe
    }
    "mutation" {
      $invalidProbe.hostMutationAttempted = $true
      $invalidProbe.probeDigest = Get-RisePalsCandidateProbeDiagnosticDigest -Diagnostic $invalidProbe
    }
  }
  Assert-RisePalsCandidateThrows -Label ("Probe diagnostic " + $tamper) -Action {
    Assert-RisePalsCandidateProbeDiagnostic -Diagnostic $invalidProbe
  }
}

$probeChildDiagnostic = New-RisePalsCandidateChildDiagnostic -Result $null `
  -ExecutionMode ElevationProbe -CleanupResponsibilityTransferredToParent $true
if (Test-RisePalsCandidateDiagnosticFunctionalSuccess -Diagnostic $probeChildDiagnostic) {
  throw "ElevationProbe incorrectly satisfied the Live functional-success predicate."
}
foreach ($gate in @($script:RisePalsCandidateFunctionalGateMap.Keys)) {
  if ($probeChildDiagnostic.functionalGates.$gate -ne "not_applicable") {
    throw "An ElevationProbe Live gate was not marked not_applicable."
  }
}
foreach ($lifecycleProperty in $script:RisePalsCandidateLifecycleEvidenceProperties) {
  if ([bool]$probeChildDiagnostic.$lifecycleProperty) {
    throw "An ElevationProbe Live lifecycle boolean was true."
  }
}
$invalidProbeGate = Copy-RisePalsCandidateContract -Contract $probeChildDiagnostic
$invalidProbeGate.functionalGates.immutableInputStaging = "passed"
$invalidProbeGate.diagnosticDigest = Get-RisePalsCandidateChildDiagnosticDigest `
  -Diagnostic $invalidProbeGate
Assert-RisePalsCandidateThrows -Label "Probe claiming a Live gate" -Action {
  Assert-RisePalsCandidateChildDiagnostic -Diagnostic $invalidProbeGate
}
$invalidProbeLifecycle = Copy-RisePalsCandidateContract -Contract $probeChildDiagnostic
$invalidProbeLifecycle.liveHostMutationBegan = $true
$invalidProbeLifecycle.diagnosticDigest = Get-RisePalsCandidateChildDiagnosticDigest `
  -Diagnostic $invalidProbeLifecycle
Assert-RisePalsCandidateThrows -Label "Probe claiming a Live lifecycle state" -Action {
  Assert-RisePalsCandidateChildDiagnostic -Diagnostic $invalidProbeLifecycle
}

$probeLaunchDiagnostic = New-RisePalsCandidateValidLaunchDiagnostic `
  -ExecutionMode ElevationProbe -Arguments $probeLaunchRequest.arguments
$probeCheckpoint = New-RisePalsCandidateParentCheckpoint `
  -InvocationNonce $probeNonce -AuthorizationId $probeAuthorization `
  -RepositoryHead ("1" * 40) -LauncherScriptSha256 ("a" * 64) `
  -BootstrapScriptSha256 ("b" * 64) -TransportScriptSha256 ("c" * 64) `
  -ChildScriptSha256 ("d" * 64) -ExecutionMode ElevationProbe `
  -LaunchDiagnostic $probeLaunchDiagnostic -ProbeDiagnostic $validProbeDiagnostic `
  -LaunchDisposition launched -Classification elevation-probe-success `
  -ProcessLaunched $true -ElevatedExitCode 0 -BootstrapEntered $true `
  -BootstrapStarted $true -BootstrapFailurePresent $false `
  -ChildLaunchAttempted $true -ChildStarted $true -LiveStarted $false `
  -FinalPresent $true -FinalValidated $true -FinalStatus success `
  -ChildDiagnostic $probeChildDiagnostic
$probeStarted = [DateTimeOffset]::UtcNow.AddMinutes(-1)
[void](Assert-RisePalsCandidateParentCheckpoint -Checkpoint $probeCheckpoint `
  -ExpectedNonce $probeNonce -ExpectedAuthorizationId $probeAuthorization `
  -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
  -ExpectedBootstrapScriptSha256 ("b" * 64) `
  -ExpectedTransportScriptSha256 ("c" * 64) `
  -ExpectedChildScriptSha256 ("d" * 64) `
  -ExpectedLaunchDiagnosticDigest $probeLaunchDiagnostic.diagnosticDigest `
  -ExpectedProbeDiagnosticDigest $validProbeDiagnostic.probeDigest `
  -ExpectedExecutionMode ElevationProbe -InvocationStartedAtUtc $probeStarted `
  -ConsumedNonces @{})
$probeCheckpointFileName = "candidate-parent-checkpoint-$probeNonce.json"
$probeParentResult = New-RisePalsCandidateParentResult -Checkpoint $probeCheckpoint `
  -CheckpointFileName $probeCheckpointFileName `
  -CheckpointDigest $probeCheckpoint.checkpointDigest `
  -DurableCheckpointValidated $true -TransientCleanupAttempted $true `
  -TransientCleanupCompleted $true -InvocationDirectoryAbsent $true `
  -RemainingTransientObjectCount 0 -RemainingTemporaryObjectCount 0
[void](Assert-RisePalsCandidateParentResult -Result $probeParentResult `
  -ExpectedNonce $probeNonce -ExpectedAuthorizationId $probeAuthorization `
  -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
  -ExpectedBootstrapScriptSha256 ("b" * 64) `
  -ExpectedTransportScriptSha256 ("c" * 64) `
  -ExpectedChildScriptSha256 ("d" * 64) `
  -ExpectedCheckpointFileName $probeCheckpointFileName `
  -ExpectedCheckpointDigest $probeCheckpoint.checkpointDigest `
  -ExpectedLaunchDiagnosticDigest $probeLaunchDiagnostic.diagnosticDigest `
  -ExpectedChildDiagnosticDigest $probeChildDiagnostic.diagnosticDigest `
  -ExpectedProbeDiagnosticDigest $validProbeDiagnostic.probeDigest `
  -ExpectedExecutionMode ElevationProbe -InvocationStartedAtUtc $probeStarted `
  -ConsumedNonces @{})
if ($probeParentResult.overallStatus -ne "success" -or
  $probeParentResult.functionalClassification -ne "elevation-probe-success") {
  throw "The successful simulated probe did not preserve its distinct classification."
}
$mismatchedProbeResult = Copy-RisePalsCandidateContract -Contract $probeParentResult
$systemProbe = Copy-RisePalsCandidateContract -Contract $validProbeDiagnostic
$systemProbe.integrityLevel = "system"
$systemProbe.probeDigest = Get-RisePalsCandidateProbeDiagnosticDigest -Diagnostic $systemProbe
$mismatchedProbeResult.probeDiagnostic = $systemProbe
$mismatchedProbeResult.resultDigest = Get-RisePalsCandidateParentResultDigest `
  -Result $mismatchedProbeResult
Assert-RisePalsCandidateThrows -Label "Checkpoint/result probe-digest mismatch" -Action {
  Assert-RisePalsCandidateParentResult -Result $mismatchedProbeResult `
    -ExpectedNonce $probeNonce -ExpectedAuthorizationId $probeAuthorization `
    -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
    -ExpectedBootstrapScriptSha256 ("b" * 64) `
    -ExpectedTransportScriptSha256 ("c" * 64) `
    -ExpectedChildScriptSha256 ("d" * 64) `
    -ExpectedCheckpointFileName $probeCheckpointFileName `
    -ExpectedCheckpointDigest $probeCheckpoint.checkpointDigest `
    -ExpectedLaunchDiagnosticDigest $probeLaunchDiagnostic.diagnosticDigest `
    -ExpectedChildDiagnosticDigest $probeChildDiagnostic.diagnosticDigest `
    -ExpectedProbeDiagnosticDigest $validProbeDiagnostic.probeDigest `
    -ExpectedExecutionMode ElevationProbe -InvocationStartedAtUtc $probeStarted `
    -ConsumedNonces @{}
}
$failedProbeClassification = Resolve-RisePalsCandidateParentClassification `
  -ExecutionMode ElevationProbe -LaunchDisposition launched `
  -BootstrapEntered $true -ChildLaunchAttempted $true -ChildStarted $true `
  -LiveStarted $false -FinalPresent $true -FinalValidated $true `
  -EvidenceInvalid $false -FinalStatus failure `
  -ProbeDiagnostic $insufficientProbeDiagnostic
if ($failedProbeClassification -ne "elevation-probe-failure") {
  throw "A post-entry probe failure lost its sanitized probe classification."
}
$probeCleanupFailure = New-RisePalsCandidateParentResult -Checkpoint $probeCheckpoint `
  -CheckpointFileName $probeCheckpointFileName `
  -CheckpointDigest $probeCheckpoint.checkpointDigest `
  -DurableCheckpointValidated $true -TransientCleanupAttempted $true `
  -TransientCleanupCompleted $false -InvocationDirectoryAbsent $false `
  -RemainingTransientObjectCount 1 -RemainingTemporaryObjectCount 1 `
  -RemainingTransientRelativePaths @("probe-result.json.tmp")
[void](Assert-RisePalsCandidateParentResult -Result $probeCleanupFailure `
  -ExpectedNonce $probeNonce -ExpectedAuthorizationId $probeAuthorization `
  -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
  -ExpectedBootstrapScriptSha256 ("b" * 64) `
  -ExpectedTransportScriptSha256 ("c" * 64) `
  -ExpectedChildScriptSha256 ("d" * 64) `
  -ExpectedCheckpointFileName $probeCheckpointFileName `
  -ExpectedCheckpointDigest $probeCheckpoint.checkpointDigest `
  -ExpectedLaunchDiagnosticDigest $probeLaunchDiagnostic.diagnosticDigest `
  -ExpectedChildDiagnosticDigest $probeChildDiagnostic.diagnosticDigest `
  -ExpectedProbeDiagnosticDigest $validProbeDiagnostic.probeDigest `
  -ExpectedExecutionMode ElevationProbe -InvocationStartedAtUtc $probeStarted `
  -ConsumedNonces @{})
if ($probeCleanupFailure.overallStatus -ne "failure" -or
  $probeCleanupFailure.remainingTransientRelativePaths[0] -ne "probe-result.json.tmp") {
  throw "Probe cleanup failure did not retain truthful sanitized residue evidence."
}
Write-Output "Non-mutating ElevationProbe launch/diagnostic/transport simulations PASS"

$contract = Get-RisePalsCandidateContract -RepositoryRoot $repository
Write-Output "Candidate contract and accepted artifact pins PASS"

foreach ($failure in @(
    "version",
    "assemblyVersion",
    "fileVersion",
    "informationalVersion",
    "includeSourceRevision",
    "productionSourceTree",
    "outerCommitExclusion",
    "executableLength",
    "executableSha256"
  )) {
  $invalid = Copy-RisePalsCandidateContract -Contract $contract
  switch ($failure) {
    "version" { $invalid.prototype.artifactIdentity.version = "0.1.1-rp19-prototype" }
    "assemblyVersion" { $invalid.prototype.artifactIdentity.assemblyVersion = "0.1.1.0" }
    "fileVersion" { $invalid.prototype.artifactIdentity.fileVersion = "0.1.1.0" }
    "informationalVersion" {
      $invalid.prototype.artifactIdentity.informationalVersion = "0.1.0-rp19-prototype+volatile"
    }
    "includeSourceRevision" {
      $invalid.prototype.artifactIdentity.includeSourceRevisionInInformationalVersion = $true
    }
    "productionSourceTree" {
      $invalid.prototype.artifactIdentity.serviceHostProductionSourceTree =
        "1111111111111111111111111111111111111111"
    }
    "outerCommitExclusion" {
      $invalid.prototype.artifactIdentity.volatileOuterRepositoryCommitMetadataExcluded = $false
    }
    "executableLength" { $invalid.prototype.executableLength++ }
    "executableSha256" {
      $invalid.prototype.executableSha256 =
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    }
  }
  Assert-RisePalsCandidateThrows -Label ("Artifact identity " + $failure) -Action {
    Assert-RisePalsCandidateContract -Contract $invalid -RepositoryRoot $repository
  }
}
Write-Output "Context-independent assembly identity and artifact-pin rejection gates PASS"

$nodeMetadata = [pscustomobject][ordered]@{
  path = [string]$contract.node.sourcePath
  version = [string]$contract.node.version
  executableLength = [int64]$contract.node.executableLength
  executableSha256 = [string]$contract.node.executableSha256
  authenticode = [string]$contract.node.authenticode
  signerSubject = [string]$contract.node.signerSubject
  signerThumbprint = [string]$contract.node.signerThumbprint
}
Assert-RisePalsCandidateNodeMetadata -Metadata $nodeMetadata -Contract $contract.node `
  -RequireSourcePath
$invalidNodeHash = $nodeMetadata.PSObject.Copy()
$invalidNodeHash.executableSha256 = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
Assert-RisePalsCandidateThrows -Label "Node source hash mismatch" -Action {
  Assert-RisePalsCandidateNodeMetadata -Metadata $invalidNodeHash -Contract $contract.node `
    -RequireSourcePath
}
$invalidNodeSignature = $nodeMetadata.PSObject.Copy()
$invalidNodeSignature.authenticode = "NotSigned"
Assert-RisePalsCandidateThrows -Label "Node source signature mismatch" -Action {
  Assert-RisePalsCandidateNodeMetadata -Metadata $invalidNodeSignature `
    -Contract $contract.node -RequireSourcePath
}
$stagedNode = $nodeMetadata.PSObject.Copy()
$stagedNode.path = "C:\RisePals\staging\candidate-0123456789abcdef0123456789abcdef\runtime\node.exe"
Assert-RisePalsCandidateNodeMetadata -Metadata $stagedNode -Contract $contract.node
$stagedNode.executableLength++
Assert-RisePalsCandidateThrows -Label "Staged Node mismatch" -Action {
  Assert-RisePalsCandidateNodeMetadata -Metadata $stagedNode -Contract $contract.node
}
Write-Output "Node source/version/hash/signature and staged-copy mismatch gates PASS"

$preshutdownRegistration = [pscustomobject]@{
  TimeoutMilliseconds = [uint32]$contract.timing.preshutdownTimeoutMilliseconds
  AcceptsPreshutdown = $true
}
Assert-RisePalsCandidatePreshutdownRegistration -Registration $preshutdownRegistration `
  -Contract $contract
$invalidPreshutdownTimeout = $preshutdownRegistration.PSObject.Copy()
$invalidPreshutdownTimeout.TimeoutMilliseconds--
Assert-RisePalsCandidateThrows -Label "Preshutdown timeout mismatch" -Action {
  Assert-RisePalsCandidatePreshutdownRegistration -Registration $invalidPreshutdownTimeout `
    -Contract $contract
}
$invalidPreshutdownControls = $preshutdownRegistration.PSObject.Copy()
$invalidPreshutdownControls.AcceptsPreshutdown = $false
Assert-RisePalsCandidateThrows -Label "Preshutdown accepted-control mismatch" -Action {
  Assert-RisePalsCandidatePreshutdownRegistration -Registration $invalidPreshutdownControls `
    -Contract $contract
}
Write-Output "Read-only Preshutdown timeout/accepted-control model PASS"

$sid = Get-RisePalsServiceSid -ServiceName "RisePalsServiceHostCandidate"
if ($sid -ne $contract.candidate.serviceSid) {
  throw "Candidate SID derivation did not match the fixed contract."
}
Write-Output "Candidate virtual-account SID derivation PASS"

$nonce = "0123456789abcdef0123456789abcdef"
$plan = New-RisePalsCandidateInstallationPlan -Contract $contract -Nonce $nonce `
  -RepositoryHead "1111111111111111111111111111111111111111" `
  -LauncherScriptSha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
if ([bool]$plan.liveExecutionAuthorized -or $plan.serviceName -ne "RisePalsServiceHostCandidate" -or
  $plan.serviceType -ne "SERVICE_WIN32_OWN_PROCESS" -or $plan.startMode -ne "demand" -or
  @($plan.rehearsalStages).Count -ne @($contract.rehearsalStages).Count) {
  throw "The repository-only candidate plan changed its fixed boundary."
}
$before = @(Get-CimInstance Win32_Service -Filter "Name LIKE 'RisePals%'" | ForEach-Object {
  "{0}|{1}|{2}|{3}" -f $_.Name, $_.State, $_.StartMode, $_.ProcessId
})
$secondPlan = New-RisePalsCandidateInstallationPlan -Contract $contract -Nonce $nonce `
  -RepositoryHead "1111111111111111111111111111111111111111" `
  -LauncherScriptSha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
$after = @(Get-CimInstance Win32_Service -Filter "Name LIKE 'RisePals%'" | ForEach-Object {
  "{0}|{1}|{2}|{3}" -f $_.Name, $_.State, $_.StartMode, $_.ProcessId
})
if (($plan | ConvertTo-Json -Depth 8 -Compress) -ne
  ($secondPlan | ConvertTo-Json -Depth 8 -Compress) -or
  @(Compare-Object -ReferenceObject $before -DifferenceObject $after).Count -ne 0) {
  throw "Candidate plan mode was not deterministic and zero-mutation."
}
Write-Output "Deterministic WhatIf/plan zero-service-mutation PASS"

$repositorySnapshot = New-RisePalsCandidateValidRepositorySnapshot -Contract $contract
Assert-RisePalsCandidateRepositorySnapshot -Snapshot $repositorySnapshot `
  -Contract $contract -ExpectedHead $repositorySnapshot.head
foreach ($property in @("branch", "head", "mainHead", "clean", "envLocalIgnored", "envLocalTracked")) {
  $invalid = New-RisePalsCandidateValidRepositorySnapshot -Contract $contract
  switch ($property) {
    "branch" { $invalid.branch = "main" }
    "head" { $invalid.head = "2222222222222222222222222222222222222222" }
    "mainHead" { $invalid.mainHead = "2222222222222222222222222222222222222222" }
    "clean" { $invalid.clean = $false }
    "envLocalIgnored" { $invalid.envLocalIgnored = $false }
    "envLocalTracked" { $invalid.envLocalTracked = $true }
  }
  Assert-RisePalsCandidateThrows -Label ("Repository snapshot " + $property) -Action {
    Assert-RisePalsCandidateRepositorySnapshot -Snapshot $invalid -Contract $contract `
      -ExpectedHead "1111111111111111111111111111111111111111"
  }
}
Write-Output "Repository head/branch/clean/main/.env boundary PASS"

$hostSnapshot = New-RisePalsCandidateValidHostSnapshot -Contract $contract
Assert-RisePalsCandidateHostSnapshot -Snapshot $hostSnapshot -Contract $contract
$hostFailures = @(
  "candidateServiceExists",
  "unexpectedRisePalsServices",
  "retainedServiceState",
  "retainedPathSubstringSpoof",
  "retainedArguments",
  "retainedAccount",
  "retainedType",
  "retainedHash",
  "retainedSharedPid",
  "retainedMissing",
  "retainedAdditional",
  "relevantListeners",
  "processesUnderRoot",
  "unexpectedPaths",
  "reparsePaths",
  "unexpectedAclEntries",
  "candidateExecutableLength",
  "candidateExecutableSha256",
  "candidateAuthenticode"
)
foreach ($failure in $hostFailures) {
  $invalid = New-RisePalsCandidateValidHostSnapshot -Contract $contract
  switch ($failure) {
    "candidateServiceExists" { $invalid.candidateServiceExists = $true }
    "unexpectedRisePalsServices" { $invalid.unexpectedRisePalsServices = @("RisePalsOther") }
    "retainedServiceState" { $invalid.retainedServices[0].state = "Running" }
    "retainedPathSubstringSpoof" {
      $invalid.retainedServices[0].pathName =
        '"C:\RisePals\approved-but-not-exact\RisePalsApp.exe"'
    }
    "retainedArguments" { $invalid.retainedServices[1].pathName += " --watch" }
    "retainedAccount" { $invalid.retainedServices[0].startName = "LocalSystem" }
    "retainedType" { $invalid.retainedServices[1].serviceType = "Share Process" }
    "retainedHash" {
      $invalid.retainedServices[1].executableSha256 =
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    }
    "retainedSharedPid" {
      $invalid.retainedServices[0].processId = 4444
      $invalid.retainedServices[1].processId = 4444
    }
    "retainedMissing" { $invalid.retainedServices = @($invalid.retainedServices[0]) }
    "retainedAdditional" {
      $invalid.retainedServices += $invalid.retainedServices[0].PSObject.Copy()
      $invalid.retainedServices[2].name = "RisePalsUnexpected"
    }
    "relevantListeners" { $invalid.relevantListeners = @(3100) }
    "processesUnderRoot" { $invalid.processesUnderRoot = @(1234) }
    "unexpectedPaths" { $invalid.unexpectedPaths = @("unexpected") }
    "reparsePaths" { $invalid.reparsePaths = @("reparse") }
    "unexpectedAclEntries" { $invalid.unexpectedAclEntries = @("Users") }
    "candidateExecutableLength" { $invalid.candidateExecutableLength++ }
    "candidateExecutableSha256" {
      $invalid.candidateExecutableSha256 = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    }
    "candidateAuthenticode" { $invalid.candidateAuthenticode = "Valid" }
  }
  Assert-RisePalsCandidateThrows -Label ("Host snapshot " + $failure) -Action {
    Assert-RisePalsCandidateHostSnapshot -Snapshot $invalid -Contract $contract
  }
}
Write-Output "Service collision/executable/path/ACL/listener preflight rejections PASS"

$retainedBefore = @((New-RisePalsCandidateValidHostSnapshot -Contract $contract).retainedServices)
$retainedAfter = @((New-RisePalsCandidateValidHostSnapshot -Contract $contract).retainedServices)
Assert-RisePalsCandidateRetainedSnapshotEquality -Before $retainedBefore -After $retainedAfter
$retainedAfter[1].pathName += " --changed"
Assert-RisePalsCandidateThrows -Label "Complete retained snapshot mismatch" -Action {
  Assert-RisePalsCandidateRetainedSnapshotEquality -Before $retainedBefore -After $retainedAfter
}
Write-Output "Exact retained before/final snapshot equality PASS"

Assert-RisePalsCandidateThrows -Label "Path traversal" -Action {
  Assert-RisePalsCandidateAuthorizedPath -Path "C:\Windows\candidate" `
    -ApprovedRoots @($contract.paths.stagingRoot)
}
Write-Output "Exact candidate path containment PASS"

$cleanupSnapshot = [pscustomobject]@{
  serviceState = "Stopped"
  startMode = "Disabled"
  processId = 0
  ownedJobProcessCount = 0
  reparsePaths = @()
  uncertainPaths = @()
  nonemptyUnexpectedPaths = @()
  cleanupTargets = @($plan.paths.configPath, $plan.paths.logDirectory)
}
Assert-RisePalsCandidateCleanupSnapshot -Snapshot $cleanupSnapshot -PathPlan $plan.paths
Assert-RisePalsCandidateCleanupSnapshot -Snapshot $cleanupSnapshot -PathPlan $plan.paths
$escapedCleanup = $cleanupSnapshot.PSObject.Copy()
$escapedCleanup.cleanupTargets = @("C:\RisePals\shared\secrets")
Assert-RisePalsCandidateThrows -Label "Cleanup escape" -Action {
  Assert-RisePalsCandidateCleanupSnapshot -Snapshot $escapedCleanup -PathPlan $plan.paths
}
$uncertainCleanup = $cleanupSnapshot.PSObject.Copy()
$uncertainCleanup.uncertainPaths = @("unknown")
Assert-RisePalsCandidateThrows -Label "Uncertain cleanup" -Action {
  Assert-RisePalsCandidateCleanupSnapshot -Snapshot $uncertainCleanup -PathPlan $plan.paths
}
Write-Output "Cleanup containment and idempotent validation PASS"

$inventoryRoot = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-candidate-inventory-" + [guid]::NewGuid().ToString("N")
)
try {
  [IO.Directory]::CreateDirectory((Join-Path $inventoryRoot "expected")) | Out-Null
  [IO.File]::WriteAllText(
    (Join-Path $inventoryRoot "expected\known.txt"),
    "synthetic",
    [Text.UTF8Encoding]::new($false)
  )
  Assert-RisePalsCandidateTaskTreeInventory -Path $inventoryRoot `
    -AllowedRelativePaths @("expected", "expected\known.txt")
  [IO.File]::WriteAllText(
    (Join-Path $inventoryRoot "expected\unexpected.txt"),
    "synthetic",
    [Text.UTF8Encoding]::new($false)
  )
  Assert-RisePalsCandidateThrows -Label "Unexpected nested cleanup child" -Action {
    Assert-RisePalsCandidateTaskTreeInventory -Path $inventoryRoot `
      -AllowedRelativePaths @("expected", "expected\known.txt")
  }
} finally {
  if ([IO.Directory]::Exists($inventoryRoot)) {
    [IO.Directory]::Delete($inventoryRoot, $true)
  }
}
Write-Output "Recursive cleanup inventory rejection PASS"

$expectedNonce = "0123456789abcdef0123456789abcdef"
$expectedAuthorization = "RP-TURN-019-R4-DIAG2-SIMULATION"
$expectedHead = "1111111111111111111111111111111111111111"
$expectedHash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
$expectedBootstrapHash = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
$expectedTransportHash = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
$expectedChildHash = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
$started = [DateTimeOffset]::UtcNow.AddSeconds(-1)
$result = New-RisePalsCandidateValidResult
$consumed = @{}
[void](Assert-RisePalsCandidateResult -Result $result -ExpectedNonce $expectedNonce `
  -ExpectedAuthorizationId $expectedAuthorization -ExpectedHead $expectedHead `
  -ExpectedLauncherScriptSha256 $expectedHash `
  -ExpectedBootstrapScriptSha256 $expectedBootstrapHash `
  -ExpectedTransportScriptSha256 $expectedTransportHash `
  -ExpectedChildScriptSha256 $expectedChildHash `
  -ObservedExitCode 0 -InvocationStartedAtUtc $started -ConsumedNonces $consumed)

$atomicRoot = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-candidate-result-" + [guid]::NewGuid().ToString("N")
)
try {
  [IO.Directory]::CreateDirectory($atomicRoot) | Out-Null
  $atomicResult = Join-Path $atomicRoot "result.json"
  $atomicTemporary = Join-Path $atomicRoot "result.tmp"
  Write-RisePalsCandidateResultAtomic -Result $result -ResultPath $atomicResult `
    -TemporaryPath $atomicTemporary
  $roundTrip = [Text.UTF8Encoding]::new($false, $true).GetString(
    [IO.File]::ReadAllBytes($atomicResult)
  ) | ConvertFrom-Json
  [void](Assert-RisePalsCandidateResult -Result $roundTrip -ExpectedNonce $expectedNonce `
    -ExpectedAuthorizationId $expectedAuthorization -ExpectedHead $expectedHead `
    -ExpectedLauncherScriptSha256 $expectedHash `
    -ExpectedBootstrapScriptSha256 $expectedBootstrapHash `
    -ExpectedTransportScriptSha256 $expectedTransportHash `
    -ExpectedChildScriptSha256 $expectedChildHash `
    -ObservedExitCode 0 -InvocationStartedAtUtc $started -ConsumedNonces @{})
  if ([IO.File]::Exists($atomicTemporary)) {
    throw "The atomic candidate result left its temporary file."
  }
} finally {
  if ([IO.File]::Exists((Join-Path $atomicRoot "result.json"))) {
    [IO.File]::Delete((Join-Path $atomicRoot "result.json"))
  }
  if ([IO.File]::Exists((Join-Path $atomicRoot "result.tmp"))) {
    [IO.File]::Delete((Join-Path $atomicRoot "result.tmp"))
  }
  if ([IO.Directory]::Exists($atomicRoot)) {
    [IO.Directory]::Delete($atomicRoot, $false)
  }
}
Write-Output "Atomic structured-result round trip PASS"
if (-not [bool]$result.streamEvidence.stderrObserved) {
  throw "Informational stderr was not preserved as bounded stream evidence."
}
Assert-RisePalsCandidateThrows -Label "Structured-result replay" -Action {
  Assert-RisePalsCandidateResult -Result $result -ExpectedNonce $expectedNonce `
    -ExpectedAuthorizationId $expectedAuthorization -ExpectedHead $expectedHead `
    -ExpectedLauncherScriptSha256 $expectedHash `
    -ExpectedBootstrapScriptSha256 $expectedBootstrapHash `
    -ExpectedTransportScriptSha256 $expectedTransportHash `
    -ExpectedChildScriptSha256 $expectedChildHash `
    -ObservedExitCode 0 -InvocationStartedAtUtc $started -ConsumedNonces $consumed
}
Write-Output "Structured success/informational-stderr/single-use result PASS"

$failureResult = New-RisePalsCandidateValidResult -Status "failure" -ExitCode 7 `
  -CleanupCompleted $true
[void](Assert-RisePalsCandidateResult -Result $failureResult -ExpectedNonce $expectedNonce `
  -ExpectedAuthorizationId $expectedAuthorization -ExpectedHead $expectedHead `
  -ExpectedLauncherScriptSha256 $expectedHash `
  -ExpectedBootstrapScriptSha256 $expectedBootstrapHash `
  -ExpectedTransportScriptSha256 $expectedTransportHash `
  -ExpectedChildScriptSha256 $expectedChildHash `
  -ObservedExitCode 7 -InvocationStartedAtUtc $started -ConsumedNonces @{})
Write-Output "Explicit native nonzero result classification PASS"

$allFunctionalStages = $script:RisePalsCandidateFunctionalStageOrder.Count
$liveSuccess = New-RisePalsCandidateSyntheticLiveResult `
  -CompletedFunctionalStageCount $allFunctionalStages -FailedStage $null `
  -Status success
[void](Assert-RisePalsCandidateResult -Result $liveSuccess `
  -ExpectedNonce $expectedNonce -ExpectedAuthorizationId $expectedAuthorization `
  -ExpectedHead $expectedHead -ExpectedLauncherScriptSha256 $expectedHash `
  -ExpectedBootstrapScriptSha256 $expectedBootstrapHash `
  -ExpectedTransportScriptSha256 $expectedTransportHash `
  -ExpectedChildScriptSha256 $expectedChildHash -ObservedExitCode 0 `
  -InvocationStartedAtUtc $started -ConsumedNonces @{})
$liveSuccessDiagnostic = New-RisePalsCandidateChildDiagnostic -Result $liveSuccess `
  -ExecutionMode Live -CleanupResponsibilityTransferredToParent $true
[void](Assert-RisePalsCandidateChildDiagnostic -Diagnostic $liveSuccessDiagnostic)
if (-not (Test-RisePalsCandidateDiagnosticFunctionalSuccess `
  -Diagnostic $liveSuccessDiagnostic) -or
  @($liveSuccessDiagnostic.functionalGates.PSObject.Properties | Where-Object {
    $_.Value -ne "passed"
  }).Count -ne 0) {
  throw "Successful live diagnostics do not preserve every mandatory gate."
}

$diagnosticFailureCases = @(
  @{ Label = "before any Live mutation"; Count = 0; Stage = "preflight"; Mutation = $false; Install = $false; Start = $false; Stop = $false },
  @{ Label = "protected preflight"; Count = 0; Stage = "preflight"; Mutation = $false; Install = $false; Start = $false; Stop = $false },
  @{ Label = "during immutable staging"; Count = 1; Stage = "stage-immutable-inputs"; Mutation = $true; Install = $false; Start = $false; Stop = $false },
  @{ Label = "before install"; Count = 3; Stage = "validate-candidate-config"; Mutation = $true; Install = $false; Start = $false; Stop = $false },
  @{ Label = "install attempt"; Count = 4; Stage = "create-own-process-service"; Mutation = $true; Install = $true; Start = $false; Stop = $false },
  @{ Label = "after install before start"; Count = 6; Stage = "configure-preshutdown-timeout"; Mutation = $true; Install = $true; Start = $false; Stop = $false },
  @{ Label = "after start before Stop"; Count = 8; Stage = "stream-first-byte"; Mutation = $true; Install = $true; Start = $true; Stop = $false },
  @{ Label = "direct Stop failure"; Count = 9; Stage = "direct-stop"; Mutation = $true; Install = $true; Start = $true; Stop = $true },
  @{ Label = "direct Stop drain"; Count = 10; Stage = "reject-new-work-during-drain"; Mutation = $true; Install = $true; Start = $true; Stop = $true }
)
foreach ($case in $diagnosticFailureCases) {
  $failure = New-RisePalsCandidateSyntheticLiveResult `
    -CompletedFunctionalStageCount ([int]$case.Count) -FailedStage ([string]$case.Stage)
  $diagnostic = New-RisePalsCandidateChildDiagnostic -Result $failure `
    -ExecutionMode Live -CleanupResponsibilityTransferredToParent $true
  [void](Assert-RisePalsCandidateChildDiagnostic -Diagnostic $diagnostic)
  $failedGate = @($diagnostic.functionalGates.PSObject.Properties | Where-Object {
    $_.Value -eq "failed"
  })
  if ($failedGate.Count -ne 1 -or
    [bool]$diagnostic.liveHostMutationBegan -ne [bool]$case.Mutation -or
    [bool]$diagnostic.candidateServiceInstallationBegan -ne [bool]$case.Install -or
    [bool]$diagnostic.candidateServiceStartReached -ne [bool]$case.Start -or
    [bool]$diagnostic.directStopServiceReached -ne [bool]$case.Stop -or
    (Test-RisePalsCandidateDiagnosticFunctionalSuccess -Diagnostic $diagnostic)) {
    throw "Diagnostic failure boundary $($case.Label) is not exact."
  }
}

$finalizationFailure = New-RisePalsCandidateSyntheticLiveResult `
  -CompletedFunctionalStageCount $allFunctionalStages `
  -FailedStage "child-finalization" -Status failure
$finalizationDiagnostic = New-RisePalsCandidateChildDiagnostic `
  -Result $finalizationFailure -ExecutionMode Live `
  -CleanupResponsibilityTransferredToParent $true
[void](Assert-RisePalsCandidateChildDiagnostic -Diagnostic $finalizationDiagnostic)
if (@($finalizationDiagnostic.functionalGates.PSObject.Properties | Where-Object {
  $_.Value -ne "passed"
}).Count -ne 0 -or
  (Test-RisePalsCandidateDiagnosticFunctionalSuccess -Diagnostic $finalizationDiagnostic)) {
  throw "A child-finalization failure was mistaken for functional success."
}

$invalidDiagnostics = @()
$duplicate = Copy-RisePalsCandidateContract -Contract $liveSuccessDiagnostic
$duplicate.completedStages = @($duplicate.completedStages) + $duplicate.completedStages[-1]
$duplicate.diagnosticDigest = Get-RisePalsCandidateChildDiagnosticDigest -Diagnostic $duplicate
$invalidDiagnostics += @{ Label = "duplicate stage"; Value = $duplicate }
$reordered = Copy-RisePalsCandidateContract -Contract $liveSuccessDiagnostic
$swap = $reordered.completedStages[0]
$reordered.completedStages[0] = $reordered.completedStages[1]
$reordered.completedStages[1] = $swap
$reordered.diagnosticDigest = Get-RisePalsCandidateChildDiagnosticDigest -Diagnostic $reordered
$invalidDiagnostics += @{ Label = "reordered stage"; Value = $reordered }
$malformedStage = Copy-RisePalsCandidateContract -Contract $finalizationDiagnostic
$malformedStage.failedStage = "unknown-live-stage"
$malformedStage.diagnosticDigest = Get-RisePalsCandidateChildDiagnosticDigest `
  -Diagnostic $malformedStage
$invalidDiagnostics += @{ Label = "malformed failed stage"; Value = $malformedStage }
$missingGate = Copy-RisePalsCandidateContract -Contract $liveSuccessDiagnostic
$missingGate.functionalGates.PSObject.Properties.Remove("directStop")
$invalidDiagnostics += @{ Label = "missing gate"; Value = $missingGate }
$extraGate = Copy-RisePalsCandidateContract -Contract $liveSuccessDiagnostic
$extraGate.functionalGates | Add-Member -NotePropertyName "unexpectedGate" `
  -NotePropertyValue "passed"
$invalidDiagnostics += @{ Label = "extra gate"; Value = $extraGate }
$inconsistentGate = Copy-RisePalsCandidateContract -Contract $liveSuccessDiagnostic
$inconsistentGate.functionalGates.directStop = "not_reached"
$inconsistentGate.diagnosticDigest = Get-RisePalsCandidateChildDiagnosticDigest `
  -Diagnostic $inconsistentGate
$invalidDiagnostics += @{ Label = "inconsistent gate"; Value = $inconsistentGate }
$impossibleLifecycle = Copy-RisePalsCandidateContract -Contract $liveSuccessDiagnostic
$impossibleLifecycle.candidateServiceInstallationBegan = $false
$impossibleLifecycle.diagnosticDigest = Get-RisePalsCandidateChildDiagnosticDigest `
  -Diagnostic $impossibleLifecycle
$invalidDiagnostics += @{ Label = "impossible lifecycle"; Value = $impossibleLifecycle }
$tamperedChildDigest = Copy-RisePalsCandidateContract -Contract $liveSuccessDiagnostic
$tamperedChildDigest.childResultDigest = "f" * 64
$invalidDiagnostics += @{ Label = "tampered child digest"; Value = $tamperedChildDigest }
foreach ($invalidDiagnostic in $invalidDiagnostics) {
  Assert-RisePalsCandidateThrows -Label ([string]$invalidDiagnostic.Label) -Action {
    Assert-RisePalsCandidateChildDiagnostic -Diagnostic $invalidDiagnostic.Value
  }
}
Write-Output "Durable child diagnostic stage/gate/lifecycle/digest rejections PASS"

$invalidCases = @("malformed", "stale", "wrong-head", "wrong-script", "partial", "digest")
foreach ($case in $invalidCases) {
  $invalid = New-RisePalsCandidateValidResult
  switch ($case) {
    "malformed" { $invalid.PSObject.Properties.Remove("cleanupCompleted") }
    "stale" {
      $invalid.startedAtUtc = [DateTimeOffset]::UtcNow.AddHours(-2).ToString("o")
      $invalid.completedAtUtc = [DateTimeOffset]::UtcNow.AddHours(-2).AddSeconds(1).ToString("o")
      $invalid.resultDigest = Get-RisePalsCandidateResultDigest -Result $invalid
    }
    "wrong-head" {
      $invalid.repositoryHead = "2222222222222222222222222222222222222222"
      $invalid.resultDigest = Get-RisePalsCandidateResultDigest -Result $invalid
    }
    "wrong-script" {
      $invalid.launcherScriptSha256 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      $invalid.resultDigest = Get-RisePalsCandidateResultDigest -Result $invalid
    }
    "partial" { $invalid.completedStages = @("child-started", "child-started") }
    "digest" { $invalid.resultDigest = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" }
  }
  Assert-RisePalsCandidateThrows -Label ("Structured result " + $case) -Action {
    Assert-RisePalsCandidateResult -Result $invalid -ExpectedNonce $expectedNonce `
      -ExpectedAuthorizationId $expectedAuthorization -ExpectedHead $expectedHead `
      -ExpectedLauncherScriptSha256 $expectedHash `
      -ExpectedBootstrapScriptSha256 $expectedBootstrapHash `
      -ExpectedTransportScriptSha256 $expectedTransportHash `
      -ExpectedChildScriptSha256 $expectedChildHash `
      -ObservedExitCode 0 -InvocationStartedAtUtc $started -ConsumedNonces @{}
  }
}
Write-Output "Malformed/stale/provenance/partial/digest result rejections PASS"

$transportScenarios = @(
  @{ Name = "successful-bootstrap-start-stage-final"; Launch = "launched"; B = $true; A = $true; C = $true; L = $true; P = $true; V = $true; I = $false; S = "success"; Expected = "final-present-validated" },
  @{ Name = "failure-before-bootstrap-invocation"; Launch = "launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $false; S = $null; Expected = "elevated-child-never-entered-bootstrap" },
  @{ Name = "bootstrap-argument-rejection"; Launch = "launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $false; S = $null; Expected = "elevated-child-never-entered-bootstrap" },
  @{ Name = "bootstrap-result-directory-rejection"; Launch = "launch-failure"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $false; S = $null; Expected = "elevated-process-launch-failure" },
  @{ Name = "failure-immediately-after-bootstrap"; Launch = "launched"; B = $true; A = $false; C = $false; L = $false; P = $false; V = $false; I = $false; S = $null; Expected = "bootstrap-entered-child-launch-not-attempted" },
  @{ Name = "child-process-launch-failure"; Launch = "launched"; B = $true; A = $true; C = $false; L = $false; P = $false; V = $false; I = $false; S = $null; Expected = "child-launch-attempted-child-not-started" },
  @{ Name = "full-child-load-failure"; Launch = "launched"; B = $true; A = $true; C = $false; L = $false; P = $false; V = $false; I = $false; S = $null; Expected = "child-launch-attempted-child-not-started" },
  @{ Name = "child-marker-without-live"; Launch = "launched"; B = $true; A = $true; C = $true; L = $false; P = $false; V = $false; I = $false; S = $null; Expected = "child-started-failed-before-live" },
  @{ Name = "live-marker-without-final"; Launch = "launched"; B = $true; A = $true; C = $true; L = $true; P = $false; V = $false; I = $false; S = $null; Expected = "live-started-failed" },
  @{ Name = "uac-cancellation"; Launch = "cancelled"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $false; S = $null; Expected = "uac-cancelled" },
  @{ Name = "elevated-process-creation-failure"; Launch = "launch-failure"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $false; S = $null; Expected = "elevated-process-launch-failure" },
  @{ Name = "uac-not-launched"; Launch = "not-launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $false; S = $null; Expected = "uac-not-launched" },
  @{ Name = "exit-code-final-status-mismatch"; Launch = "launched"; B = $true; A = $true; C = $true; L = $true; P = $true; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "missing-final-marker"; Launch = "launched"; B = $true; A = $true; C = $true; L = $true; P = $false; V = $false; I = $false; S = $null; Expected = "live-started-failed" },
  @{ Name = "partial-json"; Launch = "launched"; B = $true; A = $true; C = $true; L = $true; P = $true; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "invalid-schema"; Launch = "launched"; B = $true; A = $false; C = $false; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "incorrect-nonce"; Launch = "launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "incorrect-authorization-id"; Launch = "launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "incorrect-head"; Launch = "launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "incorrect-launcher-script-hash"; Launch = "launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "incorrect-bootstrap-script-hash"; Launch = "launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "incorrect-transport-script-hash"; Launch = "launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "incorrect-child-script-hash"; Launch = "launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "stale-marker"; Launch = "launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "replayed-marker"; Launch = "launched"; B = $true; A = $false; C = $false; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "reparse-result-root-or-marker"; Launch = "launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "marker-outside-exact-result-root"; Launch = "launched"; B = $false; A = $false; C = $false; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "atomic-write-interruption"; Launch = "launched"; B = $true; A = $true; C = $true; L = $true; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "marker-ordering-violation"; Launch = "launched"; B = $true; A = $true; C = $true; L = $false; P = $false; V = $false; I = $true; S = $null; Expected = "final-invalid-or-inconsistent" },
  @{ Name = "no-raw-output-dependency"; Launch = "launched"; B = $true; A = $true; C = $true; L = $true; P = $true; V = $true; I = $false; S = "success"; Expected = "final-present-validated" },
  @{ Name = "temporary-resource-cleanup"; Launch = "launched"; B = $true; A = $true; C = $true; L = $true; P = $true; V = $true; I = $false; S = "failure"; Expected = "final-present-validated" }
)
foreach ($scenario in $transportScenarios) {
  $actual = Resolve-RisePalsCandidateParentClassification `
    -ExecutionMode Simulation -LaunchDisposition $scenario.Launch `
    -BootstrapEntered $scenario.B `
    -ChildLaunchAttempted $scenario.A -ChildStarted $scenario.C `
    -LiveStarted $scenario.L -FinalPresent $scenario.P `
    -FinalValidated $scenario.V -EvidenceInvalid $scenario.I -FinalStatus $scenario.S
  if ($actual -ne $scenario.Expected) {
    throw ("Candidate transport simulation {0} returned {1}." -f $scenario.Name, $actual)
  }
}
Write-Output ("Candidate bootstrap/result transport simulations PASS ({0} scenarios)" -f
  $transportScenarios.Count)

$validMarker = New-RisePalsCandidateValidMarker
$markerStarted = [DateTimeOffset]::UtcNow.AddSeconds(-1)
$markerConsumed = @{}
[void](Assert-RisePalsCandidateMarker -Marker $validMarker `
  -ExpectedType "bootstrap-started" -ExpectedNonce $expectedNonce `
  -ExpectedAuthorizationId $expectedAuthorization -ExpectedHead $expectedHead `
  -ExpectedLauncherScriptSha256 $expectedHash `
  -ExpectedBootstrapScriptSha256 $expectedBootstrapHash `
  -ExpectedTransportScriptSha256 $expectedTransportHash `
  -ExpectedChildScriptSha256 $expectedChildHash `
  -InvocationStartedAtUtc $markerStarted -ConsumedMarkers $markerConsumed)
Assert-RisePalsCandidateThrows -Label "Transport marker replay" -Action {
  Assert-RisePalsCandidateMarker -Marker $validMarker `
    -ExpectedType "bootstrap-started" -ExpectedNonce $expectedNonce `
    -ExpectedAuthorizationId $expectedAuthorization -ExpectedHead $expectedHead `
    -ExpectedLauncherScriptSha256 $expectedHash `
    -ExpectedBootstrapScriptSha256 $expectedBootstrapHash `
    -ExpectedTransportScriptSha256 $expectedTransportHash `
    -ExpectedChildScriptSha256 $expectedChildHash `
    -InvocationStartedAtUtc $markerStarted -ConsumedMarkers $markerConsumed
}
$invalidMarkerCases = @(
  "partial",
  "schema",
  "nonce",
  "authorization",
  "head",
  "launcher-hash",
  "bootstrap-hash",
  "transport-hash",
  "child-hash",
  "stale",
  "digest"
)
foreach ($case in $invalidMarkerCases) {
  $invalid = New-RisePalsCandidateValidMarker
  switch ($case) {
    "partial" { $invalid.PSObject.Properties.Remove("recordedAtUtc") }
    "schema" { $invalid.schemaVersion = "invalid" }
    "nonce" { $invalid.invocationNonce = "ffffffffffffffffffffffffffffffff" }
    "authorization" { $invalid.authorizationId = "RP-TURN-019-R4-LIVE-FFFFFFFF" }
    "head" { $invalid.repositoryHead = "2222222222222222222222222222222222222222" }
    "launcher-hash" { $invalid.launcherScriptSha256 = (("d" * 64) -join "") }
    "bootstrap-hash" { $invalid.bootstrapScriptSha256 = (("d" * 64) -join "") }
    "transport-hash" { $invalid.transportScriptSha256 = (("e" * 64) -join "") }
    "child-hash" { $invalid.childScriptSha256 = (("f" * 64) -join "") }
    "stale" { $invalid.recordedAtUtc = [DateTimeOffset]::UtcNow.AddHours(-2).ToString("o") }
    "digest" { $invalid.markerDigest = ("f" * 64) }
  }
  if ($case -notin @("partial", "digest")) {
    $invalid.markerDigest = Get-RisePalsCandidateMarkerDigest -Marker $invalid
  }
  Assert-RisePalsCandidateThrows -Label ("Transport marker " + $case) -Action {
    Assert-RisePalsCandidateMarker -Marker $invalid `
      -ExpectedType "bootstrap-started" -ExpectedNonce $expectedNonce `
      -ExpectedAuthorizationId $expectedAuthorization -ExpectedHead $expectedHead `
      -ExpectedLauncherScriptSha256 $expectedHash `
      -ExpectedBootstrapScriptSha256 $expectedBootstrapHash `
      -ExpectedTransportScriptSha256 $expectedTransportHash `
      -ExpectedChildScriptSha256 $expectedChildHash `
      -InvocationStartedAtUtc $markerStarted -ConsumedMarkers @{}
  }
}
Write-Output "Transport schema/provenance/time/digest/replay rejections PASS"

$transportRoot = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-candidate-transport-" + [guid]::NewGuid().ToString("N")
)
$transportNonce = "0123456789abcdef0123456789abcdef"
$transportInvocation = Join-Path $transportRoot ("invocation-" + $transportNonce)
$outside = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-candidate-outside-" + [guid]::NewGuid().ToString("N") + ".json"
)
$junctionTarget = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-candidate-junction-target-" + [guid]::NewGuid().ToString("N")
)
$junctionRoot = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-candidate-junction-" + [guid]::NewGuid().ToString("N")
)
try {
  [IO.Directory]::CreateDirectory($transportInvocation) | Out-Null
  Protect-RisePalsCandidateInvocationDirectory -Path $transportInvocation
  [void](Assert-RisePalsCandidateInvocationDirectory -Path $transportInvocation `
    -ExpectedRoot $transportRoot -InvocationNonce $transportNonce)
  $atomicMarker = New-RisePalsCandidateValidMarker
  Write-RisePalsCandidateMarkerAtomic -Marker $atomicMarker `
    -InvocationDirectory $transportInvocation
  $roundTripMarker = Read-RisePalsCandidateTransportJson `
    -Path (Join-Path $transportInvocation "bootstrap-started.json") `
    -InvocationDirectory $transportInvocation -ExpectedName "bootstrap-started.json"
  if ($roundTripMarker.markerDigest -ne $atomicMarker.markerDigest) {
    throw "The atomic transport marker round trip changed its digest."
  }
  [IO.File]::WriteAllText($outside, "{}", [Text.UTF8Encoding]::new($false))
  Assert-RisePalsCandidateThrows -Label "Marker outside result root" -Action {
    Read-RisePalsCandidateTransportJson -Path $outside `
      -InvocationDirectory $transportInvocation -ExpectedName "bootstrap-started.json"
  }
  $interruptedPath = Join-Path $transportInvocation "child-started.json.tmp"
  [IO.File]::WriteAllText($interruptedPath, "partial", [Text.UTF8Encoding]::new($false))
  Assert-RisePalsCandidateThrows -Label "Atomic marker interruption" -Action {
    Write-RisePalsCandidateMarkerAtomic -Marker (
      New-RisePalsCandidateValidMarker -MarkerType "child-started"
    ) -InvocationDirectory $transportInvocation
  }
  $junctionInvocation = Join-Path $junctionTarget ("invocation-" + $transportNonce)
  [IO.Directory]::CreateDirectory($junctionInvocation) | Out-Null
  Protect-RisePalsCandidateInvocationDirectory -Path $junctionInvocation
  [void](New-Item -ItemType Junction -Path $junctionRoot -Target $junctionTarget)
  Assert-RisePalsCandidateThrows -Label "Reparse result root" -Action {
    Assert-RisePalsCandidateInvocationDirectory `
      -Path (Join-Path $junctionRoot ("invocation-" + $transportNonce)) `
      -ExpectedRoot $junctionRoot -InvocationNonce $transportNonce
  }
} finally {
  foreach ($name in @("bootstrap-started.json", "child-started.json.tmp")) {
    $path = Join-Path $transportInvocation $name
    if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
  }
  if ([IO.File]::Exists($outside)) { [IO.File]::Delete($outside) }
  if ([IO.Directory]::Exists($junctionRoot)) {
    [IO.Directory]::Delete($junctionRoot, $false)
  }
  if ([IO.Directory]::Exists($junctionTarget)) {
    [IO.Directory]::Delete($junctionTarget, $true)
  }
  if ([IO.Directory]::Exists($transportInvocation)) {
    [IO.Directory]::Delete($transportInvocation, $false)
  }
  if ([IO.Directory]::Exists($transportRoot)) {
    [IO.Directory]::Delete($transportRoot, $false)
  }
}
if ([IO.Directory]::Exists($transportRoot) -or [IO.File]::Exists($outside)) {
  throw "Candidate transport simulation cleanup left a temporary resource."
}
Write-Output "Explicit result-root ACL/path/atomic-write/cleanup simulations PASS"

$durableRoot = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-candidate-durable-" + [guid]::NewGuid().ToString("N")
)
$unauthorizedRoot = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-candidate-durable-unauthorized-" + [guid]::NewGuid().ToString("N")
)
$durableJunctionTarget = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-candidate-durable-target-" + [guid]::NewGuid().ToString("N")
)
$durableJunction = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-candidate-durable-junction-" + [guid]::NewGuid().ToString("N")
)
$durableNonce = "0123456789abcdef0123456789abcdef"
$interruptedNonce = "fedcba9876543210fedcba9876543210"
$interruptedResultNonce = "00112233445566778899aabbccddeeff"
$failedDiagnosticNonce = "ffeeddccbbaa99887766554433221100"
$launchFailureNonce = "aabbccddeeff00112233445566778899"
try {
  $durableDirectory = Initialize-RisePalsCandidateEvidenceDirectory `
    -Path $durableRoot -Mode Simulation
  $parentCheckpoint = New-RisePalsCandidateValidParentCheckpoint -Nonce $durableNonce
  $checkpointPath = Write-RisePalsCandidateDurableParentCheckpointAtomic `
    -Checkpoint $parentCheckpoint -EvidenceDirectory $durableDirectory -Mode Simulation
  $reopenedCheckpoint = Read-RisePalsCandidateDurableParentCheckpoint -Path $checkpointPath `
    -EvidenceDirectory $durableDirectory -InvocationNonce $durableNonce `
    -Mode Simulation
  $parentValidationStarted = [DateTimeOffset]::UtcNow.AddMinutes(-1)
  [void](Assert-RisePalsCandidateParentCheckpoint -Checkpoint $reopenedCheckpoint `
    -ExpectedNonce $durableNonce `
    -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
    -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
    -ExpectedBootstrapScriptSha256 ("b" * 64) `
    -ExpectedTransportScriptSha256 ("c" * 64) `
    -ExpectedChildScriptSha256 ("d" * 64) `
    -ExpectedLaunchDiagnosticDigest ([string]$reopenedCheckpoint.launchDiagnostic.diagnosticDigest) `
    -InvocationStartedAtUtc $parentValidationStarted -ConsumedNonces @{})
  $consumedCheckpoints = @{}
  [void](Assert-RisePalsCandidateParentCheckpoint -Checkpoint $reopenedCheckpoint `
    -ExpectedNonce $durableNonce `
    -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
    -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
    -ExpectedBootstrapScriptSha256 ("b" * 64) `
    -ExpectedTransportScriptSha256 ("c" * 64) `
    -ExpectedChildScriptSha256 ("d" * 64) `
    -ExpectedLaunchDiagnosticDigest ([string]$reopenedCheckpoint.launchDiagnostic.diagnosticDigest) `
    -InvocationStartedAtUtc $parentValidationStarted `
    -ConsumedNonces $consumedCheckpoints)
  Assert-RisePalsCandidateThrows -Label "Durable parent-checkpoint replay" -Action {
    Assert-RisePalsCandidateParentCheckpoint -Checkpoint $reopenedCheckpoint `
      -ExpectedNonce $durableNonce `
      -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
      -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
      -ExpectedBootstrapScriptSha256 ("b" * 64) `
      -ExpectedTransportScriptSha256 ("c" * 64) `
      -ExpectedChildScriptSha256 ("d" * 64) `
      -ExpectedLaunchDiagnosticDigest ([string]$reopenedCheckpoint.launchDiagnostic.diagnosticDigest) `
      -InvocationStartedAtUtc $parentValidationStarted `
      -ConsumedNonces $consumedCheckpoints
  }
  Assert-RisePalsCandidateThrows -Label "Existing durable parent-checkpoint path" -Action {
    Write-RisePalsCandidateDurableParentCheckpointAtomic -Checkpoint $parentCheckpoint `
      -EvidenceDirectory $durableDirectory -Mode Simulation
  }

  $checkpointFileName = [IO.Path]::GetFileName($checkpointPath)
  $parentResult = New-RisePalsCandidateParentResult -Checkpoint $reopenedCheckpoint `
    -CheckpointFileName $checkpointFileName `
    -CheckpointDigest ([string]$reopenedCheckpoint.checkpointDigest) `
    -DurableCheckpointValidated $true -TransientCleanupAttempted $true `
    -TransientCleanupCompleted $true -InvocationDirectoryAbsent $true `
    -RemainingTransientObjectCount 0 -RemainingTemporaryObjectCount 0
  $durablePath = Write-RisePalsCandidateDurableParentResultAtomic `
    -Result $parentResult -EvidenceDirectory $durableDirectory -Mode Simulation
  $reopenedParent = Read-RisePalsCandidateDurableParentResult -Path $durablePath `
    -EvidenceDirectory $durableDirectory -InvocationNonce $durableNonce -Mode Simulation
  [void](Assert-RisePalsCandidateParentResult -Result $reopenedParent `
    -ExpectedNonce $durableNonce `
    -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
    -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
    -ExpectedBootstrapScriptSha256 ("b" * 64) `
    -ExpectedTransportScriptSha256 ("c" * 64) `
    -ExpectedChildScriptSha256 ("d" * 64) `
    -ExpectedCheckpointFileName $checkpointFileName `
    -ExpectedCheckpointDigest ([string]$reopenedCheckpoint.checkpointDigest) `
    -ExpectedLaunchDiagnosticDigest ([string]$reopenedCheckpoint.launchDiagnostic.diagnosticDigest) `
    -ExpectedChildDiagnosticDigest ([string]$reopenedCheckpoint.childDiagnostic.diagnosticDigest) `
    -InvocationStartedAtUtc $parentValidationStarted -ConsumedNonces @{})
  $consumedResults = @{}
  [void](Assert-RisePalsCandidateParentResult -Result $reopenedParent `
    -ExpectedNonce $durableNonce `
    -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
    -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
    -ExpectedBootstrapScriptSha256 ("b" * 64) `
    -ExpectedTransportScriptSha256 ("c" * 64) `
    -ExpectedChildScriptSha256 ("d" * 64) `
    -ExpectedCheckpointFileName $checkpointFileName `
    -ExpectedCheckpointDigest ([string]$reopenedCheckpoint.checkpointDigest) `
    -ExpectedLaunchDiagnosticDigest ([string]$reopenedCheckpoint.launchDiagnostic.diagnosticDigest) `
    -ExpectedChildDiagnosticDigest ([string]$reopenedCheckpoint.childDiagnostic.diagnosticDigest) `
    -InvocationStartedAtUtc $parentValidationStarted -ConsumedNonces $consumedResults)
  Assert-RisePalsCandidateThrows -Label "Durable parent-result replay" -Action {
    Assert-RisePalsCandidateParentResult -Result $reopenedParent `
      -ExpectedNonce $durableNonce `
      -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
      -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
      -ExpectedBootstrapScriptSha256 ("b" * 64) `
      -ExpectedTransportScriptSha256 ("c" * 64) `
      -ExpectedChildScriptSha256 ("d" * 64) `
      -ExpectedCheckpointFileName $checkpointFileName `
      -ExpectedCheckpointDigest ([string]$reopenedCheckpoint.checkpointDigest) `
      -ExpectedLaunchDiagnosticDigest ([string]$reopenedCheckpoint.launchDiagnostic.diagnosticDigest) `
      -ExpectedChildDiagnosticDigest ([string]$reopenedCheckpoint.childDiagnostic.diagnosticDigest) `
      -InvocationStartedAtUtc $parentValidationStarted -ConsumedNonces $consumedResults
  }
  Assert-RisePalsCandidateThrows -Label "Existing durable parent-result path" -Action {
    Write-RisePalsCandidateDurableParentResultAtomic -Result $parentResult `
      -EvidenceDirectory $durableDirectory -Mode Simulation
  }

  $mismatchedParentResult = Copy-RisePalsCandidateContract -Contract $parentResult
  $mismatchedParentResult.launchDiagnostic = New-RisePalsCandidateValidLaunchDiagnostic `
    -Arguments @("-NoLogo", "-NoProfile", "-Different")
  $mismatchedParentResult.resultDigest = Get-RisePalsCandidateParentResultDigest `
    -Result $mismatchedParentResult
  Assert-RisePalsCandidateThrows -Label "Checkpoint/result launch-diagnostic mismatch" -Action {
    Assert-RisePalsCandidateParentResult -Result $mismatchedParentResult `
      -ExpectedNonce $durableNonce `
      -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
      -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
      -ExpectedBootstrapScriptSha256 ("b" * 64) `
      -ExpectedTransportScriptSha256 ("c" * 64) `
      -ExpectedChildScriptSha256 ("d" * 64) `
      -ExpectedCheckpointFileName $checkpointFileName `
      -ExpectedCheckpointDigest ([string]$reopenedCheckpoint.checkpointDigest) `
      -ExpectedLaunchDiagnosticDigest ([string]$reopenedCheckpoint.launchDiagnostic.diagnosticDigest) `
      -ExpectedChildDiagnosticDigest ([string]$reopenedCheckpoint.childDiagnostic.diagnosticDigest) `
      -InvocationStartedAtUtc $parentValidationStarted -ConsumedNonces @{}
  }

  $launchFailureCheckpoint = New-RisePalsCandidateParentCheckpoint `
    -InvocationNonce $launchFailureNonce `
    -AuthorizationId "RP-TURN-019-R4-DIAG3-SIMULATION" `
    -RepositoryHead ("1" * 40) -LauncherScriptSha256 ("a" * 64) `
    -BootstrapScriptSha256 ("b" * 64) -TransportScriptSha256 ("c" * 64) `
    -ChildScriptSha256 ("d" * 64) -ExecutionMode Live `
    -LaunchDiagnostic $failureLaunchDiagnostic `
    -LaunchDisposition launch-failure `
    -Classification elevated-process-launch-failure -ProcessLaunched $false `
    -ElevatedExitCode -1 -BootstrapEntered $false -BootstrapStarted $false `
    -BootstrapFailurePresent $false -ChildLaunchAttempted $false `
    -ChildStarted $false -LiveStarted $false -FinalPresent $false `
    -FinalValidated $false -FinalStatus $null `
    -ChildDiagnostic $emptyLiveChildDiagnostic
  $launchFailureCheckpointPath = Write-RisePalsCandidateDurableParentCheckpointAtomic `
    -Checkpoint $launchFailureCheckpoint -EvidenceDirectory $durableDirectory `
    -Mode Simulation
  $launchFailureResult = New-RisePalsCandidateParentResult `
    -Checkpoint $launchFailureCheckpoint `
    -CheckpointFileName ([IO.Path]::GetFileName($launchFailureCheckpointPath)) `
    -CheckpointDigest ([string]$launchFailureCheckpoint.checkpointDigest) `
    -DurableCheckpointValidated $true -TransientCleanupAttempted $true `
    -TransientCleanupCompleted $true -InvocationDirectoryAbsent $true `
    -RemainingTransientObjectCount 0 -RemainingTemporaryObjectCount 0
  $launchFailureResultPath = Write-RisePalsCandidateDurableParentResultAtomic `
    -Result $launchFailureResult -EvidenceDirectory $durableDirectory -Mode Simulation
  $launchFailureCheckpointReopened = Read-RisePalsCandidateDurableParentCheckpoint `
    -Path $launchFailureCheckpointPath -EvidenceDirectory $durableDirectory `
    -InvocationNonce $launchFailureNonce -Mode Simulation
  $launchFailureResultReopened = Read-RisePalsCandidateDurableParentResult `
    -Path $launchFailureResultPath -EvidenceDirectory $durableDirectory `
    -InvocationNonce $launchFailureNonce -Mode Simulation
  [void](Assert-RisePalsCandidateParentCheckpoint `
    -Checkpoint $launchFailureCheckpointReopened -ExpectedNonce $launchFailureNonce `
    -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG3-SIMULATION" `
    -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
    -ExpectedBootstrapScriptSha256 ("b" * 64) `
    -ExpectedTransportScriptSha256 ("c" * 64) `
    -ExpectedChildScriptSha256 ("d" * 64) `
    -ExpectedLaunchDiagnosticDigest $failureLaunchDiagnostic.diagnosticDigest `
    -ExpectedExecutionMode Live -InvocationStartedAtUtc $parentValidationStarted `
    -ConsumedNonces @{})
  [void](Assert-RisePalsCandidateParentResult `
    -Result $launchFailureResultReopened -ExpectedNonce $launchFailureNonce `
    -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG3-SIMULATION" `
    -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
    -ExpectedBootstrapScriptSha256 ("b" * 64) `
    -ExpectedTransportScriptSha256 ("c" * 64) `
    -ExpectedChildScriptSha256 ("d" * 64) `
    -ExpectedCheckpointFileName ([IO.Path]::GetFileName($launchFailureCheckpointPath)) `
    -ExpectedCheckpointDigest ([string]$launchFailureCheckpointReopened.checkpointDigest) `
    -ExpectedLaunchDiagnosticDigest $failureLaunchDiagnostic.diagnosticDigest `
    -ExpectedChildDiagnosticDigest $emptyLiveChildDiagnostic.diagnosticDigest `
    -ExpectedExecutionMode Live -InvocationStartedAtUtc $parentValidationStarted `
    -ConsumedNonces @{})
  if ($launchFailureCheckpointReopened.launchDiagnostic.diagnosticDigest -ne
      $launchFailureResultReopened.launchDiagnostic.diagnosticDigest -or
    -not [bool]$launchFailureResultReopened.transientCleanupCompleted -or
    -not [bool]$launchFailureResultReopened.invocationDirectoryAbsent) {
    throw "Durable launch-failure evidence did not survive transient cleanup."
  }

  $transientSimulation = Join-Path ([IO.Path]::GetTempPath()) (
    "risepals-candidate-transient-" + [guid]::NewGuid().ToString("N")
  )
  [IO.Directory]::CreateDirectory($transientSimulation) | Out-Null
  [IO.Directory]::Delete($transientSimulation, $false)
  if (-not [IO.File]::Exists($checkpointPath) -or -not [IO.File]::Exists($durablePath)) {
    throw "Transient cleanup deleted durable parent evidence."
  }

  $failedChild = New-RisePalsCandidateSyntheticLiveResult `
    -CompletedFunctionalStageCount 9 -FailedStage "direct-stop"
  $failedChild.invocationNonce = $failedDiagnosticNonce
  $failedChild.resultDigest = Get-RisePalsCandidateResultDigest -Result $failedChild
  $failedDiagnostic = New-RisePalsCandidateChildDiagnostic -Result $failedChild `
    -ExecutionMode Live -CleanupResponsibilityTransferredToParent $true
  $failedLaunchDiagnostic = New-RisePalsCandidateValidLaunchDiagnostic `
    -ExecutionMode Live
  $failedCheckpoint = New-RisePalsCandidateParentCheckpoint `
    -InvocationNonce $failedDiagnosticNonce `
    -AuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
    -RepositoryHead ("1" * 40) -LauncherScriptSha256 ("a" * 64) `
    -BootstrapScriptSha256 ("b" * 64) -TransportScriptSha256 ("c" * 64) `
    -ChildScriptSha256 ("d" * 64) -ExecutionMode Live `
    -LaunchDiagnostic $failedLaunchDiagnostic `
    -LaunchDisposition launched `
    -Classification final-present-validated -ProcessLaunched $true `
    -ElevatedExitCode 23 -BootstrapEntered $true -BootstrapStarted $true `
    -BootstrapFailurePresent $false -ChildLaunchAttempted $true `
    -ChildStarted $true -LiveStarted $true -FinalPresent $true `
    -FinalValidated $true -FinalStatus failure -ChildDiagnostic $failedDiagnostic
  $failedCheckpointPath = Write-RisePalsCandidateDurableParentCheckpointAtomic `
    -Checkpoint $failedCheckpoint -EvidenceDirectory $durableDirectory `
    -Mode Simulation
  $failedParentResult = New-RisePalsCandidateParentResult `
    -Checkpoint $failedCheckpoint `
    -CheckpointFileName ([IO.Path]::GetFileName($failedCheckpointPath)) `
    -CheckpointDigest ([string]$failedCheckpoint.checkpointDigest) `
    -DurableCheckpointValidated $true -TransientCleanupAttempted $true `
    -TransientCleanupCompleted $true -InvocationDirectoryAbsent $true `
    -RemainingTransientObjectCount 0 -RemainingTemporaryObjectCount 0
  $failedParentPath = Write-RisePalsCandidateDurableParentResultAtomic `
    -Result $failedParentResult -EvidenceDirectory $durableDirectory -Mode Simulation
  $failedCheckpointReopened = Read-RisePalsCandidateDurableParentCheckpoint `
    -Path $failedCheckpointPath -EvidenceDirectory $durableDirectory `
    -InvocationNonce $failedDiagnosticNonce -Mode Simulation
  $failedParentReopened = Read-RisePalsCandidateDurableParentResult `
    -Path $failedParentPath -EvidenceDirectory $durableDirectory `
    -InvocationNonce $failedDiagnosticNonce -Mode Simulation
  [void](Assert-RisePalsCandidateParentCheckpoint `
    -Checkpoint $failedCheckpointReopened -ExpectedNonce $failedDiagnosticNonce `
    -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
    -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
    -ExpectedBootstrapScriptSha256 ("b" * 64) `
    -ExpectedTransportScriptSha256 ("c" * 64) `
    -ExpectedChildScriptSha256 ("d" * 64) `
    -ExpectedLaunchDiagnosticDigest ([string]$failedCheckpointReopened.launchDiagnostic.diagnosticDigest) `
    -ExpectedExecutionMode Live `
    -InvocationStartedAtUtc $parentValidationStarted -ConsumedNonces @{})
  [void](Assert-RisePalsCandidateParentResult -Result $failedParentReopened `
    -ExpectedNonce $failedDiagnosticNonce `
    -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
    -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
    -ExpectedBootstrapScriptSha256 ("b" * 64) `
    -ExpectedTransportScriptSha256 ("c" * 64) `
    -ExpectedChildScriptSha256 ("d" * 64) `
    -ExpectedCheckpointFileName ([IO.Path]::GetFileName($failedCheckpointPath)) `
    -ExpectedCheckpointDigest ([string]$failedCheckpointReopened.checkpointDigest) `
    -ExpectedLaunchDiagnosticDigest ([string]$failedCheckpointReopened.launchDiagnostic.diagnosticDigest) `
    -ExpectedChildDiagnosticDigest ([string]$failedCheckpointReopened.childDiagnostic.diagnosticDigest) `
    -ExpectedExecutionMode Live `
    -InvocationStartedAtUtc $parentValidationStarted -ConsumedNonces @{})
  if ($failedCheckpointReopened.childDiagnostic.failedStage -ne "direct-stop" -or
    $failedCheckpointReopened.childDiagnostic.functionalGates.directStop -ne "failed" -or
    $failedParentReopened.childDiagnostic.diagnosticDigest -ne
      $failedCheckpointReopened.childDiagnostic.diagnosticDigest) {
    throw "Durable failed-stage evidence did not survive transient cleanup."
  }

  $interruptedCheckpoint = New-RisePalsCandidateValidParentCheckpoint `
    -Nonce $interruptedNonce
  $interruptedCheckpointPath = Get-RisePalsCandidateDurableParentCheckpointPath `
    -EvidenceDirectory $durableDirectory -InvocationNonce $interruptedNonce
  [IO.File]::WriteAllText(
    $interruptedCheckpointPath + ".tmp",
    "partial",
    [Text.UTF8Encoding]::new($false)
  )
  Assert-RisePalsCandidateThrows -Label "Interrupted durable parent-checkpoint write" -Action {
    Write-RisePalsCandidateDurableParentCheckpointAtomic `
      -Checkpoint $interruptedCheckpoint `
      -EvidenceDirectory $durableDirectory -Mode Simulation
  }
  if ([IO.File]::Exists($interruptedCheckpointPath)) {
    throw "An interrupted checkpoint write created a final checkpoint."
  }
  $checkpointFailureResult = New-RisePalsCandidateParentResult `
    -Checkpoint $interruptedCheckpoint `
    -CheckpointFileName ([IO.Path]::GetFileName($interruptedCheckpointPath)) `
    -CheckpointDigest $null -DurableCheckpointValidated $false `
    -TransientCleanupAttempted $false -TransientCleanupCompleted $false `
    -InvocationDirectoryAbsent $false -RemainingTransientObjectCount 1 `
    -RemainingTemporaryObjectCount 0 `
    -RemainingTransientRelativePaths @("result.json")
  [void](Assert-RisePalsCandidateParentResult -Result $checkpointFailureResult `
    -ExpectedNonce $interruptedNonce `
    -ExpectedAuthorizationId "RP-TURN-019-R4-DIAG2-SIMULATION" `
    -ExpectedHead ("1" * 40) -ExpectedLauncherScriptSha256 ("a" * 64) `
    -ExpectedBootstrapScriptSha256 ("b" * 64) `
    -ExpectedTransportScriptSha256 ("c" * 64) `
    -ExpectedChildScriptSha256 ("d" * 64) `
    -ExpectedCheckpointFileName ([IO.Path]::GetFileName($interruptedCheckpointPath)) `
    -ExpectedCheckpointDigest $null `
    -ExpectedLaunchDiagnosticDigest ([string]$interruptedCheckpoint.launchDiagnostic.diagnosticDigest) `
    -ExpectedChildDiagnosticDigest ([string]$interruptedCheckpoint.childDiagnostic.diagnosticDigest) `
    -InvocationStartedAtUtc $parentValidationStarted `
    -ConsumedNonces @{})

  $interruptedResultCheckpoint = New-RisePalsCandidateValidParentCheckpoint `
    -Nonce $interruptedResultNonce
  $interruptedResultCheckpointPath = `
    Write-RisePalsCandidateDurableParentCheckpointAtomic `
      -Checkpoint $interruptedResultCheckpoint `
      -EvidenceDirectory $durableDirectory -Mode Simulation
  $interruptedResult = New-RisePalsCandidateParentResult `
    -Checkpoint $interruptedResultCheckpoint `
    -CheckpointFileName ([IO.Path]::GetFileName($interruptedResultCheckpointPath)) `
    -CheckpointDigest ([string]$interruptedResultCheckpoint.checkpointDigest) `
    -DurableCheckpointValidated $true -TransientCleanupAttempted $true `
    -TransientCleanupCompleted $true -InvocationDirectoryAbsent $true `
    -RemainingTransientObjectCount 0 -RemainingTemporaryObjectCount 0
  $interruptedResultPath = Get-RisePalsCandidateDurableParentResultPath `
    -EvidenceDirectory $durableDirectory -InvocationNonce $interruptedResultNonce
  [IO.File]::WriteAllText(
    $interruptedResultPath + ".tmp",
    "partial",
    [Text.UTF8Encoding]::new($false)
  )
  Assert-RisePalsCandidateThrows -Label "Interrupted authoritative parent-result write" -Action {
    Write-RisePalsCandidateDurableParentResultAtomic -Result $interruptedResult `
      -EvidenceDirectory $durableDirectory -Mode Simulation
  }
  if ([IO.File]::Exists($interruptedResultPath) -or
    -not [IO.File]::Exists($interruptedResultCheckpointPath)) {
    throw "An interrupted final-result write did not preserve only its checkpoint."
  }

  [IO.Directory]::CreateDirectory($unauthorizedRoot) | Out-Null
  Assert-RisePalsCandidateThrows -Label "Unauthorized durable evidence ACL" -Action {
    Assert-RisePalsCandidateEvidenceDirectory -Path $unauthorizedRoot -Mode Simulation
  }
  Assert-RisePalsCandidateThrows -Label "Escaped durable evidence root" -Action {
    Assert-RisePalsCandidateEvidenceDirectory -Path $repository -Mode Simulation
  }
  [IO.Directory]::CreateDirectory($durableJunctionTarget) | Out-Null
  [void](New-Item -ItemType Junction -Path $durableJunction `
    -Target $durableJunctionTarget)
  Assert-RisePalsCandidateThrows -Label "Linked durable evidence root" -Action {
    Assert-RisePalsCandidateEvidenceDirectory -Path $durableJunction -Mode Simulation
  }

  $orderedStart = [DateTimeOffset]::UtcNow
  [void](Assert-RisePalsCandidateMarkerOrdering -MarkerTimes @{
    "bootstrap-started" = $orderedStart
    "child-launch-attempted" = $orderedStart.AddMilliseconds(1)
    "child-started" = $orderedStart.AddMilliseconds(2)
    "live-started" = $orderedStart.AddMilliseconds(3)
  })
  Assert-RisePalsCandidateThrows -Label "Marker ordering violation" -Action {
    Assert-RisePalsCandidateMarkerOrdering -MarkerTimes @{
      "bootstrap-started" = $orderedStart
      "child-launch-attempted" = $orderedStart.AddMilliseconds(3)
      "child-started" = $orderedStart.AddMilliseconds(2)
    }
  }
  Assert-RisePalsCandidateThrows -Label "Marker predecessor violation" -Action {
    Assert-RisePalsCandidateMarkerOrdering -MarkerTimes @{
      "bootstrap-started" = $orderedStart
      "child-started" = $orderedStart.AddMilliseconds(1)
    }
  }
} finally {
  if ([IO.Directory]::Exists($durableJunction)) {
    [IO.Directory]::Delete($durableJunction, $false)
  }
  if ([IO.Directory]::Exists($durableJunctionTarget)) {
    [IO.Directory]::Delete($durableJunctionTarget, $false)
  }
  if ([IO.Directory]::Exists($unauthorizedRoot)) {
    [IO.Directory]::Delete($unauthorizedRoot, $false)
  }
  if ([IO.Directory]::Exists($durableRoot)) {
    [IO.Directory]::Delete($durableRoot, $true)
  }
}
if ([IO.Directory]::Exists($durableRoot) -or
  [IO.Directory]::Exists($unauthorizedRoot) -or
  [IO.Directory]::Exists($durableJunction) -or
  [IO.Directory]::Exists($durableJunctionTarget)) {
  throw "Durable parent-evidence simulations left a temporary resource."
}
Write-Output "Durable parent evidence/replay/ACL/ordering/cleanup simulations PASS"

$parentSource = [IO.File]::ReadAllText(
  (Join-Path $scripts "Invoke-RisePalsCandidateRehearsal.ps1")
)
$bootstrapSource = [IO.File]::ReadAllText(
  (Join-Path $scripts "Invoke-RisePalsCandidateElevatedBootstrap.ps1")
)
$childSource = [IO.File]::ReadAllText(
  (Join-Path $scripts "Invoke-RisePalsCandidateRehearsalChild.ps1")
)
$transportSource = [IO.File]::ReadAllText(
  (Join-Path $scripts "candidate-rehearsal-transport.ps1")
)
$probeChildPath = Join-Path $scripts `
  "Invoke-RisePalsCandidateElevationProbeChild.ps1"
$probeChildSource = [IO.File]::ReadAllText($probeChildPath)
$probeTokens = $null
$probeErrors = $null
$probeAst = [Management.Automation.Language.Parser]::ParseFile(
  $probeChildPath,
  [ref]$probeTokens,
  [ref]$probeErrors
)
$probeCommandNames = @($probeAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst]
  }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object {
    -not [string]::IsNullOrWhiteSpace($_)
  })
$probeProhibitedCommands = @(
  "Get-Service", "Set-Service", "New-Service", "Start-Service", "Stop-Service",
  "Restart-Service", "Remove-Service", "Get-NetTCPConnection",
  "New-NetFirewallRule", "Set-NetFirewallRule", "Remove-NetFirewallRule",
  "Get-ChildItem", "Remove-Item", "New-Item", "Copy-Item", "Move-Item",
  "Get-Acl", "Set-Acl", "Restart-Computer", "Stop-Computer"
)
$probeProhibitedText = @(
  "Invoke-RisePalsCandidateLiveSequence", "OpenSCManager", "CreateService",
  "ChangeServiceConfig", "ControlService", "DeleteService", "sc.exe",
  "C:\RisePals\", "node.exe", "RisePalsServiceHostCandidate",
  "New-SelfSignedCertificate", "Import-Certificate", "Preshutdown"
)
if ($probeErrors.Count -ne 0 -or
  @($probeCommandNames | Where-Object { $_ -in $probeProhibitedCommands }).Count -ne 0 -or
  @($probeProhibitedText | Where-Object {
    $probeChildSource.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0
  }).Count -ne 0) {
  throw "The ElevationProbe child can reach a prohibited Live or host-mutation operation."
}
if ($parentSource.Contains("RedirectStandardOutput") -or
  $parentSource.Contains("RedirectStandardError") -or
  $bootstrapSource.Contains("RedirectStandardOutput") -or
  $bootstrapSource.Contains("RedirectStandardError") -or
  $bootstrapSource.Contains("Get-FileHash") -or
  -not $bootstrapSource.Contains("SHA256]::Create()") -or
  -not $bootstrapSource.Contains("ComputeHash") -or
  -not $bootstrapSource.Contains('MarkerType "child-launch-attempted"') -or
  $bootstrapSource.Contains('MarkerType "child-started"') -or
  -not $childSource.Contains('MarkerType "child-started"') -or
  -not $parentSource.Contains("Write-RisePalsCandidateDurableParentCheckpointAtomic") -or
  -not $parentSource.Contains("Read-RisePalsCandidateDurableParentCheckpoint") -or
  -not $parentSource.Contains("Write-RisePalsCandidateDurableParentResultAtomic") -or
  -not $parentSource.Contains("Read-RisePalsCandidateDurableParentResult") -or
  -not $parentSource.Contains("New-RisePalsCandidateCanonicalLaunchRequest") -or
  -not $transportSource.Contains('$quotedValues') -or
  -not $transportSource.Contains("New-RisePalsCandidateCanonicalLaunchRequest") -or
  ([regex]::Matches($parentSource, "New-RisePalsCandidateCanonicalLaunchRequest")).Count -ne 1 -or
  ([regex]::Matches($parentSource, "Start-Process")).Count -ne 1 -or
  -not $parentSource.Contains('SanitizedLaunchFailureCode "malformed-launch-request"')) {
  throw "The parent/bootstrap boundary depends on raw streams or unsupported hashing."
}
Write-Output "Durable parent transport, truthful child ownership and no raw-output dependency PASS"
Write-Output "ElevationProbe PowerShell 5.1 AST and prohibited-operation boundary PASS"

$stages = @($contract.rehearsalStages)
$codes = @($contract.sanitizedFailureCodes)
if ($stages.Count -ne $codes.Count) {
  throw "Every modeled candidate stage requires one fixed failure classification."
}
for ($index = 0; $index -lt $stages.Count; $index++) {
  if ((Get-RisePalsCandidateFailureCodeForStage -Contract $contract -Stage $stages[$index]) -ne
    $codes[$index]) {
    throw "A candidate modeled stage lacks deterministic failure handling."
  }
}
Write-Output ("Modeled-stage failure classification PASS ({0} stages)" -f $stages.Count)

$liveSource = [IO.File]::ReadAllText(
  (Join-Path $scripts "Invoke-RisePalsCandidateLiveSequence.ps1")
)
if (-not $liveSource.Contains("Get-RisePalsCandidateFailureCodeForStage") -or
  -not $liveSource.Contains("Assert-RisePalsCandidateTaskTreeInventory") -or
  -not $liveSource.Contains("The elevated candidate preflight no longer matches") -or
  -not $liveSource.Contains("Get-RisePalsCandidatePreshutdownRegistration") -or
  -not $liveSource.Contains("QueryServiceConfig2") -or
  -not $liveSource.Contains("QueryServiceStatusEx") -or
  -not $liveSource.Contains("verify-retained-proxy-independence") -or
  -not $liveSource.Contains("Assert-RisePalsCandidateRetainedSnapshotEquality")) {
  throw "The live source does not consume the exact stage, tree and repository boundaries."
}
Write-Output "Live-stage code/tree/repository fail-closed wiring PASS"

$controlSource = [IO.File]::ReadAllText(
  (Join-Path $scripts "Invoke-RisePalsCandidateServiceControl.ps1")
)
if ($controlSource.Contains('"Preshutdown"') -or
  $controlSource -match "(?i)sc(?:\.exe)?[^\r\n]*control[^\r\n]*15" -or
  $liveSource.Contains("verify-preshutdown-checkpoints") -or
  $liveSource.Contains("verify-independent-proxy-restart") -or
  $liveSource.Contains("proxy-independence-failed")) {
  throw "A non-reboot synthetic Preshutdown dispatch or stale stage claim remains."
}
$candidateSources = @(
  "candidate-rehearsal-contract.ps1",
  "candidate-rehearsal-transport.ps1",
  "Invoke-RisePalsCandidateRehearsal.ps1",
  "Invoke-RisePalsCandidateElevatedBootstrap.ps1",
  "Invoke-RisePalsCandidateRehearsalChild.ps1",
  "Invoke-RisePalsCandidateLiveSequence.ps1",
  "Invoke-RisePalsCandidateServiceControl.ps1"
) | ForEach-Object { [IO.File]::ReadAllText((Join-Path $scripts $_)) }
foreach ($source in $candidateSources) {
  if ($source -match "(?i)(?:Start|Stop|Restart|Set)-Service[^\r\n]*RisePalsProxy" -or
    $source -match
      "(?i)(?:sc(?:\.exe)?|Invoke-RisePalsCandidateSc)[^\r\n]*(?:start|stop|control|config)[^\r\n]*RisePalsProxy") {
    throw "A candidate script mutates the retained proxy."
  }
}
Write-Output "Read-only Preshutdown registration and retained-proxy preservation wiring PASS"

$parseTargets = @(
  "candidate-rehearsal-contract.ps1",
  "candidate-rehearsal-result.ps1",
  "candidate-rehearsal-transport.ps1",
  "Invoke-RisePalsCandidateRehearsal.ps1",
  "Invoke-RisePalsCandidateElevatedBootstrap.ps1",
  "Invoke-RisePalsCandidateRehearsalChild.ps1",
  "Invoke-RisePalsCandidateLiveSequence.ps1",
  "Invoke-RisePalsCandidateServiceControl.ps1",
  "Test-RisePalsCandidateRehearsalHarness.ps1"
)
foreach ($name in $parseTargets) {
  $tokens = $null
  $errors = $null
  [void][Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $scripts $name),
    [ref]$tokens,
    [ref]$errors
  )
  if (@($errors).Count -ne 0) {
    throw "$name is not PowerShell 5.1 AST compatible."
  }
}
$suiteTokens = $null
$suiteErrors = $null
$suiteAst = [Management.Automation.Language.Parser]::ParseFile(
  $PSCommandPath,
  [ref]$suiteTokens,
  [ref]$suiteErrors
)
$mutatingCommands = @($suiteAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -in @(
      "Start-Process",
      "Start-Service",
      "Stop-Service",
      "New-Service",
      "Remove-Service"
    )
}, $true))
if ($mutatingCommands.Count -ne 0) {
  throw "Repository tests contain a reachable live or elevated command."
}
Write-Output "PowerShell 5.1 AST and no-live-test reachability PASS"

$identitySource = [IO.File]::ReadAllText(
  (Join-Path $repository "infra\windows-service-host\RisePals.ServiceHost\ServiceRegistrationIdentity.cs")
)
$orchestratorSource = [IO.File]::ReadAllText(
  (Join-Path $repository "infra\windows-service-host\RisePals.ServiceHost\ServiceOrchestrator.cs")
)
$evidenceSource = [IO.File]::ReadAllText(
  (Join-Path $repository "infra\windows-service-host\RisePals.ServiceHost\ProcessAdapters.cs")
)
if (-not $identitySource.Contains('CandidateServiceName = "RisePalsServiceHostCandidate"') -or
  -not $identitySource.Contains('RetainedApplicationServiceName = "RisePalsApp"') -or
  -not $identitySource.Contains('RetainedProxyServiceName = "RisePalsProxy"') -or
  -not $orchestratorSource.Contains("CleanupAttemptAsync") -or
  -not $orchestratorSource.Contains("OwnedProcessCleanupFailed") -or
  -not $evidenceSource.Contains("do not copy, classify, hash or measure raw child text")) {
  throw "An accepted R3-R1 correction contract is no longer present."
}
Write-Output "R3-R1 identity/startup-cleanup/evidence preservation PASS"
Write-Output "Rise Pals candidate rehearsal harness suite PASS."
