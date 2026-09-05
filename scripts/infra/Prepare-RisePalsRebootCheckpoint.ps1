[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$ExpectedSourceCommit,
  [string]$Root = "C:\RisePals"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$current = Join-Path $validatedRoot "current"
$checkpoint = Join-Path $validatedRoot "logs\deploy\reboot-checkpoint.json"
if (-not (Test-Path -LiteralPath $current -PathType Container)) {
  throw "A reviewed current release is required for the reboot checkpoint."
}
$currentItem = Get-Item -LiteralPath $current -Force
if ($currentItem.LinkType -ne "Junction") {
  throw "The current release boundary is not an NTFS junction."
}
$target = [IO.Path]::GetFullPath([string]$currentItem.Target)
[void](Get-RisePalsValidatedChildPath -Root (Join-Path $validatedRoot "releases") -Path $target)
$manifestPath = Join-Path $target "release-manifest.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.sourceCommit -ne $ExpectedSourceCommit) {
  throw "The current release does not match the separately approved reboot source commit."
}

if (-not $PSCmdlet.ShouldProcess($validatedRoot, "Prepare two Automatic loopback-only services for one approved reboot")) {
  Write-Output "Reboot checkpoint preparation dry-run PASS"
  return
}

Assert-RisePalsAdministrator
foreach ($name in @("RisePalsApp", "RisePalsProxy")) {
  $service = Assert-RisePalsServiceIsAbsentOrOwned -Name $name -Root $validatedRoot
  if ($null -eq $service -or $service.StartName -ne "NT SERVICE\$name" -or
    $service.State -ne "Stopped" -or $service.StartMode -ne "Disabled") {
    throw "The approved disabled virtual-account service checkpoint precondition failed."
  }
}
try {
  & (Join-Path $PSScriptRoot "Set-RisePalsRehearsalSecret.ps1") `
    -Action Create -Root $validatedRoot -Confirm:$false
  foreach ($name in @("RisePalsApp", "RisePalsProxy")) {
    Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @("config", $name, "start=", "auto")
  }
  Start-Service -Name "RisePalsApp"
  (Get-Service -Name "RisePalsApp").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
  Start-Service -Name "RisePalsProxy"
  (Get-Service -Name "RisePalsProxy").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
  & (Join-Path $PSScriptRoot "Test-RisePalsHealth.ps1") -Root $validatedRoot
  $record = [ordered]@{
    schemaVersion = "rise-pals-reboot-checkpoint-v1"
    preparedAtUtc = [DateTime]::UtcNow.ToString("o")
    sourceCommit = $ExpectedSourceCommit
    releaseId = Split-Path -Leaf $target
    services = @("RisePalsApp", "RisePalsProxy")
    expectedDowntimeMinutes = "2-5"
  }
  [IO.File]::WriteAllText(
    $checkpoint,
    (($record | ConvertTo-Json -Depth 4) + "`n"),
    [Text.UTF8Encoding]::new($false)
  )
} catch {
  & (Join-Path $PSScriptRoot "Clear-RisePalsRehearsal.ps1") `
    -Root $validatedRoot -Confirm:$false
  throw
}
Write-Output "Rise Pals reboot checkpoint prepared; no reboot was initiated."
