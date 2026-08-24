[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
  [string]$Root = "C:\RisePals",
  [string]$RepositoryRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$RepositoryRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
} else {
  $RepositoryRoot
}
$repository = [IO.Path]::GetFullPath($RepositoryRoot)
if (-not (Test-Path -LiteralPath (Join-Path $repository "AGENTS.md") -PathType Leaf)) {
  throw "The exact Rise Pals repository root is unavailable."
}

if (-not $PSCmdlet.ShouldProcess($validatedRoot, "Initialize the approved layout, tools and two disabled services")) {
  Write-Output "Bounded host-setup dry-run PASS"
  return
}

Assert-RisePalsAdministrator
& (Join-Path $PSScriptRoot "Initialize-RisePalsHost.ps1") -Root $validatedRoot -Confirm:$false
& (Join-Path $PSScriptRoot "Install-RisePalsTools.ps1") `
  -Root $validatedRoot -RepositoryRoot $repository -Confirm:$false
& (Join-Path $PSScriptRoot "Install-RisePalsServices.ps1") `
  -Root $validatedRoot -RepositoryRoot $repository -Confirm:$false
& (Join-Path $PSScriptRoot "Write-RisePalsHostManifest.ps1") `
  -Root $validatedRoot -Confirm:$false

Write-Output "Rise Pals bounded host setup PASS; both services remain Stopped and Disabled."
