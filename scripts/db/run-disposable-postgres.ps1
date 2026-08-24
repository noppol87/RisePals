param(
  [string]$PostgresBin = $env:RISE_PALS_POSTGRES_BIN,
  [ValidateSet("integration", "clerk-development-smoke", "recovery-rehearsal")]
  [string]$Mode = "integration"
)

$ErrorActionPreference = "Stop"
$temporaryRoot = $null
$dataDirectory = $null
$bootstrapPasswordFile = $null
$bootstrapSqlFile = $null
$resolvedBin = $null
$clusterStarted = $false
$clusterStopped = $false
$runError = $null
$cleanupError = $null
$originalPath = $env:Path
$originalDatabaseUrl = $env:DATABASE_URL
$originalMigrationUrl = $env:DATABASE_MIGRATION_URL
$originalDisposableBootstrapUrl = $env:RISE_PALS_DISPOSABLE_BOOTSTRAP_URL
$originalPgPassword = $env:PGPASSWORD
$originalRecoveryRoot = $env:RISE_PALS_ALPHA_RECOVERY_ROOT
$originalPostgresBin = $env:RISE_PALS_POSTGRES_BIN
$recoveryRoot = $null

function Resolve-PostgresBin {
  param([string]$Candidate)

  if ($Candidate) {
    return (Resolve-Path -LiteralPath $Candidate).Path
  }

  $preparedBin = Join-Path ([IO.Path]::GetTempPath()) "risepals-postgresql-18.4\pgsql\bin"
  if (Test-Path -LiteralPath $preparedBin -PathType Container) {
    return (Resolve-Path -LiteralPath $preparedBin).Path
  }

  throw "Run npm run db:prepare:disposable, or set RISE_PALS_POSTGRES_BIN to the prepared PostgreSQL 18.4 bin directory."
}

function Get-PostgresServices {
  return @(
    Get-Service -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match "(?i)postgres" -or $_.DisplayName -match "(?i)postgres" }
  )
}

try {
  if (@(Get-PostgresServices).Count -ne 0) {
    throw "Disposable verification requires an environment without a PostgreSQL Windows service."
  }

  $resolvedBin = Resolve-PostgresBin -Candidate $PostgresBin
  foreach ($executable in @("initdb.exe", "pg_ctl.exe", "pg_isready.exe", "psql.exe", "postgres.exe", "pg_dump.exe", "pg_restore.exe")) {
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedBin $executable) -PathType Leaf)) {
      throw "The PostgreSQL bin directory is incomplete."
    }
  }

  $distributionRoot = Split-Path -Parent $resolvedBin
  $runtimeDirectory = Join-Path $distributionRoot "pgAdmin 4\python"
  if (-not (Test-Path -LiteralPath $runtimeDirectory -PathType Container)) {
    throw "The prepared PostgreSQL runtime directory is missing."
  }
  $env:Path = "$resolvedBin;$runtimeDirectory;$originalPath"

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
  [IO.File]::WriteAllText(
    $bootstrapPasswordFile,
    $bootstrapPassword,
    [Text.UTF8Encoding]::new($false)
  )

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
  if (-not $clusterStarted -or $LASTEXITCODE -ne 0) {
    throw "The disposable PostgreSQL server did not start."
  }
  Write-Output "Disposable PostgreSQL process started without a Windows service."

  $bootstrapSql = @"
