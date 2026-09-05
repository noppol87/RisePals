[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param([string]$Root = "C:\RisePals")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$checkpoint = Join-Path $validatedRoot "logs\deploy\reboot-checkpoint.json"
$completion = Join-Path $validatedRoot "logs\deploy\reboot-completion.json"
if (-not (Test-Path -LiteralPath $checkpoint -PathType Leaf)) {
  throw "The approved reboot checkpoint record is absent."
}
$record = Get-Content -LiteralPath $checkpoint -Raw -Encoding UTF8 | ConvertFrom-Json
$prepared = [DateTime]::Parse(
  [string]$record.preparedAtUtc,
  [Globalization.CultureInfo]::InvariantCulture,
  [Globalization.DateTimeStyles]::RoundtripKind
).ToUniversalTime()
$boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
if ($boot -le $prepared) {
  throw "No controlled reboot occurred after the approved checkpoint was prepared."
}

if (-not $PSCmdlet.ShouldProcess($validatedRoot, "Verify reboot recovery then stop, disable and clean the rehearsal")) {
  Write-Output "Reboot checkpoint completion dry-run PASS"
  return
}

Assert-RisePalsAdministrator
$automaticRecovery = $false
try {
  $deadline = [DateTime]::UtcNow.AddSeconds(60)
  do {
    $services = @(@("RisePalsApp", "RisePalsProxy") | ForEach-Object {
      Assert-RisePalsServiceIsAbsentOrOwned -Name $_ -Root $validatedRoot
    })
    if (@($services | Where-Object {
      $null -eq $_ -or $_.StartName -ne "NT SERVICE\$($_.Name)" -or
        $_.StartMode -ne "Auto" -or $_.State -ne "Running"
    }).Count -eq 0) {
      $automaticRecovery = $true
      break
    }
    Start-Sleep -Milliseconds 500
  } while ([DateTime]::UtcNow -lt $deadline)
  if (-not $automaticRecovery) {
    throw "A Rise Pals service did not recover automatically after reboot."
  }
  & (Join-Path $PSScriptRoot "Test-RisePalsHealth.ps1") -Root $validatedRoot
} finally {
  & (Join-Path $PSScriptRoot "Clear-RisePalsRehearsal.ps1") `
    -Root $validatedRoot -Confirm:$false
}
$finalServices = @(Get-CimInstance Win32_Service -Filter "Name='RisePalsApp' OR Name='RisePalsProxy'")
$listeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -in @(2019, 3100, 8080, 8443) })
if (@($finalServices | Where-Object {
  $_.State -ne "Stopped" -or $_.StartMode -ne "Disabled"
}).Count -ne 0 -or $listeners.Count -ne 0) {
  throw "The required post-reboot disabled final state failed."
}
$result = [ordered]@{
  schemaVersion = "rise-pals-reboot-completion-v1"
  verifiedAtUtc = [DateTime]::UtcNow.ToString("o")
  bootAfterCheckpoint = $true
  sourceCommit = [string]$record.sourceCommit
  releaseId = [string]$record.releaseId
  automaticRecovery = $automaticRecovery
  finalServiceState = "Stopped/Disabled"
  finalListenerCount = 0
  canaryRemoved = -not (Test-Path -LiteralPath (
    Join-Path $validatedRoot "shared\secrets\rehearsal.canary"
  ))
}
[IO.File]::WriteAllText(
  $completion,
  (($result | ConvertTo-Json -Depth 4) + "`n"),
  [Text.UTF8Encoding]::new($false)
)
Write-Output "Rise Pals automatic reboot recovery and disabled cleanup PASS"
