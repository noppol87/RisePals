[CmdletBinding()]
param(
  [string]$RepositoryRoot = "C:\Codex PC SG2\Jeff\risepals",
  [int]$WorkerScenario = 0,
  [string]$WorkspaceRoot,
  [ValidateSet("", "fixture-inventory-persist", "scenario-assertions-complete")]
  [string]$TestOnlyWorkerFailureStage = ""
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
$workerStages = @(
  "worker-started",
  "fixture-created",
  "outer-parent-invoked",
  "outer-parent-exited",
  "durable-records-reopened",
  "scenario-assertions-complete",
  "report-persisted",
  "cleanup-complete"
)
$workerCategories = @(
  "fixture_failure",
  "outer_parent_failure",
  "durable_record_failure",
  "scenario_assertion_failure",
  "preflight_outer_exit_failure",
  "preflight_parent_failure_claim",
  "preflight_process_creation_claim",
  "preflight_child_exit_claim",
  "preflight_inner_request_claim",
  "preflight_dispatch_claim",
  "report_persistence_failure",
  "cleanup_failure"
)
$fixtureStages = @(
  "worker-entry",
  "case-root-create",
  "evidence-root-create",
  "artifact-copy",
  "diagnostic-contract-import",
  "synthetic-node-create",
  "inventory-create",
  "inventory-persist",
  "inventory-digest",
  "complete"
)
$fixturePredicates = @("pending", "passed", "failed")
$workerPropertyNames = @(
  "scenarioNumber", "scenarioName", "workerStarted", "workerStage",
  "fixtureStage", "fixturePredicate", "sanitizedFailureCategory", "outerExitCode", "childExitCode",
  "parentMarkerPresent", "parentMarkerDigest", "parentCheckpointPresent",
  "parentCheckpointDigest", "parentFinalPresent", "parentFinalDigest",
  "reportPersistenceAttempted", "reportPersistenceCompleted", "cleanupAttempted",
  "cleanupCompleted", "evidenceResidueCount", "temporaryResidueCount",
  "canonicalDigest"
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
  $exact = [IO.Path]::GetFullPath($Path).TrimEnd('\')
  $beneathTemporary = $exact.StartsWith(
    $temporaryRoot + "\", [StringComparison]::OrdinalIgnoreCase
  )
  $beneathDocuments = $exact.StartsWith(
    $documentsCodex + "\", [StringComparison]::OrdinalIgnoreCase
  )
  if (-not $beneathTemporary -and -not $beneathDocuments) {
    throw "Harness cleanup escaped its exact temporary boundaries."
  }
  $item = Get-Item -LiteralPath $exact -Force -ErrorAction Stop
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    if (($item.Attributes -band [IO.FileAttributes]::Directory) -ne 0) {
      [IO.Directory]::Delete($item.FullName, $false)
    } else {
      [IO.File]::Delete($item.FullName)
    }
  } elseif ($item.PSIsContainer) {
    foreach ($child in @(Get-ChildItem -LiteralPath $item.FullName -Force)) {
      Remove-RisePalsParentHarnessDirectory -Path $child.FullName
    }
    [IO.Directory]::Delete($item.FullName, $false)
  } else {
    [IO.File]::Delete($item.FullName)
  }
  if (Test-Path -LiteralPath $exact) {
    throw "Harness cleanup left exact-path residue."
  }
}

function Test-RisePalsParentWorkerInteger {
  param([object]$Value, [int64]$Minimum, [int64]$Maximum)
  if ($Value -isnot [byte] -and $Value -isnot [sbyte] -and
    $Value -isnot [int16] -and $Value -isnot [uint16] -and
    $Value -isnot [int32] -and $Value -isnot [uint32] -and
    $Value -isnot [int64] -and $Value -isnot [uint64]) {
    return $false
  }
  try {
    $number = [int64]$Value
    return $number -ge $Minimum -and $number -le $Maximum
  } catch {
    return $false
  }
}

function Test-RisePalsParentWorkerHash {
  param([object]$Value)
  return $null -ne $Value -and [string]$Value -cmatch "^[a-f0-9]{64}$"
}

function Get-RisePalsParentHarnessFileSha256 {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)
  $exact = [IO.Path]::GetFullPath($LiteralPath)
  if (-not [IO.File]::Exists($exact) -or
    ([IO.File]::GetAttributes($exact) -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Harness SHA-256 input is not a regular non-reparse file."
  }
  $stream = $null
  $algorithm = $null
  try {
    $stream = [IO.File]::Open($exact, [IO.FileMode]::Open, [IO.FileAccess]::Read,
      [IO.FileShare]::Read)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    $bytes = $algorithm.ComputeHash($stream)
    return ([BitConverter]::ToString($bytes)).Replace("-", "").ToLowerInvariant()
  } finally {
    if ($null -ne $algorithm) { $algorithm.Dispose() }
    if ($null -ne $stream) { $stream.Dispose() }
  }
}

function Get-RisePalsParentWorkerDigest {
  param([Parameter(Mandatory = $true)][object]$Record)
  $values = @(
    [string]$Record.scenarioNumber,
    [string]$Record.scenarioName,
    ([bool]$Record.workerStarted).ToString().ToLowerInvariant(),
    [string]$Record.workerStage,
    [string]$Record.fixtureStage,
    [string]$Record.fixturePredicate,
    $(if ($null -eq $Record.sanitizedFailureCategory) { "" } else {
        [string]$Record.sanitizedFailureCategory
      }),
    $(if ($null -eq $Record.outerExitCode) { "" } else { [string]$Record.outerExitCode }),
    $(if ($null -eq $Record.childExitCode) { "" } else { [string]$Record.childExitCode }),
    ([bool]$Record.parentMarkerPresent).ToString().ToLowerInvariant(),
    $(if ($null -eq $Record.parentMarkerDigest) { "" } else {
        [string]$Record.parentMarkerDigest
      }),
    ([bool]$Record.parentCheckpointPresent).ToString().ToLowerInvariant(),
    $(if ($null -eq $Record.parentCheckpointDigest) { "" } else {
        [string]$Record.parentCheckpointDigest
      }),
    ([bool]$Record.parentFinalPresent).ToString().ToLowerInvariant(),
    $(if ($null -eq $Record.parentFinalDigest) { "" } else {
        [string]$Record.parentFinalDigest
      }),
    ([bool]$Record.reportPersistenceAttempted).ToString().ToLowerInvariant(),
    ([bool]$Record.reportPersistenceCompleted).ToString().ToLowerInvariant(),
    ([bool]$Record.cleanupAttempted).ToString().ToLowerInvariant(),
    ([bool]$Record.cleanupCompleted).ToString().ToLowerInvariant(),
    [string]$Record.evidenceResidueCount,
    [string]$Record.temporaryResidueCount
  )
  $bytes = [Text.Encoding]::UTF8.GetBytes(($values -join "`n"))
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function New-RisePalsParentWorkerRecord {
  param(
    [int]$ScenarioNumber,
    [string]$ScenarioName,
    [string]$WorkerStage,
    [string]$FixtureStage,
    [string]$FixturePredicate,
    [AllowNull()][object]$SanitizedFailureCategory,
    [AllowNull()][object]$OuterExitCode,
    [AllowNull()][object]$ChildExitCode,
    [hashtable]$EvidenceState,
    [bool]$ReportPersistenceAttempted,
    [bool]$ReportPersistenceCompleted,
    [bool]$CleanupAttempted,
    [bool]$CleanupCompleted,
    [int64]$EvidenceResidueCount,
    [int64]$TemporaryResidueCount
  )
  $record = [pscustomobject][ordered]@{
    scenarioNumber = $ScenarioNumber
    scenarioName = $ScenarioName
    workerStarted = $true
    workerStage = $WorkerStage
    fixtureStage = $FixtureStage
    fixturePredicate = $FixturePredicate
    sanitizedFailureCategory = $SanitizedFailureCategory
    outerExitCode = $OuterExitCode
    childExitCode = $ChildExitCode
    parentMarkerPresent = [bool]$EvidenceState.markerPresent
    parentMarkerDigest = $EvidenceState.markerDigest
    parentCheckpointPresent = [bool]$EvidenceState.checkpointPresent
    parentCheckpointDigest = $EvidenceState.checkpointDigest
    parentFinalPresent = [bool]$EvidenceState.finalPresent
    parentFinalDigest = $EvidenceState.finalDigest
    reportPersistenceAttempted = $ReportPersistenceAttempted
    reportPersistenceCompleted = $ReportPersistenceCompleted
    cleanupAttempted = $CleanupAttempted
    cleanupCompleted = $CleanupCompleted
    evidenceResidueCount = $EvidenceResidueCount
    temporaryResidueCount = $TemporaryResidueCount
    canonicalDigest = $null
  }
  $record.canonicalDigest = Get-RisePalsParentWorkerDigest -Record $record
  return $record
}

function Assert-RisePalsParentWorkerRecord {
  param([Parameter(Mandatory = $true)][object]$Record, [int]$ExpectedNumber)
  $actualNames = @($Record.PSObject.Properties.Name | Sort-Object -CaseSensitive)
  $expectedNames = @($workerPropertyNames | Sort-Object -CaseSensitive)
  if (($actualNames -join "`n") -cne ($expectedNames -join "`n") -or
    -not (Test-RisePalsParentWorkerInteger $Record.scenarioNumber 1 $scenarioNames.Count) -or
    [int]$Record.scenarioNumber -ne $ExpectedNumber -or
    [string]$Record.scenarioName -cne [string]$scenarioNames[$ExpectedNumber - 1] -or
    $Record.workerStarted -isnot [bool] -or -not [bool]$Record.workerStarted -or
    [string]$Record.workerStage -notin $workerStages -or
    [string]$Record.fixtureStage -notin $fixtureStages -or
    [string]$Record.fixturePredicate -notin $fixturePredicates -or
    ($null -ne $Record.sanitizedFailureCategory -and
      [string]$Record.sanitizedFailureCategory -notin $workerCategories)) {
    throw "worker-report-contract"
  }
  foreach ($value in @($Record.outerExitCode, $Record.childExitCode)) {
    if ($null -ne $value -and
      -not (Test-RisePalsParentWorkerInteger $value ([int32]::MinValue) ([int32]::MaxValue))) {
      throw "worker-report-exit-code"
    }
  }
  foreach ($name in @(
      "workerStarted", "parentMarkerPresent", "parentCheckpointPresent", "parentFinalPresent",
      "reportPersistenceAttempted", "reportPersistenceCompleted", "cleanupAttempted",
      "cleanupCompleted"
    )) {
    if ($Record.$name -isnot [bool]) { throw "worker-report-boolean" }
  }
  foreach ($pair in @(
      @([bool]$Record.parentMarkerPresent, $Record.parentMarkerDigest),
      @([bool]$Record.parentCheckpointPresent, $Record.parentCheckpointDigest),
      @([bool]$Record.parentFinalPresent, $Record.parentFinalDigest)
    )) {
    if (($pair[0] -and -not (Test-RisePalsParentWorkerHash $pair[1])) -or
      (-not $pair[0] -and $null -ne $pair[1])) {
      throw "worker-report-parent-evidence"
    }
  }
  if (([string]$Record.sanitizedFailureCategory -ceq "fixture_failure" -and
      ([string]$Record.workerStage -cne "worker-started" -or
        [string]$Record.fixturePredicate -cne "failed" -or
        [string]$Record.fixtureStage -ceq "complete")) -or
    ([string]$Record.workerStage -cne "worker-started" -and
      ([string]$Record.fixtureStage -cne "complete" -or
        [string]$Record.fixturePredicate -cne "passed")) -or
    -not (Test-RisePalsParentWorkerInteger $Record.evidenceResidueCount 0 1000) -or
    -not (Test-RisePalsParentWorkerInteger $Record.temporaryResidueCount 0 1000) -or
    ([bool]$Record.cleanupCompleted -and
      ([int64]$Record.evidenceResidueCount -ne 0 -or
        [int64]$Record.temporaryResidueCount -ne 0)) -or
    ([bool]$Record.reportPersistenceCompleted -and
      -not [bool]$Record.reportPersistenceAttempted) -or
    -not (Test-RisePalsParentWorkerHash $Record.canonicalDigest) -or
    [string]$Record.canonicalDigest -cne (Get-RisePalsParentWorkerDigest -Record $Record)) {
    throw "worker-report-state"
  }
  return $Record
}

function Read-RisePalsParentWorkerRecord {
  param([string]$Path, [int]$ExpectedNumber)
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if ($item.PSIsContainer -or
    ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "worker-report-file"
  }
  try {
    $bytes = [IO.File]::ReadAllBytes($item.FullName)
    $record = [Text.UTF8Encoding]::new($false, $true).GetString($bytes) |
      ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "worker-report-json"
  }
  return Assert-RisePalsParentWorkerRecord -Record $record -ExpectedNumber $ExpectedNumber
}

function Write-RisePalsParentWorkerRecordAtomic {
  param(
    [string]$Root,
    [Parameter(Mandatory = $true)][object]$Record,
    [switch]$Authoritative
  )
  [void](Assert-RisePalsParentWorkerRecord -Record $Record `
      -ExpectedNumber ([int]$Record.scenarioNumber))
  $fileName = if ($Authoritative) {
    "report-{0:d2}.json" -f [int]$Record.scenarioNumber
  } else {
    "checkpoint-{0:d2}-{1}.json" -f [int]$Record.scenarioNumber, [string]$Record.workerStage
  }
  $finalPath = Join-Path $Root $fileName
  $temporary = $finalPath + ".tmp"
  if ([IO.File]::Exists($finalPath) -or [IO.File]::Exists($temporary)) {
    throw "worker-report-temporary-exists"
  }
  try {
    [IO.File]::WriteAllText($temporary, ($Record | ConvertTo-Json -Compress),
      [Text.UTF8Encoding]::new($false))
  } catch {
    throw "worker-report-write"
  }
  try {
    [IO.File]::Move($temporary, $finalPath)
  } catch {
    throw "worker-report-move"
  }
  try {
    return Read-RisePalsParentWorkerRecord -Path $finalPath `
      -ExpectedNumber ([int]$Record.scenarioNumber)
  } catch {
    throw "worker-report-reopen"
  }
}

function Get-RisePalsParentWorkerEvidenceState {
  param([string]$EvidenceRoot, [int]$ScenarioNumber)
  $state = @{
    markerPresent = $false; markerDigest = $null
    checkpointPresent = $false; checkpointDigest = $null
    finalPresent = $false; finalDigest = $null
  }
  if (-not [IO.Directory]::Exists($EvidenceRoot)) { return $state }
  $rootItem = Get-Item -LiteralPath $EvidenceRoot -Force -ErrorAction Stop
  if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    return $state
  }
  $nonce = "{0:x32}" -f $ScenarioNumber
  foreach ($entry in @(
      @("marker", "node-parent-entry-marker-$nonce.json"),
      @("checkpoint", "node-parent-checkpoint-$nonce.json"),
      @("final", "node-parent-result-$nonce.json")
    )) {
    $path = Join-Path $rootItem.FullName $entry[1]
    if (-not [IO.File]::Exists($path)) { continue }
    $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
    if ($item.PSIsContainer -or
      ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      continue
    }
    $state["$($entry[0])Present"] = $true
    $state["$($entry[0])Digest"] =
      Get-RisePalsParentHarnessFileSha256 -LiteralPath $item.FullName
  }
  return $state
}

function Get-RisePalsParentHarnessResidueCount {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return 0 }
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return 1 }
  return 1 + @(Get-ChildItem -LiteralPath $item.FullName -Force).Count
}

