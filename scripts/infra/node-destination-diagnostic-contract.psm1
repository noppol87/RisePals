Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RisePalsNodeInventorySchema = "rise-pals-node-destination-inventory-v1"
$script:RisePalsNodeEvidenceSchema = "rise-pals-node-destination-diagnostic-v1"
$script:RisePalsNodeClassifications = @(
  "version-directory-absent",
  "version-directory-empty",
  "complete-except-node",
  "additional-official-files-missing",
  "unexpected-object-present",
  "file-content-mismatch",
  "object-type-mismatch",
  "reparse-point-present",
  "canonical-ancestry-failure",
  "ACL-boundary-failure",
  "access-denied",
  "node-already-present",
  "unknown-controlled-failure"
)
$script:RisePalsNodePredicates = @(
  "inventory-json",
  "inventory-property-set",
  "inventory-schema",
  "inventory-record-property-set",
  "inventory-relative-path",
  "inventory-record-type",
  "inventory-file-metadata",
  "inventory-directory-metadata",
  "inventory-duplicate-path",
  "inventory-counts",
  "inventory-digest",
  "evidence-json",
  "evidence-property-set",
  "evidence-schema",
  "evidence-binding",
  "evidence-classification",
  "evidence-measurement-state",
  "evidence-comparison-state",
  "evidence-repair-state",
  "evidence-digest"
)

function Get-RisePalsNodeSha256Bytes {
  param([Parameter(Mandatory = $true)][byte[]]$Bytes)

  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace("-", "").ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
  }
}

function Get-RisePalsNodeSha256Text {
  param([Parameter(Mandatory = $true)][string]$Text)
  return Get-RisePalsNodeSha256Bytes -Bytes ([Text.UTF8Encoding]::new($false).GetBytes($Text))
}

function Get-RisePalsNodeSha256File {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)

  $stream = [IO.File]::OpenRead([IO.Path]::GetFullPath($LiteralPath))
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace("-", "").ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
    $stream.Dispose()
  }
}

function Get-RisePalsNodeOrdinalSortedStrings {
  param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Values)
  $copy = [string[]]@($Values)
  [Array]::Sort($copy, [StringComparer]::Ordinal)
  foreach ($value in $copy) { $value }
}

function Assert-RisePalsNodeExactProperties {
  param(
    [Parameter(Mandatory = $true)][object]$Value,
    [Parameter(Mandatory = $true)][string[]]$Names,
    [Parameter(Mandatory = $true)][string]$Predicate,
    [int]$RecordIndex = -1
  )

  if ($null -eq $Value) {
    throw "$Predicate|$RecordIndex"
  }
  $actual = @($Value.PSObject.Properties.Name | Sort-Object)
  $expected = @($Names | Sort-Object)
  if (($actual -join "`n") -cne ($expected -join "`n")) {
    throw "$Predicate|$RecordIndex"
  }
}

function Test-RisePalsNodeNonnegativeInteger {
  param([AllowNull()][object]$Value)
  if ($null -eq $Value) { return $false }
  $text = [string]$Value
  $parsed = [int64]0
  return [int64]::TryParse($text, [Globalization.NumberStyles]::None,
    [Globalization.CultureInfo]::InvariantCulture, [ref]$parsed) -and $parsed -ge 0 -and
    $text -ceq $parsed.ToString([Globalization.CultureInfo]::InvariantCulture)
}

function Test-RisePalsNodeReparsePoint {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)
  $item = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
  return ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

