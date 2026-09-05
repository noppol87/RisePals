[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9.-]{2,63}$")][string]$LastKnownGoodReleaseId,
  [string]$Root = "C:\RisePals"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$target = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $validatedRoot "releases\$LastKnownGoodReleaseId"
)
if (-not (Test-Path -LiteralPath (Join-Path $target "release-manifest.json") -PathType Leaf)) {
  throw "The requested last-known-good release is not reviewed and manifest-backed."
}

if ($PSCmdlet.ShouldProcess($target, "Rollback current to the reviewed last-known-good release")) {
  & (Join-Path $PSScriptRoot "Switch-RisePalsRelease.ps1") `
    -ReleaseId $LastKnownGoodReleaseId `
    -Root $validatedRoot
}

Write-Output "Manual rollback PASS: $LastKnownGoodReleaseId"
