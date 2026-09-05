param(
  [string]$PostgresBin = $env:RISE_PALS_POSTGRES_BIN,
  [string]$OpenSslExecutable = "C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\usr\bin\openssl.exe"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$temporaryRoot = $null
$dataDirectory = $null
$resolvedBin = $null
$clusterStarted = $false
$clusterStopped = $false
$runError = $null
$cleanupError = $null
$originalPath = $env:Path
$originalPgPassword = $env:PGPASSWORD
$originalPgSslMode = $env:PGSSLMODE
$originalPgSslRootCert = $env:PGSSLROOTCERT

function Resolve-PostgresBin {
  param([string]$Candidate)

  if ($Candidate) {
    return (Resolve-Path -LiteralPath $Candidate).Path
  }
  $prepared = Join-Path ([IO.Path]::GetTempPath()) "risepals-postgresql-18.4\pgsql\bin"
  if (Test-Path -LiteralPath $prepared -PathType Container) {
    return (Resolve-Path -LiteralPath $prepared).Path
  }
  throw "Run npm run db:prepare:disposable before the disposable TLS rehearsal."
}

function Invoke-CheckedNative {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )

  & $FilePath @Arguments | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "A disposable TLS preparation command failed."
  }
}

try {
  $postgresServices = @(Get-Service -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match "(?i)postgres" -or $_.DisplayName -match "(?i)postgres"
  })
  if ($postgresServices.Count -ne 0) {
    throw "Disposable TLS verification requires no PostgreSQL Windows service."
  }
  if (-not (Test-Path -LiteralPath $OpenSslExecutable -PathType Leaf)) {
    throw "The existing verified OpenSSL executable is unavailable."
  }

  $resolvedBin = Resolve-PostgresBin -Candidate $PostgresBin
  foreach ($name in @("initdb.exe", "pg_ctl.exe", "pg_isready.exe", "psql.exe")) {
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedBin $name) -PathType Leaf)) {
      throw "The prepared PostgreSQL 18.4 distribution is incomplete."
    }
  }
  $runtimeDirectory = Join-Path (Split-Path -Parent $resolvedBin) "pgAdmin 4\python"
  if (-not (Test-Path -LiteralPath $runtimeDirectory -PathType Container)) {
    throw "The prepared PostgreSQL runtime directory is unavailable."
  }
  $env:Path = "$resolvedBin;$runtimeDirectory;$originalPath"

  $temporaryBase = Join-Path ([IO.Path]::GetTempPath()) "risepals-postgres-tls"
  [IO.Directory]::CreateDirectory($temporaryBase) | Out-Null
  $temporaryRoot = Join-Path $temporaryBase ([guid]::NewGuid().ToString("N"))
  [IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
  $dataDirectory = Join-Path $temporaryRoot "data"
  $bootstrapPasswordFile = Join-Path $temporaryRoot "bootstrap-password.txt"
  $serverLog = Join-Path $temporaryRoot "postgres.log"
  $caKey = Join-Path $temporaryRoot "ca.key"
  $caCertificate = Join-Path $temporaryRoot "ca.crt"
  $serverKey = Join-Path $temporaryRoot "server.key"
  $serverRequest = Join-Path $temporaryRoot "server.csr"
  $serverCertificate = Join-Path $temporaryRoot "server.crt"
  $extensionFile = Join-Path $temporaryRoot "server.ext"
  $serialFile = Join-Path $temporaryRoot "ca.srl"

  $bootstrapPassword = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
  $ownerPassword = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
  $applicationPassword = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
  [IO.File]::WriteAllText($bootstrapPasswordFile, $bootstrapPassword, [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText(
    $extensionFile,
    "subjectAltName=IP:127.0.0.1`nextendedKeyUsage=serverAuth`n",
    [Text.UTF8Encoding]::new($false)
  )

  Invoke-CheckedNative -FilePath $OpenSslExecutable -Arguments @(
    "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
    "-subj", "/CN=Rise Pals Disposable PostgreSQL CA", "-keyout", $caKey, "-out", $caCertificate
  )
  Invoke-CheckedNative -FilePath $OpenSslExecutable -Arguments @(
    "req", "-newkey", "rsa:2048", "-nodes", "-subj", "/CN=127.0.0.1",
    "-keyout", $serverKey, "-out", $serverRequest
  )
  Invoke-CheckedNative -FilePath $OpenSslExecutable -Arguments @(
    "x509", "-req", "-days", "1", "-in", $serverRequest, "-CA", $caCertificate,
    "-CAkey", $caKey, "-CAcreateserial", "-CAserial", $serialFile,
    "-extfile", $extensionFile, "-out", $serverCertificate
  )

  & (Join-Path $resolvedBin "initdb.exe") -D $dataDirectory -U postgres `
    --auth-local=trust --auth-host=scram-sha-256 --pwfile=$bootstrapPasswordFile `
    --encoding=UTF8 --locale=C | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Disposable TLS initdb failed."
  }
  Copy-Item -LiteralPath $serverCertificate -Destination (Join-Path $dataDirectory "server.crt")
  Copy-Item -LiteralPath $serverKey -Destination (Join-Path $dataDirectory "server.key")
  Copy-Item -LiteralPath $caCertificate -Destination (Join-Path $dataDirectory "ca.crt")

  $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
  $listener.Start()
  $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
  $listener.Stop()

  $arguments = "-D `"$dataDirectory`" -l `"$serverLog`" -o `"-c listen_addresses=127.0.0.1 -p $port -c ssl=on -c ssl_cert_file=server.crt -c ssl_key_file=server.key -c ssl_ca_file=ca.crt -c log_connections=off`" -w start"
  $process = Start-Process -FilePath (Join-Path $resolvedBin "pg_ctl.exe") `
    -ArgumentList $arguments -PassThru -WindowStyle Hidden
  $process.WaitForExit()
  $clusterStarted = Test-Path -LiteralPath (Join-Path $dataDirectory "postmaster.pid") -PathType Leaf
  if (-not $clusterStarted -or $process.ExitCode -ne 0) {
    throw "Disposable TLS PostgreSQL did not start."
  }

  $env:PGSSLMODE = "verify-full"
  $env:PGSSLROOTCERT = $caCertificate
  $env:PGPASSWORD = $bootstrapPassword
  $bootstrapSql = @"
CREATE ROLE rise_pals_tls_owner LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS PASSWORD '$ownerPassword';
CREATE ROLE rise_pals_tls_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS PASSWORD '$applicationPassword';
CREATE DATABASE rise_pals_tls_test OWNER rise_pals_tls_owner;
REVOKE CONNECT ON DATABASE rise_pals_tls_test FROM PUBLIC;
GRANT CONNECT ON DATABASE rise_pals_tls_test TO rise_pals_tls_owner, rise_pals_tls_app;
"@
  $bootstrapSql | & (Join-Path $resolvedBin "psql.exe") -h 127.0.0.1 -p $port `
    -U postgres -d postgres -v ON_ERROR_STOP=1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Disposable TLS role bootstrap failed."
  }

  foreach ($role in @(
    @{ Name = "rise_pals_tls_owner"; Password = $ownerPassword },
    @{ Name = "rise_pals_tls_app"; Password = $applicationPassword }
  )) {
    $env:PGPASSWORD = $role.Password
    $result = & (Join-Path $resolvedBin "psql.exe") -h 127.0.0.1 -p $port `
      -U $role.Name -d rise_pals_tls_test -tA `
      -c "SELECT current_setting('ssl') || ':' || current_user"
    if ($LASTEXITCODE -ne 0 -or $result.Trim() -ne "on:$($role.Name)") {
      throw "Explicit-CA TLS verification failed for a separated disposable role."
    }
  }

  Write-Output "Disposable PostgreSQL 18.4 TLS PASS: verify-full with explicit local CA and separated owner/application roles."
} catch {
  $runError = $_
} finally {
  if ($clusterStarted -and $resolvedBin -and $dataDirectory) {
    & (Join-Path $resolvedBin "pg_ctl.exe") -D $dataDirectory -m fast -w stop | Out-Null
    if ($LASTEXITCODE -eq 0) {
      $clusterStopped = $true
    } else {
      $cleanupError = "Disposable TLS PostgreSQL did not stop cleanly; diagnostics were retained."
    }
  }

  $env:Path = $originalPath
  foreach ($name in @("PGPASSWORD", "PGSSLMODE", "PGSSLROOTCERT")) {
    $original = Get-Variable -Name ("original" + ($name -replace "^PG", "Pg")) -ValueOnly
    if ($null -eq $original) {
      Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    } else {
      Set-Item "Env:$name" $original
    }
  }

  if ($temporaryRoot) {
    $expectedBase = [IO.Path]::GetFullPath(
      (Join-Path ([IO.Path]::GetTempPath()) "risepals-postgres-tls")
    )
    $resolvedTemporary = [IO.Path]::GetFullPath($temporaryRoot)
    if (-not $resolvedTemporary.StartsWith(
      $expectedBase + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase
    )) {
      $cleanupError = "Refusing to clean an unexpected disposable TLS path."
    } elseif (-not $clusterStarted -or $clusterStopped) {
      if ([IO.Directory]::Exists($resolvedTemporary)) {
        [IO.Directory]::Delete($resolvedTemporary, $true)
      }
    }
  }
}

if ($cleanupError) {
  throw $cleanupError
}
if ($runError) {
  throw $runError
}
Write-Output "Disposable PostgreSQL TLS cleanup PASS: process, certificates, keys and credentials removed."
