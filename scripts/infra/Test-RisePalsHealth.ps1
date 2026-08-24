[CmdletBinding()]
param([string]$Root = "C:\RisePals")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$caddy = Join-Path $validatedRoot "tools\caddy\2.11.4\caddy.exe"
$config = Join-Path $validatedRoot "shared\config\Caddyfile"
$ca = Join-Path $validatedRoot "shared\cache\caddy\pki\authorities\local\root.crt"
foreach ($path in @($caddy, $config, $ca)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Required proxy health artifact is absent."
  }
}

$live = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:3100/health/live" -TimeoutSec 15
$ready = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:3100/health/ready" -TimeoutSec 15
if ($live.StatusCode -ne 200 -or $live.Content -ne '{"status":"ok"}') {
  throw "Direct liveness failed or exposed unexpected fields."
}
if ($ready.StatusCode -ne 200 -or $ready.Content -ne '{"status":"ready"}') {
  throw "Direct readiness failed or exposed unexpected fields."
}

$redirectHeaders = & curl.exe --silent --show-error --head `
  "http://127.0.0.1:8080/health/live?token=synthetic-redaction-probe"
if ($LASTEXITCODE -ne 0 -or ($redirectHeaders -join "`n") -notmatch "HTTP/1\.1 308") {
  throw "Loopback HTTP-to-HTTPS redirect verification failed."
}

$httpsBody = & curl.exe --silent --show-error --cacert $ca `
  "https://127.0.0.1:8443/health/live?token=synthetic-redaction-probe"
if ($LASTEXITCODE -ne 0 -or $httpsBody -ne '{"status":"ok"}') {
  throw "Explicit-local-CA HTTPS liveness verification failed."
}
$accessLog = Join-Path $validatedRoot "logs\proxy\access.json"
$deadline = [DateTime]::UtcNow.AddSeconds(5)
while (-not (Test-Path -LiteralPath $accessLog -PathType Leaf) -and [DateTime]::UtcNow -lt $deadline) {
  Start-Sleep -Milliseconds 100
}
$accessBytes = Get-Content -LiteralPath $accessLog -Raw -Encoding UTF8
if ($accessBytes.Contains("synthetic-redaction-probe") -or -not $accessBytes.Contains("REDACTED")) {
  throw "Proxy access-log query redaction failed."
}

$internalCode = & curl.exe --silent --show-error --cacert $ca --output NUL --write-out "%{http_code}" `
  "https://127.0.0.1:8443/health/ready"
if ($LASTEXITCODE -ne 0 -or $internalCode -ne "404") {
  throw "The proxy exposed internal readiness."
}

$oversized = Join-Path $validatedRoot "rehearsal\oversized-request.bin"
try {
  [IO.File]::WriteAllBytes($oversized, [byte[]]::new(1048577))
  $oversizedCode = & curl.exe --silent --show-error --cacert $ca --output NUL --write-out "%{http_code}" `
    --request POST --data-binary "@$oversized" "https://127.0.0.1:8443/health/live"
  if ($LASTEXITCODE -ne 0 -or $oversizedCode -ne "413") {
    throw "Oversized-request rejection failed."
  }
} finally {
  if (Test-Path -LiteralPath $oversized) {
    Remove-RisePalsValidatedChild -Root $validatedRoot -Path $oversized
  }
}

$timing = & curl.exe --silent --show-error --no-buffer --cacert $ca --output NUL `
  --header "X-Forwarded-For: 203.0.113.1" `
  --header "X-Forwarded-Host: attacker.invalid" `
  --header "X-Forwarded-Proto: http" `
  --write-out "%{time_starttransfer} %{time_total}" `
  "https://127.0.0.1:8443/health/stream"
if ($LASTEXITCODE -ne 0) {
  throw "Streaming probe request failed."
}
$parts = $timing.Trim().Split(" ", [StringSplitOptions]::RemoveEmptyEntries)
if ($parts.Count -ne 2 -or [double]$parts[0] -ge 0.30 -or [double]$parts[1] -lt 0.25) {
  throw "Streaming appears buffered or did not preserve the intended timing."
}

& $caddy reload --config $config --adapter caddyfile --force | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Caddy loopback-admin reload failed."
}

$listeners = @(Get-NetTCPConnection -State Listen |
  Where-Object { $_.LocalPort -in @(2019, 3100, 8080, 8443) })
if ($listeners.Count -ne 4 -or @($listeners | Where-Object { $_.LocalAddress -notin @("127.0.0.1", "::1") }).Count -ne 0) {
  throw "Rise Pals listeners are not exactly the four approved loopback endpoints."
}

Write-Output "Loopback health/proxy/TLS/limits/streaming/reload PASS"
