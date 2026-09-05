[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
if ($PSVersionTable.PSEdition -cne "Desktop" -or $PSVersionTable.PSVersion.Major -ne 5 -or
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "Non-elevated PS5.1 required." }
. (Join-Path $PSScriptRoot "Invoke-RisePalsCandidateLiveSequence.ps1") -EarlyContractOnly
. (Join-Path $PSScriptRoot "candidate-rehearsal-result.ps1")
$cases=@("Stage0","Stage1","Stage2","Stage3","Stage4","Stage5","Stage6","Stage7","Stage8",
  "Missing","MissingProperty","Duplicate","Extra","WrongType","Digest","Nonce","SourceHash","Reordered","Stale","Replay","WrongMode","ExtraFile")
$passed=0
foreach ($case in $cases) {
  $nonce=[guid]::NewGuid().ToString("N"); $root=Join-Path ([IO.Path]::GetTempPath()) ("diag7-"+$nonce)
  if (Test-Path -LiteralPath $root) { throw "Early fixture collision." }
  [void][IO.Directory]::CreateDirectory($root)
  $process=$null; $processExited=$true; $started=[DateTimeOffset]::UtcNow
  try {
    $binding=New-RisePalsEarlyBinding "RP-TURN-019-R4-DIAG7-EARLY-SIMULATION" $nonce ("c"*40) Simulation
    if ($case.StartsWith("Stage",[StringComparison]::Ordinal)) {
      $last=[int]$case.Substring(5)
      $info=[Diagnostics.ProcessStartInfo]::new()
      $info.FileName=Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
      $source=Join-Path $PSScriptRoot "Invoke-RisePalsCandidateLiveSequence.ps1"
      $info.Arguments='-NoLogo -NoProfile -NonInteractive -File "'+$source+'" -RepositoryHead '+("c"*40)+' -InvocationNonce '+$nonce+
        ' -FutureAuthorizationId RP-TURN-019-R4-DIAG7-EARLY-SIMULATION -StructuredStatePath "'+(Join-Path $root "live-state.json")+'" -EarlySimulationStop '+$last
      $info.UseShellExecute=$false; $info.CreateNoWindow=$true; $info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
      $info.EnvironmentVariables["PSModulePath"]="C:\Program Files\PowerShell\7\Modules;"+$env:PSModulePath
      $process=[Diagnostics.Process]::new(); $process.StartInfo=$info
      if (-not $process.Start()) { throw "Early fixture process creation failed." }
      $processExited=$false
      if (-not $process.WaitForExit(30000)) { throw "Early fixture bounded wait failed; exact process retained." }
      $processExited=$true
      if ($process.ExitCode -ne 0) { throw "Early fixture process failed." }
      $records=Read-RisePalsEarlyChain $root $binding $started
      if ($records.Count -ne ($last+1) -or $records[-1].stage -cne $script:EarlyLiveStages[$last]) { throw "Early last-stage assertion failed." }
      # A second independent consumer reopens the same chain. Neither consumer grants functional authority.
      $again=Read-RisePalsEarlyChain $root $binding $started
      if ($again[-1].recordDigest -cne $records[-1].recordDigest) { throw "Independent early reopening failed." }
      $diagnostic=New-RisePalsCandidateChildDiagnostic -Result $null -ExecutionMode Live -CleanupResponsibilityTransferredToParent $true
      if (@($diagnostic.functionalGates.PSObject.Properties).Count -ne 21 -or
        @($diagnostic.functionalGates.PSObject.Properties | Where-Object { $_.Value -cne "not_reached" }).Count -ne 0 -or
        $diagnostic.childCleanupCompleted -or $diagnostic.liveHostMutationBegan) { throw "Early evidence claimed functional authority." }
    } elseif ($case -ceq "Missing") {
      $records=Read-RisePalsEarlyChain $root $binding $started
      if ($records.Count -ne 0 -or (Get-RisePalsCandidateFailureCodeMap)["early-live-entry"] -cne "live-process-exit-before-entry-evidence") { throw "Missing entry classification failed." }
    } else {
      $record=Write-RisePalsEarlyRecord $root $binding $null
      $path=Join-Path $root "early-live-00.json"
      $original=Get-RisePalsEarlyHash -Path $path
      $text=[Text.UTF8Encoding]::new($false,$true).GetString([IO.File]::ReadAllBytes($path))
      if ($case -ceq "Replay") {
        $rejected=$false; try { [void](Write-RisePalsEarlyRecord $root $binding $null) } catch { $rejected=$true }
        if (-not $rejected -or (Get-RisePalsEarlyHash -Path $path) -cne $original) { throw "Early replay preservation failed." }
      } else {
        switch ($case) {
          "MissingProperty" { $record.PSObject.Properties.Remove("liveStateDigest") }
          "Duplicate" { $text=$text.Replace('"sequence":0','"sequence":0,"sequence":0') }
          "Extra" { $record | Add-Member NoteProperty extra $true }
          "WrongType" { $record.sequence="0" }
          "Digest" { $record.recordDigest="f"*64 }
          "Nonce" { $record.invocationNonce="f"*32 }
          "SourceHash" { $record.sourceHashes[0]="f"*64 }
          "Reordered" { $record.stage="contracts-loaded" }
          "Stale" { $record.recordedAtUtc=$started.AddSeconds(-1).ToString("o") }
          "WrongMode" { $record.executionMode="Live" }
          "ExtraFile" { [IO.File]::WriteAllText((Join-Path $root "early-live-extra.json"),"{}",[Text.UTF8Encoding]::new($false)) }
        }
        if ($case -cnotin @("Duplicate","ExtraFile")) {
          if ($case -cnotin @("Digest","MissingProperty","Extra")) { $record.recordDigest=Get-RisePalsEarlyDigest $record }
          $text=ConvertTo-Json -InputObject $record -Depth 5 -Compress
        }
        [IO.File]::WriteAllText($path,$text,[Text.UTF8Encoding]::new($false))
        $rejected=$false; try { [void](Read-RisePalsEarlyChain $root $binding $started) } catch { $rejected=$true }
        if (-not $rejected) { throw "Early negative case accepted." }
      }
    }
    $passed++
  } finally {
    if ($process) { $process.Dispose() }
    if (-not $processExited) { throw "Early fixture still active; cleanup refused." }
    $validated=Assert-RisePalsEarlyDirectory $root $nonce Simulation
    $items=@(Get-ChildItem -LiteralPath $validated -Force)
    foreach ($item in $items) {
      if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        $item.Name -cnotmatch '^early-live-(0[0-8]|extra)\.json$') { throw "Early fixture cleanup rejected." }
    }
    foreach ($item in $items) { [IO.File]::Delete($item.FullName) }
    [IO.Directory]::Delete($validated,$false)
    if (Test-Path -LiteralPath $root) { throw "Early fixture residue." }
  }
}
# Contract-only regression: a receiving process has a different TEMP than its
# caller. Never enter Live execution or create protected-host resources.
$nonce=[guid]::NewGuid().ToString("N")
$sandbox=Join-Path ([IO.Path]::GetTempPath()) ("diag7-root-"+$nonce)
$boundRoot=Join-Path $sandbox "risepals-candidate-launcher"
$invocation=Join-Path $boundRoot ("invocation-"+$nonce)
$alternate=Join-Path $sandbox "receiving-process-temp"
$savedTemp=$env:TEMP; $savedTmp=$env:TMP
if (Test-Path -LiteralPath $sandbox) { throw "Root regression collision." }
[void][IO.Directory]::CreateDirectory($invocation)
[void][IO.Directory]::CreateDirectory($alternate)
try {
  $started=[DateTimeOffset]::UtcNow
  $binding=New-RisePalsEarlyBinding "RP-TURN-019-R4-LIVE-6F3A91D2" $nonce ("c"*40) Live $boundRoot
  $env:TEMP=$alternate; $env:TMP=$alternate
  if ([IO.Path]::GetTempPath().TrimEnd('\') -cne $alternate) { throw "Mixed temporary context setup failed." }
  $record=Write-RisePalsEarlyRecord $invocation $binding $null
  $records=Read-RisePalsEarlyChain $invocation $binding $started
  if ($records.Count -ne 1 -or $records[0].recordDigest -cne $record.recordDigest) { throw "Receiving-context reopening failed." }
  foreach ($badRoot in @("", "risepals-candidate-launcher", $alternate, (Join-Path $alternate "risepals-candidate-launcher"),
    (Join-Path $sandbox 'other\..\risepals-candidate-launcher'))) {
    $rejected=$false
    try { [void](Assert-RisePalsEarlyDirectory $invocation $nonce Live $badRoot) } catch { $rejected=$true }
    if (-not $rejected) { throw "Unbound root accepted." }
  }
  $rejected=$false
  try { [void](Assert-RisePalsEarlyDirectory $invocation ("f"*32) Live $boundRoot) } catch { $rejected=$true }
  if (-not $rejected) { throw "Wrong invocation accepted." }
  $env:TEMP=$savedTemp; $env:TMP=$savedTmp
  $reopened=Read-RisePalsEarlyChain $invocation $binding $started
  if ($reopened.Count -ne 1 -or $reopened[0].recordDigest -cne $record.recordDigest) { throw "Original-context reopening failed." }
} finally {
  $env:TEMP=$savedTemp; $env:TMP=$savedTmp
  [void](Assert-RisePalsEarlyDirectory $invocation $nonce Live $boundRoot)
  # Validate the complete flat fixture layout before removing any object.
  foreach ($directory in @($sandbox,$boundRoot,$invocation,$alternate)) {
    $item=Get-Item -LiteralPath $directory -Force
    if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Root regression cleanup object rejected." }
  }
  if (@(Get-ChildItem -LiteralPath $sandbox -Force).Count -ne 2 -or
    @(Get-ChildItem -LiteralPath $boundRoot -Force).Count -ne 1 -or
    @(Get-ChildItem -LiteralPath $alternate -Force).Count -ne 0) { throw "Root regression cleanup layout rejected." }
  $files=@(Get-ChildItem -LiteralPath $invocation -Force)
  if ($files.Count -gt 1) { throw "Root regression extra file rejected." }
  foreach ($file in $files) {
    if ($file.Name -cne "early-live-00.json" -or $file.PSIsContainer -or
      ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Root regression cleanup file rejected." }
  }
  foreach ($file in $files) { [IO.File]::Delete($file.FullName) }
  foreach ($directory in @($invocation,$boundRoot,$alternate,$sandbox)) { [IO.Directory]::Delete($directory,$false) }
  if (Test-Path -LiteralPath $sandbox) { throw "Root regression residue." }
}
Write-Output ("Early Live boundary PASS: {0}/{1}; cross-TEMP write/reopen=PASS; invalid-root cases=6; nine separate processes; UAC=0; elevated=0; protected-access=0; raw-captures=0; residue=0." -f $passed,$cases.Count)
