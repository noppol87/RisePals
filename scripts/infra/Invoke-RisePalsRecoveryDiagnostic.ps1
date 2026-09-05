[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [ValidateSet("Simulation", "Recovery")][string]$ExecutionMode = "Simulation",
  [string]$AuthorizationId = "", [string]$InvocationNonce = "", [string]$RepositoryHead = "",
  [string]$EvidenceDirectory = "", [string]$Scenario = "Success"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1")
$childPath = Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChild.ps1"
$bootstrapPath = Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildBootstrap.ps1"
$bootstrapHash = Get-RisePalsRecoveryHash $bootstrapPath
. $bootstrapPath -ContractOnly
. (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildEntry.ps1") -ContractOnly
$script:parentEnvelopeDigest=$null;$script:parentEntryDigest=$null
$livePath = Join-Path $PSScriptRoot "Invoke-RisePalsCandidateLiveSequence.ps1"
$contractPath = Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1"
$binding = [pscustomobject][ordered]@{
  executionMode = $ExecutionMode; authorizationId = $AuthorizationId; invocationNonce = $InvocationNonce
  repositoryHead = $RepositoryHead; parentScriptSha256 = Get-RisePalsRecoveryHash $PSCommandPath
  childScriptSha256 = Get-RisePalsRecoveryHash $childPath
  liveScriptSha256 = Get-RisePalsRecoveryHash $livePath
  contractScriptSha256 = Get-RisePalsRecoveryHash $contractPath
}
$request = New-RisePalsRecoveryRecord $binding request request-created $null
$script:recoveryParentLast = $null
function Add-RecoveryParentStage {
  param([string]$Stage, [string]$Category = "none", [bool]$Completed = $true,
    [AllowNull()][object]$ExitCode, [AllowNull()][object]$EvidenceDigest,
    [AllowNull()][object]$HResult, [AllowNull()][object]$NativeCode)
  $record = New-RisePalsRecoveryRecord $request parent $Stage $script:recoveryParentLast `
    -Category $Category -StageCompleted $Completed -ExitCode $ExitCode -EvidenceDigest $EvidenceDigest `
    -HResult $HResult -NativeCode $NativeCode -InvocationEnvelopeDigest $script:parentEnvelopeDigest -EntryAdapterDigest $script:parentEntryDigest
  $path = Write-RisePalsRecoveryRecord $record $EvidenceDirectory
  $script:recoveryParentLast = Read-RisePalsRecoveryRecord $path $EvidenceDirectory $request $script:recoveryParentLast
}
$process = $null
$success = $false
$stage = "parent-entry"
$category = "parent-persistence-failure"
$observedExit = $null
$nativeCode = $null
$hresult = $null
try {
  Add-RecoveryParentStage $stage
  $stage = "arguments-validated"
  $scenarios = @("Success", "Cancelled", "CreationFailure", "WaitFailure", "BeforeMarker",
    "BeforeImportFailure", "ChildFailure", "MarkerMalformed", "MarkerStale", "MarkerTamper",
    "MarkerReplay", "ResultPersistence", "ResultReopen", "CleanupTamper")
  if ($Scenario -cnotin $scenarios -or ($ExecutionMode -ne "Simulation" -and $Scenario -cne "Success") -or
    [IO.Path]::GetFileName($EvidenceDirectory) -cne ("diag7-" + $InvocationNonce)) { throw "Recovery arguments rejected." }
  $repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
  $git = "C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
  $actualHead = @(& $git -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $repository rev-parse HEAD)
  if ($LASTEXITCODE -ne 0 -or $actualHead.Count -ne 1 -or $actualHead[0] -cne $RepositoryHead) {
    throw "Recovery repository provenance rejected."
  }
  if ($ExecutionMode -eq "Recovery") {
    if (-not $PSCmdlet.ShouldProcess("reviewed recovery child", "Request one separately authorized elevation")) {
      throw "Recovery approval absent."
    }
  } elseif (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "Simulation elevation rejected." }
  Add-RecoveryParentStage $stage
  $stage = "request-write-attempted"; Add-RecoveryParentStage $stage
  $stage = "request-written"
  $requestPath = Write-RisePalsRecoveryRecord $request $EvidenceDirectory
  Add-RecoveryParentStage $stage -EvidenceDigest $request.recordDigest
  $stage = "request-reopened"
  $request = Read-RisePalsRecoveryRecord $requestPath $EvidenceDirectory $binding $null
  Add-RecoveryParentStage $stage -EvidenceDigest $request.recordDigest
  $arguments = @("-NoLogo", "-NoProfile", "-NonInteractive", "-File", ('"' + $bootstrapPath + '"'))
  foreach ($pair in @(
    [pscustomobject]@{name="BootAuthorization";value=$AuthorizationId},
    [pscustomobject]@{name="BootNonce";value=$InvocationNonce},
    [pscustomobject]@{name="BootHead";value=$RepositoryHead},
    [pscustomobject]@{name="BootScriptHash";value=$bootstrapHash},
    [pscustomobject]@{name="BootRequestDigest";value=$request.recordDigest},
    [pscustomobject]@{name="BootDirectory";value=$EvidenceDirectory}
  )) {
    if ($pair.value.Contains('"') -or $pair.value.Contains("`r") -or $pair.value.Contains("`n")) { throw "Argument serialization rejected." }
    $arguments += @("-" + $pair.name, ('"' + $pair.value + '"'))
  }
  $childScenario = if ($Scenario -in @("BeforeImportFailure", "ChildFailure")) { $Scenario } else { "Success" }
  $arguments += @("-ChildScenario", $childScenario)
  $stage = "child-launch-attempted"; Add-RecoveryParentStage $stage
  $stage = "child-process-created"; $category = "bootstrap-process-not-created"
  if ($ExecutionMode -eq "Simulation" -and $Scenario -eq "Cancelled") {
    $nativeCode = 1223; $category = "uac-cancelled"; throw "Synthetic cancellation."
  }
  if ($ExecutionMode -eq "Simulation" -and $Scenario -eq "CreationFailure") { throw "Synthetic process failure." }
  $launch = @{FilePath=(Join-Path $PSHOME "powershell.exe");ArgumentList=$arguments;WindowStyle="Hidden";PassThru=$true;ErrorAction="Stop"}
  if ($ExecutionMode -eq "Recovery") { $launch.Verb = "RunAs" }
  if ($ExecutionMode -eq "Simulation" -and $Scenario -eq "BeforeMarker") {
    $launch.ArgumentList = @("-NoProfile", "-NonInteractive", "-Command", "exit 65")
  }
  try { $process = Start-Process @launch }
  catch {
    # Reuse the reviewed ErrorRecord classifier; never persist raw exceptions.
    . (Join-Path $PSScriptRoot "candidate-rehearsal-result.ps1")
    . (Join-Path $PSScriptRoot "candidate-rehearsal-transport.ps1")
    $closed = Get-RisePalsCandidateLaunchExceptionEvidence -Exception $_.Exception -ErrorRecord $_
    $nativeCode = $closed.nativeErrorCode; $hresult = $closed.hResult
    if ($nativeCode -eq 1223) { $category = "uac-cancelled" }
    throw "Recovery process creation failed."
  }
  Add-RecoveryParentStage $stage
  $stage = "child-started-marker-observed"; $category = "wait-failure"
  if ($ExecutionMode -eq "Simulation" -and $Scenario -eq "WaitFailure") { throw "Synthetic wait failure." }
  if (-not $process.WaitForExit(300000)) { throw "Recovery wait deadline reached." }
  $observedExit = $process.ExitCode
  $category = "bootstrap-exit-before-marker"
  if (-not [IO.File]::Exists((Join-Path $EvidenceDirectory "bootstrap-00.json"))) { throw "Bootstrap marker absent." }
  $category = "evidence-invalid"
  $bootstrapLast = $null
  $bootstrapFailures = @()
  foreach ($file in @(Get-ChildItem -LiteralPath $EvidenceDirectory -File | Where-Object Name -match '^bootstrap-[0-9]{2}\.json$' | Sort-Object Name)) {
    $bootstrapLast = Read-RecoveryBootRecord $file.FullName $EvidenceDirectory $request $bootstrapHash "None" $bootstrapLast
    if (-not $bootstrapLast.stageCompleted) { $bootstrapFailures += @($bootstrapLast) }
  }
  $category = "bootstrap-marker-without-child"
  if (-not $bootstrapLast.childProcessCreated) { throw "Bootstrap did not create child." }
  $category="invocation-envelope-invalid"
  $envelope=Read-RecoveryInvocationEnvelope (Join-Path $EvidenceDirectory "invocation-envelope.json") $bootstrapLast.invocationEnvelopeDigest
  $script:parentEnvelopeDigest=$envelope.envelopeDigest
  if($bootstrapLast.entryAdapterScriptSha256 -cne $envelope.entryAdapterScriptSha256){throw "Entry adapter hash mismatch."}
  $category="entry-adapter-exit-before-marker"
  if(-not [IO.File]::Exists((Join-Path $EvidenceDirectory "entry-00.json"))){throw "Entry adapter marker absent."}
  $category="evidence-invalid";$entryLast=$null;$entryFailures=@()
  foreach($file in @(Get-ChildItem -LiteralPath $EvidenceDirectory -File | Where-Object Name -match '^entry-[0-9]{2}\.json$' | Sort-Object Name)){
    $entryLast=Read-RecoveryChildEntryRecord $file.FullName $envelope $entryLast
    if($entryLast.sequence -eq 0 -and $bootstrapLast.entryAdapterMarkerDigest -cne $entryLast.recordDigest){throw "Entry marker binding mismatch."}
    if(-not $entryLast.stageCompleted){$entryFailures+=@($entryLast)}
  }
  $script:parentEntryDigest=$entryLast.recordDigest
  if($entryLast.recordDigest -cne $bootstrapLast.entryAdapterResultDigest){throw "Entry terminal binding mismatch."}
  if($entryFailures.Count){$category=$entryFailures[0].category;throw "Entry adapter reported subject failure."}
  if($entryLast.stage -cne "entry-result-reopened" -or $entryLast.recordDigest -cne $bootstrapLast.entryAdapterResultDigest){throw "Entry final binding mismatch."}
  $category = "child-script-exit-before-entry-marker"
  if (-not $bootstrapLast.childMarkerPresent) { throw "Child entry not established by bootstrap." }
  $category = "child-script-failure"
  if ($observedExit -ne 0 -or $bootstrapFailures.Count -ne 0 -or
    $bootstrapLast.stage -cne "bootstrap-result-reopened" -or -not $bootstrapLast.stageCompleted) {
    throw "Bootstrap result did not establish child success."
  }
  $observedExit = $bootstrapLast.childExitCode
  $category = "child-exit-before-marker"
  $markerPath = Join-Path $EvidenceDirectory "child-00.json"
  if (-not [IO.File]::Exists($markerPath)) { throw "Child marker absent." }
  $category = "evidence-invalid"
  if ($ExecutionMode -eq "Simulation" -and $Scenario -in @("MarkerMalformed", "MarkerStale", "MarkerTamper", "MarkerReplay")) {
    $synthetic = ConvertFrom-RisePalsRecoveryJson ([IO.File]::ReadAllText($markerPath))
    switch ($Scenario) {
      "MarkerMalformed" { [IO.File]::WriteAllText($markerPath, "{") }
      "MarkerStale" { $synthetic.recordedAtUtc = [DateTimeOffset]::UtcNow.AddSeconds(-301).ToString("o") }
      "MarkerTamper" { $synthetic.recordDigest = "f" * 64 }
      "MarkerReplay" { $synthetic.invocationNonce = "f" * 32 }
    }
    if ($Scenario -ne "MarkerMalformed") {
      [IO.File]::WriteAllText($markerPath, ($synthetic | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
    }
  }
  $childLast = Read-RisePalsRecoveryRecord $markerPath $EvidenceDirectory $request $null
  Add-RecoveryParentStage $stage -EvidenceDigest $childLast.recordDigest
  $stage = "child-result-observed"; $category = "child-failure"
  foreach ($number in 1..3) {
    $path = Join-Path $EvidenceDirectory ("child-{0:D2}.json" -f $number)
    $childLast = Read-RisePalsRecoveryRecord $path $EvidenceDirectory $request $childLast
  }
  if ($childLast.stage -cne "recovery-result" -or $childLast.exitCode -ne $observedExit) { throw "Child result mismatch." }
  Add-RecoveryParentStage $stage -EvidenceDigest $childLast.recordDigest
  $stage = "child-process-exited"; Add-RecoveryParentStage $stage -ExitCode $observedExit
  $success = $observedExit -eq 0 -and $childLast.category -ceq "child-success" -and $childLast.cleanupCompleted -eq $true
} catch {
  if ($null -ne $script:recoveryParentLast) {
    Add-RecoveryParentStage $stage -Category $category -Completed $false -ExitCode $observedExit -NativeCode $nativeCode -HResult $hresult
  }
} finally {
  if ($null -ne $process) {
    try {
      if (-not $process.HasExited -and -not $process.WaitForExit(10000)) {
        throw "Recovery child exit remains unverified; no termination is permitted."
      }
    } finally { $process.Dispose() }
  }
}
if ($null -eq $script:recoveryParentLast) { exit 90 }
try {
  if ($ExecutionMode -eq "Simulation" -and $Scenario -eq "ResultPersistence") { throw "Synthetic final persistence failure." }
  Add-RecoveryParentStage parent-result-written
  if ($ExecutionMode -eq "Simulation" -and $Scenario -eq "ResultReopen") { throw "Synthetic final reopen failure." }
  Add-RecoveryParentStage parent-result-reopened
} catch { exit 91 }
if ($success) { exit 0 }; exit 92
