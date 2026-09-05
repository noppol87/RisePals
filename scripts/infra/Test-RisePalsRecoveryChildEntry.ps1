[CmdletBinding()]
param([ValidateSet("Envelope","Record","Adapter")][string]$Mode="Envelope")
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
if($PSVersionTable.PSEdition -cne "Desktop" -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1 -or
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw "Non-elevated PS5.1 required."}
. (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1")
. (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildEntry.ps1") -ContractOnly
$cases=switch($Mode){
  "Envelope" {@("Valid","Missing","Extra","Duplicate","Malformed","Noncanonical","Digest","Stale","Future","Replay",
    "Authorization","Nonce","Head","Directory","AdapterHash","ChildHash","ContractHash","LiveHash","BootstrapHash","ParentHash","Type","Scenario")}
  "Record" {@("Valid","Missing","Duplicate","Extra","Type","Stage","Category","Predicate","Digest")}
  "Adapter" {@("FixtureSuccess","FixtureBeforeEntry","FixtureMarkerPersistence","FixtureMarkerReopen","FixtureParse","FixtureBinding",
    "FixtureInvocation","FixtureExit","FixtureTamper","FixtureAfterMarker","FixtureResultPersistence","FixtureResultReopen","MixedModules","WhatIf")}
}
$passed=0
foreach($case in $cases){
  $nonce=[guid]::NewGuid().ToString("N");$root=Join-Path ([IO.Path]::GetTempPath()) ("diag7-"+$nonce)
  if(Test-Path -LiteralPath $root){throw "Fixture collision."}
  [void][IO.Directory]::CreateDirectory($root)
  $process=$null;$processExited=$true
  try{
    $binding=[pscustomobject]@{executionMode="Simulation";authorizationId="RP-TURN-019-R4-RECOVERY-00000000"
      invocationNonce=$nonce;repositoryHead="c6a2d359d2d8670c40fddadcaee2d0da521a4d12"
      parentScriptSha256=(Get-RecoveryEntryHash -Path (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryDiagnostic.ps1"))
      childScriptSha256=(Get-RecoveryEntryHash -Path (Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChild.ps1"))
      contractScriptSha256=(Get-RecoveryEntryHash -Path (Join-Path $PSScriptRoot "recovery-diagnostic-contract.ps1"))
      liveScriptSha256=(Get-RecoveryEntryHash -Path (Join-Path $PSScriptRoot "Invoke-RisePalsCandidateLiveSequence.ps1"))}
    $request=New-RisePalsRecoveryRecord $binding request request-created $null
    $requestPath=Write-RisePalsRecoveryRecord $request $root
    $request=Read-RisePalsRecoveryRecord $requestPath $root $binding $null
    $scenario=if($Mode -ceq "Adapter" -and $case -cnotin @("MixedModules","WhatIf")){$case}else{"FixtureSuccess"}
    Write-RecoveryEntryAtomic (Join-Path $root "child-fixture.ps1") $root $nonce (Get-RecoveryEntryFixture $scenario)
    $envelope=New-RecoveryInvocationEnvelope $request $root $scenario
    $path=Write-RecoveryInvocationEnvelope $envelope
    $envelope=Read-RecoveryInvocationEnvelope $path $envelope.envelopeDigest
    $envelopeHash=Get-RecoveryEntryHash -Path $path
    $requestHash=Get-RecoveryEntryHash -Path $requestPath
    if($Mode -ceq "Envelope"){
      if($case -cne "Valid"){
        $before=Get-RecoveryEntryHash -Path $path
        if($case -ceq "Replay"){
          $rejected=$false;try{[void](Write-RecoveryInvocationEnvelope $envelope)}catch{$rejected=$true}
          if(-not $rejected -or (Get-RecoveryEntryHash -Path $path) -cne $before){throw "Envelope replay preservation failed."}
        }else{
          switch($case){
            "Missing" {$envelope.PSObject.Properties.Remove("scenario")}
            "Extra" {$envelope | Add-Member NoteProperty extra $true}
            "Digest" {$envelope.envelopeDigest="f"*64}
            "Authorization" {$envelope.authorizationId="RP-TURN-019-R4-RECOVERY-11111111"}
            "Nonce" {$envelope.invocationNonce="f"*32}
            "Head" {$envelope.repositoryHead="f"*40}
            "Directory" {$envelope.evidenceDirectory=Join-Path ([IO.Path]::GetTempPath()) ("diag7-"+("f"*32))}
            "AdapterHash" {$envelope.entryAdapterScriptSha256="f"*64}
            "ChildHash" {$envelope.childScriptSha256="f"*64}
            "ContractHash" {$envelope.contractScriptSha256="f"*64}
            "LiveHash" {$envelope.liveScriptSha256="f"*64}
            "BootstrapHash" {$envelope.bootstrapScriptSha256="f"*64}
            "ParentHash" {$envelope.parentScriptSha256="f"*64}
            "Type" {$envelope.scenario=$false}
            "Scenario" {$envelope.scenario="unknown"}
            {$_ -cin @("Stale","Future")} {
              $request.recordedAtUtc=if($case -ceq "Stale"){[DateTimeOffset]::UtcNow.AddSeconds(-301).ToString("o")}else{[DateTimeOffset]::UtcNow.AddSeconds(90).ToString("o")}
              $request.recordDigest=Get-RisePalsRecoveryRecordDigest $request
              [IO.File]::WriteAllText($requestPath,($request | ConvertTo-Json -Depth 4 -Compress),[Text.UTF8Encoding]::new($false))
              $envelope.requestDigest=$request.recordDigest
            }
          }
          if($case -cnotin @("Missing","Extra","Digest")){$envelope.envelopeDigest=Get-RecoveryEntryDigest $envelope $script:RecoveryEnvelopeKeys "envelopeDigest"}
          $json=$envelope | ConvertTo-Json -Depth 4 -Compress
          if($case -ceq "Duplicate"){$json=$json.Replace('"scenario":"FixtureSuccess"','"scenario":"FixtureSuccess","scenario":"FixtureSuccess"')}
          if($case -ceq "Malformed"){$json="{"}
          if($case -ceq "Noncanonical"){$json=" "+$json}
          [IO.File]::WriteAllText($path,$json,[Text.UTF8Encoding]::new($false))
          $rejected=$false;try{[void](Read-RecoveryInvocationEnvelope $path $envelope.envelopeDigest)}catch{$rejected=$true}
          if(-not $rejected){throw ("Envelope rejection failed: "+$case)}
        }
      }
    }elseif($Mode -ceq "Record"){
      $recordPath=Write-RecoveryChildEntryRecord $envelope "entry-adapter-process-entry" $null
      $record=Read-RecoveryChildEntryRecord $recordPath $envelope $null
      if($case -cne "Valid"){
        switch($case){
          "Missing" {$record.PSObject.Properties.Remove("childExitCode")}
          "Extra" {$record | Add-Member NoteProperty extra $true}
          "Type" {$record.stageCompleted="true"}
          "Stage" {$record.stage="unknown"}
          "Category" {$record.category="unknown"}
          "Predicate" {$record.failedPredicate="unknown"}
          "Digest" {$record.recordDigest="f"*64}
        }
        $json=$record | ConvertTo-Json -Depth 4 -Compress
        if($case -ceq "Duplicate"){$json=$json.Replace('"stageCompleted":true','"stageCompleted":true,"stageCompleted":true')}
        [IO.File]::WriteAllText($recordPath,$json,[Text.UTF8Encoding]::new($false))
        $rejected=$false;try{[void](Read-RecoveryChildEntryRecord $recordPath $envelope $null)}catch{$rejected=$true}
        if(-not $rejected){throw ("Entry schema rejection failed: "+$case)}
      }
    }else{
      $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=Join-Path $PSHOME "powershell.exe"
      $info.Arguments=@("-NoLogo","-NoProfile","-NonInteractive","-File",('"'+(Join-Path $PSScriptRoot "Invoke-RisePalsRecoveryChildEntry.ps1")+'"'),
        "-EnvelopePath",('"'+$path+'"'),"-EnvelopeDigest",$envelope.envelopeDigest) -join " "
      $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
      if($case -ceq "WhatIf"){$info.Arguments+=" -WhatIf"}
      if($case -ceq "MixedModules"){$info.EnvironmentVariables["PSModulePath"]="C:\Program Files\PowerShell\7\Modules;"+$info.EnvironmentVariables["PSModulePath"]}
      $process=[Diagnostics.Process]::new();$process.StartInfo=$info
      if(-not $process.Start()){throw "Entry fixture process creation failed."}
      $processExited=$false
      if(-not $process.WaitForExit(60000)){throw "Entry fixture exit unproven; no termination permitted."}
      $processExited=$true;$exitCode=$process.ExitCode
      $expected=switch($case){
        {$_ -cin @("FixtureSuccess","MixedModules","WhatIf")} {0}
        "FixtureBeforeEntry" {85}
        {$_ -cin @("FixtureResultPersistence","FixtureResultReopen")} {87}
        default {86}
      }
      if($exitCode -ne $expected){throw ("Entry fixture exit failed: "+$case+"; exit="+$exitCode)}
      $files=@(Get-ChildItem -LiteralPath $root -File | Where-Object Name -match '^entry-[0-9]{2}\.json$' | Sort-Object Name)
      if($case -ceq "WhatIf"){
        if($files.Count -ne 0 -or
          @(Get-ChildItem -LiteralPath $root -File | Where-Object Name -match '^child-[0-9]{2}\.json$').Count -ne 0 -or
          (Get-RecoveryEntryHash -Path $path) -cne $envelopeHash -or
          (Get-RecoveryEntryHash -Path $requestPath) -cne $requestHash -or
          @(Get-ChildItem -LiteralPath $root -Force).Count -ne 3){throw "Entry WhatIf wrote evidence or changed input."}
      }elseif($case -ceq "FixtureBeforeEntry"){
        if($files.Count){throw "Entry-before-marker fixture unexpectedly produced marker."}
      }else{
        if(-not $files.Count){throw "Entry fixture evidence absent."}
        $last=$null;$failures=@()
        foreach($file in $files){$last=Read-RecoveryChildEntryRecord $file.FullName $envelope $last;if(-not $last.stageCompleted){$failures+=@($last)}}
        $category=switch($case){
          "FixtureMarkerPersistence" {"entry-marker-persistence-failure"};"FixtureMarkerReopen" {"entry-marker-reopen-failure"}
          "FixtureParse" {"child-source-parse-failure"};"FixtureBinding" {"child-parameter-binding-failure"}
          "FixtureInvocation" {"child-invocation-failure"};"FixtureExit" {"child-entry-marker-missing"}
          "FixtureTamper" {"child-entry-marker-invalid"};"FixtureAfterMarker" {"child-invocation-failure"}
          "FixtureResultPersistence" {"entry-result-persistence-failure"};"FixtureResultReopen" {"entry-result-reopen-failure"}
          default {"none"}
        }
        if($category -ceq "none"){
          if($failures.Count -ne 0 -or $last.stage -cne "entry-result-reopened" -or $last.childExitCode -ne 0 -or
            $null -eq $last.childMarkerDigest -or $null -eq $last.childResultDigest){throw "Entry success evidence incomplete."}
        }elseif($failures.Count -ne 1 -or $failures[0].category -cne $category){throw ("Entry category mismatch: "+$case)}
        if($case -ceq "FixtureExit" -and $last.childExitCode -ne 74){throw "Entry child exit evidence mismatch."}
        if($case -ceq "FixtureAfterMarker" -and ($last.childExitCode -ne 75 -or $null -eq $last.childMarkerDigest)){throw "Entry after-marker evidence mismatch."}
      }
    }
    $passed++;Write-Output ("Entry "+$Mode+" PASS: "+$case)
  }finally{
    if($null -ne $process){$process.Dispose()}
    if(-not $processExited){throw "Active entry fixture retained; no deletion allowed."}
    $exact=Assert-RecoveryEntryDirectory $root $nonce
    $items=@(Get-ChildItem -LiteralPath $exact -Force)
    foreach($item in $items){if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
      $item.Name -cnotmatch '^((request|child|entry)-[0-9]{2}\.json|invocation-envelope\.json|child-fixture\.ps1)(\.tmp)?$' -or
      [IO.Path]::GetDirectoryName($item.FullName) -cne $exact){throw "Entry fixture exact cleanup rejected."}}
    foreach($item in $items){Remove-Item -LiteralPath $item.FullName -Force}
    Remove-Item -LiteralPath $exact -Force
    if(Test-Path -LiteralPath $exact){throw "Entry fixture residue rejected."}
  }
}
Write-Output ("Entry "+$Mode+" PASS "+$passed+"/"+@($cases).Count+"; exact cleanup=PASS; UAC=0; elevated children=0; captures=0")
