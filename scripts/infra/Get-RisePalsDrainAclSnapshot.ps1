[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ControlDirectory,
  [string]$ChildPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$approvedControlDirectory = "C:\RisePals\shared\control"
$resolvedControl = [IO.Path]::GetFullPath($ControlDirectory).TrimEnd(
  [IO.Path]::DirectorySeparatorChar
)
if (-not $resolvedControl.Equals(
  $approvedControlDirectory,
  [StringComparison]::OrdinalIgnoreCase
)) {
  throw "The drain ACL snapshot requires the exact approved control directory."
}
if (-not (Test-Path -LiteralPath $resolvedControl -PathType Container)) {
  throw "The approved drain control directory is unavailable."
}

$resolvedChild = ""
if (-not [string]::IsNullOrWhiteSpace($ChildPath)) {
  $resolvedChild = [IO.Path]::GetFullPath($ChildPath)
  $childParent = [IO.Path]::GetDirectoryName($resolvedChild).TrimEnd(
    [IO.Path]::DirectorySeparatorChar
  )
  if (-not $childParent.Equals($resolvedControl, [StringComparison]::OrdinalIgnoreCase)) {
    throw "The drain ACL child must be a direct child of the approved control directory."
  }
  if (-not (Test-Path -LiteralPath $resolvedChild -PathType Leaf)) {
    throw "The drain ACL child file is unavailable."
  }
  if (-not [IO.Path]::GetPathRoot($resolvedChild).Equals(
    [IO.Path]::GetPathRoot($resolvedControl),
    [StringComparison]::OrdinalIgnoreCase
  )) {
    throw "The drain ACL child must remain on the control-directory volume."
  }
}

function ConvertTo-RisePalsAclRuleSnapshot {
  param([Parameter(Mandatory = $true)]$Rule)

  $sid = [Security.Principal.SecurityIdentifier]$Rule.IdentityReference
  $identityResolved = $true
  try {
    [void]$sid.Translate([Security.Principal.NTAccount])
  } catch [Security.Principal.IdentityNotMappedException] {
    $identityResolved = $false
  }
  return [ordered]@{
    sid = $sid.Value
    identityResolved = $identityResolved
    rightsMask = [int64]$Rule.FileSystemRights
    accessControlType = [int]$Rule.AccessControlType
    isInherited = [bool]$Rule.IsInherited
    inheritanceFlagsMask = [int]$Rule.InheritanceFlags
    propagationFlagsMask = [int]$Rule.PropagationFlags
  }
}

function Get-RisePalsAclEntrySnapshot {
  param([Parameter(Mandatory = $true)][string]$Path)

  $acl = Get-Acl -LiteralPath $Path
  $rules = @($acl.GetAccessRules(
    $true,
    $true,
    [Security.Principal.SecurityIdentifier]
  ) | ForEach-Object {
    ConvertTo-RisePalsAclRuleSnapshot -Rule $_
  })
  return [ordered]@{
    path = [IO.Path]::GetFullPath($Path)
    volumeRoot = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
    areAccessRulesProtected = [bool]$acl.AreAccessRulesProtected
    rules = $rules
  }
}

$approvedSids = [ordered]@{}
foreach ($entry in @(
  @{ Key = "system"; Account = "NT AUTHORITY\SYSTEM" },
  @{ Key = "administrators"; Account = "BUILTIN\Administrators" },
  @{ Key = "application"; Account = "NT SERVICE\RisePalsApp" }
)) {
  $account = [Security.Principal.NTAccount]::new([string]$entry.Account)
  $approvedSids[[string]$entry.Key] = (
    $account.Translate([Security.Principal.SecurityIdentifier])
  ).Value
}

$snapshot = [ordered]@{
  schemaVersion = "rise-pals-drain-acl-snapshot-v1"
  approvedSids = $approvedSids
  parent = Get-RisePalsAclEntrySnapshot -Path $resolvedControl
  child = if ([string]::IsNullOrWhiteSpace($resolvedChild)) {
    $null
  } else {
    Get-RisePalsAclEntrySnapshot -Path $resolvedChild
  }
}

[Console]::Out.WriteLine(($snapshot | ConvertTo-Json -Depth 8 -Compress))