function Get-RisePalsParentWorkerPersistenceExitCode {
  param([string]$ClosedError)
  $map = @{
    "worker-report-contract" = 101
    "worker-report-exit-code" = 102
    "worker-report-boolean" = 103
    "worker-report-parent-evidence" = 104
    "worker-report-state" = 105
    "worker-report-file" = 106
    "worker-report-json" = 107
    "worker-report-temporary-exists" = 108
    "worker-report-write" = 109
    "worker-report-move" = 110
    "worker-report-reopen" = 111
    "worker-report-evidence-state" = 112
    "worker-report-construction" = 113
    "worker-report-state-update" = 114
    "worker-report-state-completion" = 115
    "worker-report-attempt-state" = 116
    "worker-report-write-call" = 117
    "worker-report-command-resolution" = 118
    "worker-report-root" = 119
    "worker-report-record-shape" = 120
  }
  if ($map.ContainsKey($ClosedError)) { return [int]$map[$ClosedError] }
  return 121
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
  param(
    [string]$Scenario,
    [string]$CaseRoot,
    [string]$EvidenceRoot,
    [scriptblock]$WorkerStageSink,
    [scriptblock]$FixtureStageSink
  )
  $caseInfra = Join-Path $CaseRoot "infra"
  if ($null -ne $FixtureStageSink) { & $FixtureStageSink "artifact-copy" "pending" }
  Copy-RisePalsParentArtifacts -CaseInfra $caseInfra
  if ($null -ne $FixtureStageSink) { & $FixtureStageSink "artifact-copy" "passed" }
  if ($null -ne $FixtureStageSink) { & $FixtureStageSink "diagnostic-contract-import" "pending" }
  Import-Module (Join-Path $caseInfra "node-destination-diagnostic-contract.psm1") -Force
  if ($null -ne $FixtureStageSink) { & $FixtureStageSink "diagnostic-contract-import" "passed" }
  if ($null -ne $FixtureStageSink) { & $FixtureStageSink "synthetic-node-create" "pending" }
  $fixture = New-RisePalsParentFixture -CaseRoot $CaseRoot
  if ($null -ne $FixtureStageSink) { & $FixtureStageSink "synthetic-node-create" "passed" }
  if ($null -ne $FixtureStageSink) { & $FixtureStageSink "inventory-create" "pending" }
  $inventory = New-RisePalsNodeInventory -Root $fixture
  if ($null -ne $FixtureStageSink) { & $FixtureStageSink "inventory-create" "passed" }
  $inventoryPath = Join-Path $CaseRoot "inventory.json"
  if ($null -ne $FixtureStageSink) { & $FixtureStageSink "inventory-persist" "pending" }
  [IO.File]::WriteAllText($inventoryPath, ($inventory | ConvertTo-Json -Depth 12),
    [Text.UTF8Encoding]::new($false))
  if ($null -ne $FixtureStageSink) { & $FixtureStageSink "inventory-persist" "passed" }
  if ($null -ne $FixtureStageSink) { & $FixtureStageSink "inventory-digest" "pending" }
  $expectedInventoryHash = Get-RisePalsParentHarnessFileSha256 -LiteralPath $inventoryPath
  if ($null -ne $FixtureStageSink) {
    & $FixtureStageSink "inventory-digest" "passed"
    & $FixtureStageSink "complete" "passed"
  }
  if ($null -ne $WorkerStageSink) { & $WorkerStageSink "fixture-created" $null $null }
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
      $hashValues[$entry.Key] = Get-RisePalsParentHarnessFileSha256 -LiteralPath $path
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
  if ($null -ne $WorkerStageSink) { & $WorkerStageSink "outer-parent-invoked" $null $null }
  $process = Start-Process -FilePath $powershell51 -ArgumentList $arguments `
    -WindowStyle Hidden -Wait -PassThru
  $outerExitCode = $process.ExitCode
  $process.Dispose()
  $process = $null
  if ($null -ne $WorkerStageSink) {
    & $WorkerStageSink "outer-parent-exited" $outerExitCode $null
  }
  if ($expectNoEvidence) {
    Assert-RisePalsParentTest -Condition ($outerExitCode -eq 82) `
      -Label "$Scenario did not fail at the primitive evidence boundary."
    if ([IO.Directory]::Exists($EvidenceRoot)) {
      $allowedPreexisting = if ($Scenario -ceq "EvidenceNonempty") { 1 } else { 0 }
      Assert-RisePalsParentTest `
        -Condition (@(Get-ChildItem -LiteralPath $EvidenceRoot -Force).Count -eq $allowedPreexisting) `
        -Label "$Scenario wrote unauthorized evidence."
    }
    if ($null -ne $WorkerStageSink) {
      & $WorkerStageSink "durable-records-reopened" $outerExitCode $null
      & $WorkerStageSink "scenario-assertions-complete" $outerExitCode $null
    }
    return [pscustomobject]@{ exitCode = $outerExitCode; stage = $null; category = $null }
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
  if ($null -ne $WorkerStageSink) {
    & $WorkerStageSink "durable-records-reopened" $outerExitCode $final.childExitCode
  }
  if ($Scenario -ceq "PreflightSuccess") {
    if ($outerExitCode -ne 0) { throw "preflight_outer_exit_failure" }
    if ($null -ne $final.firstFailedStage) { throw "preflight_parent_failure_claim" }
    if ([bool]$final.processCreated) { throw "preflight_process_creation_claim" }
    if ($null -ne $final.childExitCode) { throw "preflight_child_exit_claim" }
    if (-not [bool]$final.innerRequestPresent) { throw "preflight_inner_request_claim" }
    if ("inner-transport-dispatched" -in @($final.completedStages)) {
      throw "preflight_dispatch_claim"
    }
  } else {
    Assert-RisePalsParentTest -Condition ($outerExitCode -eq 90 -and
      [string]$final.firstFailedStage -ceq $expectedStage -and
      [string]$final.sanitizedFailureCategory -ceq $expectedCategory) `
      -Label "$Scenario failure classification mismatch."
  }
  if ($null -ne $WorkerStageSink) {
    & $WorkerStageSink "scenario-assertions-complete" $outerExitCode $final.childExitCode
  }
  return [pscustomobject]@{
    exitCode = $outerExitCode
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
  param([int]$Number, [string]$Root, [string]$InjectedFailureStage)
  $scenario = [string]$scenarioNames[$Number - 1]
  $caseRoot = Join-Path $Root ("case-{0:d2}" -f $Number)
  $evidenceRoot = Join-Path $documentsCodex (
    "risepals-parent-entry-harness-{0}-{1:d2}" -f (Split-Path -Leaf $Root), $Number
  )
  $state = @{
    workerStage = "worker-started"
    fixtureStage = "worker-entry"
    fixturePredicate = "pending"
    sanitizedFailureCategory = $null
    outerExitCode = $null
    childExitCode = $null
    evidenceState = @{
      markerPresent = $false; markerDigest = $null
      checkpointPresent = $false; checkpointDigest = $null
      finalPresent = $false; finalDigest = $null
    }
    reportPersistenceAttempted = $false
    reportPersistenceCompleted = $false
    cleanupAttempted = $false
    cleanupCompleted = $false
    evidenceResidueCount = 0
    temporaryResidueCount = 0
  }
  $script:RisePalsParentWorkerState = $state
  $script:RisePalsParentInjectedFailureStage = $InjectedFailureStage
  $fixtureStageSink = {
    param([string]$Stage, [string]$Predicate)
    if ($Stage -notin $fixtureStages -or $Predicate -notin $fixturePredicates) {
      throw "fixture_failure"
    }
    $workerState = $script:RisePalsParentWorkerState
    $workerState.fixtureStage = $Stage
    $workerState.fixturePredicate = $Predicate
    if ($Stage -ceq "inventory-persist" -and $Predicate -ceq "pending" -and
      [string]$script:RisePalsParentInjectedFailureStage -ceq "fixture-inventory-persist") {
      throw "fixture_failure"
    }
  }
  $stageSink = {
    param([string]$Stage, [AllowNull()][object]$OuterExitCode,
      [AllowNull()][object]$ChildExitCode)
    $workerState = $script:RisePalsParentWorkerState
    $workerState.workerStage = $Stage
    if ($null -ne $OuterExitCode) { $workerState.outerExitCode = [int]$OuterExitCode }
    if ($null -ne $ChildExitCode) { $workerState.childExitCode = [int]$ChildExitCode }
  }
  $endToEnd = $Number -le 23
  $workerExitCode = 0
  try {
    & $fixtureStageSink "case-root-create" "pending"
    [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
    & $fixtureStageSink "case-root-create" "passed"
    & $fixtureStageSink "evidence-root-create" "pending"
    [IO.Directory]::CreateDirectory($evidenceRoot) | Out-Null
    & $fixtureStageSink "evidence-root-create" "passed"
    $result = if ($endToEnd) {
      Invoke-RisePalsParentEndToEnd -Scenario $scenario -CaseRoot $caseRoot `
        -EvidenceRoot $evidenceRoot -WorkerStageSink $stageSink `
        -FixtureStageSink $fixtureStageSink
    } else {
      & $fixtureStageSink "complete" "passed"
      & $stageSink "fixture-created" $null $null
      Invoke-RisePalsParentPureScenario -Scenario $scenario -CaseRoot $caseRoot
    }
    if (-not $endToEnd) {
      & $stageSink "scenario-assertions-complete" $null $null
    }
    if ($InjectedFailureStage -ceq "scenario-assertions-complete") {
      $state.workerStage = "scenario-assertions-complete"
      throw "scenario_assertion_failure"
    }
    $reportedOuterExitCode = if ($endToEnd) { $result.exitCode } else { $null }
    & $stageSink "report-persisted" $reportedOuterExitCode $null
    $state.evidenceState = Get-RisePalsParentWorkerEvidenceState `
      -EvidenceRoot $evidenceRoot -ScenarioNumber $Number
    $state.reportPersistenceAttempted = $true
    $checkpointRecord = New-RisePalsParentWorkerRecord -ScenarioNumber $Number `
      -ScenarioName $scenario -WorkerStage $state.workerStage `
      -FixtureStage $state.fixtureStage -FixturePredicate $state.fixturePredicate `
      -SanitizedFailureCategory $null -OuterExitCode $state.outerExitCode `
      -ChildExitCode $state.childExitCode -EvidenceState $state.evidenceState `
      -ReportPersistenceAttempted $true -ReportPersistenceCompleted $true `
      -CleanupAttempted $false -CleanupCompleted $false -EvidenceResidueCount 0 `
      -TemporaryResidueCount 0
    [void](Write-RisePalsParentWorkerRecordAtomic -Root $Root -Record $checkpointRecord)
    $state.reportPersistenceCompleted = $true
  } catch {
    $closedMessage = [string]$_.Exception.Message
    if ($closedMessage.StartsWith("worker-report-", [StringComparison]::Ordinal)) {
      $state.sanitizedFailureCategory = "report_persistence_failure"
      $workerExitCode = Get-RisePalsParentWorkerPersistenceExitCode -ClosedError $closedMessage
    } elseif ($closedMessage -in $workerCategories -and
      $closedMessage.StartsWith("preflight_", [StringComparison]::Ordinal)) {
      $state.sanitizedFailureCategory = $closedMessage
    } elseif ([string]$state.workerStage -ceq "worker-started") {
      $state.fixturePredicate = "failed"
      $state.sanitizedFailureCategory = "fixture_failure"
    } elseif ([string]$state.workerStage -ceq "outer-parent-invoked") {
      $state.sanitizedFailureCategory = "outer_parent_failure"
    } elseif ([string]$state.workerStage -ceq "outer-parent-exited") {
      $state.sanitizedFailureCategory = "durable_record_failure"
    } elseif ([string]$state.workerStage -ceq "durable-records-reopened" -or
      (-not $endToEnd -and [string]$state.workerStage -ceq "fixture-created")) {
      $state.sanitizedFailureCategory = "scenario_assertion_failure"
    } elseif ([string]$state.workerStage -ceq "report-persisted") {
      $state.sanitizedFailureCategory = "report_persistence_failure"
    } else {
      $state.sanitizedFailureCategory = "scenario_assertion_failure"
    }
    if ($workerExitCode -eq 0) {
      $workerExitCode = 91
    }
  } finally {
    try {
      $state.evidenceState = Get-RisePalsParentWorkerEvidenceState `
        -EvidenceRoot $evidenceRoot -ScenarioNumber $Number
    } catch {
      if ($null -eq $state.sanitizedFailureCategory) {
        $state.sanitizedFailureCategory = "durable_record_failure"
        $workerExitCode = 91
      }
    }
    $state.cleanupAttempted = $true
    try {
      Remove-RisePalsParentHarnessDirectory -Path $evidenceRoot
      $state.evidenceResidueCount = Get-RisePalsParentHarnessResidueCount -Path $evidenceRoot
      $state.cleanupCompleted = $state.evidenceResidueCount -eq 0
    } catch {
      $state.cleanupCompleted = $false
      $state.evidenceResidueCount = 1
    }
    $state.temporaryResidueCount = @(
      Get-ChildItem -LiteralPath $Root -Force -File |
        Where-Object { $_.Name -clike "*.tmp" }
    ).Count
    if (-not $state.cleanupCompleted -and $null -eq $state.sanitizedFailureCategory) {
      $state.workerStage = "cleanup-complete"
      $state.sanitizedFailureCategory = "cleanup_failure"
      $workerExitCode = 91
    } elseif ($null -eq $state.sanitizedFailureCategory) {
      $state.workerStage = "cleanup-complete"
    }
    try {
      $state.reportPersistenceAttempted = $true
      try {
        $finalRecord = New-RisePalsParentWorkerRecord -ScenarioNumber $Number `
          -ScenarioName $scenario -WorkerStage $state.workerStage `
          -FixtureStage $state.fixtureStage -FixturePredicate $state.fixturePredicate `
          -SanitizedFailureCategory $state.sanitizedFailureCategory `
          -OuterExitCode $state.outerExitCode -ChildExitCode $state.childExitCode `
          -EvidenceState $state.evidenceState -ReportPersistenceAttempted $true `
          -ReportPersistenceCompleted $true -CleanupAttempted $state.cleanupAttempted `
          -CleanupCompleted $state.cleanupCompleted `
          -EvidenceResidueCount $state.evidenceResidueCount `
          -TemporaryResidueCount $state.temporaryResidueCount
      } catch {
        throw "worker-report-construction"
      }
      try {
        $writeCommand = Get-Command -Name "Write-RisePalsParentWorkerRecordAtomic" `
          -CommandType Function -ErrorAction Stop
        if ($null -eq $writeCommand) { throw "worker-report-command-resolution" }
        if ([string]::IsNullOrWhiteSpace([string]$Root)) { throw "worker-report-root" }
        if (@($finalRecord).Count -ne 1 -or $null -eq $finalRecord.PSObject) {
          throw "worker-report-record-shape"
        }
        [void](Write-RisePalsParentWorkerRecordAtomic -Root $Root -Record $finalRecord `
            -Authoritative)
      } catch {
        $closedWrite = [string]$_.Exception.Message
        if ($closedWrite.StartsWith("worker-report-", [StringComparison]::Ordinal)) {
          throw $closedWrite
        }
        foreach ($closedCandidate in @(
            "worker-report-contract", "worker-report-exit-code", "worker-report-boolean",
            "worker-report-parent-evidence", "worker-report-state", "worker-report-file",
            "worker-report-json", "worker-report-temporary-exists", "worker-report-write",
            "worker-report-move", "worker-report-reopen"
          )) {
          if ($closedWrite.Contains($closedCandidate)) { throw $closedCandidate }
        }
        throw "worker-report-write-call"
      }
      $state.reportPersistenceCompleted = $true
    } catch {
      if ($workerExitCode -lt 100) {
        $workerExitCode = Get-RisePalsParentWorkerPersistenceExitCode `
          -ClosedError ([string]$_.Exception.Message)
      }
    }
  }
  return $workerExitCode
}

