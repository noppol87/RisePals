[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9.-]{2,63}$")][string]$ReleaseId,
  [string]$Root = "C:\RisePals",
  [uri]$HealthUri = "http://127.0.0.1:3100/health/ready",
  [switch]$SkipHealthCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$releases = Join-Path $validatedRoot "releases"
$target = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (Join-Path $releases $ReleaseId)
$current = Join-Path $validatedRoot "current"
if (
  -not (Test-Path -LiteralPath $target -PathType Container) -or
  -not (Test-Path -LiteralPath (Join-Path $target "release-manifest.json") -PathType Leaf)
) {
  throw "The requested reviewed release and manifest do not exist."
}
if ($HealthUri.Host -notin @("127.0.0.1", "localhost", "::1")) {
  throw "Release health checks must use loopback only."
}

$temporary = Join-Path $validatedRoot ("current.next." + [guid]::NewGuid().ToString("N"))
$previous = Join-Path $validatedRoot ("current.previous." + [guid]::NewGuid().ToString("N"))

if (-not $PSCmdlet.ShouldProcess($current, "Atomically switch to reviewed release $ReleaseId")) {
  Write-Output "Release switch dry-run PASS for $ReleaseId"
  return
}

Assert-RisePalsAdministrator

$appService = Assert-RisePalsServiceIsAbsentOrOwned -Name "RisePalsApp" -Root $validatedRoot
$restartForHealth = -not $SkipHealthCheck
if ($restartForHealth -and ($null -eq $appService -or $appService.State -ne "Running")) {
  throw "A health-checked switch requires the owned application service to be Running."
}

New-Item -ItemType Junction -Path $temporary -Target $target | Out-Null
$hadCurrent = Test-Path -LiteralPath $current
$previousReleaseId = ""
try {
  if ($hadCurrent) {
    $currentItem = Get-Item -LiteralPath $current -Force
    if ($currentItem.LinkType -ne "Junction") {
      throw "The current release boundary is not an NTFS junction."
    }
    $resolvedCurrent = [IO.Path]::GetFullPath([string]$currentItem.Target)
    [void](Get-RisePalsValidatedChildPath -Root $releases -Path $resolvedCurrent)
    $previousReleaseId = Split-Path -Leaf $resolvedCurrent
    if ($restartForHealth) {
      Stop-Service -Name "RisePalsApp"
      (Get-Service -Name "RisePalsApp").WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
    }
    Move-Item -LiteralPath $current -Destination $previous
  }
  Move-Item -LiteralPath $temporary -Destination $current

  if (-not $SkipHealthCheck) {
    Start-Service -Name "RisePalsApp"
    (Get-Service -Name "RisePalsApp").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
    $response = Invoke-WebRequest -UseBasicParsing -Uri $HealthUri -TimeoutSec 15
    if ($response.StatusCode -ne 200 -or $response.Content -notmatch '"status":"ready"') {
      throw "The switched release failed its loopback readiness check."
    }
  }

  if ($hadCurrent) {
    Remove-RisePalsValidatedChild -Root $validatedRoot -Path $previous
  }
  Write-RisePalsDeploymentEvent -Root $validatedRoot -Event "release-switched" -ReleaseId $ReleaseId
} catch {
  $failure = $_
  if ($restartForHealth) {
    $runningService = Get-Service -Name "RisePalsApp" -ErrorAction SilentlyContinue
    if ($null -ne $runningService -and $runningService.Status -ne "Stopped") {
      Stop-Service -Name "RisePalsApp" -Force
      $runningService.WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
    }
  }
  if (Test-Path -LiteralPath $current) {
    Remove-RisePalsValidatedChild -Root $validatedRoot -Path $current
  }
  if (Test-Path -LiteralPath $previous) {
    Move-Item -LiteralPath $previous -Destination $current
  }
  if (Test-Path -LiteralPath $temporary) {
    Remove-RisePalsValidatedChild -Root $validatedRoot -Path $temporary
  }
  if ($restartForHealth -and $hadCurrent) {
    Start-Service -Name "RisePalsApp"
    (Get-Service -Name "RisePalsApp").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
    $rollback = Invoke-WebRequest -UseBasicParsing -Uri $HealthUri -TimeoutSec 15
    if ($rollback.StatusCode -ne 200 -or $rollback.Content -notmatch '"status":"ready"') {
      throw "Candidate failed and the prior release did not recover readiness."
    }
    Write-RisePalsDeploymentEvent -Root $validatedRoot -Event "automatic-rollback" `
      -ReleaseId $previousReleaseId
  }
  throw $failure
}

Write-Output "Atomic release switch PASS: $ReleaseId"
