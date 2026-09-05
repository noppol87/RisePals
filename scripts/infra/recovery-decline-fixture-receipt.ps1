Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:DeclineReceiptKeys = @("schemaVersion","scenario","powerShellVersion","runspaceCreated","runspaceOpened",
  "pipelineCreated","pipelineInvoked","pipelineCompleted","confirmationCallbackReached","confirmationCallbackCount",
  "selectedChoice","pipelineHadErrors","pipelineErrorCategory","workerExitCode","requestHashBefore","requestHashAfter",
  "requestUnchanged","childProcessCreated","bootstrapEvidenceCount","temporaryEvidenceCount","cleanupCompleted",
  "finalResidueCount","receiptDigest")
function Get-DeclineReceiptJson {
  param([object]$Record,[switch]$WithoutDigest)
  $body=[ordered]@{}
  foreach($key in $script:DeclineReceiptKeys){if(-not($WithoutDigest -and $key -ceq "receiptDigest")){$body[$key]=$Record.$key}}
  return ($body | ConvertTo-Json -Depth 3 -Compress)
}
function Get-DeclineReceiptDigest {
  param([object]$Record)
  return Get-RecoveryBootHash -Bytes ([Text.UTF8Encoding]::new($false).GetBytes((Get-DeclineReceiptJson $Record -WithoutDigest)))
}
function Read-DeclineReceipt {
  param([string]$Directory,[string]$Nonce,[string]$ExpectedRequestHash)
  $root=Assert-RecoveryBootDirectory $Directory $Nonce
  $json=Read-RecoveryBootJsonFile (Join-Path $root "decline-receipt.json") $root $Nonce
  $r=$json | ConvertFrom-Json
  if(@($r.PSObject.Properties).Count -ne $script:DeclineReceiptKeys.Count -or
    @($r.PSObject.Properties.Name | Where-Object {$_ -cnotin $script:DeclineReceiptKeys}).Count -or
    $json -cne (Get-DeclineReceiptJson $r)){throw "Decline receipt exact schema rejected."}
  if($r.schemaVersion -cne "rise-pals-decline-fixture-v1" -or $r.scenario -cne "Declined" -or
    $r.powerShellVersion -cne "5.1" -or $r.selectedChoice -cnotin @("not-reached","No") -or
    $r.pipelineErrorCategory -cnotin @("none","host-compilation","runspace-create","runspace-type-unresolved",
      "runspace-open","runspace-snapin-load","runspace-module-load","runspace-host-null","runspace-host-callback",
      "runspace-open-unsupported","runspace-open-authorization","runspace-open-assembly","runspace-open-thread",
      "runspace-open-state","runspace-open-member","runspace-open-runtime","runspace-open-argument",
      "runspace-open-unsupported-legacy","runspace-open-unsupported-remote","runspace-open-unsupported-rawui",
      "runspace-open-unsupported-callstack","runspace-open-unsupported-configuration",
      "pipeline-create","pipeline-invoke","pipeline-error","confirmation-not-declined","disposal","request-changed","unexpected-evidence")
    ){throw "Decline receipt vocabulary rejected."}
  foreach($key in @("runspaceCreated","runspaceOpened","pipelineCreated","pipelineInvoked","pipelineCompleted",
    "confirmationCallbackReached","pipelineHadErrors","requestUnchanged","childProcessCreated","cleanupCompleted")){
    if($r.$key -isnot [bool]){throw "Decline receipt boolean rejected."}
  }
  foreach($key in @("confirmationCallbackCount","workerExitCode","bootstrapEvidenceCount","temporaryEvidenceCount","finalResidueCount")){
    if($r.$key -isnot [int] -or $r.$key -lt 0 -or $r.$key -gt 255){throw "Decline receipt count rejected."}
  }
  foreach($key in @("requestHashBefore","requestHashAfter","receiptDigest")){
    if($r.$key -isnot [string] -or $r.$key -cnotmatch '^[a-f0-9]{64}$'){throw "Decline receipt hash rejected."}
  }
  if($r.requestHashBefore -cne $ExpectedRequestHash -or $r.requestUnchanged -ne ($r.requestHashBefore -ceq $r.requestHashAfter) -or
    $r.confirmationCallbackReached -ne ($r.confirmationCallbackCount -gt 0) -or
    ($r.runspaceOpened -and -not $r.runspaceCreated) -or ($r.pipelineInvoked -and -not $r.pipelineCreated) -or
    ($r.pipelineCompleted -and -not $r.pipelineInvoked) -or $r.receiptDigest -cne (Get-DeclineReceiptDigest $r)){
    throw "Decline receipt consistency or digest rejected."
  }
  if($r.workerExitCode -eq 0 -and (-not $r.runspaceOpened -or -not $r.pipelineCompleted -or $r.pipelineHadErrors -or
    $r.pipelineErrorCategory -cne "none" -or $r.confirmationCallbackCount -ne 1 -or $r.selectedChoice -cne "No" -or
    -not $r.requestUnchanged -or $r.childProcessCreated -or $r.bootstrapEvidenceCount -ne 0 -or
    $r.temporaryEvidenceCount -ne 0 -or -not $r.cleanupCompleted -or $r.finalResidueCount -ne 0)){
    throw "Decline receipt success rejected."
  }
  return $r
}
function Write-DeclineReceipt {
  param([object]$Record,[string]$Directory,[string]$Nonce)
  $root=Assert-RecoveryBootDirectory $Directory $Nonce
  $Record.receiptDigest=Get-DeclineReceiptDigest $Record
  $bytes=[Text.UTF8Encoding]::new($false).GetBytes((Get-DeclineReceiptJson $Record))
  $temporary=Join-Path $root "decline-receipt.json.tmp"; $final=Join-Path $root "decline-receipt.json"
  $s=[IO.File]::Open($temporary,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try{$s.Write($bytes,0,$bytes.Length);$s.Flush($true)}finally{$s.Dispose()}
  [IO.File]::Move($temporary,$final)
}
