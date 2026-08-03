param(
  [string]$PostgresBin = $env:RISE_PALS_POSTGRES_BIN
)

$ErrorActionPreference = "Stop"
$temporaryRoot = $null
$clusterStarted = $false
$originalPath = $env:Path
$originalDatabaseUrl = $env:DATABASE_URL
$originalMigrationUrl = $env:DATABASE_MIGRATION_URL
$originalPgPassword = $env:PGPASSWORD

function Resolve-PostgresBin {
  param([string]$Candidate)

  if ($Candidate) {
    return (Resolve-Path -LiteralPath $Candidate).Path
  }

  $searchRoot = Join-Path ([IO.Path]::GetTempPath()) "risepals-postgresql-*\binaries-tar\pgsql\bin"
  $match = Get-ChildItem -Path $searchRoot -Directory -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending |
    Select-Object -First 1

  if (-not $match) {
    throw "Set RISE_PALS_POSTGRES_BIN to the bin directory of a supported PostgreSQL distribution."
  }

  return $match.FullName
}

try {
  $resolvedBin = Resolve-PostgresBin -Candidate $PostgresBin
  foreach ($executable in @("initdb.exe", "pg_ctl.exe", "psql.exe", "postgres.exe")) {
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedBin $executable) -PathType Leaf)) {
      throw "The PostgreSQL bin directory is incomplete."
    }
  }

  $runtimeDirectory = Join-Path (Split-Path -Parent $resolvedBin) "pgAdmin 4\python"
  if (Test-Path -LiteralPath $runtimeDirectory -PathType Container) {
    $env:Path = "$resolvedBin;$runtimeDirectory;$originalPath"
  } else {
    $env:Path = "$resolvedBin;$originalPath"
  }

  $temporaryBase = Join-Path ([IO.Path]::GetTempPath()) "risepals-postgres-tests"
  [IO.Directory]::CreateDirectory($temporaryBase) | Out-Null
  $temporaryRoot = Join-Path $temporaryBase ([guid]::NewGuid().ToString("N"))
  [IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
  $dataDirectory = Join-Path $temporaryRoot "data"
  $bootstrapPasswordFile = Join-Path $temporaryRoot "bootstrap-password.txt"
  $bootstrapSqlFile = Join-Path $temporaryRoot "bootstrap.sql"
  $serverLog = Join-Path $temporaryRoot "postgres.log"
  $pgCtlOutput = Join-Path $temporaryRoot "pg-ctl.out"
  $pgCtlError = Join-Path $temporaryRoot "pg-ctl.err"

  $bootstrapPassword = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
  $ownerPassword = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
  $applicationPassword = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
  [IO.File]::WriteAllText($bootstrapPasswordFile, $bootstrapPassword, [Text.UTF8Encoding]::new($false))

  & initdb.exe -D $dataDirectory -U postgres --auth-local=trust --auth-host=scram-sha-256 --pwfile=$bootstrapPasswordFile --encoding=UTF8 --locale=C | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "initdb failed." }
  Write-Output "Disposable cluster initialized outside the repository."

  $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
  $listener.Start()
  $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
  $listener.Stop()

  $pgCtlStartArguments = "-D `"$dataDirectory`" -l `"$serverLog`" -o `"-c listen_addresses=127.0.0.1 -p $port -c ssl=off -c log_connections=off`" -w start"
  $pgCtlStart = Start-Process -FilePath (Join-Path $resolvedBin "pg_ctl.exe") `
    -ArgumentList $pgCtlStartArguments `
    -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput $pgCtlOutput -RedirectStandardError $pgCtlError
  $pgCtlStart.WaitForExit()
  $clusterStarted = Test-Path -LiteralPath (Join-Path $dataDirectory "postmaster.pid") -PathType Leaf
  & pg_isready.exe -h 127.0.0.1 -p $port -d postgres | Out-Null
  if (-not $clusterStarted -or $LASTEXITCODE -ne 0) { throw "The disposable PostgreSQL server did not start." }
  Write-Output "Disposable PostgreSQL process started without a Windows service."

  $bootstrapSql = @"
CREATE ROLE rise_pals_owner LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS PASSWORD '$ownerPassword';
CREATE ROLE rise_pals_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS PASSWORD '$applicationPassword';
CREATE DATABASE rise_pals_test OWNER rise_pals_owner;
REVOKE CONNECT ON DATABASE rise_pals_test FROM PUBLIC;
GRANT CONNECT ON DATABASE rise_pals_test TO rise_pals_owner, rise_pals_app;
"@
  [IO.File]::WriteAllText($bootstrapSqlFile, $bootstrapSql, [Text.UTF8Encoding]::new($false))
  $env:PGPASSWORD = $bootstrapPassword
  & psql.exe -h 127.0.0.1 -p $port -U postgres -d postgres -v ON_ERROR_STOP=1 -f $bootstrapSqlFile | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Disposable role/database bootstrap failed." }
  Write-Output "Synthetic owner/application roles and empty database created."

  $env:DATABASE_MIGRATION_URL = "postgresql://rise_pals_owner:$ownerPassword@127.0.0.1:$port/rise_pals_test?sslmode=disable"
  $env:DATABASE_URL = "postgresql://rise_pals_app:$applicationPassword@127.0.0.1:$port/rise_pals_test?sslmode=disable"
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

  Write-Output "PostgreSQL $(& postgres.exe --version)"
  Write-Output "Disposable listener: 127.0.0.1:$port (no service, SSL disabled only for loopback test isolation)"
  & npm.cmd run db:test
  if ($LASTEXITCODE -ne 0) { throw "PostgreSQL integration checks failed." }
} finally {
  if ($clusterStarted) {
    $stopPath = Join-Path $resolvedBin "pg_ctl.exe"
    & $stopPath -D $dataDirectory -m fast -w stop | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "The disposable PostgreSQL server did not stop cleanly." }
  }

  $env:Path = $originalPath
  if ($null -eq $originalDatabaseUrl) { Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue } else { $env:DATABASE_URL = $originalDatabaseUrl }
  if ($null -eq $originalMigrationUrl) { Remove-Item Env:DATABASE_MIGRATION_URL -ErrorAction SilentlyContinue } else { $env:DATABASE_MIGRATION_URL = $originalMigrationUrl }
  if ($null -eq $originalPgPassword) { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue } else { $env:PGPASSWORD = $originalPgPassword }

  if ($temporaryRoot) {
    $resolvedBase = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) "risepals-postgres-tests"))
    $resolvedTemporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
    if (-not $resolvedTemporaryRoot.StartsWith($resolvedBase + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to clean an unexpected database path."
    }
    if ([IO.Directory]::Exists($resolvedTemporaryRoot)) {
      [IO.Directory]::Delete($resolvedTemporaryRoot, $true)
    }
  }
}