function Resolve-RisePalsNodeRelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$ApprovedRoot,
    [AllowNull()][object]$RelativePath,
    [switch]$RequireExistingNoReparse
  )

  if ($null -eq $RelativePath -or [string]::IsNullOrEmpty([string]$RelativePath)) {
    throw "inventory-relative-path|-1"
  }
  $candidate = ([string]$RelativePath).Replace("\", "/")
  if ([IO.Path]::IsPathRooted($candidate)) {
    throw "inventory-relative-path|-1"
  }
  $components = $candidate.Split([char[]]@('/'), [StringSplitOptions]::None)
  $invalid = [IO.Path]::GetInvalidFileNameChars()
  foreach ($component in $components) {
    if ([string]::IsNullOrEmpty($component) -or $component -ceq "." -or $component -ceq "..") {
      throw "inventory-relative-path|-1"
    }
    foreach ($character in $component.ToCharArray()) {
      if ($character -eq [char]0 -or $character -eq ':' -or $invalid -contains $character) {
        throw "inventory-relative-path|-1"
      }
    }
  }

  $root = [IO.Path]::GetFullPath($ApprovedRoot).TrimEnd('\')
  $resolved = $root
  foreach ($component in $components) {
    $resolved = [IO.Path]::GetFullPath((Join-Path $resolved $component))
  }
  $prefix = $root + "\"
  if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "inventory-relative-path|-1"
  }

  if ($RequireExistingNoReparse) {
    if (Test-RisePalsNodeReparsePoint -LiteralPath $root) {
      throw "reparse-point-present|-1"
    }
    $cursor = $root
    foreach ($component in $components) {
      $cursor = Join-Path $cursor $component
      if ((Test-Path -LiteralPath $cursor) -and (Test-RisePalsNodeReparsePoint -LiteralPath $cursor)) {
        throw "reparse-point-present|-1"
      }
    }
  }
  return $resolved
}

function Get-RisePalsNodeInventoryRecordsDigest {
  param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Records)

  $recordMap = @{}
  foreach ($record in $Records) { $recordMap[[string]$record.relativePath] = $record }
  $paths = @(Get-RisePalsNodeOrdinalSortedStrings -Values @($recordMap.Keys))
  $lines = @($paths | ForEach-Object {
    $record = $recordMap[$_]
    if ([string]$record.type -ceq "file") {
      "{0}|file|{1}|{2}" -f [string]$record.relativePath, [int64]$record.length, [string]$record.sha256
    } else {
      "{0}|directory|-|-" -f [string]$record.relativePath
    }
  })
  return Get-RisePalsNodeSha256Text -Text (($lines -join "`n") + "`n")
}

