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
$manifestPath = Join-Path $repository "infra\windows\tool-manifest.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.schemaVersion -ne "rise-pals-windows-tool-manifest-v1") {
  throw "Unexpected Windows tool manifest schema."
}

$downloadRoot = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $validatedRoot ("staging\tools-" + [guid]::NewGuid().ToString("N"))
)

if (-not $PSCmdlet.ShouldProcess($validatedRoot, "Download and install the pinned verified runtime tools")) {
  Write-Output "Tool installation dry-run PASS"
  return
}

Assert-RisePalsAdministrator

foreach ($path in @(
  (Join-Path $validatedRoot "tools\node\24.18.1\node.exe"),
  (Join-Path $validatedRoot "tools\caddy\2.11.4\caddy.exe"),
  (Join-Path $validatedRoot "tools\winsw\2.12.0\RisePalsApp.exe")
)) {
  if (Test-Path -LiteralPath $path) {
    throw "A pinned tool destination is unexpectedly non-empty; refusing overwrite."
  }
}

[IO.Directory]::CreateDirectory($downloadRoot) | Out-Null
try {
  foreach ($tool in $manifest.tools) {
    $downloadPath = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
      Join-Path $downloadRoot $tool.archive
    )
    Invoke-WebRequest -UseBasicParsing -Uri $tool.sourceUrl -OutFile $downloadPath
    $download = Get-Item -LiteralPath $downloadPath
    $hash = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($download.Length -ne [long]$tool.length -or $hash -ne $tool.sha256) {
      throw "Pinned $($tool.name) integrity verification failed."
    }

    switch ($tool.name) {
      "node" {
        $extract = Join-Path $downloadRoot "node-extract"
        Expand-Archive -LiteralPath $downloadPath -DestinationPath $extract
        $source = Join-Path $extract "node-v24.18.1-win-x64"
        $destination = Join-Path $validatedRoot "tools\node\24.18.1"
        Get-ChildItem -LiteralPath $source -Force | ForEach-Object {
          Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
        }
        $signature = Get-AuthenticodeSignature -LiteralPath (Join-Path $destination "node.exe")
        if (
          $signature.Status -ne "Valid" -or
          -not $signature.SignerCertificate.Subject.Contains("O=OpenJS Foundation")
        ) {
          throw "Installed Node publisher verification failed."
        }
      }
      "caddy" {
        $destination = Join-Path $validatedRoot "tools\caddy\2.11.4"
        Expand-Archive -LiteralPath $downloadPath -DestinationPath $destination -Force
        $version = & (Join-Path $destination "caddy.exe") version
        if ($LASTEXITCODE -ne 0 -or -not $version.StartsWith("v2.11.4 ")) {
          throw "Installed Caddy version verification failed."
        }
      }
      "winsw" {
        $destination = Join-Path $validatedRoot "tools\winsw\2.12.0\RisePalsApp.exe"
        Copy-Item -LiteralPath $downloadPath -Destination $destination
        $version = (Get-Item -LiteralPath $destination).VersionInfo.ProductVersion
        if (-not $version.StartsWith("2.12.0+")) {
          throw "Installed WinSW version verification failed."
        }
      }
      default { throw "Unexpected tool in the pinned manifest." }
    }
  }

  Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $validatedRoot "tools\tool-manifest.json")
} finally {
  Remove-RisePalsValidatedChild -Root $validatedRoot -Path $downloadRoot -Recurse
}

Write-Output "Pinned Rise Pals runtime-tool installation PASS"
