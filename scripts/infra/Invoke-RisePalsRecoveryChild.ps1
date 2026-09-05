[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string]$ExecutionMode = "", [string]$AuthorizationId = "", [string]$InvocationNonce = "",
  [string]$RepositoryHead = "", [string]$ParentScriptSha256 = "", [string]$ChildScriptSha256 = "",
  [string]$LiveScriptSha256 = "", [string]$ContractScriptSha256 = "", [string]$RequestDigest = "",
  [string]$EvidenceDirectory = "", [string]$Scenario = "",
  [string]$CandidateExecutableSource = "", [string]$NodeExecutableSource = "",
  [string]$StructuredStatePath = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Self-contained first-record writer: no helper import, ambient hash cmdlet,
# protected-host access, output capture or credential access precedes this marker.
function Write-RisePalsDiag7Entry {
  param([string]$Kind, [string]$Stage)
  if ($PSVersionTable.PSEdition -ne "Desktop" -or $PSVersionTable.PSVersion.Major -ne 5 -or
    $PSVersionTable.PSVersion.Minor -ne 1 -or
    $InvocationNonce -cnotmatch '^[a-f0-9]{32}$' -or
    $AuthorizationId -cnotmatch '^RP-TURN-019-R4-(RECOVERY|LIVE)-[A-F0-9]{8}$' -or
    $RepositoryHead -cnotmatch '^[a-f0-9]{40}$' -or
    $ExecutionMode -cnotin @("Simulation", "Recovery", "Live")) { throw "Entry primitives rejected." }
  foreach ($value in @($ParentScriptSha256, $ChildScriptSha256, $LiveScriptSha256, $ContractScriptSha256, $RequestDigest)) {
    if ($value -cnotmatch '^[a-f0-9]{64}$') { throw "Entry provenance rejected." }
  }
  $root = [IO.Path]::GetFullPath($EvidenceDirectory)
  $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  $documentsRoot = "C:\Users\Administrator\Documents\Codex\"
  if ($root -cne $EvidenceDirectory -or
    (-not $root.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -and
      -not $root.StartsWith($documentsRoot, [StringComparison]::OrdinalIgnoreCase)) -or
    [IO.Path]::GetFileName($root) -cne ("diag7-" + $InvocationNonce)) { throw "Entry directory rejected." }
  $ancestor = $root
  while ($ancestor) {
    $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction Stop
    if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      throw "Entry ancestry rejected."
    }
    $ancestor = [IO.Path]::GetDirectoryName($ancestor)
  }
  $own = Get-Item -LiteralPath $PSCommandPath -Force
  if ($own.PSIsContainer -or ($own.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Entry script rejected." }
  $algorithm = [Security.Cryptography.SHA256]::Create()
  $source = [IO.File]::OpenRead($PSCommandPath)
  try { $ownHash = ([BitConverter]::ToString($algorithm.ComputeHash($source))).Replace("-", "").ToLowerInvariant() }
  finally { $source.Dispose(); $algorithm.Dispose() }
  if ($ownHash -cne $ChildScriptSha256) { throw "Entry script provenance rejected." }
  $record = [ordered]@{
    schemaVersion = "rise-pals-recovery-diagnostic-v1"; kind = $Kind; executionMode = $ExecutionMode
    authorizationId = $AuthorizationId; invocationNonce = $InvocationNonce; repositoryHead = $RepositoryHead
    parentScriptSha256 = $ParentScriptSha256; childScriptSha256 = $ChildScriptSha256
    liveScriptSha256 = $LiveScriptSha256; contractScriptSha256 = $ContractScriptSha256
    requestDigest = $RequestDigest; sequence = 0; previousDigest = $null; evidenceDigest = $null
    stage = $Stage; stageCompleted = $true; category = "none"; exitCode = $null
    hResult = $null; nativeCode = $null; cleanupCompleted = $null
    invocationEnvelopeDigest = $null; entryAdapterDigest = $null
    recordedAtUtc = [DateTimeOffset]::UtcNow.ToString("o")
  }
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($record | ConvertTo-Json -Depth 4 -Compress))
    $record.recordDigest = ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
  } finally { $algorithm.Dispose() }
  $path = Join-Path $root ($Kind + "-00.json")
  if ([IO.File]::Exists($path) -or [IO.File]::Exists($path + ".tmp")) { throw "Entry replay rejected." }
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($record | ConvertTo-Json -Depth 4 -Compress))
  $stream = [IO.File]::Open($path + ".tmp", [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
  try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
  [IO.File]::Move($path + ".tmp", $path)
  return [pscustomobject]$record
}

$entry = Write-RisePalsDiag7Entry -Kind child -Stage child-started
if ($ExecutionMode -eq "Simulation" -and $Scenario -eq "BeforeImportFailure") { exit 61 }
. (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1")
$contractPath = Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1"
if ((Get-RisePalsRecoveryHash $contractPath) -cne $ContractScriptSha256) { exit 62 }
$request = Read-RisePalsRecoveryRecord (Join-Path $EvidenceDirectory "request-00.json") $EvidenceDirectory $entry $null
$entry = Read-RisePalsRecoveryRecord (Join-Path $EvidenceDirectory "child-00.json") $EvidenceDirectory $request $null
$last = $entry
$stage = "dependencies-loaded"
try {
  . (Join-Path $PSScriptRoot "windows-powershell-security-bootstrap.ps1")
  [void](Initialize-RisePalsWindowsPowerShellSecurityModule)
  . (Join-Path $PSScriptRoot "candidate-rehearsal-contract.ps1")
  $next = New-RisePalsRecoveryRecord $request child $stage $last
  $path = Write-RisePalsRecoveryRecord $next $EvidenceDirectory
  $last = Read-RisePalsRecoveryRecord $path $EvidenceDirectory $request $last
  $stage = "recovery-preflight"
  if ($ExecutionMode -eq "Simulation") {
    if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
      [Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "Simulation elevation rejected." }
    if ($Scenario -cnotin @("Success", "ChildFailure", "CleanupTamper")) { throw "Simulation case rejected." }
  } else {
    # Future read-only recovery proof only. No residue deletion or service
    # operation is implemented or authorized by DIAG7.
    if ($ExecutionMode -cne "Recovery" -or -not $PSCmdlet.ShouldProcess(
      "exact nonce residue", "Validate a separately authorized recovery safe state")) { throw "Recovery approval absent." }
    $identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "Recovery elevation absent." }
    $services = @(Get-CimInstance Win32_Service -Filter "Name='RisePalsApp' OR Name='RisePalsProxy' OR Name='RisePalsServiceHostCandidate'")
    if ($services.Count -ne 2 -or
      @($services | Where-Object { $_.Name -notin @("RisePalsApp", "RisePalsProxy") -or
        $_.State -ne "Stopped" -or $_.StartMode -ne "Disabled" -or $_.ProcessId -ne 0 }).Count) {
      throw "Recovery service state unverified."
    }
    foreach ($path in @(
      ("C:\RisePals\staging\candidate-" + $InvocationNonce),
      ("C:\RisePals\rehearsal\candidate-" + $InvocationNonce),
      ("C:\RisePals\logs\service-host-candidate\candidate-" + $InvocationNonce))) {
      $absent = $false
      try { $null = Get-Item -LiteralPath $path -Force -ErrorAction Stop }
      catch {
        if ($_.CategoryInfo.Category -eq [Management.Automation.ErrorCategory]::ObjectNotFound) { $absent = $true }
        else { throw "Recovery path inspection unverified." }
      }
      if (-not $absent) { throw "Recovery residue requires separate disposition." }
    }
    if (@(Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in @(80,443,2019,3100,8080,8443) }).Count -or
      @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and
        $_.ExecutablePath.StartsWith("C:\RisePals\", [StringComparison]::OrdinalIgnoreCase) }).Count -or
      @(Get-NetFirewallRule | Where-Object { ($_.DisplayName -like "*Rise Pals*" -or $_.DisplayName -like "*RisePals*") -and
        $_.Enabled -eq "True" }).Count) { throw "Recovery host state unverified." }
  }
  $next = New-RisePalsRecoveryRecord $request child $stage $last
  $path = Write-RisePalsRecoveryRecord $next $EvidenceDirectory
  $last = Read-RisePalsRecoveryRecord $path $EvidenceDirectory $request $last
  $stage = "recovery-result"
  $success = $ExecutionMode -ne "Simulation" -or $Scenario -ne "ChildFailure"
  $category = if ($success) { "child-success" } else { "child-failure" }
  $code = if ($success) { 0 } else { 63 }
  $next = New-RisePalsRecoveryRecord $request child $stage $last -Category $category -ExitCode $code -CleanupCompleted $success
  $path = Write-RisePalsRecoveryRecord $next $EvidenceDirectory
  [void](Read-RisePalsRecoveryRecord $path $EvidenceDirectory $request $last)
  exit $code
} catch {
  $failed = New-RisePalsRecoveryRecord $request child $stage $last -Category recovery-unverified -ExitCode 64 -StageCompleted $false
  $path = Write-RisePalsRecoveryRecord $failed $EvidenceDirectory
  [void](Read-RisePalsRecoveryRecord $path $EvidenceDirectory $request $last)
  exit 64
}
