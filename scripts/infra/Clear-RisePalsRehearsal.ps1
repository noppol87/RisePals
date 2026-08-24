[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param([string]$Root = "C:\RisePals")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
Assert-RisePalsAdministrator

if (-not $PSCmdlet.ShouldProcess($validatedRoot, "Stop/disable services and remove bounded rehearsal-only resources")) {
  Write-Output "Rehearsal cleanup dry-run PASS"
  return
}

foreach ($name in @("RisePalsProxy", "RisePalsApp")) {
  $service = Assert-RisePalsServiceIsAbsentOrOwned -Name $name -Root $validatedRoot
  if ($null -ne $service) {
    if ($service.State -ne "Stopped") {
      Stop-Service -Name $name -Force
      (Get-Service -Name $name).WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
    }
    Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @("config", $name, "start=", "disabled")
  }
}

$secretPath = Join-Path $validatedRoot "shared\secrets\rehearsal.canary"
if (Test-Path -LiteralPath $secretPath) {
  Remove-RisePalsValidatedChild -Root $validatedRoot -Path $secretPath
}

$rehearsal = Join-Path $validatedRoot "rehearsal"
Get-ChildItem -LiteralPath $rehearsal -Force | ForEach-Object {
  $validated = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path $_.FullName
  if ($_.PSIsContainer) {
    Remove-RisePalsValidatedChild -Root $validatedRoot -Path $validated -Recurse
  } else {
    Remove-RisePalsValidatedChild -Root $validatedRoot -Path $validated
  }
}

Start-Sleep -Milliseconds 500
$processes = @(Get-CimInstance Win32_Process |
  Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($validatedRoot, [StringComparison]::OrdinalIgnoreCase) })
$listeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -in @(2019, 3100, 8080, 8443) })
if ($processes.Count -ne 0 -or $listeners.Count -ne 0 -or (Test-Path -LiteralPath $secretPath)) {
  throw "Rehearsal cleanup left a process, listener or synthetic secret."
}

Write-Output "Rise Pals rehearsal cleanup PASS; services are Stopped/Disabled and temporary resources are absent."
