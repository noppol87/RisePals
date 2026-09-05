[CmdletBinding()]
param([switch]$Worker,[string]$Directory="",[switch]$HistoricalDirty,
  [ValidatePattern('^[a-f0-9]{40}$')][string]$ExpectedRepositoryHead)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
if($PSVersionTable.PSEdition -cne "Desktop" -or $PSVersionTable.PSVersion.Major -ne 5 -or
  $PSVersionTable.PSVersion.Minor -ne 1 -or
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)){throw "Non-elevated PS5.1 diagnostic required."}
if (-not $HistoricalDirty -and -not $Worker) {
  if ($Directory) { throw "Clean simulation chooses its own evidence directory." }
  & (Join-Path $PSScriptRoot "Test-RisePalsElevatedRehearsalLauncher.ps1") `
    -ExpectedRepositoryHead $ExpectedRepositoryHead -NativeSuccessOnly
  return
}
$repository="C:\Codex PC SG2\Jeff\risepals"
$launcher=Join-Path $repository "scripts\infra\Invoke-RisePalsElevatedRehearsal.ps1"
$keys=@("scenario","parentStage","childStage","nativeStage","parentProcessCreated","childProcessCreated",
  "nativeProcessCreated","parentExitCode","childExitCode","nativeExitCode","category","nativeCode","hResult",
  "resultPresent","resultReopened","resultValidated","stdoutBytes","stderrBytes","cleanupAttempted",
  "cleanupCompleted","finalResidueCount","environmentGuardActive","diagnosticDigest")
function Assert-DiagnosticDirectory {
  param([string]$Path)
  $full=[IO.Path]::GetFullPath($Path)
  if($full -cne $Path -or [IO.Path]::GetDirectoryName($full) -cne [IO.Path]::GetTempPath().TrimEnd('\') -or
    [IO.Path]::GetFileName($full) -cnotmatch '^rp19-accel2-native-[a-f0-9]{32}$'){throw "Diagnostic path rejected."}
  $ancestor=$full
  while($ancestor){$i=Get-Item -LiteralPath $ancestor -Force;if(-not $i.PSIsContainer -or
    ($i.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw "Diagnostic ancestry rejected."};$ancestor=[IO.Path]::GetDirectoryName($ancestor)}
  return $full
}
function Get-DiagnosticJson {
  param([object]$Record,[switch]$WithoutDigest)
  $body=[ordered]@{};foreach($key in $keys){if(-not($WithoutDigest -and $key -ceq "diagnosticDigest")){$body[$key]=$Record.$key}}
  return ($body | ConvertTo-Json -Compress -Depth 3)
}
function Get-DiagnosticDigest {
  param([object]$Record)
  $sha=[Security.Cryptography.SHA256]::Create()
  try{return ([BitConverter]::ToString($sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes(
    (Get-DiagnosticJson $Record -WithoutDigest))))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Write-Diagnostic {
  param([object]$Record,[string]$Name)
  if($Name -cnotin @("worker.json","final.json")){throw "Diagnostic filename rejected."}
  $Record.diagnosticDigest=Get-DiagnosticDigest $Record
  $bytes=[Text.UTF8Encoding]::new($false).GetBytes((Get-DiagnosticJson $Record))
  $path=Join-Path $Directory $Name
  $s=[IO.File]::Open($path+".tmp",[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try{$s.Write($bytes,0,$bytes.Length);$s.Flush($true)}finally{$s.Dispose()}
  [IO.File]::Move($path+".tmp",$path)
}
function Read-Diagnostic {
  param([string]$Name)
  if($Name -cnotin @("worker.json","final.json")){throw "Diagnostic filename rejected."}
  [void](Assert-DiagnosticDirectory $Directory)
  $i=Get-Item -LiteralPath (Join-Path $Directory $Name) -Force
  if($i.PSIsContainer -or ($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $i.Length -gt 8192){throw "Diagnostic file rejected."}
  $json=[Text.UTF8Encoding]::new($false,$true).GetString([IO.File]::ReadAllBytes($i.FullName));$r=$json|ConvertFrom-Json
  if(@($r.PSObject.Properties).Count -ne $keys.Count -or @($r.PSObject.Properties.Name|Where-Object {$_ -cnotin $keys}).Count -or
    $json -cne (Get-DiagnosticJson $r) -or $r.diagnosticDigest -cne (Get-DiagnosticDigest $r)){throw "Diagnostic schema/digest rejected."}
  foreach($k in @("parentProcessCreated","childProcessCreated","nativeProcessCreated","resultPresent","resultReopened",
    "resultValidated","cleanupAttempted","cleanupCompleted","environmentGuardActive")){if($r.$k -isnot [bool]){throw "Diagnostic boolean rejected."}}
  foreach($k in @("stdoutBytes","stderrBytes","finalResidueCount")){if($r.$k -isnot [int] -or $r.$k -lt 0){throw "Diagnostic count rejected."}}
  if($r.scenario -cne "NativeSuccess" -or $r.parentStage -cne "repository-precondition-rejected" -or
    $r.childStage -cne "not-reached" -or $r.nativeStage -cne "not-reached" -or
    $r.category -cne "repository-worktree-not-clean" -or $r.parentExitCode -isnot [int] -or $r.parentExitCode -ne 1 -or
    $null -ne $r.childExitCode -or $null -ne $r.nativeExitCode -or $null -ne $r.nativeCode -or $null -ne $r.hResult -or
    -not $r.parentProcessCreated -or $r.childProcessCreated -or $r.nativeProcessCreated -or $r.resultPresent -or
    $r.resultReopened -or $r.resultValidated -or -not $r.cleanupAttempted -or -not $r.cleanupCompleted -or $r.finalResidueCount -ne 0){
    throw "Diagnostic closed state rejected."
  }
  return $r
}
if($Worker){
  [void](Assert-DiagnosticDirectory $Directory)
  $g="C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
  $a=@('-c','safe.directory=C:/Codex PC SG2/Jeff/risepals','-C',$repository)
  $head=(& $g @a rev-parse HEAD).Trim();$branch=(& $g @a branch --show-current).Trim();$dirty=@(& $g @a status --porcelain)
  if($LASTEXITCODE -ne 0 -or $head -cne $ExpectedRepositoryHead -or $branch -cne "agent/windows-vps-infrastructure-readiness" -or
    $dirty.Count -eq 0){throw "This diagnostic requires the bound unfinished candidate; no launch on changed preconditions."}
  $rejected=$false
  try {
    $null=& $launcher -ExpectedRepositoryHead $ExpectedRepositoryHead -Mode Simulation -SimulationScenario NativeSuccess -RepositoryRoot $repository
  } catch {
    # Only the exact repository-owned precondition throw is classified. Neither
    # error text nor invocation/stack metadata is retained in the receipt.
    $rejected=$_.Exception.Message -ceq "The exact clean RP-TURN-019 feature head is required." -and
      $_.InvocationInfo.ScriptName -ceq $launcher
  }
  if(-not $rejected){throw "Native diagnostic boundary is unresolved."}
  $record=[pscustomobject][ordered]@{scenario="NativeSuccess";parentStage="repository-precondition-rejected";childStage="not-reached"
    nativeStage="not-reached";parentProcessCreated=$true;childProcessCreated=$false;nativeProcessCreated=$false;parentExitCode=1
    childExitCode=$null;nativeExitCode=$null;category="repository-worktree-not-clean";nativeCode=$null;hResult=$null
    resultPresent=$false;resultReopened=$false;resultValidated=$false;stdoutBytes=0;stderrBytes=0;cleanupAttempted=$true
    cleanupCompleted=$true;finalResidueCount=0;environmentGuardActive=[bool]($env:NODE_OPTIONS -match '--require=.*guard\.cjs');diagnosticDigest=""}
  Write-Diagnostic $record "worker.json";[void](Read-Diagnostic "worker.json");exit 1
}
if($Directory){throw "Parent diagnostic chooses its own fresh directory."}
$Directory=Join-Path ([IO.Path]::GetTempPath()) ("rp19-accel2-native-"+[guid]::NewGuid().ToString("N"))
if(Test-Path -LiteralPath $Directory){throw "Diagnostic collision rejected."}
[void][IO.Directory]::CreateDirectory($Directory);[void](Assert-DiagnosticDirectory $Directory)
$p=$null;$exited=$false
$outSink=$null;$errSink=$null
try{
  Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Threading;
public sealed class NativeDiagnosticCountingSink : Stream {
  private long count;
  public long Count { get { return Interlocked.Read(ref count); } }
  public override bool CanRead { get { return false; } }
  public override bool CanSeek { get { return false; } }
  public override bool CanWrite { get { return true; } }
  public override long Length { get { return Count; } }
  public override long Position { get { return Count; } set { throw new NotSupportedException(); } }
  public override void Flush() { }
  public override void Write(byte[] buffer,int offset,int length) { Interlocked.Add(ref count,length); }
  public override int Read(byte[] b,int o,int c) { throw new NotSupportedException(); }
  public override long Seek(long o,SeekOrigin s) { throw new NotSupportedException(); }
  public override void SetLength(long v) { throw new NotSupportedException(); }
}
'@
  $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=Join-Path $PSHOME "powershell.exe"
  $info.Arguments='-NoLogo -NoProfile -NonInteractive -File "'+$PSCommandPath+'" -Worker -Directory "'+$Directory+'" -ExpectedRepositoryHead '+$ExpectedRepositoryHead
  $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
  $p=[Diagnostics.Process]::new();$p.StartInfo=$info
  if(-not $p.Start()){throw "Diagnostic process creation failed."}
  # Count streams as bytes only; do not decode or retain their contents.
  $outSink=New-Object NativeDiagnosticCountingSink;$errSink=New-Object NativeDiagnosticCountingSink
  $outTask=$p.StandardOutput.BaseStream.CopyToAsync($outSink)
  $errTask=$p.StandardError.BaseStream.CopyToAsync($errSink)
  if(-not $p.WaitForExit(60000)){throw "Diagnostic owned process exit unproven."}
  $exited=$true;$outTask.GetAwaiter().GetResult();$errTask.GetAwaiter().GetResult()
  $record=Read-Diagnostic "worker.json"
  if($p.ExitCode -ne $record.parentExitCode){throw "Diagnostic receipt/exit disagreement."}
  if($outSink.Count -gt [int]::MaxValue -or $errSink.Count -gt [int]::MaxValue){throw "Diagnostic stream count exceeded."}
  $record.stdoutBytes=[int]$outSink.Count;$record.stderrBytes=[int]$errSink.Count
  # No raw capture file is created. The worker emits no streams on this exact
  # precondition rejection path; stream lengths are verified by a counting sink.
  Write-Diagnostic $record "final.json";$record=Read-Diagnostic "final.json"
  Write-Output (Get-DiagnosticJson $record)
}finally{
  if($null -ne $outSink){$outSink.Dispose()};if($null -ne $errSink){$errSink.Dispose()}
  if($null -ne $p){$p.Dispose()}
  if(-not $exited){throw "Unproven diagnostic process; cleanup withheld."}
  [void](Assert-DiagnosticDirectory $Directory)
  $items=@(Get-ChildItem -LiteralPath $Directory -Force)
  foreach($i in $items){if($i.PSIsContainer -or ($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
    $i.Name -cnotin @("worker.json","final.json")){throw "Unexpected diagnostic cleanup object."}}
  foreach($i in $items){Remove-Item -LiteralPath $i.FullName -Force}
  Remove-Item -LiteralPath $Directory -Force
  if(Test-Path -LiteralPath $Directory){throw "Diagnostic residue remains."}
}
