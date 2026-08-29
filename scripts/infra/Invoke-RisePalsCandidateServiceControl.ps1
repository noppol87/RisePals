[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][ValidateSet("Stop", "Preshutdown")][string]$Control
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$serviceName = "RisePalsServiceHostCandidate"
if (-not $PSCmdlet.ShouldProcess($serviceName, ("Send direct " + $Control + " control"))) {
  Write-Output "Rise Pals candidate service-control dry-run PASS"
  return
}

if ($Control -eq "Stop") {
  Stop-Service -Name $serviceName -ErrorAction Stop
  return
}

$sc = Join-Path $env:SystemRoot "System32\sc.exe"
if (-not (Test-Path -LiteralPath $sc -PathType Leaf)) {
  throw "The native SCM client is absent."
}
$process = Start-Process -FilePath $sc -ArgumentList @("control", $serviceName, "15") `
  -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) {
  throw "The candidate Preshutdown control was rejected."
}
