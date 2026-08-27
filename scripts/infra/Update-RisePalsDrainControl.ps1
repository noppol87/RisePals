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
$sourceConfig = Join-Path $repository "infra\windows\winsw\RisePalsApp.xml"
$installedConfig = Join-Path $validatedRoot "tools\winsw\2.12.0\RisePalsApp.xml"
$controlDirectory = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $validatedRoot "shared\control"
)

if (-not (Test-Path -LiteralPath $sourceConfig -PathType Leaf)) {
  throw "The reviewed WinSW drain configuration is absent."
}
foreach ($name in @("RisePalsApp", "RisePalsProxy")) {
  $service = Assert-RisePalsServiceIsAbsentOrOwned -Name $name -Root $validatedRoot
  if ($null -eq $service -or $service.State -ne "Stopped" -or $service.StartMode -ne "Disabled" -or
    $service.StartName -ne "NT SERVICE\$name") {
    throw "The drain-control update requires both exact virtual-account services Stopped/Disabled."
  }
}
$rootProcesses = @(Get-CimInstance Win32_Process | Where-Object {
  $_.ExecutablePath -and
    $_.ExecutablePath.StartsWith($validatedRoot, [StringComparison]::OrdinalIgnoreCase)
})
if ($rootProcesses.Count -ne 0) {
  throw "A Rise Pals process is active before the drain-control update."
}

if (-not $PSCmdlet.ShouldProcess(
  $validatedRoot,
  "Install the reviewed WinSW local drain configuration and protected control directory"
)) {
  Write-Output "Rise Pals drain-control update dry-run PASS"
  return
}

Assert-RisePalsAdministrator
[IO.Directory]::CreateDirectory($controlDirectory) | Out-Null
Set-RisePalsProtectedAcl -Path $controlDirectory -Rules @(
  @{ Identity = "NT AUTHORITY\SYSTEM"; Rights = "FullControl" },
  @{ Identity = "BUILTIN\Administrators"; Rights = "FullControl" },
  @{ Identity = "NT SERVICE\RisePalsApp"; Rights = "Modify" }
)
[IO.File]::WriteAllBytes($installedConfig, [IO.File]::ReadAllBytes($sourceConfig))
if ((Get-FileHash -LiteralPath $installedConfig -Algorithm SHA256).Hash -ne
  (Get-FileHash -LiteralPath $sourceConfig -Algorithm SHA256).Hash) {
  throw "The installed WinSW drain configuration does not match the reviewed template."
}

$node = Join-Path $validatedRoot "tools\node\24.18.1\node.exe"
$aclChecker = Join-Path $repository "scripts\infra\drain-control.mjs"
& $node $aclChecker --assert-parent $controlDirectory
if ($LASTEXITCODE -ne 0) {
  throw "The local drain-control ACL does not match the exact canonical bitmask model."
}

Write-Output "Rise Pals WinSW local drain-control update PASS; services remain Stopped/Disabled."
