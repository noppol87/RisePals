[CmdletBinding()]
param(
  [string]$RepositoryRoot = "C:\Codex PC SG2\Jeff\risepals",
  [int]$WorkerScenario = 0,
  [string]$WorkspaceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$infra = Join-Path $repository "scripts\infra"
$parentContractPath = Join-Path $infra "node-destination-parent-entry-contract.psm1"
$diagnosticContractPath = Join-Path $infra "node-destination-diagnostic-contract.psm1"
$powershell51 = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$documentsCodex = [IO.Path]::GetFullPath((Join-Path (
      [Environment]::GetFolderPath("MyDocuments")
    ) "Codex")).TrimEnd('\')
$scenarioNames = @(
  "PreflightSuccess",
  "PrimitiveArgumentFailure",
  "EarlyContractMissing",
  "EarlyContractMalformed",
  "EarlyContractDigestMismatch",
  "InvalidMode",
  "SimulationControlInjection",
  "RepositoryHeadMismatch",
  "GitControlledFailure",
  "EvidenceOutsideBoundary",
  "EvidenceMissing",
  "EvidenceNonempty",
  "EvidenceReparse",
  "InventoryMissing",
  "InventoryReparse",
  "InventoryHashMismatch",
  "ArtifactOuterHashMismatch",
  "ArtifactOuterContractHashMismatch",
  "ArtifactInnerTransportHashMismatch",
  "ArtifactSecurityHashMismatch",
  "ArtifactChildHashMismatch",
  "ArtifactDiagnosticHashMismatch",
  "ArtifactDiagnosticContractHashMismatch",
  "ShouldProcessRejection",
  "InnerRequestPersistenceFailure",
  "InnerTransportControlledFailure",
  "WrongNonce",
  "WrongHead",
  "WrongHash",
  "MarkerDigestMismatch",
  "StageReordering",
  "StageOmission",
  "StageDuplication",
  "Replay",
  "StaleBinding",
  "MalformedEvidence",
  "InterruptedAtomicWrite",
  "CleanupFailure",
  "FinalResultPersistenceFailure",
  "SuccessWithoutInnerRequest",
  "EarliestMarkerPersistenceFailure"
)

function Assert-RisePalsParentTest {
  param([bool]$Condition, [string]$Label)
  if (-not $Condition) { throw $Label }
}

function Test-RisePalsParentControlledRejection {
  param([scriptblock]$Action)
  try {
    & $Action
  } catch {
    return $true
  }
  return $false
}

function Remove-RisePalsParentHarnessDirectory {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    & (Join-Path $env:SystemRoot "System32\cmd.exe") /d /c rmdir ('"{0}"' -f $item.FullName) |
      Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Harness reparse cleanup failed." }
  } else {
    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
  }
}

function New-RisePalsParentFixture {
  param([string]$CaseRoot)
  $fixture = Join-Path $CaseRoot "node-fixture"
  [IO.Directory]::CreateDirectory((Join-Path $fixture "lib")) | Out-Null
  [IO.File]::WriteAllText((Join-Path $fixture "node.exe"), "synthetic-node",
    [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $fixture "lib\runtime.txt"), "synthetic-runtime",
    [Text.UTF8Encoding]::new($false))
  return $fixture
}

function Copy-RisePalsParentArtifacts {
  param([string]$CaseInfra)
  [IO.Directory]::CreateDirectory($CaseInfra) | Out-Null
  foreach ($name in @(
      "Invoke-RisePalsNodeDestinationDiagnosticParent.ps1",
      "node-destination-parent-entry-contract.psm1",
      "Invoke-RisePalsNodeDestinationDiagnosticTransport.ps1",
      "node-destination-early-transport.psm1",
      "windows-powershell-security-bootstrap.ps1",
      "Invoke-RisePalsNodeDestinationDiagnosticChild.ps1",
      "Invoke-RisePalsNodeDestinationDiagnostic.ps1",
      "node-destination-diagnostic-contract.psm1"
    )) {
    [IO.File]::Copy((Join-Path $infra $name), (Join-Path $CaseInfra $name), $false)
  }
}

function Get-RisePalsParentHarnessHead {
  $head = (& git -c ("safe.directory={0}" -f $repository.Replace("\", "/")) `
    -C $repository rev-parse HEAD 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or $head -cnotmatch "^[a-f0-9]{40}$") {
    throw "Repository head unavailable."
  }
  return $head
}

function New-RisePalsParentSyntheticMarker {
  param([string]$Mode = "PreflightOnly")
  $hashes = @{}
  foreach ($name in @(
      "outerSha256", "outerContractSha256", "innerTransportSha256",
      "earlyContractSha256", "securityBootstrapSha256", "childSha256",
      "diagnosticSha256", "diagnosticContractSha256", "inventorySha256"
    )) {
    $hashes[$name] = "a" * 64
  }
  return [pscustomobject]@{
    marker = New-RisePalsNodeParentMarker `
      -AuthorizationId "RP-TURN-019-R4-NODE-DIAG6-SIMULATION" `
      -InvocationNonce "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" `
      -RepositoryHead ("b" * 40) -Mode $Mode -Hashes $hashes
    hashes = $hashes
  }
}

function New-RisePalsParentValidPreflightRecords {
  param([object]$Marker)
  $checkpointStages = @(
    "parent-entry-received", "primitive-arguments-validated", "early-contract-available",
    "mode-validated", "repository-head-validated", "evidence-directory-validated",
    "inventory-path-validated", "committed-artifact-hashes-validated",
    "should-process-approved", "inner-request-created"
  )
  $checkpoint = New-RisePalsNodeParentResult -RecordType checkpoint -Marker $Marker `
    -CompletedStages $checkpointStages -InnerRequestPresent $true `
    -InnerRequestDigest ("c" * 64)
  [void](Assert-RisePalsNodeParentResult -Result $checkpoint -Marker $Marker)
  $final = New-RisePalsNodeParentResult -RecordType final -Marker $Marker `
    -CompletedStages ($checkpointStages + @("outer-parent-reopened-result", "cleanup-complete")) `
    -InnerRequestPresent $true -InnerRequestDigest ("c" * 64) `
    -CleanupAttempted $true -CleanupCompleted $true `
    -CheckpointDigest $checkpoint.evidenceDigest
  [void](Assert-RisePalsNodeParentResult -Result $final -Marker $Marker `
      -ExpectedCheckpointDigest $checkpoint.evidenceDigest)
  return [pscustomobject]@{ checkpoint = $checkpoint; final = $final }
}

function Invoke-RisePalsParentEndToEnd {
  param([string]$Scenario, [string]$CaseRoot, [string]$EvidenceRoot)
  $caseInfra = Join-Path $CaseRoot "infra"
  Copy-RisePalsParentArtifacts -CaseInfra $caseInfra
  Import-Module (Join-Path $caseInfra "node-destination-diagnostic-contract.psm1") -Force
  $fixture = New-RisePalsParentFixture -CaseRoot $CaseRoot
  $inventory = New-RisePalsNodeInventory -Root $fixture
  $inventoryPath = Join-Path $CaseRoot "inventory.json"
  [IO.File]::WriteAllText($inventoryPath, ($inventory | ConvertTo-Json -Depth 12),
    [Text.UTF8Encoding]::new($false))
  $expectedInventoryHash = (Get-FileHash -LiteralPath $inventoryPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $mode = "PreflightOnly"
  $repositoryArgument = $repository
  $head = Get-RisePalsParentHarnessHead
  $extraArguments = @()
  $expectNoEvidence = $false
  $expectedStage = $null
  $expectedCategory = $null

  if ($Scenario -ceq "EarlyContractMissing") {
    Remove-Item -LiteralPath (Join-Path $caseInfra "node-destination-early-transport.psm1") -Force
    $expectedStage = "early-contract-available"
    $expectedCategory = "early_contract_failure"
  } elseif ($Scenario -ceq "EarlyContractMalformed") {
    [IO.File]::WriteAllText((Join-Path $caseInfra "node-destination-early-transport.psm1"),
      "function {", [Text.UTF8Encoding]::new($false))
    $expectedStage = "early-contract-available"
    $expectedCategory = "early_contract_failure"
  } elseif ($Scenario -ceq "InvalidMode") {
    $mode = "InvalidMode"
    $expectedStage = "mode-validated"
    $expectedCategory = "mode_validation_failure"
  } elseif ($Scenario -ceq "SimulationControlInjection") {
    $extraArguments = @("--Scenario", "Success")
    $expectedStage = "mode-validated"
    $expectedCategory = "mode_validation_failure"
  } elseif ($Scenario -ceq "RepositoryHeadMismatch") {
    $head = "f" * 40
    $expectedStage = "repository-head-validated"
    $expectedCategory = "repository_binding_failure"
  } elseif ($Scenario -ceq "GitControlledFailure") {
    $repositoryArgument = Join-Path $CaseRoot "not-a-repository"
    [IO.Directory]::CreateDirectory($repositoryArgument) | Out-Null
    $expectedStage = "repository-head-validated"
    $expectedCategory = "repository_binding_failure"
  } elseif ($Scenario -ceq "EvidenceOutsideBoundary") {
    $EvidenceRoot = Join-Path $CaseRoot "outside-evidence"
    [IO.Directory]::CreateDirectory($EvidenceRoot) | Out-Null
    $expectNoEvidence = $true
  } elseif ($Scenario -ceq "EvidenceMissing") {
    Remove-RisePalsParentHarnessDirectory -Path $EvidenceRoot
    $expectNoEvidence = $true
  } elseif ($Scenario -ceq "EvidenceNonempty") {
    [IO.File]::WriteAllText((Join-Path $EvidenceRoot "preexisting.txt"), "synthetic",
      [Text.UTF8Encoding]::new($false))
    $expectNoEvidence = $true
  } elseif ($Scenario -ceq "EvidenceReparse") {
    Remove-RisePalsParentHarnessDirectory -Path $EvidenceRoot
    $target = Join-Path $CaseRoot "evidence-target"
    [IO.Directory]::CreateDirectory($target) | Out-Null
    & (Join-Path $env:SystemRoot "System32\cmd.exe") /d /c mklink /J `
      ('"{0}"' -f $EvidenceRoot) ('"{0}"' -f $target) | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Unable to create evidence junction." }
    $expectNoEvidence = $true
  } elseif ($Scenario -ceq "InventoryMissing") {
    Remove-Item -LiteralPath $inventoryPath -Force
    $expectedStage = "inventory-path-validated"
    $expectedCategory = "inventory_path_failure"
  } elseif ($Scenario -ceq "InventoryReparse") {
    $target = Join-Path $CaseRoot "inventory-target"
    [IO.Directory]::CreateDirectory($target) | Out-Null
    $inventoryPath = Join-Path $CaseRoot "inventory-junction"
    & (Join-Path $env:SystemRoot "System32\cmd.exe") /d /c mklink /J `
      ('"{0}"' -f $inventoryPath) ('"{0}"' -f $target) | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Unable to create inventory junction." }
    $expectedStage = "inventory-path-validated"
    $expectedCategory = "inventory_path_failure"
  }

  $files = [ordered]@{
    ExpectedOuterSha256 = "Invoke-RisePalsNodeDestinationDiagnosticParent.ps1"
    ExpectedOuterContractSha256 = "node-destination-parent-entry-contract.psm1"
    ExpectedInnerTransportSha256 = "Invoke-RisePalsNodeDestinationDiagnosticTransport.ps1"
    ExpectedEarlyContractSha256 = "node-destination-early-transport.psm1"
    ExpectedSecurityBootstrapSha256 = "windows-powershell-security-bootstrap.ps1"
    ExpectedChildSha256 = "Invoke-RisePalsNodeDestinationDiagnosticChild.ps1"
    ExpectedDiagnosticSha256 = "Invoke-RisePalsNodeDestinationDiagnostic.ps1"
    ExpectedDiagnosticContractSha256 = "node-destination-diagnostic-contract.psm1"
  }
  $hashValues = [ordered]@{}
  foreach ($entry in $files.GetEnumerator()) {
    $path = Join-Path $caseInfra $entry.Value
    if ([IO.File]::Exists($path)) {
      $hashValues[$entry.Key] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    } else {
      $hashValues[$entry.Key] = "e" * 64
    }
  }
  $hashValues.ExpectedInventorySha256 = $expectedInventoryHash
  $hashMismatchMap = @{
    "EarlyContractDigestMismatch" = "ExpectedEarlyContractSha256"
    "InventoryHashMismatch" = "ExpectedInventorySha256"
    "ArtifactOuterHashMismatch" = "ExpectedOuterSha256"
    "ArtifactOuterContractHashMismatch" = "ExpectedOuterContractSha256"
    "ArtifactInnerTransportHashMismatch" = "ExpectedInnerTransportSha256"
    "ArtifactSecurityHashMismatch" = "ExpectedSecurityBootstrapSha256"
    "ArtifactChildHashMismatch" = "ExpectedChildSha256"
    "ArtifactDiagnosticHashMismatch" = "ExpectedDiagnosticSha256"
    "ArtifactDiagnosticContractHashMismatch" = "ExpectedDiagnosticContractSha256"
  }
  if ($hashMismatchMap.ContainsKey($Scenario)) {
    $hashValues[$hashMismatchMap[$Scenario]] = "f" * 64
    if ($Scenario -ceq "EarlyContractDigestMismatch") {
      $expectedStage = "early-contract-available"
      $expectedCategory = "early_contract_failure"
    } else {
      $expectedStage = "committed-artifact-hashes-validated"
      $expectedCategory = "artifact_hash_failure"
    }
  }
  if ($Scenario -ceq "PrimitiveArgumentFailure") {
    $extraArguments = @("--UnexpectedArgument", "synthetic")
    $expectedStage = "primitive-arguments-validated"
    $expectedCategory = "primitive_argument_failure"
  }

  $outer = Join-Path $caseInfra "Invoke-RisePalsNodeDestinationDiagnosticParent.ps1"
  $arguments = @(
    "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
    "-File", ('"{0}"' -f $outer),
    "--Mode", ('"{0}"' -f $mode),
    "--AuthorizationId", "RP-TURN-019-R4-NODE-DIAG6-SIMULATION",
    "--InvocationNonce", ("{0:x32}" -f ([Array]::IndexOf($scenarioNames, $Scenario) + 1)),
    "--RepositoryHead", $head,
    "--InventoryPath", ('"{0}"' -f $inventoryPath),
    "--EvidenceDirectory", ('"{0}"' -f $EvidenceRoot),
    "--RepositoryRoot", ('"{0}"' -f $repositoryArgument)
  )
  foreach ($entry in $hashValues.GetEnumerator()) {
    $arguments += "--$($entry.Key)"
    $arguments += [string]$entry.Value
  }
  $arguments += $extraArguments
  $process = Start-Process -FilePath $powershell51 -ArgumentList $arguments `
    -WindowStyle Hidden -Wait -PassThru
  if ($expectNoEvidence) {
    Assert-RisePalsParentTest -Condition ($process.ExitCode -eq 82) `
      -Label "$Scenario did not fail at the primitive evidence boundary."
    if ([IO.Directory]::Exists($EvidenceRoot)) {
      $allowedPreexisting = if ($Scenario -ceq "EvidenceNonempty") { 1 } else { 0 }
      Assert-RisePalsParentTest `
        -Condition (@(Get-ChildItem -LiteralPath $EvidenceRoot -Force).Count -eq $allowedPreexisting) `
        -Label "$Scenario wrote unauthorized evidence."
    }
    return [pscustomobject]@{ exitCode = $process.ExitCode; stage = $null; category = $null }
  }
  $nonce = "{0:x32}" -f ([Array]::IndexOf($scenarioNames, $Scenario) + 1)
  Import-Module (Join-Path $caseInfra "node-destination-parent-entry-contract.psm1") -Force
  $markerPath = Get-RisePalsNodeParentMarkerPath -EvidenceDirectory $EvidenceRoot `
    -InvocationNonce $nonce
  $raw = Read-RisePalsNodeParentJson -LiteralPath $markerPath
  $hashes = @{}
  foreach ($name in @(
      "outerSha256", "outerContractSha256", "innerTransportSha256",
      "earlyContractSha256", "securityBootstrapSha256", "childSha256",
      "diagnosticSha256", "diagnosticContractSha256", "inventorySha256"
    )) { $hashes[$name] = [string]$raw.$name }
  $marker = Read-RisePalsNodeParentMarker -Path $markerPath `
    -AuthorizationId $raw.authorizationId -InvocationNonce $nonce `
    -RepositoryHead $raw.repositoryHead -Hashes $hashes
  $checkpoint = Read-RisePalsNodeParentResult `
    -Path (Get-RisePalsNodeParentCheckpointPath $EvidenceRoot $nonce) -Marker $marker
  $final = Read-RisePalsNodeParentResult `
    -Path (Get-RisePalsNodeParentResultPath $EvidenceRoot $nonce) -Marker $marker `
    -ExpectedCheckpointDigest $checkpoint.evidenceDigest
  if ($Scenario -ceq "PreflightSuccess") {
    Assert-RisePalsParentTest -Condition ($process.ExitCode -eq 0 -and
      $null -eq $final.firstFailedStage -and -not [bool]$final.processCreated -and
      $null -eq $final.childExitCode -and [bool]$final.innerRequestPresent -and
      "inner-transport-dispatched" -notin @($final.completedStages)) `
      -Label "PreflightOnly did not remain non-elevated and pre-dispatch."
  } else {
    Assert-RisePalsParentTest -Condition ($process.ExitCode -eq 90 -and
      [string]$final.firstFailedStage -ceq $expectedStage -and
      [string]$final.sanitizedFailureCategory -ceq $expectedCategory) `
      -Label "$Scenario failure classification mismatch."
  }
  return [pscustomobject]@{
    exitCode = $process.ExitCode
    stage = $final.firstFailedStage
    category = $final.sanitizedFailureCategory
  }
}

function Invoke-RisePalsParentPureScenario {
  param([string]$Scenario, [string]$CaseRoot)
  Import-Module $parentContractPath -Force
  $fixture = New-RisePalsParentSyntheticMarker
  $marker = $fixture.marker
  if ($Scenario -ceq "ShouldProcessRejection") {
    $approved = Test-RisePalsNodeParentApproval -Target $CaseRoot -Action "synthetic" -WhatIf
    Assert-RisePalsParentTest -Condition (-not $approved) `
      -Label "ShouldProcess rejection was not preserved."
  } elseif ($Scenario -ceq "InnerRequestPersistenceFailure") {
    Import-Module (Join-Path $infra "node-destination-early-transport.psm1") -Force
    $directory = Join-Path $CaseRoot "inner-request"
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $request = New-RisePalsNodeEarlyRequest `
      -AuthorizationId $marker.authorizationId `
      -InvocationNonce $marker.invocationNonce `
      -RepositoryHead $marker.repositoryHead `
      -LauncherSha256 $marker.innerTransportSha256 `
      -EarlyContractSha256 $marker.earlyContractSha256 `
      -SecurityBootstrapSha256 $marker.securityBootstrapSha256 `
      -ChildSha256 $marker.childSha256 `
      -DiagnosticSha256 $marker.diagnosticSha256 `
      -DiagnosticContractSha256 $marker.diagnosticContractSha256 `
      -InventorySha256 $marker.inventorySha256
    $requestPath = Get-RisePalsNodeEarlyRequestPath -EvidenceDirectory $directory `
      -InvocationNonce $marker.invocationNonce
    $rejected = Test-RisePalsParentControlledRejection {
      [void](Write-RisePalsNodeEarlyJsonAtomic -Value $request -FinalPath $requestPath `
          -InterruptBeforeMove)
    }
    Assert-RisePalsParentTest -Condition ($rejected -and
      -not [IO.File]::Exists($requestPath) -and [IO.File]::Exists($requestPath + ".tmp")) `
      -Label "Interrupted inner request persistence was not rejected atomically."
    $reopenRejected = Test-RisePalsParentControlledRejection {
      [void](Read-RisePalsNodeEarlyRequest -Path $requestPath `
          -ExpectedAuthorizationId $marker.authorizationId `
          -ExpectedInvocationNonce $marker.invocationNonce `
          -ExpectedRepositoryHead $marker.repositoryHead `
          -ExpectedLauncherSha256 $marker.innerTransportSha256 `
          -ExpectedEarlyContractSha256 $marker.earlyContractSha256 `
          -ExpectedSecurityBootstrapSha256 $marker.securityBootstrapSha256 `
          -ExpectedChildSha256 $marker.childSha256 `
          -ExpectedDiagnosticSha256 $marker.diagnosticSha256 `
          -ExpectedDiagnosticContractSha256 $marker.diagnosticContractSha256 `
          -ExpectedInventorySha256 $marker.inventorySha256)
    }
    Assert-RisePalsParentTest $reopenRejected `
      "Interrupted inner request unexpectedly reopened as authoritative evidence."
    [IO.File]::Delete($requestPath + ".tmp")
    $checkpoint = New-RisePalsNodeParentResult -RecordType checkpoint -Marker $marker `
      -CompletedStages @(
        "parent-entry-received", "primitive-arguments-validated", "early-contract-available",
        "mode-validated", "repository-head-validated", "evidence-directory-validated",
        "inventory-path-validated", "committed-artifact-hashes-validated",
        "should-process-approved"
      ) -FirstFailedStage "inner-request-created" `
      -SanitizedFailureCategory "request_persistence_failure"
    [void](Assert-RisePalsNodeParentResult -Result $checkpoint -Marker $marker)
  } elseif ($Scenario -ceq "InnerTransportControlledFailure") {
    $live = New-RisePalsParentSyntheticMarker -Mode LiveReadOnly
    $marker = $live.marker
    $checkpoint = New-RisePalsNodeParentResult -RecordType checkpoint -Marker $marker `
      -CompletedStages @(
        "parent-entry-received", "primitive-arguments-validated", "early-contract-available",
        "mode-validated", "repository-head-validated", "evidence-directory-validated",
        "inventory-path-validated", "committed-artifact-hashes-validated",
        "should-process-approved", "inner-request-created", "inner-transport-dispatched"
      ) -FirstFailedStage "inner-transport-dispatched" `
      -SanitizedFailureCategory "inner_transport_failure" `
      -InnerRequestPresent $true -InnerRequestDigest ("c" * 64)
    [void](Assert-RisePalsNodeParentResult -Result $checkpoint -Marker $marker)
  } elseif ($Scenario -in @("WrongNonce", "WrongHead", "WrongHash", "MarkerDigestMismatch")) {
    $copy = (($marker | ConvertTo-Json -Compress -Depth 8) | ConvertFrom-Json)
    if ($Scenario -ceq "WrongNonce") { $copy.invocationNonce = "f" * 32 }
    if ($Scenario -ceq "WrongHead") { $copy.repositoryHead = "f" * 40 }
    if ($Scenario -ceq "WrongHash") { $copy.childSha256 = "f" * 64 }
    if ($Scenario -ceq "MarkerDigestMismatch") {
      $copy.markerDigest = "f" * 64
    } else {
      $copy.markerDigest = Get-RisePalsNodeParentMarkerDigest -Marker $copy
    }
    $rejected = Test-RisePalsParentControlledRejection {
      [void](Assert-RisePalsNodeParentMarker -Marker $copy `
          -AuthorizationId $marker.authorizationId -InvocationNonce $marker.invocationNonce `
          -RepositoryHead $marker.repositoryHead -Hashes $fixture.hashes)
    }
    Assert-RisePalsParentTest $rejected "$Scenario binding was accepted."
  } elseif ($Scenario -in @("StageReordering", "StageOmission", "StageDuplication",
      "SuccessWithoutInnerRequest")) {
    $records = New-RisePalsParentValidPreflightRecords -Marker $marker
    $copy = (($records.final | ConvertTo-Json -Compress -Depth 12) | ConvertFrom-Json)
    if ($Scenario -ceq "StageReordering") {
      $copy.completedStages[1] = "early-contract-available"
      $copy.completedStages[2] = "primitive-arguments-validated"
    } elseif ($Scenario -ceq "StageOmission") {
      $copy.completedStages = @($copy.completedStages | Where-Object {
          [string]$_ -cne "inventory-path-validated"
        })
    } elseif ($Scenario -ceq "StageDuplication") {
      $copy.completedStages = @($copy.completedStages[0..2] +
        @("early-contract-available") + $copy.completedStages[3..($copy.completedStages.Count - 1)])
    } else {
      $copy.innerRequestPresent = $false
      $copy.innerRequestDigest = $null
    }
    $copy.lastCompletedStage = [string]$copy.completedStages[-1]
    $copy.evidenceDigest = Get-RisePalsNodeParentResultDigest -Result $copy
    $rejected = Test-RisePalsParentControlledRejection {
      [void](Assert-RisePalsNodeParentResult -Result $copy -Marker $marker `
          -ExpectedCheckpointDigest $records.checkpoint.evidenceDigest)
    }
    Assert-RisePalsParentTest $rejected "$Scenario tamper was accepted."
  } elseif ($Scenario -ceq "Replay") {
    $directory = Join-Path $CaseRoot "replay"
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    [void](Write-RisePalsNodeParentMarkerAtomic -Marker $marker -EvidenceDirectory $directory)
    $rejected = Test-RisePalsParentControlledRejection {
      [void](Write-RisePalsNodeParentMarkerAtomic -Marker $marker -EvidenceDirectory $directory)
    }
    Assert-RisePalsParentTest $rejected "Replay write was accepted."
  } elseif ($Scenario -ceq "StaleBinding") {
    $rejected = Test-RisePalsParentControlledRejection {
      [void](Assert-RisePalsNodeParentMarker -Marker $marker `
          -AuthorizationId $marker.authorizationId `
          -InvocationNonce $marker.invocationNonce `
          -RepositoryHead ("e" * 40) -Hashes $fixture.hashes)
    }
    Assert-RisePalsParentTest $rejected "Stale repository binding was accepted."
  } elseif ($Scenario -ceq "MalformedEvidence") {
    $path = Join-Path $CaseRoot "malformed.json"
    [IO.File]::WriteAllText($path, "{", [Text.UTF8Encoding]::new($false))
    $rejected = Test-RisePalsParentControlledRejection {
      [void](Read-RisePalsNodeParentJson -LiteralPath $path)
    }
    Assert-RisePalsParentTest $rejected "Malformed evidence was accepted."
  } elseif ($Scenario -in @("InterruptedAtomicWrite", "EarliestMarkerPersistenceFailure")) {
    $directory = Join-Path $CaseRoot "atomic"
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $rejected = Test-RisePalsParentControlledRejection {
      [void](Write-RisePalsNodeParentMarkerAtomic -Marker $marker `
          -EvidenceDirectory $directory -InterruptBeforeMove)
    }
    $final = Get-RisePalsNodeParentMarkerPath $directory $marker.invocationNonce
    Assert-RisePalsParentTest -Condition ($rejected -and -not [IO.File]::Exists($final) -and
      [IO.File]::Exists($final + ".tmp")) -Label "$Scenario atomic boundary failed."
    [IO.File]::Delete($final + ".tmp")
  } elseif ($Scenario -ceq "CleanupFailure") {
    $checkpoint = New-RisePalsNodeParentResult -RecordType checkpoint -Marker $marker `
      -CompletedStages @(
        "parent-entry-received", "primitive-arguments-validated", "early-contract-available",
        "mode-validated", "repository-head-validated", "evidence-directory-validated",
        "inventory-path-validated", "committed-artifact-hashes-validated",
        "should-process-approved", "inner-request-created"
      ) -InnerRequestPresent $true -InnerRequestDigest ("c" * 64)
    [void](Assert-RisePalsNodeParentResult $checkpoint $marker)
    $final = New-RisePalsNodeParentResult -RecordType final -Marker $marker `
      -CompletedStages (@($checkpoint.completedStages) + "outer-parent-reopened-result") `
      -FirstFailedStage "cleanup-complete" -SanitizedFailureCategory "cleanup_failure" `
      -InnerRequestPresent $true -InnerRequestDigest ("c" * 64) `
      -CleanupAttempted $true -CleanupCompleted $false -TransientResidueCount 1 `
      -CheckpointDigest $checkpoint.evidenceDigest
    [void](Assert-RisePalsNodeParentResult -Result $final -Marker $marker `
        -ExpectedCheckpointDigest $checkpoint.evidenceDigest)
  } elseif ($Scenario -ceq "FinalResultPersistenceFailure") {
    $records = New-RisePalsParentValidPreflightRecords -Marker $marker
    $directory = Join-Path $CaseRoot "final"
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $rejected = Test-RisePalsParentControlledRejection {
      [void](Write-RisePalsNodeParentResultAtomic -Result $records.final `
          -EvidenceDirectory $directory -InterruptBeforeMove)
    }
    $path = Get-RisePalsNodeParentResultPath $directory $marker.invocationNonce
    Assert-RisePalsParentTest -Condition ($rejected -and -not [IO.File]::Exists($path) -and
      [IO.File]::Exists($path + ".tmp")) -Label "Final persistence interruption failed."
    [IO.File]::Delete($path + ".tmp")
  } else {
    throw "Unknown pure scenario: $Scenario"
  }
  return [pscustomobject]@{ exitCode = 0; stage = $null; category = $null }
}

function Invoke-RisePalsParentWorker {
  param([int]$Number, [string]$Root)
  $scenario = [string]$scenarioNames[$Number - 1]
  $caseRoot = Join-Path $Root ("case-{0:d2}" -f $Number)
  $evidenceRoot = Join-Path $documentsCodex (
    "risepals-parent-entry-harness-{0}-{1:d2}" -f (Split-Path -Leaf $Root), $Number
  )
  [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
  [IO.Directory]::CreateDirectory($evidenceRoot) | Out-Null
  try {
    $endToEnd = $Number -le 23
    $result = if ($endToEnd) {
      Invoke-RisePalsParentEndToEnd -Scenario $scenario -CaseRoot $caseRoot `
        -EvidenceRoot $evidenceRoot
    } else {
      Invoke-RisePalsParentPureScenario -Scenario $scenario -CaseRoot $caseRoot
    }
    $report = [pscustomobject][ordered]@{
      schemaVersion = "rise-pals-node-parent-entry-simulation-v1"
      number = $Number
      name = $scenario
      passed = $true
      exitCode = $result.exitCode
      firstFailedStage = $result.stage
      sanitizedFailureCategory = $result.category
    }
    [IO.File]::WriteAllText((Join-Path $Root ("report-{0:d2}.json" -f $Number)),
      ($report | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
  } finally {
    Remove-RisePalsParentHarnessDirectory -Path $evidenceRoot
  }
}

if ($WorkerScenario -gt 0) {
  if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { throw "WorkspaceRoot is required." }
  $workspace = [IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\')
  if (-not $workspace.StartsWith($temporaryRoot + "\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "Worker workspace escaped the temporary root."
  }
  Invoke-RisePalsParentWorker -Number $WorkerScenario -Root $workspace
  exit 0
}

if (-not [IO.File]::Exists($powershell51)) { throw "Windows PowerShell 5.1 unavailable." }
$workspace = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-node-parent-entry-{0}" -f [Guid]::NewGuid().ToString("N")
)
[IO.Directory]::CreateDirectory($workspace) | Out-Null
$reports = @()
try {
  for ($number = 1; $number -le $scenarioNames.Count; $number++) {
    $arguments = @(
      "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
      "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path),
      "-RepositoryRoot", ('"{0}"' -f $repository),
      "-WorkerScenario", [string]$number,
      "-WorkspaceRoot", ('"{0}"' -f $workspace)
    )
    $process = Start-Process -FilePath $powershell51 -ArgumentList $arguments `
      -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) {
      throw "Parent-entry scenario $number failed in its separate process."
    }
    $reportPath = Join-Path $workspace ("report-{0:d2}.json" -f $number)
    if (-not [IO.File]::Exists($reportPath)) {
      throw "Parent-entry scenario $number omitted its report."
    }
    $report = [IO.File]::ReadAllText($reportPath) | ConvertFrom-Json -ErrorAction Stop
    if ([string]$report.name -cne [string]$scenarioNames[$number - 1] -or
      -not [bool]$report.passed) {
      throw "Parent-entry scenario $number report was invalid."
    }
    $reports += $report
  }
  [pscustomobject][ordered]@{
    schemaVersion = "rise-pals-node-parent-entry-harness-v1"
    processCount = $reports.Count
    preflightProcessCreated = $false
    preflightUacCount = 0
    elevatedChildCount = 0
    temporaryWorkspaceRemovedAfterReport = $true
    scenarios = $reports
  } | ConvertTo-Json -Depth 8
} finally {
  Remove-RisePalsParentHarnessDirectory -Path $workspace
}
