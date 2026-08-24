[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param([string]$Root = "C:\RisePals")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root

$relativeDirectories = @(
  "tools\node\24.18.1",
  "tools\caddy\2.11.4",
  "tools\winsw\2.12.0",
  "staging",
  "releases",
  "shared\config",
  "shared\secrets",
  "shared\cache",
  "shared\cache\caddy",
  "logs\app",
  "logs\proxy",
  "logs\deploy",
  "rehearsal"
)

if ($PSCmdlet.ShouldProcess($validatedRoot, "Create the approved Rise Pals host layout")) {
  Assert-RisePalsAdministrator
  [IO.Directory]::CreateDirectory($validatedRoot) | Out-Null
  foreach ($relative in $relativeDirectories) {
    $path = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (Join-Path $validatedRoot $relative)
    [IO.Directory]::CreateDirectory($path) | Out-Null
  }

  $baseRules = @(
    @{ Identity = "NT AUTHORITY\SYSTEM"; Rights = "FullControl" },
    @{ Identity = "BUILTIN\Administrators"; Rights = "FullControl" }
  )
  Set-RisePalsProtectedAcl -Path $validatedRoot -Rules $baseRules
}

Write-Output "Rise Pals host-layout validation PASS"
