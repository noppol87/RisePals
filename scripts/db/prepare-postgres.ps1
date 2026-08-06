param(
  [string]$DestinationRoot = (Join-Path ([IO.Path]::GetTempPath()) "risepals-postgresql-18.4")
)

$ErrorActionPreference = "Stop"
$archiveName = "postgresql-18.4-1-windows-x64-binaries.zip"
$distributionUrl = "https://get.enterprisedb.com/postgresql/$archiveName"
$distributionPage = "https://www.enterprisedb.com/download-postgresql-binaries"
$expectedLength = 337444127
$expectedSha256 = "7EFFE34C0BF89027B3F171447D351CBC460F4566C8D0F643DAEC67F140787858"
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$resolvedDestination = [IO.Path]::GetFullPath($DestinationRoot)

if (
  $resolvedDestination.Equals($repositoryRoot, [StringComparison]::OrdinalIgnoreCase) -or
  $resolvedDestination.StartsWith(
    $repositoryRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
  )
) {
  throw "PostgreSQL preparation must stay outside the repository."
}

[IO.Directory]::CreateDirectory($resolvedDestination) | Out-Null
$archivePath = Join-Path $resolvedDestination $archiveName
$downloadPath = "$archivePath.download"
$distributionRoot = Join-Path $resolvedDestination "pgsql"
$postgresBin = Join-Path $distributionRoot "bin"
$runtimeDirectory = Join-Path $distributionRoot "pgAdmin 4\python"

if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
  if (Test-Path -LiteralPath $downloadPath -PathType Leaf) {
    Remove-Item -LiteralPath $downloadPath -Force
  }

  Write-Output "Downloading the fixed PostgreSQL 18.4 archive from EDB over HTTPS."
  try {
    Invoke-WebRequest -Uri $distributionUrl -OutFile $downloadPath -UseBasicParsing
    Move-Item -LiteralPath $downloadPath -Destination $archivePath
  } catch {
    if (Test-Path -LiteralPath $downloadPath -PathType Leaf) {
      Remove-Item -LiteralPath $downloadPath -Force
    }
    throw
  }
}

$archive = Get-Item -LiteralPath $archivePath
if ($archive.Length -ne $expectedLength) {
  throw "PostgreSQL archive length verification failed; refusing to extract it."
}

$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToUpperInvariant()
if ($archiveHash -ne $expectedSha256) {
  throw "PostgreSQL archive SHA-256 verification failed; refusing to extract it."
}

if (-not (Test-Path -LiteralPath $postgresBin -PathType Container)) {
  $stagingRoot = Join-Path $resolvedDestination ("extract-" + [guid]::NewGuid().ToString("N"))
  [IO.Directory]::CreateDirectory($stagingRoot) | Out-Null
  Write-Output "Extracting the verified archive outside the repository."
  & tar.exe -xf $archivePath -C $stagingRoot
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Extraction diagnostics were preserved at $stagingRoot"
    throw "PostgreSQL archive extraction failed."
  }

  $stagedDistribution = Join-Path $stagingRoot "pgsql"
  if (-not (Test-Path -LiteralPath $stagedDistribution -PathType Container)) {
    Write-Warning "Extraction diagnostics were preserved at $stagingRoot"
    throw "The verified archive did not contain the expected pgsql directory."
  }
  if (Test-Path -LiteralPath $distributionRoot) {
    Write-Warning "Extraction diagnostics were preserved at $stagingRoot"
    throw "An unexpected PostgreSQL destination already exists; refusing to overwrite it."
  }

  Move-Item -LiteralPath $stagedDistribution -Destination $distributionRoot
  if (@(Get-ChildItem -LiteralPath $stagingRoot -Force).Count -eq 0) {
    Remove-Item -LiteralPath $stagingRoot -Force
  } else {
    Write-Warning "Non-PostgreSQL archive entries were preserved at $stagingRoot"
  }
}

foreach ($executable in @("initdb.exe", "pg_ctl.exe", "pg_isready.exe", "psql.exe", "postgres.exe")) {
  if (-not (Test-Path -LiteralPath (Join-Path $postgresBin $executable) -PathType Leaf)) {
    throw "The prepared PostgreSQL distribution is incomplete."
  }
}

$edgeCoreRoot = "C:\Program Files (x86)\Microsoft\EdgeCore"
$edgeRuntime = Get-ChildItem -LiteralPath $edgeCoreRoot -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match "^\d+\.\d+\.\d+\.\d+$" } |
  Sort-Object { [version]$_.Name } -Descending |
  Select-Object -First 1
if (-not $edgeRuntime) {
  throw "A current Microsoft-signed EdgeCore VC runtime is required for portable PostgreSQL on this Windows host."
}

$microsoftRuntimeNames = @(
  "concrt140.dll",
  "msvcp140.dll",
  "msvcp140_codecvt_ids.dll",
  "vcruntime140.dll",
  "vcruntime140_1.dll"
)
foreach ($runtimeName in $microsoftRuntimeNames) {
  $runtimeSource = Join-Path $edgeRuntime.FullName $runtimeName
  $runtimeItem = Get-Item -LiteralPath $runtimeSource
  $runtimeVersion = [version]$runtimeItem.VersionInfo.FileVersion
  $signature = Get-AuthenticodeSignature -LiteralPath $runtimeSource
  if (
    $signature.Status -ne "Valid" -or
    -not $signature.SignerCertificate.Subject.Contains("O=Microsoft Corporation") -or
    $runtimeVersion -lt [version]"14.40.0.0"
  ) {
    throw "The local Microsoft runtime publisher/version verification failed."
  }

  $runtimeDestination = Join-Path $postgresBin $runtimeName
  Copy-Item -LiteralPath $runtimeSource -Destination $runtimeDestination -Force
  $destinationSignature = Get-AuthenticodeSignature -LiteralPath $runtimeDestination
  if (
    $destinationSignature.Status -ne "Valid" -or
    -not $destinationSignature.SignerCertificate.Subject.Contains("O=Microsoft Corporation")
  ) {
    throw "The prepared Microsoft runtime publisher verification failed."
  }
}

$postgresSignature = Get-AuthenticodeSignature -LiteralPath (Join-Path $postgresBin "postgres.exe")
if ($postgresSignature.Status -notin @("NotSigned", "Valid")) {
  throw "The PostgreSQL executable signature state could not be verified safely."
}

$originalPath = $env:Path
try {
  $env:Path = "$postgresBin;$runtimeDirectory;$originalPath"
  $postgresVersion = & (Join-Path $postgresBin "postgres.exe") --version
  if ($LASTEXITCODE -ne 0 -or $postgresVersion -ne "postgres (PostgreSQL) 18.4") {
    throw "The prepared PostgreSQL executable is not the pinned 18.4 version."
  }
} finally {
  $env:Path = $originalPath
}

Write-Output "PostgreSQL preparation PASS"
Write-Output "Official distribution page: $distributionPage"
Write-Output "Source URL: $distributionUrl"
Write-Output "Archive: $archiveName ($expectedLength bytes)"
Write-Output "SHA-256: $expectedSha256"
Write-Output "PostgreSQL executable Authenticode: $($postgresSignature.Status)"
Write-Output "Portable VC runtime: Microsoft-signed EdgeCore $($edgeRuntime.Name), version $((Get-Item -LiteralPath (Join-Path $postgresBin 'msvcp140.dll')).VersionInfo.FileVersion)"
Write-Output "Prepared bin: $postgresBin"
Write-Output "No elevation, Windows service, firewall rule or machine-wide PATH change was used."
