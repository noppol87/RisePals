[CmdletBinding()]
param([string]$Root = "C:\RisePals")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$pendingReboot = [bool](
  (Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or
  (Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") -or
  ((Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
      -Name PendingFileRenameOperations -ErrorAction SilentlyContinue) -ne $null)
)
$ports = @(80, 443, 2019, 3100, 8080, 8443)
$listeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -in $ports } |
  ForEach-Object {
    [ordered]@{
      addressClass = if ($_.LocalAddress -in @("127.0.0.1", "::1")) { "loopback" } else { "non-loopback" }
      port = $_.LocalPort
    }
  })
$services = @(Get-CimInstance Win32_Service -Filter "Name='RisePalsApp' OR Name='RisePalsProxy'" |
  ForEach-Object {
    [ordered]@{
      name = $_.Name
      state = $_.State
      startMode = $_.StartMode
      identity = $_.StartName
      ownedPath = $_.PathName.IndexOf($validatedRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0
    }
  })
$enabledRisePalsFirewallRules = @(
  Get-NetFirewallRule -Enabled True -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "Rise Pals*" }
)
$processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
  Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($validatedRoot, [StringComparison]::OrdinalIgnoreCase) })

$inventory = [ordered]@{
  schemaVersion = "rise-pals-host-inventory-v1"
  operatingSystem = (Get-CimInstance Win32_OperatingSystem).Caption
  build = (Get-CimInstance Win32_OperatingSystem).BuildNumber
  architecture = $env:PROCESSOR_ARCHITECTURE
  pendingReboot = $pendingReboot
  risePalsRootExists = Test-Path -LiteralPath $validatedRoot
  listeners = $listeners
  services = $services
  enabledRisePalsFirewallRuleCount = $enabledRisePalsFirewallRules.Count
  risePalsProcessCount = $processes.Count
}

$inventory | ConvertTo-Json -Depth 5
