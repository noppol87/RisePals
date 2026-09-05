[CmdletBinding()]
param([string]$FixtureDirectory = "", [string]$Scenario = "",
  [ValidateSet("", "Schema", "Synthetic", "Transport", "Worker", "SubjectFailure", "InvalidReceipt")][string]$DiagnosticMode = "",
  [string]$DiagnosticCase = "", [string]$DiagnosticNonce = "")
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# DIAG7-DIAG1 instrumentation only. The three implementation drafts below are
# neither corrected nor substituted. This opt-in path never runs the full suite.
if ($DiagnosticMode -ne "") {
  $diagAuthorization = "RP-TURN-019-R4-RECOVERY-DIAG7-R2-72A6F4C9"
  $diagFiles = @("recovery-diagnostic-contract.ps1", "Invoke-RisePalsRecoveryDiagnostic.ps1",
    "Invoke-RisePalsRecoveryChild.ps1", "Test-RisePalsRecoveryDiagnosticContract.ps1", "Invoke-RisePalsRecoveryChildBootstrap.ps1",
    "Invoke-RisePalsRecoveryChildEntry.ps1")
  $diagKeys = @("schemaVersion", "authorizationId", "nonce", "scenario", "draftFileSha256",
    "completedStages", "lastCompletedStage", "failedStage", "failedPredicate", "sanitizedCategory",
    "processCreated", "workerExitCode", "childProcessCreated", "childExitCode", "requestPresent",
    "requestDigest", "childStartedMarkerPresent", "childStartedMarkerDigest", "childResultPresent",
    "childResultDigest", "parentResultPresent", "parentResultDigest", "cleanupAttempted",
    "cleanupCompleted", "temporaryResidueCount", "subjectClassification", "subjectExitCode", "subjectSucceeded",
    "bootstrapStartedMarkerDigest", "bootstrapFinalDigest", "bootstrapLastStage", "bootstrapFailureStage",
    "bootstrapCategory", "bootstrapExitCode", "invocationEnvelopeDigest", "entryAdapterMarkerDigest", "entryAdapterResultDigest",
    "entryAdapterLastStage", "entryAdapterFailedStage", "entryAdapterCategory", "entryAdapterPredicate", "entryAdapterChildExitCode", "receiptDigest")
  $diagStages = @("worker-entry", "arguments-validated", "fixture-created", "contract-load-attempted",
    "contract-loaded", "transport-entry", "request-create-attempted", "request-written", "request-reopened",
    "child-launch-attempted", "child-process-created", "child-started-marker-observed",
    "child-result-observed", "parent-result-written", "parent-result-reopened",
    "cleanup-attempted", "cleanup-completed", "worker-completed")
  $diagCategories = @("none", "worker-process-creation-failure", "worker-exit-before-receipt",
    "worker-receipt-invalid", "fixture-failure", "contract-load-failure", "transport-invocation-failure",
    "durable-evidence-invalid", "transport-assertion-failure", "cleanup-failure",
    "uac-cancelled", "process-creation-failure", "wait-failure", "child-exit-before-marker",
    "evidence-invalid", "child-failure", "parent-persistence-failure", "recovery-unverified",
    "bootstrap-process-not-created", "bootstrap-exit-before-marker", "bootstrap-marker-without-child",
    "child-script-exit-before-entry-marker", "child-script-failure", "entry-adapter-process-not-created",
    "entry-adapter-exit-before-marker", "invocation-envelope-invalid", "child-source-parse-failure",
    "child-parameter-binding-failure", "child-invocation-failure", "child-entry-marker-missing",
    "child-entry-marker-invalid", "entry-marker-persistence-failure", "entry-marker-reopen-failure",
    "entry-result-persistence-failure", "entry-result-reopen-failure", "controlled-unclassified-failure")
  $diagPredicates = @("none", "worker-created", "arguments-valid", "fixture-created",
    "contract-import-returned", "transport-invocation-returned", "durable-records-valid",
    "success-contract-satisfied", "flat-owned-cleanup", "receipt-valid")
  $diagCases = @("ValidSuccess", "ProcessCreationFailure", "ExitBeforeReceipt", "Malformed",
    "Stale", "DigestTamper", "InvalidStage", "InvalidCategory", "PartialWrite", "CleanupResidue", "ValidSubjectFailure")
  if ($PSVersionTable.PSEdition -cne "Desktop" -or $PSVersionTable.PSVersion.Major -ne 5 -or
    $PSVersionTable.PSVersion.Minor -ne 1 -or
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
      [Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "Diagnostic execution boundary rejected." }
  function Get-DiagHash {
    param([string]$Path, [byte[]]$Bytes)
    $algorithm = [Security.Cryptography.SHA256]::Create(); $stream = $null
    try {
      if ($Path) { $stream = [IO.File]::OpenRead($Path); $hash = $algorithm.ComputeHash($stream) }
      else { $hash = $algorithm.ComputeHash($Bytes) }
      return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
    } finally { if ($null -ne $stream) { $stream.Dispose() }; $algorithm.Dispose() }
  }
  function Get-DiagBindings {
    $bindings = [ordered]@{}
    foreach ($name in $diagFiles) { $bindings[$name] = Get-DiagHash -Path (Join-Path $PSScriptRoot $name) }
    return [pscustomobject]$bindings
  }
  function Get-DiagJson {
    param([object]$Record, [switch]$WithoutDigest)
    $body = [ordered]@{}
    foreach ($key in $diagKeys) {
      if (-not ($WithoutDigest -and $key -ceq "receiptDigest")) { $body[$key] = $Record.$key }
    }
    return ($body | ConvertTo-Json -Depth 5 -Compress)
  }
  function Set-DiagDigest {
    param([object]$Record)
    $Record.receiptDigest = Get-DiagHash -Bytes ([Text.UTF8Encoding]::new($false).GetBytes((Get-DiagJson $Record -WithoutDigest)))
  }
  function Assert-DiagDirectory {
    param([string]$Directory, [string]$Prefix)
    $exact = [IO.Path]::GetFullPath($Directory)
    if ([IO.Path]::GetDirectoryName($exact).TrimEnd('\') -cne [IO.Path]::GetTempPath().TrimEnd('\') -or
      [IO.Path]::GetFileName($exact) -cnotmatch ('^' + $Prefix + '-[a-f0-9]{32}$')) { throw "Diagnostic path rejected." }
    $current = $exact
    while ($current) {
      $item = Get-Item -LiteralPath $current -Force
      if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Diagnostic reparse rejected." }
      $current = [IO.Path]::GetDirectoryName($current)
    }
    return $exact
  }
  function Remove-DiagDirectory {
    param([string]$Directory, [string]$Prefix, [string]$AllowedNames)
    $exact = Assert-DiagDirectory $Directory $Prefix
    $children = @(Get-ChildItem -LiteralPath $exact -Force)
    # Validate the entire flat target before deleting any child. No recursion.
    foreach ($item in $children) {
      if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        $item.Name -cnotmatch $AllowedNames -or [IO.Path]::GetDirectoryName($item.FullName) -cne $exact) {
        throw "Diagnostic cleanup rejected."
      }
    }
    foreach ($item in $children) { Remove-Item -LiteralPath $item.FullName -Force }
    Remove-Item -LiteralPath $exact -Force
    if (Test-Path -LiteralPath $exact) { throw "Diagnostic cleanup incomplete." }
  }
  function New-DiagReceipt {
    param([string]$Nonce)
    return [pscustomobject][ordered]@{
      schemaVersion="rise-pals-recovery-worker-r2-v3"; authorizationId=$diagAuthorization
      nonce=$Nonce; scenario="TransportSuccess"; draftFileSha256=(Get-DiagBindings)
      completedStages=@("worker-entry"); lastCompletedStage="worker-entry"
      failedStage=$null; failedPredicate="none"; sanitizedCategory="none"
      processCreated=$true; workerExitCode=$null; childProcessCreated=$false; childExitCode=$null
      requestPresent=$false; requestDigest=$null; childStartedMarkerPresent=$false; childStartedMarkerDigest=$null
      childResultPresent=$false; childResultDigest=$null; parentResultPresent=$false; parentResultDigest=$null
      cleanupAttempted=$false; cleanupCompleted=$false; temporaryResidueCount=0
      subjectClassification="none";subjectExitCode=$null;subjectSucceeded=$false
      bootstrapStartedMarkerDigest=$null;bootstrapFinalDigest=$null;bootstrapLastStage=$null
      bootstrapFailureStage=$null;bootstrapCategory=$null;bootstrapExitCode=$null
      invocationEnvelopeDigest=$null;entryAdapterMarkerDigest=$null;entryAdapterResultDigest=$null;entryAdapterLastStage=$null
      entryAdapterFailedStage=$null;entryAdapterCategory=$null;entryAdapterPredicate=$null;entryAdapterChildExitCode=$null;receiptDigest=""
    }
  }
  function Read-DiagReceipt {
    param([string]$Path, [string]$Nonce, [DateTime]$StartedUtc)
    $directory = Assert-DiagDirectory ([IO.Path]::GetDirectoryName($Path)) "diag7diag"
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
      $item.Name -cnotmatch '^receipt-[0-9]{2}\.json$' -or $item.Length -lt 2 -or $item.Length -gt 16384 -or
      $item.LastWriteTimeUtc -lt $StartedUtc.AddSeconds(-30) -or $item.LastWriteTimeUtc -gt [DateTime]::UtcNow.AddSeconds(30)) {
      throw "Diagnostic receipt file rejected."
    }
    $bytes = [IO.File]::ReadAllBytes($item.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { throw "Diagnostic BOM rejected." }
    $json = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    $r = $json | ConvertFrom-Json
    if (@($r.PSObject.Properties).Count -ne $diagKeys.Count -or
      @($r.PSObject.Properties.Name | Where-Object { $_ -cnotin $diagKeys }).Count -ne 0) { throw "Diagnostic schema rejected." }
    # Byte-canonical JSON rejects duplicate/escaped duplicate keys and extra syntax,
    # not merely the parser's collapsed property set.
    if ($json -cne (Get-DiagJson $r) -or $r.schemaVersion -cne "rise-pals-recovery-worker-r2-v3" -or
      $r.authorizationId -cne $diagAuthorization -or $r.nonce -cne $Nonce -or $Nonce -cnotmatch '^[a-f0-9]{32}$' -or
      $r.scenario -cne "TransportSuccess") { throw "Diagnostic binding rejected." }
    $bindings = Get-DiagBindings
    if (@($r.draftFileSha256.PSObject.Properties).Count -ne $diagFiles.Count -or
      @($r.draftFileSha256.PSObject.Properties.Name | Where-Object { $_ -cnotin $diagFiles }).Count) { throw "Diagnostic hashes rejected." }
    foreach ($name in $diagFiles) {
      if ($r.draftFileSha256.$name -isnot [string] -or $r.draftFileSha256.$name -cne $bindings.$name) { throw "Diagnostic draft mismatch." }
    }
    foreach ($key in @("processCreated", "childProcessCreated", "requestPresent", "childStartedMarkerPresent",
      "childResultPresent", "parentResultPresent", "cleanupAttempted", "cleanupCompleted", "subjectSucceeded")) {
      if ($r.$key -isnot [bool]) { throw "Diagnostic boolean rejected." }
    }
    foreach ($key in @("workerExitCode", "childExitCode", "subjectExitCode", "bootstrapExitCode", "entryAdapterChildExitCode")) {
      if ($null -ne $r.$key -and ($r.$key -isnot [int] -or $r.$key -lt 0 -or $r.$key -gt 255)) { throw "Diagnostic exit rejected." }
    }
    if ($r.temporaryResidueCount -isnot [int] -or $r.temporaryResidueCount -lt 0 -or $r.temporaryResidueCount -gt 100 -or
      ($r.cleanupCompleted -and (-not $r.cleanupAttempted -or $r.temporaryResidueCount -ne 0)) -or
      ($null -ne $r.childExitCode -and -not $r.childProcessCreated)) { throw "Diagnostic state rejected." }
    foreach ($pair in @(@("requestPresent","requestDigest"), @("childStartedMarkerPresent","childStartedMarkerDigest"),
      @("childResultPresent","childResultDigest"), @("parentResultPresent","parentResultDigest"))) {
      $value = $r.($pair[1])
      if (($r.($pair[0]) -and ($value -isnot [string] -or $value -cnotmatch '^[a-f0-9]{64}$')) -or
        (-not $r.($pair[0]) -and $null -ne $value)) { throw "Diagnostic evidence digest rejected." }
    }
    if ($r.completedStages -isnot [array] -or $r.completedStages.Count -lt 1 -or
      $r.completedStages[0] -cne "worker-entry" -or $r.lastCompletedStage -cne $r.completedStages[-1]) { throw "Diagnostic stages rejected." }
    $position = -1
    foreach ($stage in $r.completedStages) {
      if ($stage -isnot [string] -or $stage -cnotin $diagStages -or [array]::IndexOf($diagStages,$stage) -le $position) { throw "Diagnostic stage order rejected." }
      $position = [array]::IndexOf($diagStages,$stage)
    }
    if (($null -ne $r.failedStage -and ($r.failedStage -isnot [string] -or $r.failedStage -cnotin $diagStages)) -or
      $r.failedPredicate -isnot [string] -or $r.failedPredicate -cnotin $diagPredicates -or
      $r.sanitizedCategory -isnot [string] -or $r.sanitizedCategory -cnotin $diagCategories -or
      (($r.sanitizedCategory -ceq "none") -ne ($null -eq $r.failedStage -and $r.failedPredicate -ceq "none"))) { throw "Diagnostic classification rejected." }
    if ($r.subjectClassification -isnot [string] -or $r.subjectClassification -cnotin $diagCategories) { throw "Diagnostic subject classification rejected." }
    if ($null -ne $r.workerExitCode -and $r.workerExitCode -eq 0 -and
      (-not $r.cleanupCompleted -or $r.lastCompletedStage -cne "worker-completed")) { throw "Diagnostic completion rejected." }
    if ($r.subjectSucceeded -and
      ($r.sanitizedCategory -cne "none" -or -not $r.cleanupCompleted -or $r.lastCompletedStage -cne "worker-completed" -or
        -not $r.processCreated -or -not $r.childProcessCreated -or $r.childExitCode -ne 0 -or
        -not $r.requestPresent -or -not $r.childStartedMarkerPresent -or -not $r.childResultPresent -or -not $r.parentResultPresent)) {
      throw "Functional subject success rejected."
    }
    if ($r.subjectSucceeded -and ($r.subjectClassification -cne "none" -or $r.subjectExitCode -ne 0)) {throw "Subject outcome rejected."}
    foreach ($key in @("bootstrapStartedMarkerDigest","bootstrapFinalDigest","invocationEnvelopeDigest","entryAdapterMarkerDigest","entryAdapterResultDigest")) {
      if ($null -ne $r.$key -and ($r.$key -isnot [string] -or $r.$key -cnotmatch '^[a-f0-9]{64}$')) {throw "Bootstrap receipt digest rejected."}
    }
    . (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildBootstrap.ps1") -ContractOnly
    foreach ($key in @("bootstrapLastStage","bootstrapFailureStage")) {
      if ($null -ne $r.$key -and ($r.$key -isnot [string] -or $r.$key -cnotin $script:RecoveryBootStages)) {throw "Bootstrap receipt stage rejected."}
    }
    if ($null -ne $r.bootstrapCategory -and $r.bootstrapCategory -cnotin $script:RecoveryBootCategories) {throw "Bootstrap receipt category rejected."}
    . (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildEntry.ps1") -ContractOnly
    foreach($key in @("entryAdapterLastStage","entryAdapterFailedStage")){
      if($null -ne $r.$key -and ($r.$key -isnot [string] -or $r.$key -cnotin $script:RecoveryEntryStages)){throw "Entry receipt stage rejected."}
    }
    if($null -ne $r.entryAdapterCategory -and $r.entryAdapterCategory -cnotin $script:RecoveryEntryCategories){throw "Entry receipt category rejected."}
    if($null -ne $r.entryAdapterPredicate -and $r.entryAdapterPredicate -cnotin $script:RecoveryEntryPredicates){throw "Entry receipt predicate rejected."}
    $digest = $r.receiptDigest
    Set-DiagDigest $r
    if ($digest -cnotmatch '^[a-f0-9]{64}$' -or $digest -cne $r.receiptDigest) { throw "Diagnostic digest rejected." }
    return $r
  }
  function Write-DiagReceipt {
    param([object]$Record, [string]$Directory)
    $root = Assert-DiagDirectory $Directory "diag7diag"
    Set-DiagDigest $Record
    $number = @(Get-ChildItem -LiteralPath $root -File -Force | Where-Object Name -match '^receipt-[0-9]{2}\.json$').Count
    if ($number -gt 50) { throw "Diagnostic receipt bound exceeded." }
    $path = Join-Path $root ("receipt-{0:D2}.json" -f $number)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes((Get-DiagJson $Record))
    $stream = [IO.File]::Open($path + ".tmp", [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
    [IO.File]::Move($path + ".tmp", $path)
    return $path
  }
  function Add-DiagStage {
    param([object]$Record, [string]$Stage, [string]$Directory)
    if ($Stage -cnotin $diagStages -or [array]::IndexOf($diagStages,$Stage) -le [array]::IndexOf($diagStages,$Record.lastCompletedStage)) {
      throw "Diagnostic progress rejected."
    }
    $Record.completedStages = @($Record.completedStages) + @($Stage); $Record.lastCompletedStage=$Stage
    [void](Write-DiagReceipt $Record $Directory)
  }
  if ($DiagnosticMode -eq "Schema") {
    if ($diagKeys.Count -ne (@($diagKeys | Select-Object -Unique)).Count -or
      $diagStages.Count -ne (@($diagStages | Select-Object -Unique)).Count) { throw "Diagnostic allowlist rejected." }
    Write-Output ("Schema/allowlist PASS; keys=" + $diagKeys.Count + "; stages=" + $diagStages.Count +
      "; categories=" + $diagCategories.Count + "; predicates=" + $diagPredicates.Count + "; TransportSuccess invocations=0")
    exit 0
  }
  if ($DiagnosticMode -eq "Worker") {
    $root = Assert-DiagDirectory $FixtureDirectory "diag7diag"
    if ($DiagnosticNonce -cnotmatch '^[a-f0-9]{32}$' -or [IO.Path]::GetFileName($root) -cne ("diag7diag-"+$DiagnosticNonce) -or
      $DiagnosticCase -cnotin (@($diagCases)+@("TransportSuccess"))) { throw "Diagnostic worker arguments rejected." }
    if ($DiagnosticCase -eq "ExitBeforeReceipt") { exit 93 }
    $receipt = New-DiagReceipt $DiagnosticNonce
    if ($DiagnosticCase -ne "TransportSuccess") {
      $receipt.completedStages=@($diagStages); $receipt.lastCompletedStage="worker-completed"
      $receipt.workerExitCode=0; $receipt.childProcessCreated=$true; $receipt.childExitCode=0
      foreach ($pair in @(@("requestPresent","requestDigest"), @("childStartedMarkerPresent","childStartedMarkerDigest"),
        @("childResultPresent","childResultDigest"), @("parentResultPresent","parentResultDigest"))) {
        $receipt.($pair[0])=$true; $receipt.($pair[1])="a"*64
      }
      $receipt.cleanupAttempted=$true; $receipt.cleanupCompleted=$true
      $receipt.subjectSucceeded=$true;$receipt.subjectExitCode=0
      switch ($DiagnosticCase) {
        "ValidSubjectFailure" {
          $receipt.completedStages=@($diagStages | Where-Object {$_ -cnotin @("child-started-marker-observed","child-result-observed")})
          $receipt.subjectSucceeded=$false;$receipt.subjectExitCode=1;$receipt.subjectClassification="child-exit-before-marker"
          $receipt.failedStage="child-started-marker-observed";$receipt.failedPredicate="success-contract-satisfied"
          $receipt.sanitizedCategory="child-exit-before-marker";$receipt.childExitCode=1
          $receipt.childStartedMarkerPresent=$false;$receipt.childStartedMarkerDigest=$null
          $receipt.childResultPresent=$false;$receipt.childResultDigest=$null
        }
        "ProcessCreationFailure" {
          $receipt=New-DiagReceipt $DiagnosticNonce; $receipt.processCreated=$false; $receipt.workerExitCode=91
          $receipt.failedStage="worker-entry"; $receipt.failedPredicate="worker-created"
          $receipt.sanitizedCategory="worker-process-creation-failure"
        }
        "InvalidStage" { $receipt.completedStages=@("worker-entry","invalid"); $receipt.lastCompletedStage="invalid" }
        "InvalidCategory" { $receipt.sanitizedCategory="invalid" }
        "CleanupResidue" { $receipt.temporaryResidueCount=1 }
      }
      $path = Write-DiagReceipt $receipt $root
      switch ($DiagnosticCase) {
        "Malformed" { [IO.File]::WriteAllText($path,"{}",[Text.UTF8Encoding]::new($false)) }
        "Stale" { [IO.File]::SetLastWriteTimeUtc($path,[DateTime]::UtcNow.AddMinutes(-10)) }
        "DigestTamper" { $receipt.receiptDigest="f"*64; [IO.File]::WriteAllText($path,(Get-DiagJson $receipt),[Text.UTF8Encoding]::new($false)) }
        "PartialWrite" { [IO.File]::Move($path,$path+".tmp") }
      }
      exit 0
    }
    # Actual one-shot worker. All observations are receipts or independently
    # validated closed transport records; streams are discarded, never retained.
    [void](Write-DiagReceipt $receipt $root)
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ("diag7-"+$DiagnosticNonce)
    $owned=$false; $failureStage="arguments-validated"; $predicate="arguments-valid"; $category="fixture-failure"
    $exitCode=91; $transportReturned=$false; $transportExit=$null; $request=$null; $evidenceValid=$true
    try {
      Add-DiagStage $receipt "arguments-validated" $root
      $failureStage="fixture-created"; $predicate="fixture-created"
      if (Test-Path -LiteralPath $fixture) { throw "Diagnostic fixture collision." }
      [void][IO.Directory]::CreateDirectory($fixture); $owned=$true
      [void](Assert-DiagDirectory $fixture "diag7")
      Add-DiagStage $receipt "fixture-created" $root
      $failureStage="contract-load-attempted"; $predicate="contract-import-returned"; $category="contract-load-failure"
      Add-DiagStage $receipt "contract-load-attempted" $root
      . (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1")
      Add-DiagStage $receipt "contract-loaded" $root
      # Capture the current committed identity once; provisional amendments must
      # not keep binding a simulation to the historical draft's HEAD.
      $diagnosticGit="C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
      $diagnosticRepository=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
      $diagnosticHeads=@(& $diagnosticGit -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $diagnosticRepository rev-parse HEAD)
      if ($LASTEXITCODE -ne 0 -or $diagnosticHeads.Count -ne 1 -or
        $diagnosticHeads[0] -cnotmatch '^[a-f0-9]{40}$') { throw "Diagnostic repository identity rejected." }
      $diagnosticHead=$diagnosticHeads[0]
      $failureStage="transport-entry"; $predicate="transport-invocation-returned"; $category="transport-invocation-failure"
      Add-DiagStage $receipt "transport-entry" $root
      & (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryDiagnostic.ps1") -ExecutionMode Simulation `
        -AuthorizationId RP-TURN-019-R4-RECOVERY-00000000 -InvocationNonce $DiagnosticNonce `
        -RepositoryHead $diagnosticHead -EvidenceDirectory $fixture -Scenario Success *> $null
      $transportExit=$LASTEXITCODE; $transportReturned=$true
    } catch {
      $receipt.failedStage=$failureStage; $receipt.failedPredicate=$predicate; $receipt.sanitizedCategory=$category
    } finally {
      try {
        if ($owned -and [IO.File]::Exists((Join-Path $fixture "request-00.json"))) {
          $binding=[pscustomobject]@{
            executionMode="Simulation"; authorizationId="RP-TURN-019-R4-RECOVERY-00000000"; invocationNonce=$DiagnosticNonce
            repositoryHead=$diagnosticHead
            parentScriptSha256=$receipt.draftFileSha256.'Invoke-RisePalsRecoveryDiagnostic.ps1'
            childScriptSha256=$receipt.draftFileSha256.'Invoke-RisePalsRecoveryChild.ps1'
            contractScriptSha256=$receipt.draftFileSha256.'recovery-diagnostic-contract.ps1'
            liveScriptSha256=(Get-DiagHash -Path (Join-Path $PSScriptRoot "Invoke-RisePalsCandidateLiveSequence.ps1"))
          }
          $request=Read-RisePalsRecoveryRecord (Join-Path $fixture "request-00.json") $fixture $binding $null
          $receipt.requestPresent=$true; $receipt.requestDigest=$request.recordDigest
          Add-DiagStage $receipt "request-create-attempted" $root
          Add-DiagStage $receipt "request-written" $root
          Add-DiagStage $receipt "request-reopened" $root
          . (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildBootstrap.ps1") -ContractOnly
          $bootstrapRecord=$null
          foreach ($file in @(Get-ChildItem -LiteralPath $fixture -File | Where-Object Name -match '^bootstrap-[0-9]{2}\.json$' | Sort-Object Name)) {
            $bootstrapRecord=Read-RecoveryBootRecord $file.FullName $fixture $request $receipt.draftFileSha256.'Invoke-RisePalsRecoveryChildBootstrap.ps1' "None" $bootstrapRecord
            if ($bootstrapRecord.sequence -eq 0) {$receipt.bootstrapStartedMarkerDigest=$bootstrapRecord.recordDigest}
            $receipt.bootstrapLastStage=$bootstrapRecord.stage
            if (-not $bootstrapRecord.stageCompleted) {
              $receipt.bootstrapFailureStage=$bootstrapRecord.stage;$receipt.bootstrapCategory=$bootstrapRecord.category
            }
          }
          if ($null -ne $bootstrapRecord) {
            $receipt.childProcessCreated=$bootstrapRecord.childProcessCreated;$receipt.childExitCode=$bootstrapRecord.childExitCode
            if ($bootstrapRecord.stage -ceq "bootstrap-result-reopened") {$receipt.bootstrapFinalDigest=$bootstrapRecord.recordDigest}
          }
          if([IO.File]::Exists((Join-Path $fixture "invocation-envelope.json"))){
            . (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildEntry.ps1") -ContractOnly
            $diagEnvelope=Read-RecoveryInvocationEnvelope (Join-Path $fixture "invocation-envelope.json") $bootstrapRecord.invocationEnvelopeDigest
            $receipt.invocationEnvelopeDigest=$diagEnvelope.envelopeDigest
            $diagEntry=$null
            foreach($file in @(Get-ChildItem -LiteralPath $fixture -File | Where-Object Name -match '^entry-[0-9]{2}\.json$' | Sort-Object Name)){
              $diagEntry=Read-RecoveryChildEntryRecord $file.FullName $diagEnvelope $diagEntry
              if($diagEntry.sequence -eq 0){$receipt.entryAdapterMarkerDigest=$diagEntry.recordDigest}
              if(-not $diagEntry.stageCompleted){$receipt.entryAdapterFailedStage=$diagEntry.stage;$receipt.entryAdapterCategory=$diagEntry.category;$receipt.entryAdapterPredicate=$diagEntry.failedPredicate}
            }
            if($null -ne $diagEntry){$receipt.entryAdapterResultDigest=$diagEntry.recordDigest;$receipt.entryAdapterLastStage=$diagEntry.stage
              $receipt.entryAdapterChildExitCode=$diagEntry.childExitCode
              if($null -ne $diagEntry.childExitCode){$receipt.childExitCode=$diagEntry.childExitCode}}
          }
          $previous=$null; $parents=@()
          foreach ($file in @(Get-ChildItem -LiteralPath $fixture -File | Where-Object Name -match '^parent-[0-9]{2}\.json$' | Sort-Object Name)) {
            $previous=Read-RisePalsRecoveryRecord $file.FullName $fixture $request $previous; $parents+=@($previous)
          }
          foreach ($record in $parents) {
            if ($record.stageCompleted -and $record.stage -cin @("child-launch-attempted","child-process-created")) {
              Add-DiagStage $receipt $record.stage $root
            }
            if (-not $record.stageCompleted) {
              $receipt.failedStage=if ($record.stage -ceq "request-write-attempted") { "request-create-attempted" } else { $record.stage }
              $receipt.failedPredicate="success-contract-satisfied"; $receipt.sanitizedCategory=$record.category
              if ($null -ne $record.exitCode) { $receipt.bootstrapExitCode=$record.exitCode }
            }
          }
          $child=$null
          foreach ($file in @(Get-ChildItem -LiteralPath $fixture -File | Where-Object Name -match '^child-[0-9]{2}\.json$' | Sort-Object Name)) {
            $child=Read-RisePalsRecoveryRecord $file.FullName $fixture $request $child
            if ($child.sequence -eq 0) {
              $receipt.childStartedMarkerPresent=$true; $receipt.childStartedMarkerDigest=$child.recordDigest
              Add-DiagStage $receipt "child-started-marker-observed" $root
            }
            if ($child.stage -ceq "recovery-result") {
              $receipt.childResultPresent=$true; $receipt.childResultDigest=$child.recordDigest; $receipt.childExitCode=$child.exitCode
              Add-DiagStage $receipt "child-result-observed" $root
            }
          }
          if ($null -ne $previous -and $previous.stage -ceq "parent-result-reopened" -and $previous.stageCompleted) {
            $receipt.parentResultPresent=$true; $receipt.parentResultDigest=$previous.recordDigest
            Add-DiagStage $receipt "parent-result-written" $root
            Add-DiagStage $receipt "parent-result-reopened" $root
          }
        }
        if ($transportReturned -and $transportExit -eq 0 -and $receipt.parentResultPresent -and
          $receipt.childResultPresent -and $receipt.childExitCode -eq 0 -and $receipt.sanitizedCategory -ceq "none") { $exitCode=0 }
        elseif ($receipt.sanitizedCategory -ceq "none") {
          $receipt.failedStage="parent-result-reopened"; $receipt.failedPredicate="success-contract-satisfied"
          $receipt.sanitizedCategory="transport-assertion-failure"
        }
      } catch {
        $evidenceValid=$false
        if ($receipt.sanitizedCategory -ceq "none") {
          $receipt.failedStage="request-reopened"; $receipt.failedPredicate="durable-records-valid"
          $receipt.sanitizedCategory="durable-evidence-invalid"
        }
      }
      $receipt.cleanupAttempted=$true
      Add-DiagStage $receipt "cleanup-attempted" $root
      try {
        if ($owned) { Remove-DiagDirectory $fixture "diag7" '^((request|parent|child|bootstrap|entry)-[0-9]{2}\.json|invocation-envelope\.json)(\.tmp)?$' }
        $receipt.cleanupCompleted=$true; $receipt.temporaryResidueCount=0
        Add-DiagStage $receipt "cleanup-completed" $root
      } catch {
        $exitCode=91; $receipt.cleanupCompleted=$false; $receipt.temporaryResidueCount=1
        if ($receipt.sanitizedCategory -ceq "none") {
          $receipt.failedStage="cleanup-completed"; $receipt.failedPredicate="flat-owned-cleanup"; $receipt.sanitizedCategory="cleanup-failure"
        }
      }
      $receipt.subjectClassification=$receipt.sanitizedCategory
      $receipt.subjectExitCode=if ($null -ne $receipt.childExitCode) {$receipt.childExitCode} else {$transportExit}
      $receipt.subjectSucceeded=($exitCode -eq 0)
      # Diagnosis success is independent of subject success; validation and
      # cleanup failures still cannot return diagnostic success.
      $exitCode=if ($receipt.cleanupCompleted -and $evidenceValid) {0} else {91}
      $receipt.workerExitCode=$exitCode
      Add-DiagStage $receipt "worker-completed" $root
    }
    exit $exitCode
  }
  $selected = @(if ($DiagnosticMode -eq "Synthetic") {$diagCases}
    elseif ($DiagnosticMode -eq "SubjectFailure") {"ValidSubjectFailure"}
    elseif ($DiagnosticMode -eq "InvalidReceipt") {"Malformed"}
    else {"TransportSuccess"})
  $diagnosticFailed=$false
  foreach ($case in $selected) {
    $nonce=[guid]::NewGuid().ToString("N"); $started=[DateTime]::UtcNow
    $root=Join-Path ([IO.Path]::GetTempPath()) ("diag7diag-"+$nonce)
    if (Test-Path -LiteralPath $root) { throw "Diagnostic root collision." }
    [void][IO.Directory]::CreateDirectory($root)
    $process=$null; $observedExit=$null; $validated=$null; $classification="worker-process-creation-failure"
    try {
      $argsList=@("-NoLogo","-NoProfile","-NonInteractive","-File",('"'+$PSCommandPath+'"'),
        "-DiagnosticMode","Worker","-DiagnosticCase",$case,"-DiagnosticNonce",$nonce,
        "-FixtureDirectory",('"'+$root+'"'))
      try {
        $process=Start-Process -FilePath (Join-Path $PSHOME "powershell.exe") -ArgumentList $argsList -WindowStyle Hidden -PassThru
      } catch {
        Write-Output "worker-process-creation-failure; no worker exit or receipt established"
        throw "Diagnostic process creation failed; no raw launch evidence retained."
      }
      if (-not $process.WaitForExit(360000)) { throw "Diagnostic worker exit unproven; no termination or active-resource deletion permitted." }
      $observedExit=$process.ExitCode
      $files=@(Get-ChildItem -LiteralPath $root -File -Force | Where-Object Name -match '^receipt-[0-9]{2}\.json$' | Sort-Object Name)
      if ($files.Count -eq 0) {
        $classification=if (@(Get-ChildItem -LiteralPath $root -Force).Count) { "worker-receipt-invalid" } else { "worker-exit-before-receipt" }
      } else {
        $classification="worker-receipt-invalid"
        try {
          foreach ($file in $files) { $validated=Read-DiagReceipt $file.FullName $nonce $started }
          if ($null -eq $validated.workerExitCode) { throw "Incomplete final receipt." }
          if ($case -cin @("TransportSuccess","ValidSubjectFailure") -and $validated.workerExitCode -ne $observedExit) { throw "Worker exit mismatch." }
          if ($case -ceq "ValidSubjectFailure" -and ($validated.subjectSucceeded -ne $false -or
            $validated.subjectExitCode -ne 1 -or $validated.subjectClassification -cne "child-exit-before-marker")) {
            throw "Synthetic exact subject outcome mismatch."
          }
          $classification=$validated.sanitizedCategory
        } catch { $validated=$null }
      }
      if ($DiagnosticMode -eq "Synthetic") {
        $expected=switch($case) { "ValidSuccess" {"none"}; "ValidSubjectFailure" {"child-exit-before-marker"}; "ProcessCreationFailure" {"worker-process-creation-failure"}; "ExitBeforeReceipt" {"worker-exit-before-receipt"}; default {"worker-receipt-invalid"} }
        if ($classification -cne $expected -or ($case -ne "ExitBeforeReceipt" -and $observedExit -ne 0)) { throw ("Synthetic receipt FAIL: "+$case) }
        Write-Output ("Synthetic receipt PASS: "+$case+"; classification="+$classification)
      } else {
        Write-Output ("Diagnostic case="+$case+"; observed worker exit="+$observedExit+"; classification="+$classification)
        if ($null -ne $validated) { Write-Output (Get-DiagJson $validated) }
        if ($null -eq $validated -or $observedExit -ne 0) {$diagnosticFailed=$true}
        # The worker's diagnostic success remains distinct from subject success.
        # This explicit positive transport gate requires both, using the reopened
        # validated receipt rather than treating exit zero as transport authority.
        if ($DiagnosticMode -ceq "Transport" -and ($null -eq $validated -or
          -not $validated.subjectSucceeded -or $validated.subjectExitCode -ne 0 -or
          $validated.subjectClassification -cne "none")) {$diagnosticFailed=$true}
      }
    } finally {
      $canRemove=$true
      if ($null -ne $process) {
        $canRemove=$process.HasExited
        $process.Dispose()
      }
      if ($canRemove) { Remove-DiagDirectory $root "diag7diag" '^receipt-[0-9]{2}\.json(\.tmp)?$' }
    }
  }
  Write-Output ("Diagnostic exact receipt-directory cleanup PASS; executed cases="+$selected.Count+"; UAC=0; elevated children=0; captures=0")
  if ($diagnosticFailed) {exit 94};exit 0
}

. (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1")

$cases = @(
  "RequestReopen", "LiveProgression", "MissingProperty", "ExtraProperty", "WrongType",
  "WrongNonce", "WrongHead", "WrongAuthorization", "WrongHash", "DigestTamper",
  "DuplicateDecodedKey", "Stale", "Future", "StageSkip", "StageRegression",
  "WrongFilename", "InterruptedWrite", "CleanupClaim", "CleanupType", "SequenceType"
)
$transportCases = @("Success", "Cancelled", "CreationFailure", "WaitFailure", "BeforeMarker",
  "BeforeImportFailure", "ChildFailure", "MarkerMalformed", "MarkerStale", "MarkerTamper",
  "MarkerReplay", "ResultPersistence", "ResultReopen")
$cases += @($transportCases | ForEach-Object { "Transport" + $_ })
if ($Scenario -ne "") {
  if ($Scenario -cnotin $cases) { throw "Unknown fixture scenario." }
  if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "Fixture elevation rejected." }
  $directory = [IO.Path]::GetFullPath($FixtureDirectory)
  if ([IO.Path]::GetDirectoryName($directory).TrimEnd('\') -cne [IO.Path]::GetTempPath().TrimEnd('\') -or
    [IO.Path]::GetFileName($directory) -cnotmatch '^diag7-[a-f0-9]{32}$') { throw "Fixture boundary rejected." }
  $nonce = [IO.Path]::GetFileName($directory).Substring(6)
  if ($Scenario.StartsWith("Transport", [StringComparison]::Ordinal)) {
    $transportCase = $Scenario.Substring(9)
    $parentPath = Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryDiagnostic.ps1"
    $git = "C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
    $repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
    $head = (& $git -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $repository rev-parse HEAD).Trim()
    & $parentPath -ExecutionMode Simulation -AuthorizationId RP-TURN-019-R4-RECOVERY-00000000 `
      -InvocationNonce $nonce -RepositoryHead $head -EvidenceDirectory $directory -Scenario $transportCase
    $observedExit = $LASTEXITCODE
    $binding = [pscustomobject]@{
      executionMode = "Simulation"; authorizationId = "RP-TURN-019-R4-RECOVERY-00000000"
      invocationNonce = $nonce; repositoryHead = $head
      parentScriptSha256 = Get-RisePalsRecoveryHash $parentPath
      childScriptSha256 = Get-RisePalsRecoveryHash (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChild.ps1")
      liveScriptSha256 = Get-RisePalsRecoveryHash (Join-Path $PSScriptRoot "Invoke-RisePalsCandidateLiveSequence.ps1")
      contractScriptSha256 = Get-RisePalsRecoveryHash (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1")
    }
    $request = Read-RisePalsRecoveryRecord (Join-Path $directory "request-00.json") $directory $binding $null
    $last = $null
    $parents = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $directory -Filter "parent-*.json" | Sort-Object Name)) {
      $last = Read-RisePalsRecoveryRecord $file.FullName $directory $request $last
      $parents += $last
    }
    $expectedExit = if ($transportCase -eq "Success") { 0 } elseif ($transportCase -in @("ResultPersistence", "ResultReopen")) { 91 } else { 92 }
    $expectedCategory = switch ($transportCase) {
      "Cancelled" { "uac-cancelled" }
      "CreationFailure" { "bootstrap-process-not-created" }
      "WaitFailure" { "wait-failure" }
      "BeforeMarker" { "bootstrap-exit-before-marker" }
      { $_ -in @("BeforeImportFailure", "ChildFailure") } { "child-invocation-failure" }
      { $_ -in @("MarkerMalformed", "MarkerStale", "MarkerTamper", "MarkerReplay") } { "evidence-invalid" }
      default { "none" }
    }
    $failures = @($parents | Where-Object { -not $_.stageCompleted })
    $good = $observedExit -eq $expectedExit -and @($parents | Where-Object { $null -ne $_.cleanupCompleted }).Count -eq 0
    if ($expectedCategory -ne "none") {
      $good = $good -and $failures.Count -eq 1 -and $failures[0].category -ceq $expectedCategory
    }
    if ($transportCase -notin @("ResultPersistence", "ResultReopen")) {
      $good = $good -and $last.stage -ceq "parent-result-reopened"
    }
    if ($transportCase -in @("Success", "ChildFailure")) {
      $childLast = $null
      foreach ($number in 0..3) {
        $childLast = Read-RisePalsRecoveryRecord (Join-Path $directory ("child-{0:D2}.json" -f $number)) $directory $request $childLast
      }
      $observed = @($parents | Where-Object { $_.stage -ceq "child-result-observed" })
      $good = $good -and $childLast.cleanupCompleted -eq ($transportCase -eq "Success")
      if($transportCase -eq "Success"){
        $good=$good -and $observed.Count -eq 1 -and $observed[0].evidenceDigest -ceq $childLast.recordDigest
      }else{
        # A rejected entry result must not masquerade as parent-observed child
        # success. Independently validate the denied, digest-bound adapter chain.
        . (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildEntry.ps1") -ContractOnly
        $fixtureEnvelope=Read-RecoveryInvocationEnvelope (Join-Path $directory "invocation-envelope.json") $last.invocationEnvelopeDigest
        $fixtureEntry=$null;$entryFailures=@()
        foreach($file in @(Get-ChildItem -LiteralPath $directory -File | Where-Object Name -match '^entry-[0-9]{2}\.json$' | Sort-Object Name)){
          $fixtureEntry=Read-RecoveryChildEntryRecord $file.FullName $fixtureEnvelope $fixtureEntry
          if(-not $fixtureEntry.stageCompleted){$entryFailures+=@($fixtureEntry)}
        }
        $good=$good -and $observed.Count -eq 0 -and $entryFailures.Count -eq 1 -and
          $entryFailures[0].category -ceq "child-invocation-failure" -and $fixtureEntry.recordDigest -ceq $last.entryAdapterDigest -and
          $fixtureEntry.childResultDigest -ceq $childLast.recordDigest -and $fixtureEntry.childExitCode -eq $childLast.exitCode
      }
    }
    $verdict = [ordered]@{scenario=$Scenario;passed=[bool]$good;rejected=($expectedExit -ne 0);uacCount=0;hostOperations=0}
    [IO.File]::WriteAllText((Join-Path $directory "verdict.json"),
      ($verdict | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
    if (-not $good) { exit 89 }; exit 0
  }
  $binding = [pscustomobject][ordered]@{
    executionMode = "Simulation"
    authorizationId = "RP-TURN-019-R4-RECOVERY-00000000"
    invocationNonce = $nonce
    repositoryHead = ("a" * 40)
    parentScriptSha256 = ("b" * 64)
    childScriptSha256 = ("c" * 64)
    liveScriptSha256 = ("d" * 64)
    contractScriptSha256 = Get-RisePalsRecoveryHash (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1")
  }
  $request = New-RisePalsRecoveryRecord -Binding $binding -Kind request -Stage request-created
  $path = Write-RisePalsRecoveryRecord $request $directory
  $request = Read-RisePalsRecoveryRecord $path $directory $binding $null
  $record = New-RisePalsRecoveryRecord $request live live-process-entry $null
  $previous = $null
  $reject = $Scenario -cnotin @("RequestReopen", "LiveProgression")
  switch ($Scenario) {
    "LiveProgression" {
      foreach ($stage in $script:RisePalsRecoveryStageOrders.live) {
        $next = New-RisePalsRecoveryRecord $request live $stage $previous
        $p = Write-RisePalsRecoveryRecord $next $directory
        $previous = Read-RisePalsRecoveryRecord $p $directory $request $previous
      }
      if ($previous.stage -cne "live-state-written" -or $null -ne $previous.cleanupCompleted) {
        throw "Live progression assertion failed."
      }
    }
    "MissingProperty" { $record.PSObject.Properties.Remove("exitCode") }
    "ExtraProperty" { $record | Add-Member NoteProperty unexpected $true }
    "WrongType" { $record.stage = 1 }
    "WrongNonce" { $record.invocationNonce = "f" * 32 }
    "WrongHead" { $record.repositoryHead = "f" * 40 }
    "WrongAuthorization" { $record.authorizationId = "RP-TURN-019-R4-RECOVERY-11111111" }
    "WrongHash" { $record.childScriptSha256 = "f" * 64 }
    "DigestTamper" { $record.recordDigest = "f" * 64 }
    "Stale" { $record.recordedAtUtc = [DateTimeOffset]::UtcNow.AddSeconds(-301).ToString("o") }
    "Future" { $record.recordedAtUtc = [DateTimeOffset]::UtcNow.AddSeconds(60).ToString("o") }
    "StageSkip" { $record.stage = "security-bootstrap-started" }
    "StageRegression" {
      $previous = New-RisePalsRecoveryRecord $request live raw-arguments-validated $record
      $record.sequence = 2
      $record.previousDigest = $previous.recordDigest
    }
    "CleanupClaim" { $record.cleanupCompleted = $true }
    "CleanupType" { $record.cleanupCompleted = "false" }
    "SequenceType" { $record.sequence = "0" }
  }
  $rejected = $false
  if ($reject) {
    try {
      switch ($Scenario) {
        "DuplicateDecodedKey" {
          $json = ($record | ConvertTo-Json -Compress).Replace('"kind":"live"', '"kind":"live","\u006bind":"live"')
          [void](ConvertFrom-RisePalsRecoveryJson $json)
        }
        "WrongFilename" {
          $p = Write-RisePalsRecoveryRecord $record $directory
          $wrong = Join-Path $directory "live-01.json"
          [IO.File]::Move($p, $wrong)
          [void](Read-RisePalsRecoveryRecord $wrong $directory $request $null)
        }
        "InterruptedWrite" {
          $partial = Join-Path $directory "live-00.json.tmp"
          [IO.File]::WriteAllText($partial, "{", [Text.UTF8Encoding]::new($false))
          [void](Write-RisePalsRecoveryRecord $record $directory)
        }
        default {
          if ($Scenario -cnotin @("DigestTamper", "MissingProperty")) {
            $record.recordDigest = Get-RisePalsRecoveryRecordDigest $record
          }
          [void](Assert-RisePalsRecoveryRecord $record $request $previous)
        }
      }
    } catch { $rejected = $true }
    if (-not $rejected) { throw "Negative fixture was accepted." }
  }
  # The parent reopens this synthetic verdict. Process stdout is not authority.
  $verdict = [ordered]@{scenario=$Scenario;passed=$true;rejected=$rejected;uacCount=0;hostOperations=0}
  [IO.File]::WriteAllText((Join-Path $directory "verdict.json"),
    ($verdict | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
  exit 0
}

$powerShell = Join-Path $PSHOME "powershell.exe"
$passed = 0
foreach ($case in $cases) {
  $directory = Join-Path ([IO.Path]::GetTempPath()) ("diag7-" + [guid]::NewGuid().ToString("N"))
  [void][IO.Directory]::CreateDirectory($directory)
  $process = $null
  try {
    $arguments = @("-NoLogo", "-NoProfile", "-NonInteractive", "-File", ('"' + $PSCommandPath + '"'),
      "-FixtureDirectory", ('"' + $directory + '"'), "-Scenario", $case)
    $process = Start-Process -FilePath $powerShell -ArgumentList $arguments -WindowStyle Hidden -PassThru
    # No kill or retry: only this test-owned process is awaited and disposed.
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw ("Recovery contract fixture failed: " + $case) }
    $verdictPath = Join-Path $directory "verdict.json"
    $verdict = ConvertFrom-RisePalsRecoveryJson ([Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes($verdictPath)))
    if ($verdict.scenario -cne $case -or $verdict.passed -ne $true -or
      $verdict.uacCount -ne 0 -or $verdict.hostOperations -ne 0) { throw "Fixture verdict rejected." }
    $passed++
  } finally {
    if ($null -ne $process) { $process.Dispose() }
    # Validate the complete flat test-owned target before deleting any file.
    $rootItem = Get-Item -LiteralPath $directory -Force
    $children = @(Get-ChildItem -LiteralPath $directory -Force)
    if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
      [IO.Path]::GetDirectoryName($rootItem.FullName).TrimEnd('\') -cne [IO.Path]::GetTempPath().TrimEnd('\') -or
      @($children | Where-Object { $_.PSIsContainer -or
        ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        $_.Name -cnotmatch '^(verdict\.json|invocation-envelope\.json(\.tmp)?|(request|live|parent|child|bootstrap|entry)-[0-9]{2}\.json(\.tmp)?)$' }).Count -ne 0) {
      throw "Fixture cleanup rejected."
    }
    foreach ($child in $children) { Remove-Item -LiteralPath $child.FullName -Force }
    Remove-Item -LiteralPath $directory -Force
    if (Test-Path -LiteralPath $directory) { throw "Fixture cleanup incomplete." }
  }
}
Write-Output ("Recovery record contract PASS: " + $passed + "/" + $cases.Count + "; UAC=0; captures=0; residue=0.")
