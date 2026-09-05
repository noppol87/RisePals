[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [switch]$ContractOnly, [switch]$SyntheticChild,
  [string]$BootDirectory = "", [string]$BootNonce = "", [string]$BootAuthorization = "",
  [string]$BootHead = "", [string]$BootRequestDigest = "", [string]$BootScriptHash = "",
  [string]$BootScenario = "None", [string]$ChildScenario = "Success"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Self-contained pre-import protocol. ContractOnly defines readers, not a launch.
$script:RecoveryBootStages = @("bootstrap-entry", "raw-arguments-validated",
  "bootstrap-marker-write-attempted", "bootstrap-marker-written", "bootstrap-marker-reopened",
  "child-script-launch-attempted", "child-script-process-created", "child-script-process-exited",
  "child-entry-marker-observed", "bootstrap-result-written", "bootstrap-result-reopened")
$script:RecoveryBootCategories = @("none", "bootstrap-arguments-invalid", "bootstrap-provenance-invalid",
  "bootstrap-marker-persistence-failure", "bootstrap-marker-reopen-failure",
  "child-script-process-creation-failure", "child-script-exit-before-entry-marker",
  "child-entry-marker-invalid", "child-script-failure", "bootstrap-result-persistence-failure",
  "bootstrap-result-reopen-failure")
$script:RecoveryBootScenarios = @("None", "Success", "Arguments", "Provenance", "MarkerPersistence",
  "MarkerReopen", "BeforeMarker", "ChildCreation", "ChildBeforeMarker", "ChildMarkerTamper",
  "ChildFailure", "ResultPersistence", "ResultReopen", "MixedModules")
$script:RecoveryBootKeys = @("schemaVersion", "authorizationId", "invocationNonce", "repositoryHead",
  "executionMode", "requestDigest", "bootstrapScriptSha256", "parentScriptSha256", "childScriptSha256",
  "contractScriptSha256", "liveScriptSha256", "fixtureScenario", "sequence", "previousDigest",
  "stage", "stageCompleted", "category", "childProcessCreated", "childExitCode",
  "childMarkerPresent", "childMarkerDigest", "childResultDigest", "invocationEnvelopeDigest",
  "entryAdapterScriptSha256", "entryAdapterMarkerDigest", "entryAdapterResultDigest", "recordedAtUtc", "recordDigest")

function Get-RecoveryBootHash {
  param([string]$Path, [byte[]]$Bytes)
  $sha=[Security.Cryptography.SHA256]::Create(); $stream=$null
  try {
    if ($Path) {
      $item=Get-Item -LiteralPath $Path -Force
      if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Bootstrap file rejected." }
      $stream=[IO.File]::OpenRead($item.FullName); $hash=$sha.ComputeHash($stream)
    } else { $hash=$sha.ComputeHash($Bytes) }
    return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
  } finally { if ($null -ne $stream) { $stream.Dispose() }; $sha.Dispose() }
}
function Assert-RecoveryBootDirectory {
  param([string]$Directory, [string]$Nonce)
  $root=[IO.Path]::GetFullPath($Directory)
  if ($root -cne $Directory -or $Nonce -cnotmatch '^[a-f0-9]{32}$' -or
    [IO.Path]::GetFileName($root) -cne ("diag7-"+$Nonce) -or
    ([IO.Path]::GetDirectoryName($root).TrimEnd('\') -cne [IO.Path]::GetTempPath().TrimEnd('\') -and
      [IO.Path]::GetDirectoryName($root) -cne "C:\Users\Administrator\Documents\Codex")) { throw "Bootstrap directory rejected." }
  $ancestor=$root
  while ($ancestor) {
    $item=Get-Item -LiteralPath $ancestor -Force
    if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Bootstrap ancestry rejected." }
    $ancestor=[IO.Path]::GetDirectoryName($ancestor)
  }
  return $root
}
function Get-RecoveryBootJson {
  param([object]$Record, [switch]$WithoutDigest)
  $body=[ordered]@{}
  foreach ($key in $script:RecoveryBootKeys) {
    if (-not ($WithoutDigest -and $key -ceq "recordDigest")) { $body[$key]=$Record.$key }
  }
  return ($body | ConvertTo-Json -Depth 4 -Compress)
}
function Get-RecoveryBootDigest {
  param([object]$Record)
  return Get-RecoveryBootHash -Bytes ([Text.UTF8Encoding]::new($false).GetBytes((Get-RecoveryBootJson $Record -WithoutDigest)))
}
function Read-RecoveryBootJsonFile {
  param([string]$Path, [string]$Directory, [string]$Nonce)
  $root=Assert-RecoveryBootDirectory $Directory $Nonce
  if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)) -cne $root) { throw "Bootstrap containment rejected." }
  $item=Get-Item -LiteralPath $Path -Force
  if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
    $item.Length -lt 2 -or $item.Length -gt 16384) { throw "Bootstrap evidence object rejected." }
  $bytes=[IO.File]::ReadAllBytes($item.FullName)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { throw "Bootstrap BOM rejected." }
  return [Text.UTF8Encoding]::new($false,$true).GetString($bytes)
}
function Read-RecoveryBootRecord {
  param([string]$Path, [string]$Directory, [object]$Request, [string]$BootstrapHash,
    [string]$FixtureScenario, [AllowNull()][object]$Previous)
  $json=Read-RecoveryBootJsonFile $Path $Directory $Request.invocationNonce
  $r=$json | ConvertFrom-Json
  if (@($r.PSObject.Properties).Count -ne $script:RecoveryBootKeys.Count -or
    @($r.PSObject.Properties.Name | Where-Object { $_ -cnotin $script:RecoveryBootKeys }).Count -ne 0 -or
    $json -cne (Get-RecoveryBootJson $r)) { throw "Bootstrap exact schema rejected." }
  foreach ($key in @("authorizationId","invocationNonce","repositoryHead","executionMode",
    "parentScriptSha256","childScriptSha256","contractScriptSha256","liveScriptSha256")) {
    if ($r.$key -isnot [string] -or $r.$key -cne $Request.$key) { throw "Bootstrap binding rejected." }
  }
  if ($r.schemaVersion -cne "rise-pals-recovery-bootstrap-v1" -or $r.requestDigest -cne $Request.recordDigest -or
    $r.bootstrapScriptSha256 -cne $BootstrapHash -or $BootstrapHash -cnotmatch '^[a-f0-9]{64}$' -or
    $r.fixtureScenario -cne $FixtureScenario -or $FixtureScenario -cnotin $script:RecoveryBootScenarios -or
    $r.stage -isnot [string] -or $r.stage -cnotin $script:RecoveryBootStages -or
    $r.category -isnot [string] -or $r.category -cnotin $script:RecoveryBootCategories) { throw "Bootstrap vocabulary rejected." }
  foreach ($key in @("stageCompleted","childProcessCreated","childMarkerPresent")) {
    if ($r.$key -isnot [bool]) { throw "Bootstrap boolean rejected." }
  }
  if ($r.sequence -isnot [int] -or $r.sequence -lt 0 -or $r.sequence -gt 20 -or
    ($null -ne $r.childExitCode -and ($r.childExitCode -isnot [int] -or $r.childExitCode -lt 0 -or $r.childExitCode -gt 255)) -or
    ($null -ne $r.childExitCode -and -not $r.childProcessCreated) -or
    ($r.stageCompleted -and $r.category -cne "none") -or (-not $r.stageCompleted -and $r.category -ceq "none")) { throw "Bootstrap state rejected." }
  foreach ($key in @("previousDigest","childMarkerDigest","childResultDigest","invocationEnvelopeDigest",
    "entryAdapterScriptSha256","entryAdapterMarkerDigest","entryAdapterResultDigest")) {
    if ($null -ne $r.$key -and ($r.$key -isnot [string] -or $r.$key -cnotmatch '^[a-f0-9]{64}$')) { throw "Bootstrap digest type rejected." }
  }
  if ($r.childMarkerPresent -ne ($null -ne $r.childMarkerDigest) -or
    ($r.childMarkerPresent -and -not $r.childProcessCreated) -or ($null -ne $r.childResultDigest -and -not $r.childMarkerPresent)) {
    throw "Bootstrap observation rejected."
  }
  $instant=[DateTimeOffset]::MinValue
  if ($r.recordedAtUtc -isnot [string] -or -not [DateTimeOffset]::TryParseExact($r.recordedAtUtc,"o",
      [Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$instant) -or
    $instant.Offset -ne [TimeSpan]::Zero -or ([DateTimeOffset]::UtcNow-$instant).TotalSeconds -gt 300 -or
    ($instant-[DateTimeOffset]::UtcNow).TotalSeconds -gt 30) { throw "Bootstrap timestamp rejected." }
  if ($null -eq $Previous) {
    if ($r.sequence -ne 0 -or $r.stage -cne "bootstrap-entry" -or $null -ne $r.previousDigest) { throw "Bootstrap first stage rejected." }
  } else {
    $afterFailure= -not $Previous.stageCompleted -and $r.stage -ceq "bootstrap-result-written" -and $r.stageCompleted
    if ($r.sequence -ne $Previous.sequence+1 -or $r.previousDigest -cne $Previous.recordDigest -or
      $instant -lt [DateTimeOffset]::Parse($Previous.recordedAtUtc) -or
      (-not $afterFailure -and (-not $Previous.stageCompleted -or
        [array]::IndexOf($script:RecoveryBootStages,$r.stage) -ne [array]::IndexOf($script:RecoveryBootStages,$Previous.stage)+1)) -or
      ($Previous.childProcessCreated -and -not $r.childProcessCreated) -or
      ($Previous.childMarkerPresent -and -not $r.childMarkerPresent)) { throw "Bootstrap progression rejected." }
  }
  if ([IO.Path]::GetFileName($Path) -cne ("bootstrap-{0:D2}.json" -f $r.sequence) -or
    $r.recordDigest -cnotmatch '^[a-f0-9]{64}$' -or $r.recordDigest -cne (Get-RecoveryBootDigest $r)) { throw "Bootstrap digest or filename rejected." }
  return $r
}
function Write-RecoveryBootRecord {
  param([object]$Request, [string]$BootstrapHash, [string]$FixtureScenario, [string]$Directory,
    [string]$Stage, [AllowNull()][object]$Previous, [string]$Category="none", [bool]$Completed=$true,
    [bool]$Created=$false, [AllowNull()][object]$ExitCode, [AllowNull()][object]$MarkerDigest, [AllowNull()][object]$ResultDigest,
    [AllowNull()][object]$InvocationDigest, [AllowNull()][object]$EntryHash, [AllowNull()][object]$EntryMarker, [AllowNull()][object]$EntryResult)
  $root=Assert-RecoveryBootDirectory $Directory $Request.invocationNonce
  $r=[ordered]@{schemaVersion="rise-pals-recovery-bootstrap-v1";authorizationId=$Request.authorizationId
    invocationNonce=$Request.invocationNonce;repositoryHead=$Request.repositoryHead;executionMode=$Request.executionMode
    requestDigest=$Request.recordDigest;bootstrapScriptSha256=$BootstrapHash;parentScriptSha256=$Request.parentScriptSha256
    childScriptSha256=$Request.childScriptSha256;contractScriptSha256=$Request.contractScriptSha256;liveScriptSha256=$Request.liveScriptSha256
    fixtureScenario=$FixtureScenario;sequence=$(if ($null -eq $Previous) {0} else {[int]$Previous.sequence+1})
    previousDigest=$(if ($null -eq $Previous) {$null} else {$Previous.recordDigest});stage=$Stage;stageCompleted=$Completed
    category=$Category;childProcessCreated=$Created;childExitCode=$ExitCode;childMarkerPresent=($null -ne $MarkerDigest)
    childMarkerDigest=$MarkerDigest;childResultDigest=$ResultDigest;invocationEnvelopeDigest=$InvocationDigest
    entryAdapterScriptSha256=$EntryHash;entryAdapterMarkerDigest=$EntryMarker;entryAdapterResultDigest=$EntryResult
    recordedAtUtc=[DateTimeOffset]::UtcNow.ToString("o");recordDigest=""}
  $r.recordDigest=Get-RecoveryBootDigest ([pscustomobject]$r)
  $path=Join-Path $root ("bootstrap-{0:D2}.json" -f $r.sequence)
  $bytes=[Text.UTF8Encoding]::new($false).GetBytes((Get-RecoveryBootJson ([pscustomobject]$r)))
  $stream=[IO.File]::Open($path+".tmp",[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try {$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)} finally {$stream.Dispose()}
  [IO.File]::Move($path+".tmp",$path)
  return $path
}
if ($ContractOnly) { return }

# Primitive parsing, canonical request binding and all source hashes are checked
# without importing any repository helper. Invalid boundaries receive no success.
if ($PSVersionTable.PSEdition -cne "Desktop" -or $PSVersionTable.PSVersion.Major -ne 5 -or
  $PSVersionTable.PSVersion.Minor -ne 1 -or $BootNonce -cnotmatch '^[a-f0-9]{32}$' -or
  $BootAuthorization -cnotmatch '^RP-TURN-019-R4-(RECOVERY|LIVE)-[A-F0-9]{8}$' -or
  $BootHead -cnotmatch '^[a-f0-9]{40}$' -or $BootRequestDigest -cnotmatch '^[a-f0-9]{64}$' -or
  $BootScriptHash -cnotmatch '^[a-f0-9]{64}$' -or $BootScenario -cnotin $script:RecoveryBootScenarios -or
  $ChildScenario -cnotin @("Success","BeforeImportFailure","ChildFailure")) { exit 80 }
try {
  $requestJson=Read-RecoveryBootJsonFile (Join-Path $BootDirectory "request-00.json") $BootDirectory $BootNonce
  $bootRequest=$requestJson | ConvertFrom-Json
  $requestKeys=@("schemaVersion","kind","executionMode","authorizationId","invocationNonce","repositoryHead",
    "parentScriptSha256","childScriptSha256","liveScriptSha256","contractScriptSha256","requestDigest","sequence",
    "previousDigest","evidenceDigest","stage","stageCompleted","category","exitCode","hResult","nativeCode",
    "cleanupCompleted","invocationEnvelopeDigest","entryAdapterDigest","recordedAtUtc","recordDigest")
  if (@($bootRequest.PSObject.Properties).Count -ne $requestKeys.Count -or
    @($bootRequest.PSObject.Properties.Name | Where-Object {$_ -cnotin $requestKeys}).Count) { exit 80 }
  $canonical=[ordered]@{}; $body=[ordered]@{}
  foreach ($key in $requestKeys) { $canonical[$key]=$bootRequest.$key; if ($key -cne "recordDigest") {$body[$key]=$bootRequest.$key} }
  if ($requestJson -cne ($canonical | ConvertTo-Json -Depth 4 -Compress) -or
    (Get-RecoveryBootHash -Bytes ([Text.UTF8Encoding]::new($false).GetBytes(($body | ConvertTo-Json -Depth 4 -Compress)))) -cne $BootRequestDigest -or
    $bootRequest.recordDigest -cne $BootRequestDigest -or $bootRequest.invocationNonce -cne $BootNonce -or
    $bootRequest.authorizationId -cne $BootAuthorization -or $bootRequest.repositoryHead -cne $BootHead -or
    $bootRequest.kind -cne "request" -or $bootRequest.stage -cne "request-created" -or
    $bootRequest.executionMode -cnotin @("Simulation","Recovery")) { exit 80 }
  if ($bootRequest.executionMode -ceq "Simulation") {
    if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
      [Security.Principal.WindowsBuiltInRole]::Administrator)) {exit 80}
  } elseif ($BootScenario -cne "None" -or $SyntheticChild) {exit 80}
  if ((Get-RecoveryBootHash -Path $PSCommandPath) -cne $BootScriptHash) {exit 80}
  foreach ($pair in @(@("parentScriptSha256","Invoke-RisePalsRecoveryDiagnostic.ps1"),
    @("childScriptSha256","Invoke-RisePalsRecoveryChild.ps1"),@("contractScriptSha256","recovery-diagnostic-contract.ps1"),
    @("liveScriptSha256","Invoke-RisePalsCandidateLiveSequence.ps1"))) {
    if ((Get-RecoveryBootHash -Path (Join-Path $PSScriptRoot $pair[1])) -cne $bootRequest.($pair[0])) {exit 80}
  }
} catch {exit 80}
# Read-only binding validation above is allowed during dry-run. No evidence write
# or child creation (including the synthetic child path) precedes this boundary.
if (-not $PSCmdlet.ShouldProcess("Validated recovery invocation", "Write bootstrap evidence and dispatch the bound child")) {
  return
}
if ($SyntheticChild) {
  if ($BootScenario -ceq "None" -or $bootRequest.executionMode -cne "Simulation") {exit 80}
  if ($BootScenario -ceq "ChildBeforeMarker") {exit 71}
  . (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1")
  $bootRequest=Read-RisePalsRecoveryRecord (Join-Path $BootDirectory "request-00.json") $BootDirectory $bootRequest $null
  $previous=$null
  foreach ($stage in $script:RisePalsRecoveryStageOrders.child) {
    $recordArguments=@{Binding=$bootRequest;Kind="child";Stage=$stage;Previous=$previous}
    if ($stage -ceq "recovery-result") {
      $recordArguments.Category=if($BootScenario -ceq "ChildFailure"){"child-failure"}else{"child-success"}
      $recordArguments.ExitCode=if($BootScenario -ceq "ChildFailure"){72}else{0};$recordArguments.CleanupCompleted=($BootScenario -cne "ChildFailure")
    }
    $record=New-RisePalsRecoveryRecord @recordArguments
    $path=Write-RisePalsRecoveryRecord $record $BootDirectory
    $previous=Read-RisePalsRecoveryRecord $path $BootDirectory $bootRequest $previous
  }
  if ($BootScenario -ceq "ChildMarkerTamper") {
    [IO.File]::WriteAllText((Join-Path $BootDirectory "child-00.json"),"{}",[Text.UTF8Encoding]::new($false))
  }
  if ($BootScenario -ceq "ChildFailure") {exit 72}; exit 0
}
if ($BootScenario -ceq "BeforeMarker") {exit 81}
$script:bootLast=$null; $bootProcess=$null; $created=$false; $childCode=$null; $markerDigest=$null; $resultDigest=$null
$invocationDigest=$null;$entryHash=$null;$entryMarker=$null;$entryResult=$null
$bootStage="bootstrap-entry"; $bootCategory="bootstrap-marker-persistence-failure"; $bootSuccess=$false
function Add-RecoveryBootStage {
  param([string]$Stage,[string]$Category="none",[bool]$Completed=$true)
  $path=Write-RecoveryBootRecord $bootRequest $BootScriptHash $BootScenario $BootDirectory $Stage $script:bootLast `
    -Category $Category -Completed $Completed -Created $created -ExitCode $childCode -MarkerDigest $markerDigest -ResultDigest $resultDigest `
    -InvocationDigest $invocationDigest -EntryHash $entryHash -EntryMarker $entryMarker -EntryResult $entryResult
  $script:bootLast=Read-RecoveryBootRecord $path $BootDirectory $bootRequest $BootScriptHash $BootScenario $script:bootLast
}
try {
  # Authenticated bootstrap-started record, before any helper import or child.
  Add-RecoveryBootStage $bootStage
  $bootStage="raw-arguments-validated"; $bootCategory="bootstrap-arguments-invalid"
  if ($BootScenario -ceq "Arguments") {throw "Synthetic arguments rejection."}
  $bootCategory="bootstrap-provenance-invalid"
  if ($BootScenario -ceq "Provenance") {throw "Synthetic provenance rejection."}
  Add-RecoveryBootStage $bootStage
  $bootStage="bootstrap-marker-write-attempted";Add-RecoveryBootStage $bootStage
  $bootStage="bootstrap-marker-written";$bootCategory="bootstrap-marker-persistence-failure"
  if ($BootScenario -ceq "MarkerPersistence") {throw "Synthetic marker persistence failure."}
  Add-RecoveryBootStage $bootStage
  $bootStage="bootstrap-marker-reopened";$bootCategory="bootstrap-marker-reopen-failure"
  if ($BootScenario -ceq "MarkerReopen") {throw "Synthetic marker reopen failure."}
  Add-RecoveryBootStage $bootStage
  . (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1")
  $bootRequest=Read-RisePalsRecoveryRecord (Join-Path $BootDirectory "request-00.json") $BootDirectory $bootRequest $null
  $bootStage="child-script-launch-attempted";Add-RecoveryBootStage $bootStage
  $bootStage="child-script-process-created";$bootCategory="child-script-process-creation-failure"
  if ($BootScenario -ceq "ChildCreation") {throw "Synthetic child creation failure."}
  if ($BootScenario -cne "None") {
    $childArgs=@("-NoLogo","-NoProfile","-NonInteractive","-File",('"'+$PSCommandPath+'"'),"-SyntheticChild",
      "-BootDirectory",('"'+$BootDirectory+'"'),"-BootNonce",$BootNonce,"-BootAuthorization",$BootAuthorization,
      "-BootHead",$BootHead,"-BootRequestDigest",$BootRequestDigest,"-BootScriptHash",$BootScriptHash,"-BootScenario",$BootScenario)
  } else {
    . (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildEntry.ps1") -ContractOnly
    $envelope=New-RecoveryInvocationEnvelope $bootRequest $BootDirectory $ChildScenario
    $envelopePath=Write-RecoveryInvocationEnvelope $envelope
    $envelope=Read-RecoveryInvocationEnvelope $envelopePath $envelope.envelopeDigest
    $invocationDigest=$envelope.envelopeDigest;$entryHash=$envelope.entryAdapterScriptSha256
    $childArgs=@("-NoLogo","-NoProfile","-NonInteractive","-File",('"'+(Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildEntry.ps1")+'"'),
      "-EnvelopePath",('"'+$envelopePath+'"'),"-EnvelopeDigest",$invocationDigest)
  }
  $bootProcess=Start-Process -FilePath (Join-Path $PSHOME "powershell.exe") -ArgumentList $childArgs -WindowStyle Hidden -PassThru
  $created=$true;Add-RecoveryBootStage $bootStage
  $bootStage="child-script-process-exited";$bootCategory="child-script-failure"
  if (-not $bootProcess.WaitForExit(240000)) {throw "Bootstrap child exit unproven."}
  $childCode=$bootProcess.ExitCode;Add-RecoveryBootStage $bootStage
  if($BootScenario -ceq "None"){
    $entryPrevious=$null;$entryFailures=@()
    foreach($file in @(Get-ChildItem -LiteralPath $BootDirectory -File | Where-Object Name -match '^entry-[0-9]{2}\.json$' | Sort-Object Name)){
      $entryPrevious=Read-RecoveryChildEntryRecord $file.FullName $envelope $entryPrevious
      if($entryPrevious.sequence -eq 0){$entryMarker=$entryPrevious.recordDigest}
      if(-not $entryPrevious.stageCompleted){$entryFailures+=@($entryPrevious)}
    }
    if($null -ne $entryPrevious){$entryResult=$entryPrevious.recordDigest}
    if($null -ne $entryPrevious -and $null -ne $entryPrevious.childExitCode){$childCode=$entryPrevious.childExitCode}
  }
  $bootStage="child-entry-marker-observed";$bootCategory="child-script-exit-before-entry-marker"
  if (-not [IO.File]::Exists((Join-Path $BootDirectory "child-00.json"))) {throw "Bootstrap child entry absent."}
  $bootCategory="child-entry-marker-invalid"
  $child=Read-RisePalsRecoveryRecord (Join-Path $BootDirectory "child-00.json") $BootDirectory $bootRequest $null
  $markerDigest=$child.recordDigest;Add-RecoveryBootStage $bootStage
  $bootStage="bootstrap-result-written";$bootCategory="child-script-failure"
  foreach ($number in 1..3) {$child=Read-RisePalsRecoveryRecord (Join-Path $BootDirectory ("child-{0:D2}.json" -f $number)) $BootDirectory $bootRequest $child}
  $resultDigest=$child.recordDigest
  if ($childCode -ne 0 -or $child.exitCode -ne 0 -or $child.category -cne "child-success" -or $child.cleanupCompleted -ne $true) {throw "Bootstrap child failed."}
  $bootSuccess=$true
} catch {
  if ($null -ne $script:bootLast) {Add-RecoveryBootStage $bootStage $bootCategory $false}
} finally {
  if ($null -ne $bootProcess) {
    try {if (-not $bootProcess.HasExited -and -not $bootProcess.WaitForExit(10000)) {throw "Bootstrap owned child remains active."}}
    finally {$bootProcess.Dispose()}
  }
}
try {
  if ($BootScenario -ceq "ResultPersistence") {
    Add-RecoveryBootStage "bootstrap-result-written" "bootstrap-result-persistence-failure" $false
    exit 83
  }
  if ($script:bootLast.stage -cne "bootstrap-result-written") {Add-RecoveryBootStage "bootstrap-result-written"}
  if ($BootScenario -ceq "ResultReopen") {
    Add-RecoveryBootStage "bootstrap-result-reopened" "bootstrap-result-reopen-failure" $false
    exit 83
  }
  if (-not $script:bootLast.stageCompleted) {exit 82}
  Add-RecoveryBootStage "bootstrap-result-reopened"
} catch {exit 83}
if ($bootSuccess) {exit 0};exit 82
