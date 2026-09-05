[CmdletBinding()]
param(
  [string]$CaddyExecutable = "C:\RisePals\tools\caddy\2.11.4\caddy.exe",
  [string]$RepositoryRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $CaddyExecutable -PathType Leaf)) {
  throw "The verified Caddy executable is absent."
}
$RepositoryRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
} else {
  $RepositoryRoot
}
$source = Join-Path ([IO.Path]::GetFullPath($RepositoryRoot)) "infra\windows\caddy\Caddyfile"
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("risepals-caddy-validate-" + [guid]::NewGuid().ToString("N"))
$temporaryConfig = Join-Path $temporaryRoot "Caddyfile"
[IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
try {
  $configuration = Get-Content -LiteralPath $source -Raw -Encoding UTF8
  $configuration = $configuration.Replace(
    "C:\RisePals\shared\cache\caddy",
    (Join-Path $temporaryRoot "cache")
  ).Replace(
    "C:\RisePals\logs\proxy\access.json",
    (Join-Path $temporaryRoot "access.json")
  )
  [IO.File]::WriteAllText($temporaryConfig, $configuration, [Text.UTF8Encoding]::new($false))
  & $CaddyExecutable validate --config $temporaryConfig --adapter caddyfile
  if ($LASTEXITCODE -ne 0) {
    throw "Caddy configuration validation failed."
  }
} finally {
  $resolvedTemporary = [IO.Path]::GetFullPath($temporaryRoot)
  $expectedPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  if (-not $resolvedTemporary.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unexpected Caddy validation cleanup path."
  }
  if (Test-Path -LiteralPath $resolvedTemporary) {
    Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force
  }
}

Write-Output "Side-effect-isolated Caddy configuration validation PASS"
