[CmdletBinding()]
param([string]$Root = "C:\RisePals")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$caddy = Join-Path $validatedRoot "tools\caddy\2.11.4\caddy.exe"
$node = Join-Path $validatedRoot "tools\node\24.18.1\node.exe"
$config = Join-Path $validatedRoot "shared\config\Caddyfile"
$ca = Join-Path $validatedRoot "shared\cache\caddy\pki\authorities\local\root.crt"
$probe = Join-Path $PSScriptRoot "loopback-https-probe.mjs"
foreach ($path in @($caddy, $node, $config, $ca, $probe)) {
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

& $node $probe --ca $ca --url `
  "https://127.0.0.1:8443/health/live?token=synthetic-redaction-probe" `
  --status 200 --body-base64 "eyJzdGF0dXMiOiJvayJ9"
if ($LASTEXITCODE -ne 0) {
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

& $node $probe --ca $ca --url "https://127.0.0.1:8443/health/ready" --status 404
if ($LASTEXITCODE -ne 0) {
  throw "The proxy exposed internal readiness."
}

& $node $probe --ca $ca --url "https://127.0.0.1:8443/health/live" --status 413 `
  --method POST --body-bytes 1048577
if ($LASTEXITCODE -ne 0) {
  throw "Oversized-request rejection failed."
}

& $node $probe --ca $ca --url "https://127.0.0.1:8443/health/stream" --status 200 `
  --header "X-Forwarded-For: 203.0.113.1" `
  --header "X-Forwarded-Host: attacker.invalid" `
  --header "X-Forwarded-Proto: http" `
  --max-first-byte-ms 300 --min-total-ms 1200
if ($LASTEXITCODE -ne 0) {
  throw "Streaming probe request failed."
}

& $caddy reload --config $config --adapter caddyfile --force | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Caddy loopback-admin reload failed."
}

$listeners = @(Get-NetTCPConnection -State Listen |
  Where-Object { $_.LocalPort -in @(2019, 3100, 8080, 8443) })
if ($listeners.Count -ne 4 -or @($listeners | Where-Object { $_.LocalAddress -notin @("127.0.0.1", "::1") }).Count -ne 0) {
  $observedListeners = (($listeners | Sort-Object LocalPort, LocalAddress | ForEach-Object {
    "{0}:{1}" -f $_.LocalAddress, $_.LocalPort
  }) -join ",")
  throw "Rise Pals listeners are not exactly the four approved loopback endpoints: $observedListeners."
}

Write-Output "Loopback health/proxy/TLS/limits/streaming/reload PASS"