function New-RisePalsNodeInventory {
  param([Parameter(Mandatory = $true)][string]$Root)

  $exactRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
  if (-not [IO.Directory]::Exists($exactRoot)) {
    throw "inventory-root-absent|-1"
  }
  if (Test-RisePalsNodeReparsePoint -LiteralPath $exactRoot) {
    throw "reparse-point-present|-1"
  }
  $records = @()
  foreach ($item in @(Get-ChildItem -LiteralPath $exactRoot -Force -Recurse | Sort-Object FullName)) {
    $relative = $item.FullName.Substring($exactRoot.Length + 1).Replace("\", "/")
    [void](Resolve-RisePalsNodeRelativePath -ApprovedRoot $exactRoot -RelativePath $relative `
      -RequireExistingNoReparse)
    if ($item.PSIsContainer) {
      $records += [pscustomobject][ordered]@{
        relativePath = $relative
        type = "directory"
        length = $null
        sha256 = $null
      }
    } else {
      $records += [pscustomobject][ordered]@{
        relativePath = $relative
        type = "file"
        length = [int64]$item.Length
        sha256 = Get-RisePalsNodeSha256File -LiteralPath $item.FullName
      }
    }
  }
  $recordMap = @{}
  foreach ($record in $records) { $recordMap[[string]$record.relativePath] = $record }
  $paths = @(Get-RisePalsNodeOrdinalSortedStrings -Values @($recordMap.Keys))
  $records = @($paths | ForEach-Object { $recordMap[$_] })
  $files = @($records | Where-Object { $_.type -ceq "file" }).Count
  $directories = @($records | Where-Object { $_.type -ceq "directory" }).Count
  return [pscustomobject][ordered]@{
    schemaVersion = $script:RisePalsNodeInventorySchema
    distribution = "node-v24.18.1-win-x64"
    recordCount = $records.Count
    fileCount = $files
    directoryCount = $directories
    recordsDigest = Get-RisePalsNodeInventoryRecordsDigest -Records $records
    records = $records
  }
}

function Assert-RisePalsNodeInventory {
  param(
    [Parameter(Mandatory = $true)][object]$Inventory,
    [Parameter(Mandatory = $true)][string]$ApprovedRoot
  )

  Assert-RisePalsNodeExactProperties -Value $Inventory -Names @(
    "schemaVersion", "distribution", "recordCount", "fileCount", "directoryCount",
    "recordsDigest", "records"
  ) -Predicate "inventory-property-set"
  if ([string]$Inventory.schemaVersion -cne $script:RisePalsNodeInventorySchema -or
    [string]$Inventory.distribution -cne "node-v24.18.1-win-x64") {
    throw "inventory-schema|-1"
  }
  if (-not (Test-RisePalsNodeNonnegativeInteger $Inventory.recordCount) -or
    -not (Test-RisePalsNodeNonnegativeInteger $Inventory.fileCount) -or
    -not (Test-RisePalsNodeNonnegativeInteger $Inventory.directoryCount)) {
    throw "inventory-counts|-1"
  }
  $records = @($Inventory.records)
  $seen = @{}
  for ($index = 0; $index -lt $records.Count; $index++) {
    $record = $records[$index]
    Assert-RisePalsNodeExactProperties -Value $record -Names @(
      "relativePath", "type", "length", "sha256"
    ) -Predicate "inventory-record-property-set" -RecordIndex $index
    try {
      [void](Resolve-RisePalsNodeRelativePath -ApprovedRoot $ApprovedRoot `
        -RelativePath $record.relativePath)
    } catch {
      throw "inventory-relative-path|$index"
    }
    $key = ([string]$record.relativePath).ToLowerInvariant()
    if ($seen.ContainsKey($key)) { throw "inventory-duplicate-path|$index" }
    $seen[$key] = $true
    if ([string]$record.type -notin @("file", "directory")) {
      throw "inventory-record-type|$index"
    }
    if ([string]$record.type -ceq "file") {
      if (-not (Test-RisePalsNodeNonnegativeInteger $record.length) -or
        [string]$record.sha256 -cnotmatch "^[a-f0-9]{64}$") {
        throw "inventory-file-metadata|$index"
      }
    } elseif ($null -ne $record.length -or $null -ne $record.sha256) {
      throw "inventory-directory-metadata|$index"
    }
  }
  $recordPaths = @($records | ForEach-Object { [string]$_.relativePath })
  $sortedPaths = @(Get-RisePalsNodeOrdinalSortedStrings -Values $recordPaths)
  if (($recordPaths -join "`n") -cne ($sortedPaths -join "`n")) {
    throw "inventory-counts|-1"
  }
  $fileCount = @($records | Where-Object { $_.type -ceq "file" }).Count
  $directoryCount = @($records | Where-Object { $_.type -ceq "directory" }).Count
  if ([int64]$Inventory.recordCount -ne $records.Count -or
    [int64]$Inventory.fileCount -ne $fileCount -or
    [int64]$Inventory.directoryCount -ne $directoryCount -or
    $records.Count -ne ($fileCount + $directoryCount)) {
    throw "inventory-counts|-1"
  }
  $digest = Get-RisePalsNodeInventoryRecordsDigest -Records $records
  if ([string]$Inventory.recordsDigest -cne $digest) {
    throw "inventory-digest|-1"
  }
  return $Inventory
}

function Read-RisePalsNodeInventory {
  param(
    [Parameter(Mandatory = $true)][string]$LiteralPath,
    [Parameter(Mandatory = $true)][string]$ApprovedRoot
  )
  try {
    $bytes = [IO.File]::ReadAllBytes([IO.Path]::GetFullPath($LiteralPath))
    $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    $inventory = $text | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "inventory-json|-1"
  }
  return Assert-RisePalsNodeInventory -Inventory $inventory -ApprovedRoot $ApprovedRoot
}