if ($WorkerScenario -gt 0) {
  if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { throw "WorkspaceRoot is required." }
  $workspace = [IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\')
  if (-not $workspace.StartsWith($temporaryRoot + "\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "Worker workspace escaped the temporary root."
  }
  if (-not [string]::IsNullOrEmpty($TestOnlyWorkerFailureStage) -and
    $WorkerScenario -ne 1) {
    throw "Synthetic worker failure is restricted to scenario 1."
  }
  $workerExitCode = Invoke-RisePalsParentWorker -Number $WorkerScenario -Root $workspace `
    -InjectedFailureStage $TestOnlyWorkerFailureStage
  exit $workerExitCode
}

if (-not [string]::IsNullOrEmpty($TestOnlyWorkerFailureStage)) {
  throw "Synthetic worker failure requires worker mode."
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
    $processExitCode = $process.ExitCode
    $process.Dispose()
    $process = $null
    $reportPath = Join-Path $workspace ("report-{0:d2}.json" -f $number)
    if (-not [IO.File]::Exists($reportPath)) {
      throw "Parent-entry scenario $number stage worker-started fixture worker-entry/pending category report_persistence_failure exit $processExitCode."
    }
    $report = Read-RisePalsParentWorkerRecord -Path $reportPath -ExpectedNumber $number
    if ($processExitCode -ne 0 -or $null -ne $report.sanitizedFailureCategory -or
      [string]$report.workerStage -cne "cleanup-complete" -or
      -not [bool]$report.reportPersistenceCompleted -or
      -not [bool]$report.cleanupCompleted) {
      $category = if ($null -eq $report.sanitizedFailureCategory) {
        "report_persistence_failure"
      } else {
        [string]$report.sanitizedFailureCategory
      }
      throw "Parent-entry scenario $number stage $($report.workerStage) fixture $($report.fixtureStage)/$($report.fixturePredicate) category $category exit $processExitCode."
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
