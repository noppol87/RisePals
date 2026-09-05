[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][ValidateSet("Stop")][string]$Control
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$serviceName = "RisePalsServiceHostCandidate"
if (-not $PSCmdlet.ShouldProcess($serviceName, ("Send direct " + $Control + " control"))) {
  Write-Output "Rise Pals candidate service-control dry-run PASS"
  return
}

Stop-Service -Name $serviceName -ErrorAction Stop
