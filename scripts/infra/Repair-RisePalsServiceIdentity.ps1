[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
  [string]$Root = "C:\RisePals",
  [string]$RepositoryRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
if (-not (Test-Path -LiteralPath $validatedRoot -PathType Container)) {
  throw "The approved Rise Pals root is absent."
}
$RepositoryRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
} else {
  $RepositoryRoot
}
$repository = [IO.Path]::GetFullPath($RepositoryRoot)
$sourceConfig = Join-Path $repository "infra\windows\winsw\RisePalsApp.xml"
$installedConfig = Join-Path $validatedRoot "tools\winsw\2.12.0\RisePalsApp.xml"
if (-not (Test-Path -LiteralPath $sourceConfig -PathType Leaf)) {
  throw "The corrected reviewed WinSW 2.x configuration is absent."
}
$services = @{}
foreach ($name in @("RisePalsApp", "RisePalsProxy")) {
  $service = Assert-RisePalsServiceIsAbsentOrOwned -Name $name -Root $validatedRoot
  if ($null -eq $service) {
    throw "The bounded repair requires both owned Rise Pals services."
  }
  if ($service.State -ne "Stopped" -or $service.StartMode -ne "Disabled") {
    throw "The bounded repair requires both services to remain Stopped and Disabled."
  }
  $services[$name] = $service
}
if ($services.RisePalsProxy.StartName -ne "NT SERVICE\RisePalsProxy") {
  throw "The proxy identity is not the expected virtual service account."
}

if (-not $PSCmdlet.ShouldProcess(
  "RisePalsApp",
  "Replace the rejected LocalSystem identity with NT SERVICE\RisePalsApp"
)) {
  Write-Output "Rise Pals application-service identity repair dry-run PASS"
  return
}

Assert-RisePalsAdministrator
Copy-Item -LiteralPath $sourceConfig -Destination $installedConfig -Force
Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @(
  "config",
  "RisePalsApp",
  "obj=",
  "NT SERVICE\RisePalsApp"
)

$repaired = Get-CimInstance Win32_Service -Filter "Name='RisePalsApp'"
if (
  $repaired.StartName -ne "NT SERVICE\RisePalsApp" -or
  $repaired.StartMode -ne "Disabled" -or
  $repaired.State -ne "Stopped"
) {
  throw "The bounded application-service identity repair did not converge safely."
}

Write-Output "Rise Pals application-service identity repair PASS; service remains Stopped and Disabled."
