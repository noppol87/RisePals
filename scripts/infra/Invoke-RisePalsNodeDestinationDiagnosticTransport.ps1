[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Low")]
param(
  [ValidateSet("Simulation", "LiveReadOnly")][string]$Mode = "Simulation",
  [Parameter(Mandatory = $true)][ValidatePattern("^[A-Z0-9-]{12,120}$")]
  [string]$AuthorizationId,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")]
  [string]$InvocationNonce,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")]
  [string]$RepositoryHead,
  [Parameter(Mandatory = $true)][string]$InventoryPath,
  [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
  [string]$PrevalidatedRequestPath,
  [string]$RepositoryRoot = "C:\Codex PC SG2\Jeff\risepals",
  [string]$SimulationRoot,
  [ValidateSet(
    "Success", "LaunchFailure", "BootstrapEntryFailure", "SecurityModuleFailure",
    "ContractImportFailure", "ArgumentValidationFailure",
    "EvidenceDirectoryValidationFailure", "DiagnosticPreDispatchFailure",
    "ChildNonzeroBeforeEvidence", "MalformedEarlyRecord", "WrongBinding",
    "StaleOrReplay", "EarlySchemaDigestMismatch", "InterruptedAtomicWrite",
    "CleanupFailure", "FinalResultPersistenceFailure"
  )]
  [string]$Scenario = "Success",
  [switch]$ReturnResult
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$earlyContractPath = Join-Path $PSScriptRoot "node-destination-early-transport.psm1"
$securityBootstrapPath = Join-Path $PSScriptRoot "windows-powershell-security-bootstrap.ps1"
$childPath = Join-Path $PSScriptRoot "Invoke-RisePalsNodeDestinationDiagnosticChild.ps1"
$diagnosticPath = Join-Path $PSScriptRoot "Invoke-RisePalsNodeDestinationDiagnostic.ps1"
$diagnosticContractPath = Join-Path $PSScriptRoot "node-destination-diagnostic-contract.psm1"
$launcherPath = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
Import-Module -Name $earlyContractPath -Force -ErrorAction Stop

function Get-RisePalsNodeTransportResidueCount {
  param([string]$Path)
  if (-not [IO.Directory]::Exists($Path)) { return 0 }
  return @(Get-ChildItem -LiteralPath $Path -Force -Recurse).Count
}

function Get-RisePalsNodeTransportTemporaryCount {
  param([string]$Path)
  if (-not [IO.Directory]::Exists($Path)) { return 0 }
  return @(Get-ChildItem -LiteralPath $Path -Force -Recurse -File |
      Where-Object { $_.Name.EndsWith(".tmp", [StringComparison]::Ordinal) }).Count
}

function Remove-RisePalsNodeTransportDirectoryExact {
  param([string]$Path)
  $exact = [IO.Path]::GetFullPath($Path)
  if ([IO.Directory]::Exists($exact)) {
    $item = Get-Item -LiteralPath $exact -Force -ErrorAction Stop
    if (-not $item.PSIsContainer -or
      ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "transport-cleanup-boundary"
    }
    Remove-Item -LiteralPath $exact -Recurse -Force -ErrorAction Stop
  }
}

function Get-RisePalsNodeTransportFailureFromExit {
  param([int]$ExitCode)
  switch ($ExitCode) {
    70 { return [pscustomobject]@{ stage = "arguments-validated"; category = "argument_validation_failure" } }
    71 { return [pscustomobject]@{ stage = "bootstrap-entered"; category = "bootstrap_entry_failure" } }
    72 { return [pscustomobject]@{ stage = "security-module-initialized"; category = "security_module_failure" } }
    73 { return [pscustomobject]@{ stage = "contract-imported"; category = "contract_import_failure" } }
    74 { return [pscustomobject]@{ stage = "arguments-validated"; category = "argument_validation_failure" } }
    75 { return [pscustomobject]@{ stage = "diagnostic-dispatched"; category = "evidence_directory_failure" } }
    76 { return [pscustomobject]@{ stage = "diagnostic-dispatched"; category = "dispatch_failure" } }
    78 { return [pscustomobject]@{ stage = "schema-v2-evidence-persisted"; category = "child_exit_failure" } }
    79 { return [pscustomobject]@{ stage = "bootstrap-entered"; category = "atomic_write_failure" } }
    default { return [pscustomobject]@{ stage = "schema-v2-evidence-persisted"; category = "child_exit_failure" } }
  }
}

function Get-RisePalsNodeTransportChildArguments {
  param(
    [object]$Request,
    [string]$RequestPath,
    [string]$TransientDirectory,
    [string]$SchemaV2EvidenceDirectory
  )
  $pairs = [ordered]@{
    RequestPath = $RequestPath
    TransientDirectory = $TransientDirectory
    SchemaV2EvidenceDirectory = $SchemaV2EvidenceDirectory
    RepositoryRoot = $repository
    InventoryPath = [IO.Path]::GetFullPath($InventoryPath)
    Mode = $Mode
    AuthorizationId = [string]$Request.authorizationId
    InvocationNonce = [string]$Request.invocationNonce
    RepositoryHead = [string]$Request.repositoryHead
    LauncherSha256 = [string]$Request.launcherSha256
    EarlyContractSha256 = [string]$Request.earlyContractSha256
    SecurityBootstrapSha256 = [string]$Request.securityBootstrapSha256
    ChildSha256 = [string]$Request.childSha256
    DiagnosticSha256 = [string]$Request.diagnosticSha256
    DiagnosticContractSha256 = [string]$Request.diagnosticContractSha256
    InventorySha256 = [string]$Request.inventorySha256
    SimulationRoot = if ($Mode -ceq "Simulation") { [IO.Path]::GetFullPath($SimulationRoot) } else { "" }
    Scenario = $Scenario
  }
  $arguments = @(
    "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
    "-File", ('"{0}"' -f $childPath)
  )
  foreach ($entry in $pairs.GetEnumerator()) {
    $arguments += "--$($entry.Key)"
    $arguments += ('"{0}"' -f ([string]$entry.Value).Replace('"', '""'))
  }
  return $arguments
}

function Set-RisePalsNodeTransportSimulationTamper {
  param([string]$TransientDirectory, [object]$Request)
  if ($Scenario -ceq "MalformedEarlyRecord") {
    $path = Join-Path $TransientDirectory "marker-03-bootstrap-entered.json"
    [IO.File]::WriteAllText($path, "{", [Text.UTF8Encoding]::new($false))
  } elseif ($Scenario -ceq "WrongBinding") {
    $path = Join-Path $TransientDirectory "marker-03-bootstrap-entered.json"
    $marker = Read-RisePalsNodeEarlyJson -LiteralPath $path
    $marker.invocationNonce = "ffffffffffffffffffffffffffffffff"
    $marker.markerDigest = Get-RisePalsNodeEarlyMarkerDigest -Marker $marker
    [IO.File]::WriteAllText($path, ($marker | ConvertTo-Json -Compress -Depth 8),
      [Text.UTF8Encoding]::new($false))
  } elseif ($Scenario -ceq "StaleOrReplay") {
    $path = Join-Path $TransientDirectory "marker-99-replayed.json"
    [IO.File]::WriteAllText($path, "{}", [Text.UTF8Encoding]::new($false))
  } elseif ($Scenario -ceq "EarlySchemaDigestMismatch") {
    $path = Join-Path $TransientDirectory "marker-08-schema-v2-evidence-persisted.json"
    $marker = Read-RisePalsNodeEarlyJson -LiteralPath $path
    $marker.schemaV2EvidenceDigest = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    $marker.markerDigest = Get-RisePalsNodeEarlyMarkerDigest -Marker $marker
    [IO.File]::WriteAllText($path, ($marker | ConvertTo-Json -Compress -Depth 8),
      [Text.UTF8Encoding]::new($false))
  }
}

if ($Mode -ceq "LiveReadOnly") {
  if ($Scenario -cne "Success" -or -not [string]::IsNullOrEmpty($SimulationRoot)) {
    throw "LiveReadOnly prohibits simulation controls."
  }
} elseif ([string]::IsNullOrWhiteSpace($SimulationRoot) -or
  -not [string]::IsNullOrWhiteSpace($PrevalidatedRequestPath)) {
  throw "SimulationRoot is required in Simulation mode."
}

$head = (& git -c ("safe.directory={0}" -f $repository.Replace("\", "/")) `
  -C $repository rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $head -cne $RepositoryHead) {
  throw "The repository HEAD does not match the authorized binding."
}

$usingPrevalidatedRequest = -not [string]::IsNullOrWhiteSpace($PrevalidatedRequestPath)
$evidenceRoot = if ($usingPrevalidatedRequest) {
  Assert-RisePalsNodeEarlyEvidenceDirectory -Path $EvidenceDirectory -Mode $Mode
} else {
  Assert-RisePalsNodeEarlyEvidenceDirectory -Path $EvidenceDirectory -Mode $Mode -RequireEmpty
}
$inventoryExact = [IO.Path]::GetFullPath($InventoryPath)
$hashes = [ordered]@{
  launcher = Get-RisePalsNodeEarlySha256File -LiteralPath $launcherPath
  earlyContract = Get-RisePalsNodeEarlySha256File -LiteralPath $earlyContractPath
  securityBootstrap = Get-RisePalsNodeEarlySha256File -LiteralPath $securityBootstrapPath
  child = Get-RisePalsNodeEarlySha256File -LiteralPath $childPath
  diagnostic = Get-RisePalsNodeEarlySha256File -LiteralPath $diagnosticPath
  diagnosticContract = Get-RisePalsNodeEarlySha256File -LiteralPath $diagnosticContractPath
  inventory = Get-RisePalsNodeEarlySha256File -LiteralPath $inventoryExact
}
if (-not $PSCmdlet.ShouldProcess(
    $evidenceRoot,
    ("Run the {0} Node destination early-evidence transport" -f $Mode)
  )) {
  return
}
$requestPath = if ($usingPrevalidatedRequest) {
  $candidate = [IO.Path]::GetFullPath($PrevalidatedRequestPath)
  $expected = [IO.Path]::GetFullPath((Get-RisePalsNodeEarlyRequestPath `
        -EvidenceDirectory $evidenceRoot -InvocationNonce $InvocationNonce))
  $children = @(Get-ChildItem -LiteralPath $evidenceRoot -Force)
  $item = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
  if ($candidate -cne $expected -or $children.Count -ne 1 -or
    $children[0].FullName -cne $candidate -or $item.PSIsContainer -or
    ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "The prevalidated request boundary is invalid."
  }
  $candidate
} else {
  $request = New-RisePalsNodeEarlyRequest -AuthorizationId $AuthorizationId `
    -InvocationNonce $InvocationNonce -RepositoryHead $RepositoryHead `
    -LauncherSha256 $hashes.launcher -EarlyContractSha256 $hashes.earlyContract `
    -SecurityBootstrapSha256 $hashes.securityBootstrap -ChildSha256 $hashes.child `
    -DiagnosticSha256 $hashes.diagnostic `
    -DiagnosticContractSha256 $hashes.diagnosticContract -InventorySha256 $hashes.inventory
  Write-RisePalsNodeEarlyRequestAtomic -Request $request -EvidenceDirectory $evidenceRoot
}
$request = Read-RisePalsNodeEarlyRequest -Path $requestPath `
  -ExpectedAuthorizationId $AuthorizationId -ExpectedInvocationNonce $InvocationNonce `
  -ExpectedRepositoryHead $RepositoryHead -ExpectedLauncherSha256 $hashes.launcher `
  -ExpectedEarlyContractSha256 $hashes.earlyContract `
  -ExpectedSecurityBootstrapSha256 $hashes.securityBootstrap `
  -ExpectedChildSha256 $hashes.child -ExpectedDiagnosticSha256 $hashes.diagnostic `
  -ExpectedDiagnosticContractSha256 $hashes.diagnosticContract `
  -ExpectedInventorySha256 $hashes.inventory

$transientDirectory = Join-Path $evidenceRoot ("transient-{0}" -f $InvocationNonce)
$schemaDirectory = Join-Path $evidenceRoot ("schema-v2-{0}" -f $InvocationNonce)
[IO.Directory]::CreateDirectory($transientDirectory) | Out-Null
[IO.Directory]::CreateDirectory($schemaDirectory) | Out-Null
$completed = @("request-created", "elevated-launch-attempted")
$processCreated = $false
$childExitCode = $null
$nativeCode = $null
$hResult = $null
$failedStage = $null
$failureCategory = $null
$schemaEvidence = $null
$schemaDigest = $null

if ($Scenario -ceq "LaunchFailure") {
  $failedStage = "elevated-process-created"
  $failureCategory = "launch_failure"
  $nativeCode = 2
} else {
  $powershell51 = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
  $arguments = Get-RisePalsNodeTransportChildArguments -Request $request `
    -RequestPath $requestPath -TransientDirectory $transientDirectory `
    -SchemaV2EvidenceDirectory $schemaDirectory
  try {
    if ($Mode -ceq "LiveReadOnly") {
      $process = Start-Process -FilePath $powershell51 -ArgumentList $arguments `
        -Verb RunAs -Wait -PassThru -ErrorAction Stop
    } else {
      $process = Start-Process -FilePath $powershell51 -ArgumentList $arguments `
        -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
    }
    $processCreated = $true
    $childExitCode = [int]$process.ExitCode
    $completed += "elevated-process-created"
  } catch {
    $failedStage = "elevated-process-created"
    $failureCategory = "launch_failure"
    if ($_.Exception -is [ComponentModel.Win32Exception]) {
      $nativeCode = [int]$_.Exception.NativeErrorCode
    }
    $hResult = [int]$_.Exception.HResult
  }
}

if ($processCreated) {
  if ($Scenario -in @(
      "MalformedEarlyRecord", "WrongBinding", "StaleOrReplay", "EarlySchemaDigestMismatch"
    )) {
    Set-RisePalsNodeTransportSimulationTamper -TransientDirectory $transientDirectory `
      -Request $request
  }
  $schemaPath = Join-Path $schemaDirectory ("node-diagnostic-{0}.json" -f $InvocationNonce)
  if ([IO.File]::Exists($schemaPath)) {
    try {
      Import-Module -Name $diagnosticContractPath -Force -ErrorAction Stop
      $schemaEvidence = Read-RisePalsNodeEvidence -LiteralPath $schemaPath `
        -AuthorizationId $AuthorizationId -InvocationNonce $InvocationNonce `
        -RepositoryHead $RepositoryHead -ScriptSha256 $hashes.diagnostic `
        -InventoryFileSha256 $hashes.inventory
      $schemaDigest = [string]$schemaEvidence.evidenceDigest
    } catch {
      $schemaEvidence = $null
      $schemaDigest = $null
    }
  }
  $chain = Read-RisePalsNodeEarlyMarkerChain -TransientDirectory $transientDirectory `
    -Request $request -ExpectedSchemaV2EvidenceDigest $schemaDigest
  $completed += @($chain.stages)
  $completed += "child-exited"
  if (-not [bool]$chain.valid) {
    $failedStage = [string]$chain.firstFailedStage
    $failureCategory = [string]$chain.category
  } elseif ([int]$childExitCode -ne 0) {
    $exitFailure = Get-RisePalsNodeTransportFailureFromExit -ExitCode $childExitCode
    $failedStage = [string]$exitFailure.stage
    $failureCategory = [string]$exitFailure.category
  } elseif (@($chain.stages).Count -ne 6 -or $null -eq $schemaEvidence) {
    $failedStage = "schema-v2-evidence-persisted"
    $failureCategory = "evidence_mismatch"
  }
}

$schemaValid = $null -ne $schemaEvidence -and
  "schema-v2-evidence-persisted" -in $completed
$claimedSchemaDigest = if ($schemaValid) { $schemaDigest } else { $null }
$checkpoint = New-RisePalsNodeEarlyResult -RecordType checkpoint -Request $request `
  -ProcessCreated $processCreated -ChildExitCode $childExitCode -CompletedStages $completed `
  -FirstFailedStage $failedStage -SanitizedFailureCategory $failureCategory `
  -NativeErrorCode $nativeCode -HResult $hResult `
  -SchemaV2EvidencePresent $schemaValid -SchemaV2EvidenceDigest $claimedSchemaDigest `
  -CleanupAttempted $false -CleanupCompleted $false -TransientResidueCount 0 `
  -TemporaryResidueCount 0
$checkpointPath = Write-RisePalsNodeEarlyResultAtomic -Result $checkpoint `
  -EvidenceDirectory $evidenceRoot
$checkpoint = Read-RisePalsNodeEarlyResult -Path $checkpointPath -Request $request
$completed += "parent-reopened-result"

$cleanupAttempted = $true
$cleanupCompleted = $false
if ($Scenario -cne "CleanupFailure") {
  try {
    Remove-RisePalsNodeTransportDirectoryExact -Path $transientDirectory
    if (-not $schemaValid) {
      Remove-RisePalsNodeTransportDirectoryExact -Path $schemaDirectory
    }
    $cleanupCompleted = -not [IO.Directory]::Exists($transientDirectory)
  } catch {
    $cleanupCompleted = $false
  }
}
if ($cleanupCompleted) { $completed += "cleanup-complete" }
$transientResidue = Get-RisePalsNodeTransportResidueCount -Path $transientDirectory
$temporaryResidue = Get-RisePalsNodeTransportTemporaryCount -Path $evidenceRoot
if (-not $cleanupCompleted) {
  $failedStage = "cleanup-complete"
  $failureCategory = "cleanup_failure"
}

$final = New-RisePalsNodeEarlyResult -RecordType final -Request $request `
  -ProcessCreated $processCreated -ChildExitCode $childExitCode -CompletedStages $completed `
  -FirstFailedStage $failedStage -SanitizedFailureCategory $failureCategory `
  -NativeErrorCode $nativeCode -HResult $hResult `
  -SchemaV2EvidencePresent $schemaValid -SchemaV2EvidenceDigest $claimedSchemaDigest `
  -CleanupAttempted $cleanupAttempted -CleanupCompleted $cleanupCompleted `
  -TransientResidueCount $transientResidue -TemporaryResidueCount $temporaryResidue `
  -CheckpointDigest $checkpoint.evidenceDigest
$resultPath = $null
if ($Scenario -ceq "FinalResultPersistenceFailure") {
  try {
    [void](Write-RisePalsNodeEarlyResultAtomic -Result $final `
        -EvidenceDirectory $evidenceRoot -InterruptBeforeMove)
    throw "Expected interrupted result persistence."
  } catch {
    $primaryTemporary = (Get-RisePalsNodeEarlyResultPath -EvidenceDirectory $evidenceRoot `
        -InvocationNonce $InvocationNonce) + ".tmp"
    if ([IO.File]::Exists($primaryTemporary)) { [IO.File]::Delete($primaryTemporary) }
    $failedStage = "parent-reopened-result"
    $failureCategory = "final_result_failure"
    $temporaryResidue = Get-RisePalsNodeTransportTemporaryCount -Path $evidenceRoot
    $final = New-RisePalsNodeEarlyResult -RecordType final -Request $request `
      -ProcessCreated $processCreated -ChildExitCode $childExitCode -CompletedStages $completed `
      -FirstFailedStage $failedStage -SanitizedFailureCategory $failureCategory `
      -NativeErrorCode $nativeCode -HResult $hResult `
      -SchemaV2EvidencePresent $schemaValid -SchemaV2EvidenceDigest $claimedSchemaDigest `
      -CleanupAttempted $cleanupAttempted -CleanupCompleted $cleanupCompleted `
      -TransientResidueCount $transientResidue -TemporaryResidueCount $temporaryResidue `
      -CheckpointDigest $checkpoint.evidenceDigest
    $resultPath = Write-RisePalsNodeEarlyResultAtomic -Result $final `
      -EvidenceDirectory $evidenceRoot -Fallback
  }
} else {
  $resultPath = Write-RisePalsNodeEarlyResultAtomic -Result $final `
    -EvidenceDirectory $evidenceRoot
}
$final = Read-RisePalsNodeEarlyResult -Path $resultPath -Request $request `
  -ExpectedCheckpointDigest $checkpoint.evidenceDigest

$output = [pscustomobject][ordered]@{
  requestPath = $requestPath
  checkpointPath = $checkpointPath
  resultPath = $resultPath
  schemaV2EvidencePath = if ($schemaValid) { $schemaPath } else { $null }
  request = $request
  checkpoint = $checkpoint
  result = $final
}
if ($ReturnResult) { return $output }
$output | ConvertTo-Json -Compress -Depth 8
