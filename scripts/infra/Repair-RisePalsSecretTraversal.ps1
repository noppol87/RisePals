[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param([string]$Root = "C:\RisePals")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$secretDirectory = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $validatedRoot "shared\secrets"
)
Assert-RisePalsAdministrator
foreach ($name in @("RisePalsApp", "RisePalsProxy")) {
  $service = Assert-RisePalsServiceIsAbsentOrOwned -Name $name -Root $validatedRoot
  if ($null -eq $service -or $service.StartName -ne "NT SERVICE\$name" -or
    $service.State -ne "Stopped") {
    throw "Secret-boundary repair requires both owned virtual-account services to be Stopped."
  }
}

if (-not $PSCmdlet.ShouldProcess(
  $secretDirectory,
  "Grant non-inheriting Traverse to only the application virtual account"
)) {
  Write-Output "Secret-directory traversal repair dry-run PASS"
  return
}

Set-RisePalsProtectedAcl -Path $secretDirectory -Rules @(
  @{ Identity = "NT AUTHORITY\SYSTEM"; Rights = "FullControl" },
  @{ Identity = "BUILTIN\Administrators"; Rights = "FullControl" },
  @{
    Identity = "NT SERVICE\RisePalsApp"
    Rights = "Traverse"
    InheritanceFlags = "None"
  }
)
$acl = Get-Acl -LiteralPath $secretDirectory
$application = @($acl.Access | Where-Object {
  $_.IdentityReference.Value -eq "NT SERVICE\RisePalsApp"
})
$proxy = @($acl.Access | Where-Object {
  $_.IdentityReference.Value -eq "NT SERVICE\RisePalsProxy"
})
$unexpectedApplicationRights = [Security.AccessControl.FileSystemRights]::ListDirectory -bor
  [Security.AccessControl.FileSystemRights]::ReadAttributes -bor
  [Security.AccessControl.FileSystemRights]::ReadExtendedAttributes -bor
  [Security.AccessControl.FileSystemRights]::ReadPermissions
if (-not $acl.AreAccessRulesProtected -or $application.Count -ne 1 -or
  (($application[0].FileSystemRights -band [Security.AccessControl.FileSystemRights]::Traverse) -eq 0) -or
  (($application[0].FileSystemRights -band $unexpectedApplicationRights) -ne 0) -or
  $application[0].InheritanceFlags -ne [Security.AccessControl.InheritanceFlags]::None -or
  $proxy.Count -ne 0) {
  throw "The exact non-inheriting application-only secret traversal ACL failed verification."
}

Write-Output "Rise Pals application-only non-inheriting secret traversal repair PASS"