CREATE ROLE rise_pals_owner LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS PASSWORD '$ownerPassword';
CREATE ROLE rise_pals_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS PASSWORD '$applicationPassword';
CREATE ROLE rise_pals_identity_resolver NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
CREATE ROLE rise_pals_privacy_operator NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT rise_pals_identity_resolver TO rise_pals_owner WITH ADMIN OPTION;
GRANT rise_pals_privacy_operator TO rise_pals_owner WITH ADMIN OPTION;
CREATE DATABASE rise_pals_test OWNER rise_pals_owner;
REVOKE CONNECT ON DATABASE rise_pals_test FROM PUBLIC;
GRANT CONNECT ON DATABASE rise_pals_test TO rise_pals_owner, rise_pals_app;
"@
  [IO.File]::WriteAllText($bootstrapSqlFile, $bootstrapSql, [Text.UTF8Encoding]::new($false))
  $env:PGPASSWORD = $bootstrapPassword
  & psql.exe -h 127.0.0.1 -p $port -U postgres -d postgres -v ON_ERROR_STOP=1 -f $bootstrapSqlFile | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Disposable role/database bootstrap failed." }
  Write-Output "Synthetic owner/application roles, credentialless resolver/privacy roles and empty database created."

  $env:DATABASE_MIGRATION_URL = "postgresql://rise_pals_owner:$ownerPassword@127.0.0.1:$port/rise_pals_test?sslmode=disable"
  $env:DATABASE_URL = "postgresql://rise_pals_app:$applicationPassword@127.0.0.1:$port/rise_pals_test?sslmode=disable"
  $env:RISE_PALS_DISPOSABLE_BOOTSTRAP_URL = "postgresql://postgres:$bootstrapPassword@127.0.0.1:$port/rise_pals_test?sslmode=disable"
  $env:RISE_PALS_POSTGRES_BIN = $resolvedBin
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

  Write-Output "$(& postgres.exe --version)"
  Write-Output "Disposable listener: 127.0.0.1:$port (no service, SSL disabled only for loopback test isolation)"
  if ($Mode -eq "integration") {
    & npm.cmd run db:test
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL integration checks failed." }
  } elseif ($Mode -eq "recovery-rehearsal") {
    & npm.cmd run db:test
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL integration checks failed before recovery." }
    $recoveryBase = Join-Path ([IO.Path]::GetTempPath()) "risepals-alpha-recovery"
    [IO.Directory]::CreateDirectory($recoveryBase) | Out-Null
    $recoveryRoot = Join-Path $recoveryBase ([guid]::NewGuid().ToString("N"))
    $env:RISE_PALS_ALPHA_RECOVERY_ROOT = $recoveryRoot
    & node.exe scripts/recovery/alpha-recovery.mjs
    if ($LASTEXITCODE -ne 0) { throw "Alpha recovery rehearsal failed." }
  } else {
    if (-not (Test-Path -LiteralPath ".env.local" -PathType Leaf)) {
      throw "The Clerk Development smoke requires an ignored .env.local file."
    }
    & node.exe scripts/auth/bootstrap-disposable-postgres.mjs
    if ($LASTEXITCODE -ne 0) { throw "Disposable smoke database bootstrap failed." }
    & node.exe --env-file=.env.local scripts/auth/clerk-development-smoke.mjs
    if ($LASTEXITCODE -ne 0) { throw "Clerk Development smoke failed." }
  }
} catch {
  $runError = $_
} finally {
  if ($clusterStarted -and $resolvedBin -and $dataDirectory) {
    & (Join-Path $resolvedBin "pg_ctl.exe") -D $dataDirectory -m fast -w stop | Out-Null
    if ($LASTEXITCODE -eq 0) {
      $clusterStopped = $true
    } else {
      $postmasterPidPath = Join-Path $dataDirectory "postmaster.pid"
      $liveVerifiedProcess = $null
      $processStateUnverified = $false
      if (Test-Path -LiteralPath $postmasterPidPath -PathType Leaf) {
        $postmasterPidText = Get-Content -LiteralPath $postmasterPidPath -TotalCount 1
        $postmasterPid = 0
        if ([int]::TryParse($postmasterPidText, [ref]$postmasterPid)) {
          $candidateProcess = Get-Process -Id $postmasterPid -ErrorAction SilentlyContinue
          if ($candidateProcess) {
            try {
              $expectedProcessPath = [IO.Path]::GetFullPath((Join-Path $resolvedBin "postgres.exe"))
              $actualProcessPath = [IO.Path]::GetFullPath($candidateProcess.Path)
              if ($actualProcessPath.Equals($expectedProcessPath, [StringComparison]::OrdinalIgnoreCase)) {
                $liveVerifiedProcess = $candidateProcess
              }
            } catch {
              $processStateUnverified = $true
            }
          }
        }
      }

      if ($liveVerifiedProcess) {
        $cleanupError = "Normal PostgreSQL stop failed; the verified live process and diagnostics were preserved at $temporaryRoot"
      } elseif ($processStateUnverified -or (Test-Path -LiteralPath $postmasterPidPath -PathType Leaf)) {
        $cleanupError = "Normal PostgreSQL stop failed and process state is unverified; diagnostics were preserved at $temporaryRoot"
      } else {
        $clusterStopped = $true
      }
    }
  }

  $env:Path = $originalPath
  if ($null -eq $originalDatabaseUrl) {
    Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
  } else {
    $env:DATABASE_URL = $originalDatabaseUrl
  }
  if ($null -eq $originalMigrationUrl) {
    Remove-Item Env:DATABASE_MIGRATION_URL -ErrorAction SilentlyContinue
  } else {
    $env:DATABASE_MIGRATION_URL = $originalMigrationUrl
  }
  if ($null -eq $originalDisposableBootstrapUrl) {
    Remove-Item Env:RISE_PALS_DISPOSABLE_BOOTSTRAP_URL -ErrorAction SilentlyContinue
  } else {
    $env:RISE_PALS_DISPOSABLE_BOOTSTRAP_URL = $originalDisposableBootstrapUrl
  }
  if ($null -eq $originalPgPassword) {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
  } else {
    $env:PGPASSWORD = $originalPgPassword
  }
  if ($null -eq $originalRecoveryRoot) {
    Remove-Item Env:RISE_PALS_ALPHA_RECOVERY_ROOT -ErrorAction SilentlyContinue
  } else {
    $env:RISE_PALS_ALPHA_RECOVERY_ROOT = $originalRecoveryRoot
  }
  if ($null -eq $originalPostgresBin) {
    Remove-Item Env:RISE_PALS_POSTGRES_BIN -ErrorAction SilentlyContinue
  } else {
    $env:RISE_PALS_POSTGRES_BIN = $originalPostgresBin
  }

  foreach ($secretFile in @($bootstrapPasswordFile, $bootstrapSqlFile)) {
    if ($secretFile -and (Test-Path -LiteralPath $secretFile -PathType Leaf)) {
      Remove-Item -LiteralPath $secretFile -Force
    }
  }

  if ($recoveryRoot) {
    $resolvedRecoveryBase = [IO.Path]::GetFullPath(
      (Join-Path ([IO.Path]::GetTempPath()) "risepals-alpha-recovery")
    )
    $resolvedRecoveryRoot = [IO.Path]::GetFullPath($recoveryRoot)
    if (
      -not $resolvedRecoveryRoot.StartsWith(
        $resolvedRecoveryBase + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
      )
    ) {
      $cleanupError = "Refusing to clean an unexpected recovery path."
    } elseif ([IO.Directory]::Exists($resolvedRecoveryRoot)) {
      [IO.Directory]::Delete($resolvedRecoveryRoot, $true)
    }
  }

  if ($temporaryRoot) {
    $resolvedBase = [IO.Path]::GetFullPath(
      (Join-Path ([IO.Path]::GetTempPath()) "risepals-postgres-tests")
    )
    $resolvedTemporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
    if (
      -not $resolvedTemporaryRoot.StartsWith(
        $resolvedBase + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
      )
    ) {
      $cleanupError = "Refusing to clean an unexpected database path."
    } elseif (-not $clusterStarted -or $clusterStopped) {
      if ([IO.Directory]::Exists($resolvedTemporaryRoot)) {
        [IO.Directory]::Delete($resolvedTemporaryRoot, $true)
      }
    } elseif (-not $cleanupError) {
      $cleanupError = "PostgreSQL process state is unverified; diagnostics were preserved at $temporaryRoot"
    }
  }

  if (@(Get-PostgresServices).Count -ne 0 -and -not $cleanupError) {
    $cleanupError = "A PostgreSQL Windows service exists after disposable verification."
  }
}

if ($cleanupError) {
  throw $cleanupError
}
if ($runError) {
  throw $runError
}

Write-Output "Disposable PostgreSQL stopped; temporary data, logs and credentials were removed."
