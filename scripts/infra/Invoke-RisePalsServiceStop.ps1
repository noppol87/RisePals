[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("RisePalsApp")]
  [string]$ServiceName,
  [switch]$IgnoreAlreadyStopped
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($PSCmdlet.ShouldProcess($ServiceName, "Stop the exact Rise Pals application service")) {
  if ($IgnoreAlreadyStopped) {
    Stop-Service -Name $ServiceName -ErrorAction SilentlyContinue
  } else {
    Stop-Service -Name $ServiceName
  }
}