function Compare-RisePalsNodeInventories {
  param(
    [Parameter(Mandatory = $true)][object]$Expected,
    [Parameter(Mandatory = $true)][object]$Actual
  )

  $expectedMap = @{}
  foreach ($record in @($Expected.records)) { $expectedMap[[string]$record.relativePath] = $record }
  $actualMap = @{}
  foreach ($record in @($Actual.records)) { $actualMap[[string]$record.relativePath] = $record }
  $missing = @(Get-RisePalsNodeOrdinalSortedStrings -Values @(
    $expectedMap.Keys | Where-Object { -not $actualMap.ContainsKey($_) }
  ))
  $unexpected = @(Get-RisePalsNodeOrdinalSortedStrings -Values @(
    $actualMap.Keys | Where-Object { -not $expectedMap.ContainsKey($_) }
  ))
  $typeMismatch = @()
  $contentMismatch = @()
  $commonPaths = @(Get-RisePalsNodeOrdinalSortedStrings -Values @(
    $expectedMap.Keys | Where-Object { $actualMap.ContainsKey($_) }
  ))
  foreach ($path in $commonPaths) {
    $before = $expectedMap[$path]
    $after = $actualMap[$path]
    if ([string]$before.type -cne [string]$after.type) {
      $typeMismatch += $path
    } elseif ([string]$before.type -ceq "file" -and
      ([int64]$before.length -ne [int64]$after.length -or
        [string]$before.sha256 -cne [string]$after.sha256)) {
      $contentMismatch += $path
    }
  }
  $allMap = @{}
  foreach ($path in @($missing + $unexpected + $typeMismatch + $contentMismatch)) {
    $allMap[[string]$path] = $true
  }
  $all = @(Get-RisePalsNodeOrdinalSortedStrings -Values @($allMap.Keys))
  return [pscustomobject][ordered]@{
    state = "measured"
    missingCount = $missing.Count
    unexpectedCount = $unexpected.Count
    typeMismatchCount = $typeMismatch.Count
    contentMismatchCount = $contentMismatch.Count
    discrepancyDigest = Get-RisePalsNodeSha256Text -Text (($all -join "`n") + "`n")
    firstDiscrepancies = @($all | Select-Object -First 50)
    missingPaths = $missing
    unexpectedPaths = $unexpected
    typeMismatchPaths = $typeMismatch
    contentMismatchPaths = $contentMismatch
  }
}

function New-RisePalsNodeMeasurement {
  param([ValidateSet("not_reached", "measured")][string]$State = "not_reached", [AllowNull()][object]$Inventory)
  if ($State -ceq "not_reached") {
    return [pscustomobject][ordered]@{
      state = "not_reached"; recordCount = $null; fileCount = $null
      directoryCount = $null; recordsDigest = $null
    }
  }
  return [pscustomobject][ordered]@{
    state = "measured"; recordCount = [int64]$Inventory.recordCount
    fileCount = [int64]$Inventory.fileCount; directoryCount = [int64]$Inventory.directoryCount
    recordsDigest = [string]$Inventory.recordsDigest
  }
}

function New-RisePalsNodeEmptyComparison {
  return [pscustomobject][ordered]@{
    state = "not_reached"; missingCount = $null; unexpectedCount = $null
    typeMismatchCount = $null; contentMismatchCount = $null; discrepancyDigest = $null
    firstDiscrepancies = @(); missingPaths = @(); unexpectedPaths = @()
    typeMismatchPaths = @(); contentMismatchPaths = @()
  }
}

function Get-RisePalsNodeEvidenceDigest {
  param([Parameter(Mandatory = $true)][object]$Evidence)
  $body = [pscustomobject][ordered]@{
    schemaVersion = $Evidence.schemaVersion
    authorizationId = $Evidence.authorizationId
    invocationNonce = $Evidence.invocationNonce
    repositoryHead = $Evidence.repositoryHead
    scriptSha256 = $Evidence.scriptSha256
    inventoryFileSha256 = $Evidence.inventoryFileSha256
    mode = $Evidence.mode
    status = $Evidence.status
    classification = $Evidence.classification
    completedPredicates = @($Evidence.completedPredicates)
    failedPredicate = $Evidence.failedPredicate
    source = $Evidence.source
    destination = $Evidence.destination
    comparison = $Evidence.comparison
    boundary = $Evidence.boundary
    nodeExeOnlyRepairSafe = $Evidence.nodeExeOnlyRepairSafe
    recordedAtUtc = $Evidence.recordedAtUtc
  }
  return Get-RisePalsNodeSha256Text -Text ($body | ConvertTo-Json -Depth 12 -Compress)
}

