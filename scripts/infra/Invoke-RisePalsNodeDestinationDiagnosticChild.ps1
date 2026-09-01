Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Exit-RisePalsNodeEarlyChild {
  param([ValidateRange(1, 255)][int]$Code)
  [Environment]::Exit($Code)
}

$values = @{}
if ($args.Count -eq 0 -or ($args.Count % 2) -ne 0) {
  Exit-RisePalsNodeEarlyChild -Code 70
}
for ($index = 0; $index -lt $args.Count; $index += 2) {
  $name = [string]$args[$index]
  $value = [string]$args[$index + 1]
  if ($name -cnotmatch "^--[A-Za-z][A-Za-z0-9]+$" -or $values.ContainsKey($name)) {
    Exit-RisePalsNodeEarlyChild -Code 70
  }
  $values[$name] = $value
}
$required = @(
  "--RequestPath", "--TransientDirectory", "--SchemaV2EvidenceDirectory",
  "--RepositoryRoot", "--InventoryPath", "--Mode", "--AuthorizationId",
  "--InvocationNonce", "--RepositoryHead", "--LauncherSha256",
  "--EarlyContractSha256", "--SecurityBootstrapSha256", "--ChildSha256",
  "--DiagnosticSha256", "--DiagnosticContractSha256", "--InventorySha256",
  "--SimulationRoot", "--Scenario"
)
if ((@($values.Keys | Sort-Object) -join "|") -cne
  (@($required | Sort-Object) -join "|")) {
  Exit-RisePalsNodeEarlyChild -Code 70
}

$scenario = [string]$values["--Scenario"]
if ($scenario -ceq "BootstrapEntryFailure") {
  Exit-RisePalsNodeEarlyChild -Code 71
}

$earlyContractPath = Join-Path $PSScriptRoot "node-destination-early-transport.psm1"
try {
  Import-Module -Name $earlyContractPath -Force -ErrorAction Stop
} catch {
  Exit-RisePalsNodeEarlyChild -Code 71
}

