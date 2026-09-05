[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param([string]$Root = "C:\RisePals")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
Assert-RisePalsAdministrator
foreach ($name in @("RisePalsApp", "RisePalsProxy")) {
  $service = Assert-RisePalsServiceIsAbsentOrOwned -Name $name -Root $validatedRoot
  if ($null -eq $service) {
    throw "Required service $name is not installed."
  }
  if ($service.StartName -ne "NT SERVICE\$name") {
    throw "Required virtual service identity mismatch for $name."
  }
}
$secret = Join-Path $validatedRoot "shared\secrets\rehearsal.canary"
if (-not (Test-Path -LiteralPath $secret -PathType Leaf)) {
  throw "The bounded synthetic rehearsal secret is absent."
}

if (-not $PSCmdlet.ShouldProcess($validatedRoot, "Temporarily set Manual and start both loopback-only rehearsal services")) {
  Write-Output "Rehearsal service start dry-run PASS"
  return
}

foreach ($name in @("RisePalsApp", "RisePalsProxy")) {
  Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @("config", $name, "start=", "demand")
}
Start-Service -Name "RisePalsApp"
(Get-Service -Name "RisePalsApp").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
Start-Service -Name "RisePalsProxy"
(Get-Service -Name "RisePalsProxy").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))

$deadline = [DateTime]::UtcNow.AddSeconds(30)
do {
  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:3100/health/ready" `
      -TimeoutSec 2
    if ($response.StatusCode -eq 200) {
      break
    }
  } catch {
    if ([DateTime]::UtcNow -ge $deadline) {
      throw "Application readiness did not become healthy."
    }
    Start-Sleep -Milliseconds 500
  }
} while ([DateTime]::UtcNow -lt $deadline)

& (Join-Path $PSScriptRoot "Test-RisePalsHealth.ps1") -Root $validatedRoot

Write-Output "Rise Pals loopback rehearsal services PASS"
