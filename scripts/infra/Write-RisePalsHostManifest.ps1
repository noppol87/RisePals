[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param([string]$Root = "C:\RisePals")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$destination = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $validatedRoot "logs\deploy\host-change-manifest.json"
)

if (-not $PSCmdlet.ShouldProcess($destination, "Write the sanitized Rise Pals host-change manifest")) {
  Write-Output "Host-change manifest dry-run PASS"
  return
}

Assert-RisePalsAdministrator
$approvedPaths = @(
  "tools\node\24.18.1",
  "tools\caddy\2.11.4",
  "tools\winsw\2.12.0",
  "staging",
  "releases",
  "current",
  "shared\config",
  "shared\secrets",
  "shared\cache",
  "shared\cache\caddy",
  "logs\app",
  "logs\proxy",
  "logs\deploy",
  "rehearsal"
)
$pathState = @($approvedPaths | ForEach-Object {
  [ordered]@{
    relativePath = $_
    exists = Test-Path -LiteralPath (Join-Path $validatedRoot $_)
  }
})
$serviceState = @(@("RisePalsApp", "RisePalsProxy") | ForEach-Object {
  $service = Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue
  if ($null -eq $service) {
    [ordered]@{ name = $_; exists = $false }
  } else {
    [ordered]@{
      name = $_
      exists = $true
      identity = $service.StartName
      startMode = $service.StartMode
      state = $service.State
      ownedPath = $service.PathName.IndexOf($validatedRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0
    }
  }
})
$manifest = [ordered]@{
  schemaVersion = "rise-pals-host-change-manifest-v1"
  generatedAtUtc = [DateTime]::UtcNow.ToString("o")
  root = $validatedRoot
  paths = $pathState
  services = $serviceState
  enabledRisePalsFirewallRuleCount = @(
    Get-NetFirewallRule -Enabled True -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName -like "Rise Pals*" }
  ).Count
}
[IO.File]::WriteAllText(
  $destination,
  (($manifest | ConvertTo-Json -Depth 5) + "`n"),
  [Text.UTF8Encoding]::new($false)
)
Write-Output "Sanitized Rise Pals host-change manifest PASS"