try {
  $request = Read-RisePalsNodeEarlyRequest -Path $values["--RequestPath"] `
    -ExpectedAuthorizationId $values["--AuthorizationId"] `
    -ExpectedInvocationNonce $values["--InvocationNonce"] `
    -ExpectedRepositoryHead $values["--RepositoryHead"] `
    -ExpectedLauncherSha256 $values["--LauncherSha256"] `
    -ExpectedEarlyContractSha256 $values["--EarlyContractSha256"] `
    -ExpectedSecurityBootstrapSha256 $values["--SecurityBootstrapSha256"] `
    -ExpectedChildSha256 $values["--ChildSha256"] `
    -ExpectedDiagnosticSha256 $values["--DiagnosticSha256"] `
    -ExpectedDiagnosticContractSha256 $values["--DiagnosticContractSha256"] `
    -ExpectedInventorySha256 $values["--InventorySha256"]
  $previousDigest = [string]$request.requestDigest
  $bootstrapMarker = New-RisePalsNodeEarlyMarker -Request $request `
    -Stage "bootstrap-entered" -PreviousDigest $previousDigest
  if ($scenario -ceq "InterruptedAtomicWrite") {
    [void](Write-RisePalsNodeEarlyMarkerAtomic -Marker $bootstrapMarker `
        -TransientDirectory $values["--TransientDirectory"] -InterruptBeforeMove)
  }
  [void](Write-RisePalsNodeEarlyMarkerAtomic -Marker $bootstrapMarker `
      -TransientDirectory $values["--TransientDirectory"])
  $previousDigest = [string]$bootstrapMarker.markerDigest
} catch {
  Exit-RisePalsNodeEarlyChild -Code 79
}

if ($scenario -ceq "SecurityModuleFailure") {
  Exit-RisePalsNodeEarlyChild -Code 72
}
$securityBootstrapPath = Join-Path $PSScriptRoot "windows-powershell-security-bootstrap.ps1"
try {
  if ((Get-RisePalsNodeEarlySha256File -LiteralPath $securityBootstrapPath) -cne
    [string]$request.securityBootstrapSha256) {
    throw "security-bootstrap-hash"
  }
  . $securityBootstrapPath
  [void](Initialize-RisePalsWindowsPowerShellSecurityModule)
  $securityMarker = New-RisePalsNodeEarlyMarker -Request $request `
    -Stage "security-module-initialized" -PreviousDigest $previousDigest
  [void](Write-RisePalsNodeEarlyMarkerAtomic -Marker $securityMarker `
      -TransientDirectory $values["--TransientDirectory"])
  $previousDigest = [string]$securityMarker.markerDigest
} catch {
  Exit-RisePalsNodeEarlyChild -Code 72
}

if ($scenario -ceq "ContractImportFailure") {
  Exit-RisePalsNodeEarlyChild -Code 73
}
$diagnosticContractPath = Join-Path $PSScriptRoot "node-destination-diagnostic-contract.psm1"
try {
  if ((Get-RisePalsNodeEarlySha256File -LiteralPath $diagnosticContractPath) -cne
    [string]$request.diagnosticContractSha256) {
    throw "diagnostic-contract-hash"
  }
  Import-Module -Name $diagnosticContractPath -Force -ErrorAction Stop
  $contractMarker = New-RisePalsNodeEarlyMarker -Request $request `
    -Stage "contract-imported" -PreviousDigest $previousDigest
  [void](Write-RisePalsNodeEarlyMarkerAtomic -Marker $contractMarker `
      -TransientDirectory $values["--TransientDirectory"])
  $previousDigest = [string]$contractMarker.markerDigest
} catch {
  Exit-RisePalsNodeEarlyChild -Code 73
}

if ($scenario -ceq "ArgumentValidationFailure") {
  Exit-RisePalsNodeEarlyChild -Code 74
}
$diagnosticPath = Join-Path $PSScriptRoot "Invoke-RisePalsNodeDestinationDiagnostic.ps1"
$childPath = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
try {
  if ([string]$values["--AuthorizationId"] -cnotmatch "^[A-Z0-9-]{12,120}$" -or
    [string]$values["--InvocationNonce"] -cnotmatch "^[a-f0-9]{32}$" -or
    [string]$values["--RepositoryHead"] -cnotmatch "^[a-f0-9]{40}$" -or
    [string]$values["--Mode"] -notin @("Simulation", "LiveReadOnly") -or
    (Get-RisePalsNodeEarlySha256File -LiteralPath $earlyContractPath) -cne
      [string]$request.earlyContractSha256 -or
    (Get-RisePalsNodeEarlySha256File -LiteralPath $childPath) -cne
      [string]$request.childSha256 -or
    (Get-RisePalsNodeEarlySha256File -LiteralPath $diagnosticPath) -cne
      [string]$request.diagnosticSha256 -or
    (Get-RisePalsNodeEarlySha256File -LiteralPath $values["--InventoryPath"]) -cne
      [string]$request.inventorySha256) {
    throw "argument-binding"
  }
  $safeRepository = [IO.Path]::GetFullPath($values["--RepositoryRoot"]).TrimEnd('\')
  $head = (& git -c ("safe.directory={0}" -f $safeRepository.Replace("\", "/")) `
    -C $safeRepository rev-parse HEAD 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or $head -cne [string]$request.repositoryHead) {
    throw "repository-head"
  }
  if ([string]$values["--Mode"] -ceq "Simulation") {
    $simulationRoot = [IO.Path]::GetFullPath($values["--SimulationRoot"])
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if (-not $simulationRoot.StartsWith(
        $temporaryRoot + "\", [StringComparison]::OrdinalIgnoreCase)) {
      throw "simulation-root"
    }
  } elseif (-not [string]::IsNullOrEmpty([string]$values["--SimulationRoot"])) {
    throw "live-simulation-root"
  }
  $argumentMarker = New-RisePalsNodeEarlyMarker -Request $request `
    -Stage "arguments-validated" -PreviousDigest $previousDigest
  [void](Write-RisePalsNodeEarlyMarkerAtomic -Marker $argumentMarker `
      -TransientDirectory $values["--TransientDirectory"])
  $previousDigest = [string]$argumentMarker.markerDigest
} catch {
  Exit-RisePalsNodeEarlyChild -Code 74
}

if ($scenario -ceq "EvidenceDirectoryValidationFailure") {
  Exit-RisePalsNodeEarlyChild -Code 75
}
try {
  [void](Assert-RisePalsNodeEarlyEvidenceDirectory `
      -Path $values["--SchemaV2EvidenceDirectory"] -Mode $values["--Mode"] -RequireEmpty)
} catch {
  Exit-RisePalsNodeEarlyChild -Code 75
}

if ($scenario -ceq "DiagnosticPreDispatchFailure") {
  Exit-RisePalsNodeEarlyChild -Code 76
}
try {
  $dispatchMarker = New-RisePalsNodeEarlyMarker -Request $request `
    -Stage "diagnostic-dispatched" -PreviousDigest $previousDigest
  [void](Write-RisePalsNodeEarlyMarkerAtomic -Marker $dispatchMarker `
      -TransientDirectory $values["--TransientDirectory"])
  $previousDigest = [string]$dispatchMarker.markerDigest
} catch {
  Exit-RisePalsNodeEarlyChild -Code 76
}
if ($scenario -ceq "ChildNonzeroBeforeEvidence") {
  Exit-RisePalsNodeEarlyChild -Code 78
}

try {
  $parameters = @{
    Mode = [string]$values["--Mode"]
    AuthorizationId = [string]$request.authorizationId
    InvocationNonce = [string]$request.invocationNonce
    RepositoryHead = [string]$request.repositoryHead
    ExpectedScriptSha256 = [string]$request.diagnosticSha256
    ExpectedInventorySha256 = [string]$request.inventorySha256
    InventoryPath = [string]$values["--InventoryPath"]
    EvidenceDirectory = [string]$values["--SchemaV2EvidenceDirectory"]
    RepositoryRoot = [string]$values["--RepositoryRoot"]
    Confirm = $false
  }
  if ([string]$values["--Mode"] -ceq "Simulation") {
    $parameters.SimulationRoot = [string]$values["--SimulationRoot"]
    $parameters.SimulationFault = "None"
  }
  $null = & $diagnosticPath @parameters 2>$null
  $schemaPath = Join-Path $values["--SchemaV2EvidenceDirectory"] `
    ("node-diagnostic-{0}.json" -f [string]$request.invocationNonce)
  $schema = Read-RisePalsNodeEvidence -LiteralPath $schemaPath `
    -AuthorizationId $request.authorizationId -InvocationNonce $request.invocationNonce `
    -RepositoryHead $request.repositoryHead -ScriptSha256 $request.diagnosticSha256 `
    -InventoryFileSha256 $request.inventorySha256
  $schemaMarker = New-RisePalsNodeEarlyMarker -Request $request `
    -Stage "schema-v2-evidence-persisted" -PreviousDigest $previousDigest `
    -SchemaV2EvidenceDigest $schema.evidenceDigest
  [void](Write-RisePalsNodeEarlyMarkerAtomic -Marker $schemaMarker `
      -TransientDirectory $values["--TransientDirectory"])
} catch {
  Exit-RisePalsNodeEarlyChild -Code 78
}

[Environment]::Exit(0)
