[CmdletBinding(SupportsShouldProcess = $true)]
param([string]$EnvelopePath="", [string]$EnvelopeDigest="", [switch]$ContractOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:RecoveryEnvelopeKeys=@("schemaVersion","authorizationId","invocationNonce","repositoryHead","executionMode","scenario",
  "parentScriptSha256","bootstrapScriptSha256","entryAdapterScriptSha256","childScriptSha256","contractScriptSha256",
  "liveScriptSha256","requestDigest","evidenceDirectory","envelopeDigest")
$script:RecoveryEntryStages=@("entry-adapter-process-entry","minimal-arguments-validated","entry-marker-write-attempted",
  "entry-marker-written","entry-marker-reopened","envelope-read-attempted","envelope-validated",
  "child-source-parse-attempted","child-source-parse-complete","child-invocation-attempted",
  "child-entry-marker-observed","entry-result-written","entry-result-reopened")
$script:RecoveryEntryCategories=@("none","entry-arguments-invalid","entry-marker-persistence-failure","entry-marker-reopen-failure",
  "invocation-envelope-invalid","child-source-parse-failure","child-parameter-binding-failure","child-invocation-failure",
  "child-entry-marker-missing","child-entry-marker-invalid","entry-result-persistence-failure","entry-result-reopen-failure",
  "controlled-unclassified-failure")
$script:RecoveryEntryPredicates=@("none","minimal-reference-valid","marker-write","marker-reopen","envelope-valid",
  "ast-no-errors","splat-invocation-returned","child-marker-present","child-marker-valid","child-result-success",
  "result-write","result-reopen")
$script:RecoveryEntryScenarios=@("Success","BeforeImportFailure","ChildFailure","FixtureSuccess","FixtureParse",
  "FixtureBinding","FixtureInvocation","FixtureExit","FixtureTamper","FixtureAfterMarker",
  "FixtureBeforeEntry","FixtureMarkerPersistence","FixtureMarkerReopen","FixtureResultPersistence","FixtureResultReopen")
$script:RecoveryEntryKeys=@("schemaVersion","authorizationId","invocationNonce","repositoryHead","executionMode","envelopeDigest",
  "entryAdapterScriptSha256","requestDigest","sequence","previousDigest","stage","stageCompleted","category","failedPredicate",
  "errorId","exceptionType","hResult","nativeErrorCode","childExitCode","childMarkerDigest","childResultDigest","recordedAtUtc","recordDigest")
function Get-RecoveryEntryHash {
  param([string]$Path,[byte[]]$Bytes)
  $sha=[Security.Cryptography.SHA256]::Create();$stream=$null
  try {
    if($Path){$item=Get-Item -LiteralPath $Path -Force
      if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw "Entry source boundary rejected."}
      $stream=[IO.File]::OpenRead($Path);$hash=$sha.ComputeHash($stream)
    }else{$hash=$sha.ComputeHash($Bytes)}
    return ([BitConverter]::ToString($hash)).Replace("-","").ToLowerInvariant()
  }finally{if($null -ne $stream){$stream.Dispose()};$sha.Dispose()}
}
function Get-RecoveryEntryCanonical {
  param([object]$Record,[string[]]$Keys,[string]$Omit="")
  $body=[ordered]@{};foreach($key in $Keys){if($key -cne $Omit){$body[$key]=$Record.$key}}
  return ($body | ConvertTo-Json -Depth 4 -Compress)
}
function Get-RecoveryEntryDigest {
  param([object]$Record,[string[]]$Keys,[string]$DigestKey)
  return Get-RecoveryEntryHash -Bytes ([Text.UTF8Encoding]::new($false).GetBytes((Get-RecoveryEntryCanonical $Record $Keys $DigestKey)))
}
function Assert-RecoveryEntryDirectory {
  param([string]$Directory,[string]$Nonce)
  $exact=[IO.Path]::GetFullPath($Directory)
  if($Directory -cne $exact -or $Nonce -cnotmatch '^[a-f0-9]{32}$' -or
    [IO.Path]::GetFileName($exact) -cne ("diag7-"+$Nonce) -or
    ([IO.Path]::GetDirectoryName($exact).TrimEnd('\') -cne [IO.Path]::GetTempPath().TrimEnd('\') -and
      [IO.Path]::GetDirectoryName($exact) -cne "C:\Users\Administrator\Documents\Codex")){throw "Entry evidence boundary rejected."}
  $ancestor=$exact
  while($ancestor){$item=Get-Item -LiteralPath $ancestor -Force
    if(-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw "Entry reparse rejected."}
    $ancestor=[IO.Path]::GetDirectoryName($ancestor)}
  return $exact
}
function Read-RecoveryEntryJson {
  param([string]$Path,[string]$Directory,[string]$Nonce)
  $root=Assert-RecoveryEntryDirectory $Directory $Nonce
  if([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)) -cne $root){throw "Entry containment rejected."}
  $item=Get-Item -LiteralPath $Path -Force
  if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -lt 2 -or $item.Length -gt 16384){throw "Entry object rejected."}
  $bytes=[IO.File]::ReadAllBytes($Path)
  if($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191){throw "Entry BOM rejected."}
  return [Text.UTF8Encoding]::new($false,$true).GetString($bytes)
}
function Write-RecoveryEntryAtomic {
  param([string]$Path,[string]$Directory,[string]$Nonce,[string]$Json)
  $root=Assert-RecoveryEntryDirectory $Directory $Nonce
  if([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)) -cne $root -or
    [IO.File]::Exists($Path) -or [IO.File]::Exists($Path+".tmp")){throw "Entry replay or containment rejected."}
  $bytes=[Text.UTF8Encoding]::new($false).GetBytes($Json)
  $stream=[IO.File]::Open($Path+".tmp",[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
  [IO.File]::Move($Path+".tmp",$Path)
}
function Get-RecoveryEntryFixture {
  param([string]$Scenario)
  if($Scenario -ceq "FixtureParse"){return 'param('}
  if($Scenario -ceq "FixtureBinding"){return '[CmdletBinding()]param([string]$OnlyParameter)'}
  $prefix='[CmdletBinding(SupportsShouldProcess=$true)]param($ExecutionMode,$AuthorizationId,$InvocationNonce,$RepositoryHead,$ParentScriptSha256,$ChildScriptSha256,$LiveScriptSha256,$ContractScriptSha256,$RequestDigest,$EvidenceDirectory,$Scenario)'
  if($Scenario -ceq "FixtureInvocation"){return ($prefix+"`n"+'throw [InvalidOperationException]::new("synthetic")')}
  if($Scenario -ceq "FixtureExit"){return ($prefix+"`n"+'exit 74')}
  $body=@'
. 'C:\Codex PC SG2\Jeff\risepals\scripts\infra\recovery-diagnostic-contract.ps1'
$request=ConvertFrom-RisePalsRecoveryJson ([IO.File]::ReadAllText((Join-Path $EvidenceDirectory 'request-00.json')))
$request=Read-RisePalsRecoveryRecord (Join-Path $EvidenceDirectory 'request-00.json') $EvidenceDirectory $request $null
$previous=$null
foreach($stage in $script:RisePalsRecoveryStageOrders.child){
  $parameters=@{Binding=$request;Kind='child';Stage=$stage;Previous=$previous}
  if($stage -eq 'recovery-result'){$parameters.Category='child-success';$parameters.ExitCode=0;$parameters.CleanupCompleted=$true}
  $record=New-RisePalsRecoveryRecord @parameters
  $path=Write-RisePalsRecoveryRecord $record $EvidenceDirectory
  $previous=Read-RisePalsRecoveryRecord $path $EvidenceDirectory $request $previous
  if($Scenario -eq 'FixtureAfterMarker'){exit 75}
}
if($Scenario -eq 'FixtureTamper'){[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'child-00.json'),'{}',[Text.UTF8Encoding]::new($false))}
exit 0
'@
  return ($prefix+"`n"+$body)
}
function Get-RecoveryEntryChildPath {
  param([object]$Envelope)
  if($Envelope.scenario.StartsWith("Fixture",[StringComparison]::Ordinal)){
    if($Envelope.executionMode -cne "Simulation"){throw "Entry fixture mode rejected."}
    return Join-Path $Envelope.evidenceDirectory "child-fixture.ps1"
  }
  return Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChild.ps1"
}
function New-RecoveryInvocationEnvelope {
  param([object]$Request,[string]$Directory,[string]$Scenario="Success")
  $envelope=[ordered]@{schemaVersion="rise-pals-recovery-invocation-v1";authorizationId=$Request.authorizationId
    invocationNonce=$Request.invocationNonce;repositoryHead=$Request.repositoryHead;executionMode=$Request.executionMode;scenario=$Scenario
    parentScriptSha256=$Request.parentScriptSha256
    bootstrapScriptSha256=(Get-RecoveryEntryHash -Path (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildBootstrap.ps1"))
    entryAdapterScriptSha256=(Get-RecoveryEntryHash -Path (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildEntry.ps1"))
    childScriptSha256=$Request.childScriptSha256;contractScriptSha256=$Request.contractScriptSha256;liveScriptSha256=$Request.liveScriptSha256
    requestDigest=$Request.recordDigest;evidenceDirectory=$Directory;envelopeDigest=""}
  if($Scenario.StartsWith("Fixture",[StringComparison]::Ordinal)){
    $envelope.childScriptSha256=Get-RecoveryEntryHash -Bytes ([Text.UTF8Encoding]::new($false).GetBytes((Get-RecoveryEntryFixture $Scenario)))
  }
  $envelope.envelopeDigest=Get-RecoveryEntryDigest ([pscustomobject]$envelope) $script:RecoveryEnvelopeKeys "envelopeDigest"
  return [pscustomobject]$envelope
}
function Read-RecoveryInvocationEnvelope {
  param([string]$Path,[string]$Digest,[switch]$ReferenceOnly)
  $directory=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))
  $name=[IO.Path]::GetFileName($directory)
  if($name -cnotmatch '^diag7-[a-f0-9]{32}$' -or [IO.Path]::GetFileName($Path) -cne "invocation-envelope.json" -or $Digest -cnotmatch '^[a-f0-9]{64}$'){throw "Entry reference rejected."}
  $nonce=$name.Substring(6)
  $json=Read-RecoveryEntryJson $Path $directory $nonce
  $e=$json | ConvertFrom-Json
  if(@($e.PSObject.Properties).Count -ne $script:RecoveryEnvelopeKeys.Count -or
    @($e.PSObject.Properties.Name | Where-Object {$_ -cnotin $script:RecoveryEnvelopeKeys}).Count){throw "Envelope exact schema rejected."}
  foreach($key in $script:RecoveryEnvelopeKeys){if($e.$key -isnot [string]){throw "Envelope type rejected."}}
  if($json -cne (Get-RecoveryEntryCanonical $e $script:RecoveryEnvelopeKeys) -or
    $e.schemaVersion -cne "rise-pals-recovery-invocation-v1" -or $e.envelopeDigest -cne $Digest -or
    $Digest -cne (Get-RecoveryEntryDigest $e $script:RecoveryEnvelopeKeys "envelopeDigest") -or
    $e.invocationNonce -cne $nonce -or $e.evidenceDirectory -cne $directory -or
    $e.authorizationId -cnotmatch '^RP-TURN-019-R4-(RECOVERY|LIVE)-[A-F0-9]{8}$' -or
    $e.repositoryHead -cnotmatch '^[a-f0-9]{40}$' -or $e.executionMode -cnotin @("Simulation","Recovery") -or
    $e.scenario -cnotin $script:RecoveryEntryScenarios){throw "Envelope binding rejected."}
  foreach($key in @("parentScriptSha256","bootstrapScriptSha256","entryAdapterScriptSha256","childScriptSha256","contractScriptSha256","liveScriptSha256","requestDigest")){
    if($e.$key -cnotmatch '^[a-f0-9]{64}$'){throw "Envelope hash type rejected."}
  }
  if($ReferenceOnly){return $e}
  foreach($pair in @(@("parentScriptSha256","Invoke-RisePalsRecoveryDiagnostic.ps1"),@("bootstrapScriptSha256","Invoke-RisePalsRecoveryChildBootstrap.ps1"),
    @("entryAdapterScriptSha256","Invoke-RisePalsRecoveryChildEntry.ps1"),@("contractScriptSha256","recovery-diagnostic-contract.ps1"),@("liveScriptSha256","Invoke-RisePalsCandidateLiveSequence.ps1"))){
    if((Get-RecoveryEntryHash -Path (Join-Path $PSScriptRoot $pair[1])) -cne $e.($pair[0])){throw "Envelope source provenance rejected."}
  }
  $childPath=Get-RecoveryEntryChildPath $e
  if((Get-RecoveryEntryHash -Path $childPath) -cne $e.childScriptSha256){throw "Envelope child provenance rejected."}
  if($e.scenario.StartsWith("Fixture",[StringComparison]::Ordinal) -and
    $e.childScriptSha256 -cne (Get-RecoveryEntryHash -Bytes ([Text.UTF8Encoding]::new($false).GetBytes((Get-RecoveryEntryFixture $e.scenario))))){throw "Closed fixture rejected."}
  $request=ConvertFrom-RisePalsRecoveryJson (Read-RecoveryEntryJson (Join-Path $directory "request-00.json") $directory $nonce)
  $request=Read-RisePalsRecoveryRecord (Join-Path $directory "request-00.json") $directory $request $null
  foreach($key in @("authorizationId","invocationNonce","repositoryHead","executionMode","parentScriptSha256","contractScriptSha256","liveScriptSha256")){
    if($request.$key -cne $e.$key){throw "Envelope request binding rejected."}
  }
  if($request.recordDigest -cne $e.requestDigest -or
    (-not $e.scenario.StartsWith("Fixture",[StringComparison]::Ordinal) -and $request.childScriptSha256 -cne $e.childScriptSha256)){throw "Envelope request digest rejected."}
  return $e
}
function Write-RecoveryInvocationEnvelope {
  param([object]$Envelope)
  $path=Join-Path $Envelope.evidenceDirectory "invocation-envelope.json"
  Write-RecoveryEntryAtomic $path $Envelope.evidenceDirectory $Envelope.invocationNonce (Get-RecoveryEntryCanonical $Envelope $script:RecoveryEnvelopeKeys)
  return $path
}
function Read-RecoveryChildEntryRecord {
  param([string]$Path,[object]$Envelope,[AllowNull()][object]$Previous)
  $json=Read-RecoveryEntryJson $Path $Envelope.evidenceDirectory $Envelope.invocationNonce
  $r=$json | ConvertFrom-Json
  if(@($r.PSObject.Properties).Count -ne $script:RecoveryEntryKeys.Count -or
    @($r.PSObject.Properties.Name | Where-Object {$_ -cnotin $script:RecoveryEntryKeys}).Count -or
    $json -cne (Get-RecoveryEntryCanonical $r $script:RecoveryEntryKeys)){throw "Entry exact record rejected."}
  foreach($key in @("authorizationId","invocationNonce","repositoryHead","executionMode","envelopeDigest","entryAdapterScriptSha256","requestDigest")){
    if($r.$key -isnot [string] -or $r.$key -cne $Envelope.$key){throw "Entry record binding rejected."}
  }
  if($r.schemaVersion -cne "rise-pals-recovery-entry-v1" -or $r.stage -cnotin $script:RecoveryEntryStages -or
    $r.category -cnotin $script:RecoveryEntryCategories -or $r.failedPredicate -cnotin $script:RecoveryEntryPredicates -or
    $r.stageCompleted -isnot [bool] -or $r.sequence -isnot [int] -or $r.sequence -lt 0 -or $r.sequence -gt 25 -or
    ($r.stageCompleted -and ($r.category -cne "none" -or $r.failedPredicate -cne "none")) -or
    (-not $r.stageCompleted -and ($r.category -ceq "none" -or $r.failedPredicate -ceq "none"))){throw "Entry state rejected."}
  foreach($key in @("stage","category","failedPredicate")){if($r.$key -isnot [string]){throw "Entry enum type rejected."}}
  foreach($key in @("hResult","nativeErrorCode","childExitCode")){
    if($null -ne $r.$key -and ($r.$key -isnot [int] -and $r.$key -isnot [long])){throw "Entry numeric evidence rejected."}
  }
  if($null -ne $r.childExitCode -and ($r.childExitCode -lt 0 -or $r.childExitCode -gt 255)){throw "Entry exit rejected."}
  if($null -ne $r.errorId -and $r.errorId -cnotin @("NamedParameterNotFound","ParameterArgumentValidationError")){throw "Entry error ID rejected."}
  if($null -ne $r.exceptionType -and $r.exceptionType -cnotin @("System.Management.Automation.ParameterBindingException",
    "System.Management.Automation.ParameterBindingValidationException","System.Management.Automation.RuntimeException","System.InvalidOperationException")){throw "Entry exception type rejected."}
  foreach($key in @("previousDigest","childMarkerDigest","childResultDigest")){
    if($null -ne $r.$key -and ($r.$key -isnot [string] -or $r.$key -cnotmatch '^[a-f0-9]{64}$')){throw "Entry digest type rejected."}
  }
  $instant=[DateTimeOffset]::MinValue
  if($r.recordedAtUtc -isnot [string] -or -not [DateTimeOffset]::TryParseExact($r.recordedAtUtc,"o",[Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::None,[ref]$instant) -or $instant.Offset -ne [TimeSpan]::Zero -or
    ([DateTimeOffset]::UtcNow-$instant).TotalSeconds -gt 300 -or ($instant-[DateTimeOffset]::UtcNow).TotalSeconds -gt 30){throw "Entry time rejected."}
  if($null -eq $Previous){if($r.sequence -ne 0 -or $r.stage -cne "entry-adapter-process-entry" -or $null -ne $r.previousDigest){throw "Entry first record rejected."}}
  else{
    $failureFinal= -not $Previous.stageCompleted -and $r.stage -ceq "entry-result-written" -and $r.stageCompleted
    $invocationFailure= $Previous.stage -ceq "child-invocation-attempted" -and $Previous.stageCompleted -and
      $r.stage -ceq $Previous.stage -and -not $r.stageCompleted
    if($r.sequence -ne $Previous.sequence+1 -or $r.previousDigest -cne $Previous.recordDigest -or
      $instant -lt [DateTimeOffset]::Parse($Previous.recordedAtUtc) -or
      (-not $failureFinal -and -not $invocationFailure -and (-not $Previous.stageCompleted -or
        [array]::IndexOf($script:RecoveryEntryStages,$r.stage) -ne [array]::IndexOf($script:RecoveryEntryStages,$Previous.stage)+1))){throw "Entry sequence rejected."}
  }
  if([IO.Path]::GetFileName($Path) -cne ("entry-{0:D2}.json" -f $r.sequence) -or
    $r.recordDigest -cnotmatch '^[a-f0-9]{64}$' -or $r.recordDigest -cne (Get-RecoveryEntryDigest $r $script:RecoveryEntryKeys "recordDigest")){throw "Entry digest rejected."}
  return $r
}
function Write-RecoveryChildEntryRecord {
  param([object]$Envelope,[string]$Stage,[AllowNull()][object]$Previous,[string]$Category="none",[string]$Predicate="none",
    [AllowNull()][object]$ChildCode,[AllowNull()][object]$MarkerDigest,[AllowNull()][object]$ResultDigest,
    [AllowNull()][object]$ErrorId,[AllowNull()][object]$ExceptionType,[AllowNull()][object]$HResult)
  $r=[ordered]@{schemaVersion="rise-pals-recovery-entry-v1";authorizationId=$Envelope.authorizationId;invocationNonce=$Envelope.invocationNonce
    repositoryHead=$Envelope.repositoryHead;executionMode=$Envelope.executionMode;envelopeDigest=$Envelope.envelopeDigest
    entryAdapterScriptSha256=$Envelope.entryAdapterScriptSha256;requestDigest=$Envelope.requestDigest
    sequence=$(if($null -eq $Previous){0}else{[int]$Previous.sequence+1});previousDigest=$(if($null -eq $Previous){$null}else{$Previous.recordDigest})
    stage=$Stage;stageCompleted=($Category -ceq "none");category=$Category;failedPredicate=$Predicate
    errorId=$ErrorId;exceptionType=$ExceptionType;hResult=$HResult;nativeErrorCode=$null;childExitCode=$ChildCode
    childMarkerDigest=$MarkerDigest;childResultDigest=$ResultDigest;recordedAtUtc=[DateTimeOffset]::UtcNow.ToString("o");recordDigest=""}
  $r.recordDigest=Get-RecoveryEntryDigest ([pscustomobject]$r) $script:RecoveryEntryKeys "recordDigest"
  $path=Join-Path $Envelope.evidenceDirectory ("entry-{0:D2}.json" -f $r.sequence)
  Write-RecoveryEntryAtomic $path $Envelope.evidenceDirectory $Envelope.invocationNonce (Get-RecoveryEntryCanonical ([pscustomobject]$r) $script:RecoveryEntryKeys)
  return $path
}
if($ContractOnly){return}
if($PSVersionTable.PSEdition -cne "Desktop" -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){exit 84}
try{
  # Only the exact, digest-authenticated reference is inspected before the first
  # record. Full request freshness and source validation follow its reopening.
  $entryEnvelope=Read-RecoveryInvocationEnvelope $EnvelopePath $EnvelopeDigest -ReferenceOnly
  if((Get-RecoveryEntryHash -Path $PSCommandPath) -cne $entryEnvelope.entryAdapterScriptSha256){exit 84}
  if($entryEnvelope.executionMode -ceq "Simulation" -and
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){exit 84}
}catch{exit 84}
if(-not $PSCmdlet.ShouldProcess("validated recovery invocation envelope", "Write entry evidence and invoke recovery child")){
  return
}
if($entryEnvelope.scenario -ceq "FixtureBeforeEntry"){exit 85}
$script:entryLast=$null;$entryStage="entry-adapter-process-entry";$entryCategory="entry-marker-persistence-failure";$entryPredicate="marker-write"
$entryCode=$null;$entryMarker=$null;$entryChildResult=$null;$entrySuccess=$false;$entryExceptionType=$null;$entryErrorId=$null;$entryHResult=$null
function Add-RecoveryEntryStage {
  param([string]$Stage,[string]$Category="none",[string]$Predicate="none")
  $path=Write-RecoveryChildEntryRecord $entryEnvelope $Stage $script:entryLast -Category $Category -Predicate $Predicate `
    -ChildCode $entryCode -MarkerDigest $entryMarker -ResultDigest $entryChildResult -ErrorId $entryErrorId -ExceptionType $entryExceptionType -HResult $entryHResult
  $script:entryLast=Read-RecoveryChildEntryRecord $path $entryEnvelope $script:entryLast
}
try{
  Add-RecoveryEntryStage $entryStage
  $entryStage="minimal-arguments-validated";Add-RecoveryEntryStage $entryStage
  $entryStage="entry-marker-write-attempted";Add-RecoveryEntryStage $entryStage
  $entryStage="entry-marker-written"
  if($entryEnvelope.scenario -ceq "FixtureMarkerPersistence"){throw "Synthetic marker persistence failure."}
  Add-RecoveryEntryStage $entryStage
  $entryStage="entry-marker-reopened";$entryCategory="entry-marker-reopen-failure";$entryPredicate="marker-reopen"
  if($entryEnvelope.scenario -ceq "FixtureMarkerReopen"){throw "Synthetic marker reopen failure."}
  Add-RecoveryEntryStage $entryStage
  $entryStage="envelope-read-attempted";Add-RecoveryEntryStage $entryStage
  $entryStage="envelope-validated";$entryCategory="invocation-envelope-invalid";$entryPredicate="envelope-valid"
  # Import only after the independent first marker has been persisted/reopened.
  if((Get-RecoveryEntryHash -Path (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1")) -cne $entryEnvelope.contractScriptSha256){throw "Contract source mismatch."}
  . (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1")
  $entryEnvelope=Read-RecoveryInvocationEnvelope $EnvelopePath $EnvelopeDigest
  Add-RecoveryEntryStage $entryStage
  $entryStage="child-source-parse-attempted";Add-RecoveryEntryStage $entryStage
  $entryStage="child-source-parse-complete";$entryCategory="child-source-parse-failure";$entryPredicate="ast-no-errors"
  $source=Get-RecoveryEntryChildPath $entryEnvelope;$tokens=$null;$parseErrors=$null
  [void][Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
  if($parseErrors.Count){throw "Child parse rejected."}
  Add-RecoveryEntryStage $entryStage
  $entryStage="child-invocation-attempted";$entryCategory="child-invocation-failure";$entryPredicate="splat-invocation-returned"
  Add-RecoveryEntryStage $entryStage
  $parameters=@{ExecutionMode=$entryEnvelope.executionMode;AuthorizationId=$entryEnvelope.authorizationId
    InvocationNonce=$entryEnvelope.invocationNonce;RepositoryHead=$entryEnvelope.repositoryHead
    ParentScriptSha256=$entryEnvelope.parentScriptSha256;ChildScriptSha256=$entryEnvelope.childScriptSha256
    LiveScriptSha256=$entryEnvelope.liveScriptSha256;ContractScriptSha256=$entryEnvelope.contractScriptSha256
    RequestDigest=$entryEnvelope.requestDigest;EvidenceDirectory=$entryEnvelope.evidenceDirectory
    Scenario=$entryEnvelope.scenario;Confirm=$false}
  try{& $source @parameters *> $null;$entryCode=$LASTEXITCODE}
  catch{
    $type=$_.Exception.GetType().FullName
    if($type -cin @("System.Management.Automation.ParameterBindingException","System.Management.Automation.ParameterBindingValidationException")){
      $entryCategory="child-parameter-binding-failure";$entryExceptionType=$type;$entryHResult=$_.Exception.HResult
      if($_.FullyQualifiedErrorId -cin @("NamedParameterNotFound,Invoke-RisePalsRecoveryChild.ps1","NamedParameterNotFound,child-fixture.ps1")){$entryErrorId="NamedParameterNotFound"}
    }elseif($type -cin @("System.Management.Automation.RuntimeException","System.InvalidOperationException")){$entryExceptionType=$type;$entryHResult=$_.Exception.HResult}
    else{$entryCategory="controlled-unclassified-failure"}
    throw "Child invocation failed with closed provenance."
  }
  $entryStage="child-entry-marker-observed";$entryCategory="child-entry-marker-missing";$entryPredicate="child-marker-present"
  $markerPath=Join-Path $entryEnvelope.evidenceDirectory "child-00.json"
  if(-not [IO.File]::Exists($markerPath)){throw "Child marker absent."}
  $entryCategory="child-entry-marker-invalid";$entryPredicate="child-marker-valid"
  $request=ConvertFrom-RisePalsRecoveryJson (Read-RecoveryEntryJson (Join-Path $entryEnvelope.evidenceDirectory "request-00.json") $entryEnvelope.evidenceDirectory $entryEnvelope.invocationNonce)
  $request=Read-RisePalsRecoveryRecord (Join-Path $entryEnvelope.evidenceDirectory "request-00.json") $entryEnvelope.evidenceDirectory $request $null
  $child=Read-RisePalsRecoveryRecord $markerPath $entryEnvelope.evidenceDirectory $request $null
  $entryMarker=$child.recordDigest;Add-RecoveryEntryStage $entryStage
  $entryStage="entry-result-written";$entryCategory="child-invocation-failure";$entryPredicate="child-result-success"
  foreach($number in 1..3){$child=Read-RisePalsRecoveryRecord (Join-Path $entryEnvelope.evidenceDirectory ("child-{0:D2}.json" -f $number)) $entryEnvelope.evidenceDirectory $request $child}
  $entryChildResult=$child.recordDigest
  if($entryCode -ne 0 -or $child.exitCode -ne 0 -or $child.category -cne "child-success" -or -not $child.cleanupCompleted){throw "Child result not successful."}
  $entrySuccess=$true
}catch{
  if($null -ne $script:entryLast){Add-RecoveryEntryStage $entryStage $entryCategory $entryPredicate}
}
try{
  if($entryEnvelope.scenario -ceq "FixtureResultPersistence"){Add-RecoveryEntryStage "entry-result-written" "entry-result-persistence-failure" "result-write";exit 87}
  if($script:entryLast.stage -cne "entry-result-written"){Add-RecoveryEntryStage "entry-result-written"}
  if($entryEnvelope.scenario -ceq "FixtureResultReopen"){Add-RecoveryEntryStage "entry-result-reopened" "entry-result-reopen-failure" "result-reopen";exit 87}
  if(-not $script:entryLast.stageCompleted){exit 86}
  Add-RecoveryEntryStage "entry-result-reopened"
}catch{exit 87}
if($entrySuccess){exit 0};exit 86
