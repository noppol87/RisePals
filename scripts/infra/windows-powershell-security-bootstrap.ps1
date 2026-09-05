Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RisePalsSecurityBootstrapStages = @(
  "runtime",
  "manifest-path",
  "manifest-item",
  "manifest-reparse",
  "module-import",
  "module-identity",
  "module-base",
  "command-resolution"
)
$script:RisePalsSecurityBootstrapCategories = @(
  "unsupported_runtime",
  "outside_pshome",
  "path_mismatch",
  "not_found",
  "access_denied",
  "invalid_object",
  "reparse_point",
  "read_failure",
  "import_failure",
  "module_mismatch",
  "command_mismatch"
)

function Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
      "runtime", "manifest-path", "manifest-item", "manifest-reparse", "module-import",
      "module-identity", "module-base", "command-resolution"
    )]
    [string]$Stage,
    [Parameter(Mandatory = $true)]
    [ValidateSet(
      "unsupported_runtime", "outside_pshome", "path_mismatch", "not_found",
      "access_denied", "invalid_object", "reparse_point", "read_failure",
      "import_failure", "module_mismatch", "command_mismatch"
    )]
    [string]$Category
  )

  throw [InvalidOperationException]::new(
    ("rise-pals-security-bootstrap|{0}|{1}" -f $Stage, $Category)
  )
}

function Get-RisePalsWindowsPowerShellSecurityBootstrapFailure {
  param([Parameter(Mandatory = $true)][Management.Automation.ErrorRecord]$ErrorRecord)

  $match = [regex]::Match(
    [string]$ErrorRecord.Exception.Message,
    "^rise-pals-security-bootstrap\|([a-z-]+)\|([a-z_]+)$",
    [Text.RegularExpressions.RegexOptions]::CultureInvariant
  )
  if (-not $match.Success -or
    [string]$match.Groups[1].Value -notin $script:RisePalsSecurityBootstrapStages -or
    [string]$match.Groups[2].Value -notin $script:RisePalsSecurityBootstrapCategories) {
    throw "A Windows PowerShell security-module bootstrap failure was not sanitized."
  }

  return [pscustomobject][ordered]@{
    stage = [string]$match.Groups[1].Value
    category = [string]$match.Groups[2].Value
  }
}

function Assert-RisePalsWindowsPowerShell51Runtime {
  if ($PSVersionTable.PSEdition -cne "Desktop" -or
    $PSVersionTable.PSVersion.Major -ne 5 -or
    $PSVersionTable.PSVersion.Minor -ne 1) {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "runtime" -Category "unsupported_runtime"
  }
}

function Get-RisePalsWindowsPowerShellSecurityManifestItem {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)

  try {
    return Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
  } catch [Management.Automation.ItemNotFoundException] {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "manifest-item" -Category "not_found"
  } catch [UnauthorizedAccessException] {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "manifest-item" -Category "access_denied"
  } catch {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "manifest-item" -Category "read_failure"
  }
}

