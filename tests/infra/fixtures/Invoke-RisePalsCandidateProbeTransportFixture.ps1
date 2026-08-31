[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ResultScriptPath,
  [Parameter(Mandatory = $true)][string]$TransportScriptPath,
  [Parameter(Mandatory = $true)][string]$CheckpointPath,
  [Parameter(Mandatory = $true)][string]$ResultPath,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")]
  [string]$InvocationNonce,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")]
  [string]$RepositoryHead,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")]
  [string]$LauncherScriptSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")]
  [string]$BootstrapScriptSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")]
  [string]$TransportScriptSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")]
  [string]$ChildScriptSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. ([IO.Path]::GetFullPath($ResultScriptPath))
. ([IO.Path]::GetFullPath($TransportScriptPath))

$authorizationId = "RP-TURN-019-R4-PROBE-A1B2C3D4"
$launchArguments = @(
  "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
  '"synthetic-probe-bootstrap.ps1"'
)
$launchDiagnostic = New-RisePalsCandidateLaunchDiagnostic `
  -LaunchAttempted $true -ProcessCreated $true -LaunchDisposition launched `
  -SanitizedLaunchFailureCode none -NativeErrorCode $null -HResult $null `
  -ExceptionDepth 0 -LauncherExecutableExists $true `
  -LauncherSignatureStatus valid -LaunchVerb RunAs `
  -ArgumentCount $launchArguments.Count `
  -CanonicalArgumentDigest (Get-RisePalsCandidateCanonicalArgumentDigest `
    -Arguments $launchArguments)
$probeDiagnostic = New-RisePalsCandidateProbeDiagnostic -ProbeStatus success `
  -FailedStage $null -SanitizedFailureCode $null `
  -ElevatedChildEntered $true -AdministratorRoleConfirmed $true `
  -IntegrityLevel high -RepositoryHeadMatched $true `
  -AuthorizationMatched $true -InvocationNonceMatched $true `
  -LauncherHashMatched $true -BootstrapHashMatched $true `
  -TransportHashMatched $true -ChildHashMatched $true
$childDiagnostic = New-RisePalsCandidateChildDiagnostic -Result $null `
  -ExecutionMode ElevationProbe -CleanupResponsibilityTransferredToParent $true
$checkpoint = New-RisePalsCandidateParentCheckpoint `
  -InvocationNonce $InvocationNonce -AuthorizationId $authorizationId `
  -RepositoryHead $RepositoryHead -LauncherScriptSha256 $LauncherScriptSha256 `
  -BootstrapScriptSha256 $BootstrapScriptSha256 `
  -TransportScriptSha256 $TransportScriptSha256 `
  -ChildScriptSha256 $ChildScriptSha256 -ExecutionMode ElevationProbe `
  -LaunchDiagnostic $launchDiagnostic -ProbeDiagnostic $probeDiagnostic `
  -LaunchDisposition launched -Classification elevation-probe-success `
  -ProcessLaunched $true -ElevatedExitCode 0 -BootstrapEntered $true `
  -BootstrapStarted $true -BootstrapFailurePresent $false `
  -ChildLaunchAttempted $true -ChildStarted $true -LiveStarted $false `
  -FinalPresent $true -FinalValidated $true -FinalStatus success `
  -ChildDiagnostic $childDiagnostic
Write-RisePalsCandidateJsonAtomic -Value $checkpoint `
  -ResultPath ([IO.Path]::GetFullPath($CheckpointPath)) `
  -TemporaryPath ([IO.Path]::GetFullPath($CheckpointPath) + ".tmp")

$result = New-RisePalsCandidateParentResult -Checkpoint $checkpoint `
  -CheckpointFileName ([IO.Path]::GetFileName($CheckpointPath)) `
  -CheckpointDigest $checkpoint.checkpointDigest `
  -DurableCheckpointValidated $true -TransientCleanupAttempted $true `
  -TransientCleanupCompleted $true -InvocationDirectoryAbsent $true `
  -RemainingTransientObjectCount 0 -RemainingTemporaryObjectCount 0
Write-RisePalsCandidateJsonAtomic -Value $result `
  -ResultPath ([IO.Path]::GetFullPath($ResultPath)) `
  -TemporaryPath ([IO.Path]::GetFullPath($ResultPath) + ".tmp")