function New-RisePalsNodeEvidence {
  param(
    [Parameter(Mandatory = $true)][string]$AuthorizationId,
    [Parameter(Mandatory = $true)][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][string]$ScriptSha256,
    [Parameter(Mandatory = $true)][string]$InventoryFileSha256,
    [ValidateSet("Simulation", "LiveReadOnly")][string]$Mode,
    [ValidateSet("complete", "controlled-failure")][string]$Status,
    [Parameter(Mandatory = $true)][string]$Classification,
    [string[]]$CompletedPredicates = @(),
    [AllowNull()][string]$FailedPredicate,
    [Parameter(Mandatory = $true)][object]$Source,
    [Parameter(Mandatory = $true)][object]$Destination,
    [Parameter(Mandatory = $true)][object]$Comparison,
    [Parameter(Mandatory = $true)][object]$Boundary,
    [bool]$NodeExeOnlyRepairSafe = $false
  )
  $evidence = [pscustomobject][ordered]@{
    schemaVersion = $script:RisePalsNodeEvidenceSchema
    authorizationId = $AuthorizationId
    invocationNonce = $InvocationNonce
    repositoryHead = $RepositoryHead
    scriptSha256 = $ScriptSha256
    inventoryFileSha256 = $InventoryFileSha256
    mode = $Mode
    status = $Status
    classification = $Classification
    completedPredicates = @($CompletedPredicates)
    failedPredicate = $(if ([string]::IsNullOrEmpty($FailedPredicate)) { $null } else { $FailedPredicate })
    source = $Source
    destination = $Destination
    comparison = $Comparison
    boundary = $Boundary
    nodeExeOnlyRepairSafe = $NodeExeOnlyRepairSafe
    recordedAtUtc = [DateTimeOffset]::UtcNow.ToString("o")
    evidenceDigest = $null
  }
  $evidence.evidenceDigest = Get-RisePalsNodeEvidenceDigest -Evidence $evidence
  return $evidence
}