function Assert-RisePalsWindowsPowerShellSecurityManifestBoundary {
  param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$WindowsPowerShellHome
  )

  $canonicalHome = [IO.Path]::GetFullPath($WindowsPowerShellHome).TrimEnd('\')
  $moduleRoot = [IO.Path]::GetFullPath((Join-Path $canonicalHome "Modules")).TrimEnd('\')
  $expectedManifest = [IO.Path]::GetFullPath((Join-Path $moduleRoot `
      "Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1"))
  $canonicalManifest = [IO.Path]::GetFullPath($ManifestPath)
  $modulePrefix = $moduleRoot + [IO.Path]::DirectorySeparatorChar

  if (-not $canonicalManifest.StartsWith(
      $modulePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "manifest-path" -Category "outside_pshome"
  }
  if (-not $canonicalManifest.Equals(
      $expectedManifest, [StringComparison]::OrdinalIgnoreCase)) {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "manifest-path" -Category "path_mismatch"
  }

  $moduleDirectory = Split-Path -Parent $canonicalManifest
  $probes = @(
    [pscustomobject]@{ path = $moduleRoot; directory = $true },
    [pscustomobject]@{ path = $moduleDirectory; directory = $true },
    [pscustomobject]@{ path = $canonicalManifest; directory = $false }
  )
  foreach ($probe in $probes) {
    $item = Get-RisePalsWindowsPowerShellSecurityManifestItem -LiteralPath $probe.path
    $itemPath = [IO.Path]::GetFullPath([string]$item.FullName)
    if (-not $itemPath.Equals([string]$probe.path, [StringComparison]::OrdinalIgnoreCase) -or
      [bool]$item.PSIsContainer -ne [bool]$probe.directory) {
      Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
        -Stage "manifest-item" -Category "invalid_object"
    }
    if (([IO.FileAttributes]$item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
        -Stage "manifest-reparse" -Category "reparse_point"
    }
  }

  return [pscustomobject][ordered]@{
    windowsPowerShellHome = $canonicalHome
    moduleRoot = $moduleRoot
    manifestPath = $canonicalManifest
  }
}

function Assert-RisePalsWindowsPowerShellSecurityLoadedState {
  param(
    [Parameter(Mandatory = $true)][object]$Module,
    [Parameter(Mandatory = $true)][object]$Command,
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$WindowsPowerShellHome
  )

  $canonicalHome = [IO.Path]::GetFullPath($WindowsPowerShellHome).TrimEnd('\')
  $homePrefix = $canonicalHome + [IO.Path]::DirectorySeparatorChar
  $canonicalManifest = [IO.Path]::GetFullPath($ManifestPath)
  $modulePath = [IO.Path]::GetFullPath([string]$Module.Path)
  if ([string]$Module.Name -cne "Microsoft.PowerShell.Security" -or
    -not $modulePath.Equals($canonicalManifest, [StringComparison]::OrdinalIgnoreCase)) {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "module-identity" -Category "module_mismatch"
  }

  $moduleBase = [IO.Path]::GetFullPath([string]$Module.ModuleBase).TrimEnd('\')
  if (-not $moduleBase.Equals($canonicalHome, [StringComparison]::OrdinalIgnoreCase) -and
    -not $moduleBase.StartsWith($homePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "module-base" -Category "outside_pshome"
  }

  $commandModulePath = [IO.Path]::GetFullPath([string]$Command.Module.Path)
  if ([string]$Command.Name -cne "Get-Acl" -or
    [string]$Command.ModuleName -cne "Microsoft.PowerShell.Security" -or
    -not $commandModulePath.Equals($canonicalManifest, [StringComparison]::OrdinalIgnoreCase)) {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "command-resolution" -Category "command_mismatch"
  }
}

function Initialize-RisePalsWindowsPowerShellSecurityModule {
  Assert-RisePalsWindowsPowerShell51Runtime

  $manifestPath = Join-Path $PSHOME `
    "Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1"
  $boundary = Assert-RisePalsWindowsPowerShellSecurityManifestBoundary `
    -ManifestPath $manifestPath -WindowsPowerShellHome $PSHOME

  try {
    $modules = @(Import-Module -Name $boundary.manifestPath -Force -Global -PassThru `
        -ErrorAction Stop)
  } catch {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "module-import" -Category "import_failure"
  }
  $loaded = @($modules | Where-Object {
      [string]$_.Name -ceq "Microsoft.PowerShell.Security" -and
      [IO.Path]::GetFullPath([string]$_.Path).Equals(
        $boundary.manifestPath, [StringComparison]::OrdinalIgnoreCase)
    })
  if ($loaded.Count -ne 1) {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "module-identity" -Category "module_mismatch"
  }

  try {
    $commands = @(Get-Command -Name "Get-Acl" -CommandType Cmdlet `
        -Module "Microsoft.PowerShell.Security" -ErrorAction Stop)
  } catch {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "command-resolution" -Category "command_mismatch"
  }
  $resolvedCommands = @($commands | Where-Object {
      $null -ne $_.Module -and
      [IO.Path]::GetFullPath([string]$_.Module.Path).Equals(
        $boundary.manifestPath, [StringComparison]::OrdinalIgnoreCase)
    })
  if ($resolvedCommands.Count -ne 1) {
    Throw-RisePalsWindowsPowerShellSecurityBootstrapFailure `
      -Stage "command-resolution" -Category "command_mismatch"
  }

  Assert-RisePalsWindowsPowerShellSecurityLoadedState -Module $loaded[0] `
    -Command $resolvedCommands[0] -ManifestPath $boundary.manifestPath `
    -WindowsPowerShellHome $boundary.windowsPowerShellHome

  return [pscustomobject][ordered]@{
    moduleName = "Microsoft.PowerShell.Security"
    manifestPath = $boundary.manifestPath
    moduleBase = [IO.Path]::GetFullPath([string]$loaded[0].ModuleBase).TrimEnd('\')
    commandName = "Get-Acl"
  }
}
