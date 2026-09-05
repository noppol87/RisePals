[CmdletBinding()]
param([ValidateSet("Schema","Simulations","HarnessSemantics","ShouldProcess","DeclineWorker")][string]$Mode="Schema",
  [string]$FixtureDirectory="", [string]$FixtureNonce="")
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
if ($PSVersionTable.PSEdition -cne "Desktop" -or $PSVersionTable.PSVersion.Major -ne 5 -or
  $PSVersionTable.PSVersion.Minor -ne 1 -or
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {throw "Non-elevated PS5.1 fixture required."}
. (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1")
. (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildBootstrap.ps1") -ContractOnly
. (Join-Path $PSScriptRoot "recovery-decline-fixture-receipt.ps1")

if ($Mode -ceq "DeclineWorker") {
  $root=Assert-RecoveryBootDirectory $FixtureDirectory $FixtureNonce
  $requestPath=Join-Path $root "request-00.json"
  $before=Get-RecoveryBootHash -Path $requestPath
  $receipt=[pscustomobject][ordered]@{schemaVersion="rise-pals-decline-fixture-v1";scenario="Declined";powerShellVersion="5.1"
    runspaceCreated=$false;runspaceOpened=$false;pipelineCreated=$false;pipelineInvoked=$false;pipelineCompleted=$false
    confirmationCallbackReached=$false;confirmationCallbackCount=0;selectedChoice="not-reached";pipelineHadErrors=$false
    pipelineErrorCategory="none";workerExitCode=91;requestHashBefore=$before;requestHashAfter=$before;requestUnchanged=$true
    childProcessCreated=$false;bootstrapEvidenceCount=0;temporaryEvidenceCount=0;cleanupCompleted=$false;finalResidueCount=0;receiptDigest=""}
  $runspace=$null;$pipeline=$null;$hostFixture=$null;$category="host-compilation"
  try {
  # A separate PS5.1 process hosts the real cmdlet in a test-only runspace whose
  # confirmation UI explicitly chooses No. There is no interactive input/retry.
  Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Security;
public sealed class RecoveryDeclineHost : PSHost, IDisposable {
  private readonly RecoveryDeclineUI ui;
  private readonly PSHost parent;
  private readonly Guid id = Guid.NewGuid();
  public RecoveryDeclineHost(PSHost parent) { this.parent=parent; ui=new RecoveryDeclineUI(parent.UI); }
  public override Guid InstanceId { get { return id; } }
  public override string Name { get { return "RecoveryDeclineFixture"; } }
  public override Version Version { get { return new Version(1,0); } }
  public override CultureInfo CurrentCulture { get { return parent.CurrentCulture; } }
  public override CultureInfo CurrentUICulture { get { return parent.CurrentUICulture; } }
  public override PSHostUserInterface UI { get { return ui; } }
  public int Declines { get { return ui.Declines; } }
  public void Dispose() { }
  public override void SetShouldExit(int exitCode) { throw new InvalidOperationException(); }
  public override void EnterNestedPrompt() { throw new InvalidOperationException(); }
  public override void ExitNestedPrompt() { throw new InvalidOperationException(); }
  public override void NotifyBeginApplication() { throw new InvalidOperationException(); }
  public override void NotifyEndApplication() { throw new InvalidOperationException(); }
}
public sealed class RecoveryDeclineUI : PSHostUserInterface {
  private readonly PSHostUserInterface parent;
  public RecoveryDeclineUI(PSHostUserInterface parent) { this.parent=parent; }
  public int Declines;
  public override PSHostRawUserInterface RawUI { get { return parent.RawUI; } }
  public override int PromptForChoice(string caption, string message, Collection<ChoiceDescription> choices, int defaultChoice) {
    for (int i=0;i<choices.Count;i++) {
      if (choices[i].Label.Replace("&", "") == "No") { Declines++; return i; }
    }
    throw new InvalidOperationException();
  }
  public override Dictionary<string,PSObject> Prompt(string c,string m,Collection<FieldDescription> d) { throw new InvalidOperationException(); }
  public override PSCredential PromptForCredential(string c,string m,string u,string t) { throw new InvalidOperationException(); }
  public override PSCredential PromptForCredential(string c,string m,string u,string t,PSCredentialTypes a,PSCredentialUIOptions b) { throw new InvalidOperationException(); }
  public override string ReadLine() { throw new InvalidOperationException(); }
  public override SecureString ReadLineAsSecureString() { throw new InvalidOperationException(); }
  public override void Write(string v) { }
  public override void Write(ConsoleColor f,ConsoleColor b,string v) { }
  public override void WriteLine(string v) { }
  public override void WriteLine() { }
  public override void WriteLine(ConsoleColor f,ConsoleColor b,string v) { }
  public override void WriteErrorLine(string v) { throw new InvalidOperationException(); }
  public override void WriteDebugLine(string v) { }
  public override void WriteProgress(long s,ProgressRecord r) { }
  public override void WriteVerboseLine(string v) { }
  public override void WriteWarningLine(string v) { }
}
'@
  $root=Assert-RecoveryBootDirectory $FixtureDirectory $FixtureNonce
  $json=Read-RecoveryBootJsonFile (Join-Path $root "request-00.json") $root $FixtureNonce
  $binding=$json | ConvertFrom-Json
  $request=Read-RisePalsRecoveryRecord (Join-Path $root "request-00.json") $root $binding $null
  $hostFixture=[RecoveryDeclineHost]::new($Host)
  $category="runspace-create"
  # Use an explicit initial session state rather than the legacy host-only
  # factory overload whose runspace open fails in this PS5.1 fixture.
  $initialState=[System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
  $runspace=[System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($hostFixture,$initialState)
  $receipt.runspaceCreated=$true
  $category="pipeline-create"
  $pipeline=[PowerShell]::Create()
  $receipt.pipelineCreated=$true
    $category="runspace-open";$runspace.Open();$receipt.runspaceOpened=$true; $pipeline.Runspace=$runspace
    $bootstrap=Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildBootstrap.ps1"
    [void]$pipeline.AddCommand($bootstrap).AddParameter("BootDirectory",$root).AddParameter("BootNonce",$FixtureNonce).
      AddParameter("BootAuthorization",$request.authorizationId).AddParameter("BootHead",$request.repositoryHead).
      AddParameter("BootRequestDigest",$request.recordDigest).AddParameter("BootScriptHash",(Get-RecoveryBootHash -Path $bootstrap)).
      AddParameter("BootScenario","Success").AddParameter("Confirm",$true)
    $category="pipeline-invoke";$receipt.pipelineInvoked=$true;[void]$pipeline.Invoke();$receipt.pipelineCompleted=$true
    $receipt.pipelineHadErrors=$pipeline.HadErrors
    if($pipeline.HadErrors){$category="pipeline-error";throw "Controlled pipeline failure."}
    if($hostFixture.Declines -ne 1){$category="confirmation-not-declined";throw "Controlled confirmation failure."}
    $receipt.workerExitCode=0
  } catch {
    if($category -ceq "runspace-create" -and $_.FullyQualifiedErrorId -ceq "TypeNotFound"){$category="runspace-type-unresolved"}
    if($category -ceq "runspace-open"){
      # Classify only in memory; never persist exception text or type names.
      if($_.FullyQualifiedErrorId -match 'MethodNotFound|PropertyNotFound'){$category="runspace-open-member"}
      $exception=$_.Exception
      for($depth=0;$null -ne $exception -and $depth -lt 6;$depth++){
        if($exception.GetType().Name -ceq "PSSnapInException"){$category="runspace-snapin-load"}
        elseif($exception -is [NullReferenceException]){$category="runspace-host-null"}
        elseif($exception.Message -match 'module.*(load|import)|(load|import).*module'){$category="runspace-module-load"}
        elseif($exception.StackTrace -match 'RecoveryDecline(Host|UI)'){$category="runspace-host-callback"}
        elseif($exception.Message -match 'not supported|does not support|not implemented'){$category="runspace-open-unsupported"}
        elseif($exception.Message -match 'execution.?policy|authorization|signature|access.*denied'){$category="runspace-open-authorization"}
        elseif($exception.Message -match 'assembly|file.*load|registry'){$category="runspace-open-assembly"}
        elseif($exception.Message -match 'thread|apartment'){$category="runspace-open-thread"}
        elseif($exception.Message -match 'already|state'){$category="runspace-open-state"}
        elseif($exception -is [ArgumentException]){$category="runspace-open-argument"}
        elseif($exception.GetType().Name -ceq "RuntimeException"){$category="runspace-open-runtime"}
        $exception=$exception.InnerException
      }
      if($category -ceq "runspace-open-unsupported"){
        $trace=$_.Exception.ToString()
        if($trace -match 'RunspaceConfiguration'){$category="runspace-open-unsupported-legacy"}
        elseif($trace -match 'RemoteRunspace'){$category="runspace-open-unsupported-remote"}
        elseif($trace -match 'RawUI|RawUserInterface'){$category="runspace-open-unsupported-rawui"}
        elseif($trace -match 'CallStack|CallDepth|GetFrame'){$category="runspace-open-unsupported-callstack"}
        elseif($trace -match 'InitialSessionState|SessionState|Configuration'){$category="runspace-open-unsupported-configuration"}
        $trace=$null
      }
      $exception=$null
    }
    $receipt.pipelineErrorCategory=$category
  } finally {
    if($null -ne $hostFixture){$receipt.confirmationCallbackCount=$hostFixture.Declines}
    $receipt.confirmationCallbackReached=$receipt.confirmationCallbackCount -gt 0
    if($receipt.confirmationCallbackReached){$receipt.selectedChoice="No"}
    try {
      if($null -ne $pipeline){$pipeline.Dispose()}
      if($null -ne $runspace){$runspace.Dispose()}
      if($null -ne $hostFixture){$hostFixture.Dispose()}
      $receipt.cleanupCompleted=$true
    } catch {$receipt.pipelineErrorCategory="disposal";$receipt.workerExitCode=91}
  }
  $receipt.requestHashAfter=Get-RecoveryBootHash -Path $requestPath
  $receipt.requestUnchanged=$receipt.requestHashAfter -ceq $before
  $objects=@(Get-ChildItem -LiteralPath $root -Force)
  $receipt.bootstrapEvidenceCount=@($objects|Where-Object Name -match '^(bootstrap|child|entry)-').Count
  $receipt.temporaryEvidenceCount=@($objects|Where-Object Name -like '*.tmp').Count
  $receipt.finalResidueCount=@($objects|Where-Object Name -cne 'request-00.json').Count
  # Any dispatch is preceded by a bootstrap marker; no marker plus the exact
  # validated No callback is required before claiming no child was dispatched.
  $receipt.childProcessCreated=$receipt.bootstrapEvidenceCount -gt 0
  if(-not $receipt.requestUnchanged){$receipt.pipelineErrorCategory="request-changed";$receipt.workerExitCode=91}
  if($receipt.finalResidueCount -ne 0){$receipt.pipelineErrorCategory="unexpected-evidence";$receipt.workerExitCode=91}
  Write-DeclineReceipt $receipt $root $FixtureNonce
  [void](Read-DeclineReceipt $root $FixtureNonce $before)
  exit $receipt.workerExitCode
}

function Invoke-RecoveryFixtureProcess {
  param([string[]]$Arguments,[switch]$Mixed)
  $info=[Diagnostics.ProcessStartInfo]::new()
  $info.FileName=Join-Path $PSHOME "powershell.exe"
  $info.Arguments=$Arguments -join " "
  $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
  # Deliberately incompatible first entry; no global/user/profile change.
  if ($Mixed) {$info.EnvironmentVariables["PSModulePath"]="C:\Program Files\PowerShell\7\Modules;"+$info.EnvironmentVariables["PSModulePath"]}
  $process=[Diagnostics.Process]::new();$process.StartInfo=$info
  try {
    if (-not $process.Start()) {throw "Synthetic process creation failed."}
    $script:fixtureExitProven=$false
    if (-not $process.WaitForExit(60000)) {throw "Synthetic process exit unproven; no termination permitted."}
    $script:fixtureExitProven=$true
    return [int]$process.ExitCode
  } finally {$process.Dispose()}
}
function Remove-RecoveryBootstrapFixture {
  param([string]$Directory,[string]$Nonce)
  $root=Assert-RecoveryBootDirectory $Directory $Nonce
  $items=@(Get-ChildItem -LiteralPath $root -Force)
  foreach($item in $items){
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
      $item.Name -cnotmatch '^((request|bootstrap|child)-[0-9]{2}\.json|decline-receipt\.json)(\.tmp)?$' -or
      [IO.Path]::GetDirectoryName($item.FullName) -cne $root) {throw "Synthetic exact cleanup rejected."}
  }
  foreach($item in $items){Remove-Item -LiteralPath $item.FullName -Force}
  Remove-Item -LiteralPath $root -Force
  if (Test-Path -LiteralPath $root) {throw "Synthetic residue rejected."}
}
if($Mode -ceq "HarnessSemantics"){
  $harness=Join-Path $PSScriptRoot "Test-RisePalsRecoveryDiagnosticContract.ps1"
  foreach($case in @("SubjectFailure","InvalidReceipt")){
    $exitCode=Invoke-RecoveryFixtureProcess @("-NoLogo","-NoProfile","-NonInteractive","-File",('"'+$harness+'"'),"-DiagnosticMode",$case)
    $expected=if($case -ceq "SubjectFailure"){0}else{94}
    if($exitCode -ne $expected){throw ("Diagnostic result semantics failed: "+$case)}
    Write-Output ("Diagnostic wrapper semantics PASS: "+$case+"; exit="+$exitCode)
  }
  exit 0
}
$cases=if($Mode -ceq "ShouldProcess"){@("Success","WhatIf","WhatIfSyntheticChild","Declined")}
  elseif($Mode -ceq "Schema"){@("Valid","Missing","Duplicate","Unknown","Type","Stage","Category","Digest")}
  else {@("Success","Arguments","Provenance","MarkerPersistence","MarkerReopen","BeforeMarker","ChildCreation",
    "ChildBeforeMarker","ChildMarkerTamper","ChildFailure","ResultPersistence","ResultReopen","MixedModules",
    "WrongHead","WrongBootstrapHash")}
$passed=0
foreach($case in $cases){
  $script:fixtureExitProven=$true
  $nonce=[guid]::NewGuid().ToString("N")
  $directory=Join-Path ([IO.Path]::GetTempPath()) ("diag7-"+$nonce)
  if(Test-Path -LiteralPath $directory){throw "Synthetic collision rejected."}
  [void][IO.Directory]::CreateDirectory($directory)
  try {
    $bootstrap=Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildBootstrap.ps1"
    $hash=Get-RecoveryBootHash -Path $bootstrap
    $binding=[pscustomobject]@{executionMode="Simulation";authorizationId="RP-TURN-019-R4-RECOVERY-00000000"
      invocationNonce=$nonce;repositoryHead="c6a2d359d2d8670c40fddadcaee2d0da521a4d12"
      parentScriptSha256=(Get-RecoveryBootHash -Path (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryDiagnostic.ps1"))
      childScriptSha256=(Get-RecoveryBootHash -Path (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChild.ps1"))
      contractScriptSha256=(Get-RecoveryBootHash -Path (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1"))
      liveScriptSha256=(Get-RecoveryBootHash -Path (Join-Path $PSScriptRoot "Invoke-RisePalsCandidateLiveSequence.ps1"))}
    $request=New-RisePalsRecoveryRecord $binding request request-created $null
    $path=Write-RisePalsRecoveryRecord $request $directory
    $request=Read-RisePalsRecoveryRecord $path $directory $binding $null
    if($Mode -ceq "Schema"){
      $path=Write-RecoveryBootRecord $request $hash "Success" $directory "bootstrap-entry" $null
      $record=Read-RecoveryBootRecord $path $directory $request $hash "Success" $null
      if($case -cne "Valid"){
        switch($case){
          "Missing" {$record.PSObject.Properties.Remove("childExitCode")}
          "Unknown" {$record | Add-Member NoteProperty unknown $true}
          "Type" {$record.childProcessCreated="false"}
          "Stage" {$record.stage="unknown"}
          "Category" {$record.category="unknown"}
          "Digest" {$record.recordDigest="f"*64}
        }
        $json=$record | ConvertTo-Json -Depth 4 -Compress
        if($case -ceq "Duplicate"){$json=$json.Replace('"stage":"bootstrap-entry"','"stage":"bootstrap-entry","stage":"bootstrap-entry"')}
        [IO.File]::WriteAllText($path,$json,[Text.UTF8Encoding]::new($false))
        $rejected=$false
        try{[void](Read-RecoveryBootRecord $path $directory $request $hash "Success" $null)}catch{$rejected=$true}
        if(-not $rejected){throw ("Bootstrap schema accepted "+$case)}
      }
    } else {
      $scenario=if($case -cin @("WrongHead","WrongBootstrapHash","WhatIf","WhatIfSyntheticChild","Declined")){"Success"}else{$case}
      $head=if($case -ceq "WrongHead"){"b"*40}else{$request.repositoryHead}
      $passedHash=if($case -ceq "WrongBootstrapHash"){"f"*64}else{$hash}
      $arguments=@("-NoLogo","-NoProfile","-NonInteractive","-File",('"'+$bootstrap+'"'),
        "-BootDirectory",('"'+$directory+'"'),"-BootNonce",$nonce,"-BootAuthorization",$request.authorizationId,
        "-BootHead",$head,"-BootRequestDigest",$request.recordDigest,"-BootScriptHash",$passedHash,"-BootScenario",$scenario)
      if($case -cin @("WhatIf","WhatIfSyntheticChild")){$arguments+=@("-WhatIf")}
      if($case -ceq "WhatIfSyntheticChild"){$arguments+=@("-SyntheticChild")}
      if($case -ceq "Declined"){
        $arguments=@("-NoLogo","-NoProfile","-NonInteractive","-File",('"'+$PSCommandPath+'"'),
          "-Mode","DeclineWorker","-FixtureDirectory",('"'+$directory+'"'),"-FixtureNonce",$nonce)
      }
      $beforeDigest=Get-RecoveryBootHash -Path (Join-Path $directory "request-00.json")
      $exitCode=Invoke-RecoveryFixtureProcess $arguments -Mixed:($case -ceq "MixedModules")
      if($case -ceq "Declined"){
        $receipt=Read-DeclineReceipt $directory $nonce $beforeDigest
        Write-Output ("Decline receipt validated: "+(Get-DeclineReceiptJson $receipt))
        if($exitCode -ne $receipt.workerExitCode){throw "Decline receipt/process exit disagreement."}
        Remove-Item -LiteralPath (Join-Path $directory "decline-receipt.json") -Force
        if($exitCode -ne 0){throw ("Decline controlled failure: "+$receipt.pipelineErrorCategory)}
      }
      if($case -cin @("WhatIf","WhatIfSyntheticChild","Declined")){
        $objects=@(Get-ChildItem -LiteralPath $directory -Force)
        if($exitCode -ne 0 -or $objects.Count -ne 1 -or $objects[0].Name -cne "request-00.json" -or
          (Get-RecoveryBootHash -Path $objects[0].FullName) -cne $beforeDigest){throw "Dry-run changed evidence or failed."}
        $passed++; Write-Output ("Bootstrap ShouldProcess PASS: "+$case+"; child/evidence creation=0")
        continue
      }
      $expected=switch($case){
        {$_ -cin @("Success","MixedModules")} {0}
        "BeforeMarker" {81}
        {$_ -cin @("WrongHead","WrongBootstrapHash")} {80}
        {$_ -cin @("ResultPersistence","ResultReopen")} {83}
        default {82}
      }
      if($exitCode -ne $expected){throw ("Bootstrap simulation failed: "+$case+"; exit="+$exitCode)}
      $files=@(Get-ChildItem -LiteralPath $directory -File | Where-Object Name -match '^bootstrap-[0-9]{2}\.json$' | Sort-Object Name)
      if($case -cin @("BeforeMarker","WrongHead","WrongBootstrapHash")){
        if($files.Count -ne 0){throw "Rejected bootstrap unexpectedly wrote marker."}
      } else {
        if($files.Count -eq 0){throw "Bootstrap receipt absent."}
        $last=$null;$failures=@()
        foreach($file in $files){
          $last=Read-RecoveryBootRecord $file.FullName $directory $request $hash $scenario $last
          if(-not $last.stageCompleted){$failures+=@($last)}
        }
        $category=switch($case){
          "Arguments" {"bootstrap-arguments-invalid"};"Provenance" {"bootstrap-provenance-invalid"}
          "MarkerPersistence" {"bootstrap-marker-persistence-failure"};"MarkerReopen" {"bootstrap-marker-reopen-failure"}
          "ChildCreation" {"child-script-process-creation-failure"};"ChildBeforeMarker" {"child-script-exit-before-entry-marker"}
          "ChildMarkerTamper" {"child-entry-marker-invalid"};"ChildFailure" {"child-script-failure"}
          "ResultPersistence" {"bootstrap-result-persistence-failure"};"ResultReopen" {"bootstrap-result-reopen-failure"}
          default {"none"}
        }
        if($category -ceq "none"){
          if($failures.Count -ne 0 -or $last.stage -cne "bootstrap-result-reopened" -or
            -not $last.childProcessCreated -or $last.childExitCode -ne 0 -or -not $last.childMarkerPresent -or
            $null -eq $last.childResultDigest){throw "Bootstrap synthetic success assertion failed."}
        } elseif($failures.Count -ne 1 -or $failures[0].category -cne $category){throw ("Bootstrap category assertion failed: "+$case)}
      }
    }
    $passed++
    Write-Output ("Bootstrap "+$Mode+" PASS: "+$case)
  } finally {
    if ($script:fixtureExitProven) {Remove-RecoveryBootstrapFixture $directory $nonce}
    else {throw "Active synthetic worker boundary unproven; fixture retained without deletion."}
  }
}
Write-Output ("Bootstrap "+$Mode+" PASS "+$passed+"/"+@($cases).Count+"; exact temporary cleanup=PASS; captures=0; elevation=0")