function Assert-RisePalsNodeEvidence {
  param(
    [Parameter(Mandatory = $true)][object]$Evidence,
    [Parameter(Mandatory = $true)][string]$AuthorizationId,
    [Parameter(Mandatory = $true)][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][string]$ScriptSha256,
    [Parameter(Mandatory = $true)][string]$InventoryFileSha256
  )
  Assert-RisePalsNodeExactProperties -Value $Evidence -Names @(
    "schemaVersion", "authorizationId", "invocationNonce", "repositoryHead", "scriptSha256",
    "inventoryFileSha256", "mode", "status", "classification", "completedPredicates",
    "failedPredicate", "source", "destination", "comparison", "boundary",
    "nodeExeOnlyRepairSafe", "recordedAtUtc", "evidenceDigest"
  ) -Predicate "evidence-property-set"
  if ([string]$Evidence.schemaVersion -cne $script:RisePalsNodeEvidenceSchema) {
    throw "evidence-schema|-1"
  }
  if ([string]$Evidence.authorizationId -cne $AuthorizationId -or
    [string]$Evidence.invocationNonce -cne $InvocationNonce -or
    [string]$Evidence.repositoryHead -cne $RepositoryHead -or
    [string]$Evidence.scriptSha256 -cne $ScriptSha256 -or
    [string]$Evidence.inventoryFileSha256 -cne $InventoryFileSha256 -or
    $InvocationNonce -cnotmatch "^[a-f0-9]{32}$" -or $RepositoryHead -cnotmatch "^[a-f0-9]{40}$" -or
    $ScriptSha256 -cnotmatch "^[a-f0-9]{64}$" -or $InventoryFileSha256 -cnotmatch "^[a-f0-9]{64}$") {
    throw "evidence-binding|-1"
  }
  if ([string]$Evidence.classification -notin $script:RisePalsNodeClassifications) {
    throw "evidence-classification|-1"
  }
  if ([string]$Evidence.mode -notin @("Simulation", "LiveReadOnly") -or
    [string]$Evidence.status -notin @("complete", "controlled-failure")) {
    throw "evidence-schema|-1"
  }
  $recordedAt = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParseExact([string]$Evidence.recordedAtUtc, "o",
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::None, [ref]$recordedAt) -or
    $recordedAt.Offset -ne [TimeSpan]::Zero) {
    throw "evidence-schema|-1"
  }
  foreach ($predicate in @($Evidence.completedPredicates)) {
    if ([string]$predicate -notin $script:RisePalsNodePredicates) { throw "evidence-schema|-1" }
  }
  if (-not [string]::IsNullOrEmpty([string]$Evidence.failedPredicate) -and
    [string]$Evidence.failedPredicate -notin $script:RisePalsNodePredicates) {
    throw "evidence-schema|-1"
  }
  if (([string]$Evidence.classification -ceq "unknown-controlled-failure") -ne
    ([string]$Evidence.status -ceq "controlled-failure") -or
    (([string]$Evidence.status -ceq "complete") -and
      -not [string]::IsNullOrEmpty([string]$Evidence.failedPredicate)) -or
    (([string]$Evidence.status -ceq "controlled-failure") -and
      [string]::IsNullOrEmpty([string]$Evidence.failedPredicate))) {
    throw "evidence-schema|-1"
  }
  foreach ($measurement in @($Evidence.source, $Evidence.destination)) {
    Assert-RisePalsNodeExactProperties -Value $measurement -Names @(
      "state", "recordCount", "fileCount", "directoryCount", "recordsDigest"
    ) -Predicate "evidence-measurement-state"
    if ([string]$measurement.state -ceq "not_reached") {
      if ($null -ne $measurement.recordCount -or $null -ne $measurement.fileCount -or
        $null -ne $measurement.directoryCount -or $null -ne $measurement.recordsDigest) {
        throw "evidence-measurement-state|-1"
      }
    } elseif ([string]$measurement.state -ceq "measured") {
      if (-not (Test-RisePalsNodeNonnegativeInteger $measurement.recordCount) -or
        -not (Test-RisePalsNodeNonnegativeInteger $measurement.fileCount) -or
        -not (Test-RisePalsNodeNonnegativeInteger $measurement.directoryCount) -or
        [string]$measurement.recordsDigest -cnotmatch "^[a-f0-9]{64}$") {
        throw "evidence-measurement-state|-1"
      }
    } else { throw "evidence-measurement-state|-1" }
  }
  $comparison = $Evidence.comparison
  Assert-RisePalsNodeExactProperties -Value $comparison -Names @(
    "state", "missingCount", "unexpectedCount", "typeMismatchCount", "contentMismatchCount",
    "discrepancyDigest", "firstDiscrepancies", "missingPaths", "unexpectedPaths",
    "typeMismatchPaths", "contentMismatchPaths"
  ) -Predicate "evidence-comparison-state"
  if ([string]$comparison.state -ceq "not_reached") {
    if ($null -ne $comparison.missingCount -or $null -ne $comparison.unexpectedCount -or
      $null -ne $comparison.typeMismatchCount -or $null -ne $comparison.contentMismatchCount -or
      $null -ne $comparison.discrepancyDigest -or @($comparison.firstDiscrepancies).Count -ne 0 -or
      @($comparison.missingPaths).Count -ne 0 -or @($comparison.unexpectedPaths).Count -ne 0 -or
      @($comparison.typeMismatchPaths).Count -ne 0 -or @($comparison.contentMismatchPaths).Count -ne 0) {
      throw "evidence-comparison-state|-1"
    }
  } elseif ([string]$comparison.state -ceq "measured") {
    foreach ($name in @("missingCount", "unexpectedCount", "typeMismatchCount", "contentMismatchCount")) {
      if (-not (Test-RisePalsNodeNonnegativeInteger $comparison.$name)) {
        throw "evidence-comparison-state|-1"
      }
    }
    if ([string]$comparison.discrepancyDigest -cnotmatch "^[a-f0-9]{64}$") {
      throw "evidence-comparison-state|-1"
    }
  } else { throw "evidence-comparison-state|-1" }
  if ([string]$Evidence.status -ceq "controlled-failure" -and
    ([string]$Evidence.destination.state -cne "not_reached" -or
      [string]$comparison.state -cne "not_reached")) {
    throw "evidence-comparison-state|-1"
  }
  $boundary = $Evidence.boundary
  Assert-RisePalsNodeExactProperties -Value $boundary -Names @(
    "state", "rootCanonical", "rootReparse", "ancestryValid", "ownerReadSucceeded",
    "aclReadSucceeded", "accessDenied", "protectedWritesAttempted"
  ) -Predicate "evidence-measurement-state"
  if ([string]$boundary.state -ceq "not_reached") {
    if ($null -ne $boundary.rootCanonical -or $null -ne $boundary.rootReparse -or
      $null -ne $boundary.ancestryValid -or $null -ne $boundary.ownerReadSucceeded -or
      $null -ne $boundary.aclReadSucceeded -or $null -ne $boundary.accessDenied) {
      throw "evidence-measurement-state|-1"
    }
  } elseif ([string]$boundary.state -ceq "measured") {
    foreach ($name in @(
      "rootCanonical", "rootReparse", "ancestryValid", "ownerReadSucceeded",
      "aclReadSucceeded", "accessDenied"
    )) {
      if ($null -ne $boundary.$name -and $boundary.$name -isnot [bool]) {
        throw "evidence-measurement-state|-1"
      }
    }
  } else { throw "evidence-measurement-state|-1" }
  if ($boundary.protectedWritesAttempted -isnot [bool] -or
    [bool]$boundary.protectedWritesAttempted) {
    throw "evidence-measurement-state|-1"
  }
  if ([bool]$Evidence.nodeExeOnlyRepairSafe) {
    if ([string]$Evidence.status -cne "complete" -or
      [string]$Evidence.classification -cne "complete-except-node" -or
      [string]$comparison.state -cne "measured" -or
      [int]$comparison.missingCount -ne 1 -or
      @($comparison.missingPaths).Count -ne 1 -or
      [string]$comparison.missingPaths[0] -cne "node.exe" -or
      [int]$comparison.unexpectedCount -ne 0 -or [int]$comparison.typeMismatchCount -ne 0 -or
      [int]$comparison.contentMismatchCount -ne 0) {
      throw "evidence-repair-state|-1"
    }
  }
  if ([string]$Evidence.evidenceDigest -cne (Get-RisePalsNodeEvidenceDigest -Evidence $Evidence)) {
    throw "evidence-digest|-1"
  }
  return $Evidence
}

