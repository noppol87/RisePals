[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param([string]$Root = "C:\RisePals")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$rehearsal = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $validatedRoot "rehearsal"
)
$installedConfig = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $validatedRoot "tools\winsw\2.12.0\RisePalsApp.xml"
)
$diagnosticScript = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $rehearsal "readiness-diagnostic.js"
)
$resultPath = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $validatedRoot "logs\app\readiness-diagnostic.json"
)
$secretPath = Join-Path $validatedRoot "shared\secrets\rehearsal.canary"

if (-not $PSCmdlet.ShouldProcess(
  $validatedRoot,
  "Run one non-listening readiness dependency check as the application virtual account"
)) {
  Write-Output "Application-identity readiness diagnostic dry-run PASS"
  return
}

Assert-RisePalsAdministrator
foreach ($name in @("RisePalsApp", "RisePalsProxy")) {
  $service = Assert-RisePalsServiceIsAbsentOrOwned -Name $name -Root $validatedRoot
  if ($null -eq $service -or $service.StartName -ne "NT SERVICE\$name" -or
    $service.State -ne "Stopped" -or $service.StartMode -ne "Disabled") {
    throw "The readiness diagnostic requires both approved services Stopped and Disabled."
  }
}
if (-not (Test-Path -LiteralPath (Join-Path $validatedRoot "current\release-manifest.json") -PathType Leaf)) {
  throw "The reviewed current release marker is absent."
}
if ((Test-Path -LiteralPath $diagnosticScript) -or (Test-Path -LiteralPath $resultPath) -or
  (Test-Path -LiteralPath $secretPath)) {
  throw "A readiness diagnostic temporary path already exists."
}

$originalConfig = [IO.File]::ReadAllBytes($installedConfig)
$originalHash = (Get-FileHash -LiteralPath $installedConfig -Algorithm SHA256).Hash
$diagnostic = @'
const { readFileSync, writeFileSync } = require("node:fs");

function readable(path, expectedLength) {
  try {
    return readFileSync(path).byteLength === expectedLength;
  } catch {
    return false;
  }
}

function readableNonEmpty(path) {
  try {
    return readFileSync(path).byteLength > 0;
  } catch {
    return false;
  }
}

const marker = process.env.RISE_PALS_RELEASE_MARKER || "";
const canary = process.env.RISE_PALS_REHEARSAL_SECRET_FILE || "";
const result = {
  schemaVersion: "rise-pals-readiness-diagnostic-v1",
  rehearsalEnabled: process.env.RISE_PALS_INFRA_REHEARSAL === "1",
  markerPathExact: marker === "C:\\RisePals\\current\\release-manifest.json",
  markerReadable: readableNonEmpty(marker),
  canaryPathExact: canary === "C:\\RisePals\\shared\\secrets\\rehearsal.canary",
  canaryReadable: readable(canary, 64),
  workingDirectoryExact: process.cwd() === "C:\\RisePals\\rehearsal",
};
writeFileSync("C:\\RisePals\\logs\\app\\readiness-diagnostic.json", `${JSON.stringify(result)}\n`, {
  encoding: "utf8",
  flag: "wx",
});
setInterval(() => {}, 1000);
'@

try {
  & (Join-Path $PSScriptRoot "Repair-RisePalsSecretTraversal.ps1") `
    -Root $validatedRoot -Confirm:$false
  & (Join-Path $PSScriptRoot "Set-RisePalsRehearsalSecret.ps1") `
    -Action Create -Root $validatedRoot -Confirm:$false
  [IO.File]::WriteAllText($diagnosticScript, $diagnostic, [Text.UTF8Encoding]::new($false))

  [xml]$config = Get-Content -LiteralPath $installedConfig -Raw -Encoding UTF8
  $config.service.arguments = $diagnosticScript
  $config.service.workingdirectory = $rehearsal
  $settings = [Xml.XmlWriterSettings]::new()
  $settings.Encoding = [Text.UTF8Encoding]::new($false)
  $settings.Indent = $true
  $writer = [Xml.XmlWriter]::Create($installedConfig, $settings)
  try {
    $config.Save($writer)
  } finally {
    $writer.Dispose()
  }

  Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @(
    "config", "RisePalsApp", "start=", "demand"
  )
  Start-Service -Name "RisePalsApp"
  (Get-Service -Name "RisePalsApp").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
  $deadline = [DateTime]::UtcNow.AddSeconds(15)
  while (-not (Test-Path -LiteralPath $resultPath -PathType Leaf) -and
    [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 250
  }
  if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
    throw "The application-identity readiness result was not written."
  }
  $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Write-Output ("Readiness dependency booleans: rehearsal={0}; markerPath={1}; markerRead={2}; canaryPath={3}; canaryRead={4}; cwd={5}" -f
    $result.rehearsalEnabled,
    $result.markerPathExact,
    $result.markerReadable,
    $result.canaryPathExact,
    $result.canaryReadable,
    $result.workingDirectoryExact)
} finally {
  $service = Get-Service -Name "RisePalsApp" -ErrorAction SilentlyContinue
  if ($null -ne $service -and $service.Status -ne "Stopped") {
    Stop-Service -Name "RisePalsApp" -Force
    $service.WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
  }
  [IO.File]::WriteAllBytes($installedConfig, $originalConfig)
  [Array]::Clear($originalConfig, 0, $originalConfig.Length)
  Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @(
    "config", "RisePalsApp", "start=", "disabled"
  )
  foreach ($temporary in @($diagnosticScript, $resultPath)) {
    if (Test-Path -LiteralPath $temporary) {
      Remove-RisePalsValidatedChild -Root $validatedRoot -Path $temporary
    }
  }
  if (Test-Path -LiteralPath $secretPath) {
    & (Join-Path $PSScriptRoot "Set-RisePalsRehearsalSecret.ps1") `
      -Action Delete -Root $validatedRoot -Confirm:$false
  }
}

if ((Get-FileHash -LiteralPath $installedConfig -Algorithm SHA256).Hash -ne $originalHash -or
  (Get-CimInstance Win32_Service -Filter "Name='RisePalsApp'").StartMode -ne "Disabled") {
  throw "Readiness diagnostic cleanup did not restore the exact service configuration."
}

Write-Output "Application-identity readiness diagnostic and byte-identical cleanup PASS"
