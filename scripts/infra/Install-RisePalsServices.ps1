[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
  [string]$Root = "C:\RisePals",
  [string]$RepositoryRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
Assert-RisePalsAdministrator
$RepositoryRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
} else {
  $RepositoryRoot
}
$repository = [IO.Path]::GetFullPath($RepositoryRoot)
$winsw = Join-Path $validatedRoot "tools\winsw\2.12.0\RisePalsApp.exe"
$winswConfig = Join-Path $validatedRoot "tools\winsw\2.12.0\RisePalsApp.xml"
$caddy = Join-Path $validatedRoot "tools\caddy\2.11.4\caddy.exe"
$caddyConfig = Join-Path $validatedRoot "shared\config\Caddyfile"

foreach ($path in @($winsw, $caddy)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Pinned service executable is absent."
  }
}

$appService = Assert-RisePalsServiceIsAbsentOrOwned -Name "RisePalsApp" -Root $validatedRoot
$proxyService = Assert-RisePalsServiceIsAbsentOrOwned -Name "RisePalsProxy" -Root $validatedRoot
if ($null -ne $appService -or $null -ne $proxyService) {
  throw "Rise Pals services already exist; refusing an implicit reinstall."
}

if (-not $PSCmdlet.ShouldProcess($validatedRoot, "Install the two approved disabled least-privilege services")) {
  Write-Output "Service installation dry-run PASS"
  return
}

Copy-Item -LiteralPath (Join-Path $repository "infra\windows\winsw\RisePalsApp.xml") `
  -Destination $winswConfig
Copy-Item -LiteralPath (Join-Path $repository "infra\windows\caddy\Caddyfile") `
  -Destination $caddyConfig

& (Join-Path $repository "scripts\infra\Test-RisePalsCaddyConfig.ps1") `
  -RepositoryRoot $repository
if ($LASTEXITCODE -ne 0) {
  throw "Side-effect-isolated Caddy configuration validation failed."
}

$appInstalled = $false
$proxyInstalled = $false
try {
  & $winsw install --no-elevate
  if ($LASTEXITCODE -ne 0) {
    throw "WinSW application-service installation failed."
  }
  $appInstalled = $true
  Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @(
    "config",
    "RisePalsApp",
    "obj=",
    "NT SERVICE\RisePalsApp"
  )

  $proxyCommand = ('"{0}" run --config "{1}" --adapter caddyfile' -f $caddy, $caddyConfig)
  Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @(
    "create",
    "RisePalsProxy",
    "binPath=",
    $proxyCommand,
    "start=",
    "demand",
    "obj=",
    "NT SERVICE\RisePalsProxy",
    "DisplayName=",
    "Rise Pals Proxy"
  )
  $proxyInstalled = $true
  Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @(
    "failure",
    "RisePalsProxy",
    "reset=",
    "3600",
    "actions=",
    "restart/5000/restart/15000//0"
  )

  $systemAdmin = @(
    @{ Identity = "NT AUTHORITY\SYSTEM"; Rights = "FullControl" },
    @{ Identity = "BUILTIN\Administrators"; Rights = "FullControl" }
  )
  $rootRules = @(
    $systemAdmin[0],
    $systemAdmin[1],
    @{ Identity = "NT SERVICE\RisePalsApp"; Rights = "ReadAndExecute" },
    @{ Identity = "NT SERVICE\RisePalsProxy"; Rights = "ReadAndExecute" }
  )
  Set-RisePalsProtectedAcl -Path $validatedRoot -Rules $rootRules
  Set-RisePalsProtectedAcl -Path (Join-Path $validatedRoot "tools\node") -Rules @(
    $systemAdmin[0], $systemAdmin[1],
    @{ Identity = "NT SERVICE\RisePalsApp"; Rights = "ReadAndExecute" }
  )
  Set-RisePalsProtectedAcl -Path (Join-Path $validatedRoot "tools\winsw") -Rules @(
    $systemAdmin[0], $systemAdmin[1],
    @{ Identity = "NT SERVICE\RisePalsApp"; Rights = "ReadAndExecute" }
  )
  Set-RisePalsProtectedAcl -Path (Join-Path $validatedRoot "tools\caddy") -Rules @(
    $systemAdmin[0], $systemAdmin[1],
    @{ Identity = "NT SERVICE\RisePalsProxy"; Rights = "ReadAndExecute" }
  )
  Set-RisePalsProtectedAcl -Path (Join-Path $validatedRoot "releases") -Rules @(
    $systemAdmin[0], $systemAdmin[1],
    @{ Identity = "NT SERVICE\RisePalsApp"; Rights = "ReadAndExecute" }
  )
  Set-RisePalsProtectedAcl -Path (Join-Path $validatedRoot "shared\config") -Rules @(
    $systemAdmin[0], $systemAdmin[1],
    @{ Identity = "NT SERVICE\RisePalsApp"; Rights = "Read" },
    @{ Identity = "NT SERVICE\RisePalsProxy"; Rights = "Read" }
  )
  Set-RisePalsProtectedAcl -Path (Join-Path $validatedRoot "shared\secrets") -Rules @(
    $systemAdmin[0], $systemAdmin[1],
    @{
      Identity = "NT SERVICE\RisePalsApp"
      Rights = "Traverse"
      InheritanceFlags = "None"
    }
  )
  Set-RisePalsProtectedAcl -Path (Join-Path $validatedRoot "shared\cache") -Rules $systemAdmin
  Set-RisePalsProtectedAcl -Path (Join-Path $validatedRoot "shared\cache\caddy") -Rules @(
    $systemAdmin[0], $systemAdmin[1],
    @{ Identity = "NT SERVICE\RisePalsProxy"; Rights = "Modify" }
  )
  Set-RisePalsProtectedAcl -Path (Join-Path $validatedRoot "logs\app") -Rules @(
    $systemAdmin[0], $systemAdmin[1],
    @{ Identity = "NT SERVICE\RisePalsApp"; Rights = "Modify" }
  )
  Set-RisePalsProtectedAcl -Path (Join-Path $validatedRoot "logs\proxy") -Rules @(
    $systemAdmin[0], $systemAdmin[1],
    @{ Identity = "NT SERVICE\RisePalsProxy"; Rights = "Modify" }
  )

  Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @("config", "RisePalsApp", "start=", "disabled")
  Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @("config", "RisePalsProxy", "start=", "disabled")
} catch {
  if ($proxyInstalled) {
    & sc.exe delete RisePalsProxy | Out-Null
  }
  if ($appInstalled) {
    & $winsw uninstall --no-elevate | Out-Null
  }
  throw
}

foreach ($name in @("RisePalsApp", "RisePalsProxy")) {
  $service = Get-CimInstance Win32_Service -Filter "Name='$name'"
  if ($service.StartName -ne "NT SERVICE\$name" -or $service.StartMode -ne "Disabled") {
    throw "Service identity or disabled final state verification failed for $name."
  }
}

Write-Output "Rise Pals least-privilege service installation PASS; both services are Disabled."