function Write-RisePalsNodeEvidenceAtomic {
  param(
    [Parameter(Mandatory = $true)][object]$Evidence,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory
  )
  $directory = [IO.Path]::GetFullPath($EvidenceDirectory)
  [IO.Directory]::CreateDirectory($directory) | Out-Null
  $final = Join-Path $directory ("node-diagnostic-{0}.json" -f $Evidence.invocationNonce)
  $temporary = $final + ".tmp"
  if ([IO.File]::Exists($final) -or [IO.File]::Exists($temporary)) {
    throw "evidence-path-exists|-1"
  }
  $json = $Evidence | ConvertTo-Json -Depth 12
  [IO.File]::WriteAllText($temporary, $json, [Text.UTF8Encoding]::new($false))
  [IO.File]::Move($temporary, $final)
  return $final
}

function Read-RisePalsNodeEvidence {
  param(
    [Parameter(Mandatory = $true)][string]$LiteralPath,
    [Parameter(Mandatory = $true)][string]$AuthorizationId,
    [Parameter(Mandatory = $true)][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][string]$ScriptSha256,
    [Parameter(Mandatory = $true)][string]$InventoryFileSha256
  )
  try {
    $bytes = [IO.File]::ReadAllBytes([IO.Path]::GetFullPath($LiteralPath))
    $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    $evidence = $text | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "evidence-json|-1"
  }
  return Assert-RisePalsNodeEvidence -Evidence $evidence -AuthorizationId $AuthorizationId `
    -InvocationNonce $InvocationNonce -RepositoryHead $RepositoryHead -ScriptSha256 $ScriptSha256 `
    -InventoryFileSha256 $InventoryFileSha256
}

Export-ModuleMember -Function @(
  "Get-RisePalsNodeSha256Bytes",
  "Get-RisePalsNodeSha256Text",
  "Get-RisePalsNodeSha256File",
  "Get-RisePalsNodeOrdinalSortedStrings",
  "Assert-RisePalsNodeExactProperties",
  "Test-RisePalsNodeNonnegativeInteger",
  "Test-RisePalsNodeReparsePoint",
  "Resolve-RisePalsNodeRelativePath",
  "Get-RisePalsNodeInventoryRecordsDigest",
  "New-RisePalsNodeInventory",
  "Assert-RisePalsNodeInventory",
  "Read-RisePalsNodeInventory",
  "Compare-RisePalsNodeInventories",
  "New-RisePalsNodeMeasurement",
  "New-RisePalsNodeEmptyComparison",
  "Get-RisePalsNodeEvidenceDigest",
  "New-RisePalsNodeEvidence",
  "Assert-RisePalsNodeEvidence",
  "Write-RisePalsNodeEvidenceAtomic",
  "Read-RisePalsNodeEvidence"
)
