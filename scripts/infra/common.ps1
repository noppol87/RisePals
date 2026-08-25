Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RisePalsApprovedRoot = "C:\RisePals"

function Get-RisePalsValidatedRoot {
  param([string]$Root = $script:RisePalsApprovedRoot)

  $resolved = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)
  if (-not $resolved.Equals($script:RisePalsApprovedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "The infrastructure root must resolve exactly to C:\RisePals."
  }
  return $resolved
}

function Get-RisePalsValidatedChildPath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $resolvedPath = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $prefix = $resolvedRoot + [IO.Path]::DirectorySeparatorChar
  if (-not $resolvedPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "The path is not a validated child of the Rise Pals infrastructure root."
  }
  return $resolvedPath
}

function Assert-RisePalsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This bounded host mutation requires an elevated Windows PowerShell process."
  }
}

function Assert-RisePalsServiceIsAbsentOrOwned {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Root
  )

  $service = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
  if ($null -eq $service) {
    return $null
  }

  if ($service.PathName.IndexOf($Root, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw "Service $Name exists but is not owned by the validated Rise Pals root."
  }
  return $service
}

function Invoke-RisePalsNativeCommand {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Native command failed with exit code $LASTEXITCODE."
  }
}

function Remove-RisePalsValidatedChild {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path,
    [switch]$Recurse
  )

  $validated = Get-RisePalsValidatedChildPath -Root $Root -Path $Path
  if (-not (Test-Path -LiteralPath $validated)) {
    return
  }

  if (-not $Recurse) {
    Remove-Item -LiteralPath $validated -Force
    return
  }

  function Remove-RisePalsDirectoryEntry {
    param([Parameter(Mandatory = $true)][string]$EntryPath)

    $attributes = [IO.File]::GetAttributes($EntryPath)
    $isDirectory = ($attributes -band [IO.FileAttributes]::Directory) -ne 0
    $isReparsePoint = ($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
    if (-not $isDirectory) {
      [IO.File]::SetAttributes($EntryPath, [IO.FileAttributes]::Normal)
      [IO.File]::Delete($EntryPath)
      return
    }
    if ($isReparsePoint) {
      [IO.Directory]::Delete($EntryPath)
      return
    }
    foreach ($child in [IO.Directory]::EnumerateFileSystemEntries($EntryPath)) {
      Remove-RisePalsDirectoryEntry -EntryPath $child
    }
    [IO.Directory]::Delete($EntryPath)
  }

  Remove-RisePalsDirectoryEntry -EntryPath $validated
}

function Set-RisePalsProtectedAcl {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][hashtable[]]$Rules
  )

  $acl = [Security.AccessControl.DirectorySecurity]::new()
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    $acl = [Security.AccessControl.FileSecurity]::new()
  }
  $acl.SetAccessRuleProtection($true, $false)

  foreach ($rule in $Rules) {
    $identity = [Security.Principal.NTAccount]::new([string]$rule.Identity)
    [void]$identity.Translate([Security.Principal.SecurityIdentifier])
    $inheritance = if ($acl -is [Security.AccessControl.DirectorySecurity]) {
      [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [Security.AccessControl.InheritanceFlags]::ObjectInherit
    } else {
      [Security.AccessControl.InheritanceFlags]::None
    }
    $accessRule = [Security.AccessControl.FileSystemAccessRule]::new(
      $identity,
      [Security.AccessControl.FileSystemRights]$rule.Rights,
      $inheritance,
      [Security.AccessControl.PropagationFlags]::None,
      [Security.AccessControl.AccessControlType]::Allow
    )
    [void]$acl.AddAccessRule($accessRule)
  }
  Set-Acl -LiteralPath $Path -AclObject $acl
}

function Write-RisePalsDeploymentEvent {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-z][a-z0-9-]{2,63}$")][string]$Event,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9.-]{2,63}$")][string]$ReleaseId,
    [ValidatePattern("^$|^[a-f0-9]{40}$")][string]$SourceCommit = ""
  )

  $validatedRoot = Get-RisePalsValidatedRoot -Root $Root
  $logDirectory = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
    Join-Path $validatedRoot "logs\deploy"
  )
  if (-not (Test-Path -LiteralPath $logDirectory -PathType Container)) {
    throw "The protected deployment-log directory is absent."
  }
  $logPath = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
    Join-Path $logDirectory "deployment-events.jsonl"
  )
  $entry = [ordered]@{
    schemaVersion = "rise-pals-deployment-event-v1"
    timestampUtc = [DateTime]::UtcNow.ToString("o")
    event = $Event
    releaseId = $ReleaseId
    sourceCommit = $SourceCommit
  }
  Add-Content -LiteralPath $logPath -Value ($entry | ConvertTo-Json -Compress) -Encoding UTF8
}
