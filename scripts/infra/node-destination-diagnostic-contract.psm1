Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "windows-powershell-security-bootstrap.ps1")
[void](Initialize-RisePalsWindowsPowerShellSecurityModule)

$script:RisePalsNodeInventorySchema = "rise-pals-node-destination-inventory-v1"
$script:RisePalsNodeEvidenceSchema = "rise-pals-node-destination-diagnostic-v2"
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
$script:RisePalsNodeBoundaryPathIds = @(
  "rise-pals-root",
  "tools-directory",
  "node-directory",
  "version-directory",
  "node-executable"
)
$script:RisePalsNodeDiagnosticStages = @(
  "boundary-root",
  "boundary-tools",
  "boundary-node",
  "boundary-version",
  "boundary-executable",
  "destination-inventory",
  "inventory-comparison",
  "evidence-construction",
  "evidence-persistence",
  "evidence-reopen"
)
$script:RisePalsNodeFailurePredicates = @(
  $script:RisePalsNodeDiagnosticStages + @(
    "boundary-owner",
    "boundary-acl",
    "boundary-reparse",
    "boundary-canonical",
    "boundary-parent",
    "boundary-volume",
    "boundary-object-type"
  )
)
$script:RisePalsNodeFailedOperations = @(
  "item-read",
  "canonical-path-validation",
  "parent-path-validation",
  "volume-validation",
  "filesystem-read",
  "owner-read",
  "acl-read",
  "acl-rule-validation",
  "reparse-check",
  "object-type-validation",
  "inventory-enumeration",
  "inventory-comparison",
  "evidence-construction",
  "evidence-write",
  "evidence-reopen"
)
$script:RisePalsNodeSanitizedErrorCategories = @(
  "not_found",
  "access_denied",
  "io_error",
  "security_error",
  "invalid_operation",
  "canonical_path",
  "parent_path",
  "volume_mismatch",
  "object_type",
  "reparse_point",
  "acl_policy",
  "inventory_mismatch",
  "evidence_error"
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
      [void](Get-Item -LiteralPath $cursor -Force -ErrorAction Stop)
      if (Test-RisePalsNodeReparsePoint -LiteralPath $cursor) {
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
  $rootItem = Get-Item -LiteralPath $exactRoot -Force -ErrorAction Stop
  if (-not $rootItem.PSIsContainer) {
    throw "inventory-root-type|-1"
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

function New-RisePalsNodeBoundaryResult {
  param(
    [Parameter(Mandatory = $true)][ValidateSet(
      "rise-pals-root", "tools-directory", "node-directory", "version-directory",
      "node-executable"
    )][string]$PathId,
    [ValidateSet("inspected", "absent", "access_denied", "controlled_failure", "not_reached")]
    [string]$Disposition = "not_reached"
  )

  return [pscustomobject][ordered]@{
    pathId = $PathId
    disposition = $Disposition
    objectType = $null
    canonicalPathMatched = $null
    parentPathMatched = $null
    sameVolume = $null
    filesystem = $null
    owner = $null
    accessRulesProtected = $null
    reparsePoint = $null
    ancestryValid = $null
    ownerReadSucceeded = $null
    aclReadSucceeded = $null
    accessDenied = $(if ($Disposition -ceq "not_reached") { $null } else { $false })
    explicitAllowAceCount = $null
    inheritedAllowAceCount = $null
    denyAceCount = $null
    unexpectedAceCount = $null
    resolvedAcePrincipals = $null
    failedOperation = $null
    sanitizedErrorCategory = $null
    nativeErrorCode = $null
    hResult = $null
    protectedWritesAttempted = $false
  }
}

function Get-RisePalsNodeExceptionFacts {
  param([Parameter(Mandatory = $true)][Exception]$Exception)

  $cursor = $Exception
  $selected = $Exception
  $category = "io_error"
  for ($depth = 0; $depth -lt 4 -and $null -ne $cursor; $depth++) {
    $typeName = $cursor.GetType().FullName
    if ($cursor -is [UnauthorizedAccessException] -or
      $cursor -is [Security.SecurityException]) {
      $selected = $cursor
      $category = "access_denied"
      break
    }
    if ($cursor -is [IO.FileNotFoundException] -or
      $cursor -is [IO.DirectoryNotFoundException] -or
      $typeName -ceq "System.Management.Automation.ItemNotFoundException") {
      $selected = $cursor
      $category = "not_found"
      break
    }
    if ($cursor -is [InvalidOperationException]) {
      $selected = $cursor
      $category = "invalid_operation"
    } elseif ($cursor -is [Security.SecurityException]) {
      $selected = $cursor
      $category = "security_error"
    }
    $cursor = $cursor.InnerException
  }

  $hResult = [int]$selected.HResult
  $native = $null
  if ($hResult -eq -2147024891) { $native = 5 }
  elseif ($hResult -eq -2147024894) { $native = 2 }
  elseif ($hResult -eq -2147024893) { $native = 3 }
  return [pscustomobject][ordered]@{
    category = $category
    nativeErrorCode = $native
    hResult = $hResult
  }
}

function Invoke-RisePalsNodeSimulationFault {
  param(
    [Parameter(Mandatory = $true)][string]$Fault,
    [Parameter(Mandatory = $true)][string]$Token,
    [Parameter(Mandatory = $true)][string]$Operation
  )

  if ($Fault -ceq ("AccessDenied{0}" -f $Token) -and $Operation -ceq "item-read") {
    throw [UnauthorizedAccessException]::new("synthetic access denial")
  }
  if ($Fault -ceq ("OwnerDenied{0}" -f $Token) -and $Operation -ceq "owner-read") {
    throw [UnauthorizedAccessException]::new("synthetic owner denial")
  }
  if ($Fault -ceq ("AclDenied{0}" -f $Token) -and $Operation -ceq "acl-read") {
    throw [UnauthorizedAccessException]::new("synthetic ACL denial")
  }
  if ($Fault -ceq ("ControlledFailure{0}" -f $Token) -and $Operation -ceq "item-read") {
    throw [IO.IOException]::new("synthetic controlled I/O failure")
  }
}

function Invoke-RisePalsNodeBoundaryProbe {
  param(
    [Parameter(Mandatory = $true)][string]$PathId,
    [Parameter(Mandatory = $true)][string]$LiteralPath,
    [AllowNull()][string]$ExpectedParent,
    [Parameter(Mandatory = $true)][ValidateSet("directory", "file")][string]$ExpectedType,
    [Parameter(Mandatory = $true)][string]$FaultToken,
    [string]$SimulationFault = "None",
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$AllowedPrincipalSids
  )

  $result = New-RisePalsNodeBoundaryResult -PathId $PathId
  $exactPath = [IO.Path]::GetFullPath($LiteralPath).TrimEnd('\')
  $operation = "item-read"
  try {
    Invoke-RisePalsNodeSimulationFault -Fault $SimulationFault -Token $FaultToken -Operation $operation
    $item = Get-Item -LiteralPath $exactPath -Force -ErrorAction Stop
  } catch {
    $facts = Get-RisePalsNodeExceptionFacts -Exception $_.Exception
    $result.disposition = $(if ($facts.category -ceq "not_found") { "absent" } elseif (
        $facts.category -ceq "access_denied") { "access_denied" } else { "controlled_failure" })
    $result.accessDenied = $facts.category -ceq "access_denied"
    $result.failedOperation = $operation
    $result.sanitizedErrorCategory = $facts.category
    $result.nativeErrorCode = $facts.nativeErrorCode
    $result.hResult = $facts.hResult
    return $result
  }

  $result.disposition = "inspected"
  $result.accessDenied = $false
  $result.objectType = $(if ($item.PSIsContainer) { "directory" } elseif (
      $item -is [IO.FileInfo]) { "file" } else { "other" })
  $canonical = [IO.Path]::GetFullPath($item.FullName).TrimEnd('\')
  $result.canonicalPathMatched = $canonical.Equals($exactPath, [StringComparison]::OrdinalIgnoreCase)
  if ([string]::IsNullOrEmpty($ExpectedParent)) {
    $result.parentPathMatched = $null
  } else {
    $actualParent = if ($item.PSIsContainer) { $item.Parent.FullName } else { $item.Directory.FullName }
    $result.parentPathMatched = ([IO.Path]::GetFullPath($actualParent).TrimEnd('\')).Equals(
      [IO.Path]::GetFullPath($ExpectedParent).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)
  }
  $result.sameVolume = ([IO.Path]::GetPathRoot($canonical)).Equals(
    [IO.Path]::GetPathRoot($exactPath), [StringComparison]::OrdinalIgnoreCase)
  try {
    $result.filesystem = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($canonical)).DriveFormat
  } catch {
    $facts = Get-RisePalsNodeExceptionFacts -Exception $_.Exception
    $result.disposition = $(if ($facts.category -ceq "access_denied") {
        "access_denied" } else { "controlled_failure" })
    $result.accessDenied = $facts.category -ceq "access_denied"
    $result.failedOperation = "filesystem-read"
    $result.sanitizedErrorCategory = $facts.category
    $result.nativeErrorCode = $facts.nativeErrorCode
    $result.hResult = $facts.hResult
    return $result
  }

  try {
    $result.reparsePoint = Test-RisePalsNodeReparsePoint -LiteralPath $exactPath
  } catch {
    $facts = Get-RisePalsNodeExceptionFacts -Exception $_.Exception
    $result.disposition = $(if ($facts.category -ceq "access_denied") {
        "access_denied" } else { "controlled_failure" })
    $result.accessDenied = $facts.category -ceq "access_denied"
    $result.failedOperation = "reparse-check"
    $result.sanitizedErrorCategory = $facts.category
    $result.nativeErrorCode = $facts.nativeErrorCode
    $result.hResult = $facts.hResult
    return $result
  }

  if ($SimulationFault -ceq ("CanonicalAncestryFailure{0}" -f $FaultToken)) {
    $result.canonicalPathMatched = $false
  }
  $result.ancestryValid = [bool]($result.canonicalPathMatched -and
    ($null -eq $result.parentPathMatched -or $result.parentPathMatched) -and
    $result.sameVolume -and -not $result.reparsePoint)

  if (-not $result.canonicalPathMatched) {
    $result.failedOperation = "canonical-path-validation"
    $result.sanitizedErrorCategory = "canonical_path"
    return $result
  }
  if ($null -ne $result.parentPathMatched -and -not $result.parentPathMatched) {
    $result.failedOperation = "parent-path-validation"
    $result.sanitizedErrorCategory = "parent_path"
    return $result
  }
  if (-not $result.sameVolume) {
    $result.failedOperation = "volume-validation"
    $result.sanitizedErrorCategory = "volume_mismatch"
    return $result
  }
  if ($result.objectType -cne $ExpectedType) {
    $result.failedOperation = "object-type-validation"
    $result.sanitizedErrorCategory = "object_type"
    return $result
  }
  if ($result.reparsePoint) {
    $result.failedOperation = "reparse-check"
    $result.sanitizedErrorCategory = "reparse_point"
    return $result
  }

  $operation = "owner-read"
  try {
    Invoke-RisePalsNodeSimulationFault -Fault $SimulationFault -Token $FaultToken -Operation $operation
    $ownerAcl = Get-Acl -LiteralPath $exactPath -ErrorAction Stop
    $result.owner = $ownerAcl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    $result.ownerReadSucceeded = $true
  } catch {
    $facts = Get-RisePalsNodeExceptionFacts -Exception $_.Exception
    $result.disposition = $(if ($facts.category -ceq "access_denied") {
        "access_denied" } else { "controlled_failure" })
    $result.ownerReadSucceeded = $false
    $result.accessDenied = $facts.category -ceq "access_denied"
    $result.failedOperation = $operation
    $result.sanitizedErrorCategory = $facts.category
    $result.nativeErrorCode = $facts.nativeErrorCode
    $result.hResult = $facts.hResult
    return $result
  }

  $operation = "acl-read"
  try {
    Invoke-RisePalsNodeSimulationFault -Fault $SimulationFault -Token $FaultToken -Operation $operation
    $acl = Get-Acl -LiteralPath $exactPath -ErrorAction Stop
    $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    $result.accessRulesProtected = [bool]$acl.AreAccessRulesProtected
    $result.explicitAllowAceCount = @($rules | Where-Object {
        $_.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
        -not $_.IsInherited
      }).Count
    $result.inheritedAllowAceCount = @($rules | Where-Object {
        $_.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
        $_.IsInherited
      }).Count
    $result.denyAceCount = @($rules | Where-Object {
        $_.AccessControlType -eq [Security.AccessControl.AccessControlType]::Deny
      }).Count
    $principals = @($rules | ForEach-Object { [string]$_.IdentityReference.Value } | Select-Object -Unique)
    $result.resolvedAcePrincipals = @(Get-RisePalsNodeOrdinalSortedStrings -Values $principals)
    $result.unexpectedAceCount = @($rules | Where-Object {
        [string]$_.IdentityReference.Value -notin $AllowedPrincipalSids
      }).Count
    if ($SimulationFault -ceq ("DenyAce{0}" -f $FaultToken)) {
      $result.denyAceCount = [int]$result.denyAceCount + 1
    }
    if ($SimulationFault -ceq ("UnexpectedAce{0}" -f $FaultToken)) {
      $result.unexpectedAceCount = [int]$result.unexpectedAceCount + 1
      $result.resolvedAcePrincipals = @($result.resolvedAcePrincipals + "S-1-5-21-999-999-999-999" |
          Select-Object -Unique | Sort-Object)
    }
    $result.aclReadSucceeded = $true
  } catch {
    $facts = Get-RisePalsNodeExceptionFacts -Exception $_.Exception
    $result.disposition = $(if ($facts.category -ceq "access_denied") {
        "access_denied" } else { "controlled_failure" })
    $result.aclReadSucceeded = $false
    $result.accessDenied = $facts.category -ceq "access_denied"
    $result.failedOperation = $operation
    $result.sanitizedErrorCategory = $facts.category
    $result.nativeErrorCode = $facts.nativeErrorCode
    $result.hResult = $facts.hResult
    return $result
  }

  if ([int]$result.denyAceCount -gt 0 -or [int]$result.unexpectedAceCount -gt 0) {
    $result.failedOperation = "acl-rule-validation"
    $result.sanitizedErrorCategory = "acl_policy"
  }
  return $result
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
    firstFailedPredicate = $Evidence.firstFailedPredicate
    failedBoundary = $Evidence.failedBoundary
    failedOperation = $Evidence.failedOperation
    sanitizedErrorCategory = $Evidence.sanitizedErrorCategory
    nativeErrorCode = $Evidence.nativeErrorCode
    hResult = $Evidence.hResult
    source = $Evidence.source
    destination = $Evidence.destination
    comparison = $Evidence.comparison
    boundaries = @($Evidence.boundaries)
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
    [AllowNull()][string]$FirstFailedPredicate,
    [AllowNull()][string]$FailedBoundary,
    [AllowNull()][string]$FailedOperation,
    [AllowNull()][string]$SanitizedErrorCategory,
    [AllowNull()][object]$NativeErrorCode,
    [AllowNull()][object]$HResult,
    [Parameter(Mandatory = $true)][object]$Source,
    [Parameter(Mandatory = $true)][object]$Destination,
    [Parameter(Mandatory = $true)][object]$Comparison,
    [Parameter(Mandatory = $true)][object[]]$Boundaries,
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
    firstFailedPredicate = $(if ([string]::IsNullOrEmpty($FirstFailedPredicate)) {
        $null } else { $FirstFailedPredicate })
    failedBoundary = $(if ([string]::IsNullOrEmpty($FailedBoundary)) { $null } else { $FailedBoundary })
    failedOperation = $(if ([string]::IsNullOrEmpty($FailedOperation)) { $null } else { $FailedOperation })
    sanitizedErrorCategory = $(if ([string]::IsNullOrEmpty($SanitizedErrorCategory)) {
        $null } else { $SanitizedErrorCategory })
    nativeErrorCode = $NativeErrorCode
    hResult = $HResult
    source = $Source
    destination = $Destination
    comparison = $Comparison
    boundaries = @($Boundaries)
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
    "firstFailedPredicate", "failedBoundary", "failedOperation", "sanitizedErrorCategory",
    "nativeErrorCode", "hResult", "source", "destination", "comparison", "boundaries",
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
  $completed = @($Evidence.completedPredicates)
  if ($completed.Count -gt $script:RisePalsNodeDiagnosticStages.Count) {
    throw "evidence-schema|-1"
  }
  for ($index = 0; $index -lt $completed.Count; $index++) {
    if ([string]$completed[$index] -cne [string]$script:RisePalsNodeDiagnosticStages[$index]) {
      throw "evidence-schema|-1"
    }
  }
  $hasFailure = -not [string]::IsNullOrEmpty([string]$Evidence.firstFailedPredicate)
  if ($hasFailure) {
    if ([string]$Evidence.firstFailedPredicate -notin $script:RisePalsNodeFailurePredicates -or
      [string]$Evidence.failedOperation -notin $script:RisePalsNodeFailedOperations -or
      [string]$Evidence.sanitizedErrorCategory -notin $script:RisePalsNodeSanitizedErrorCategories -or
      ($null -ne $Evidence.failedBoundary -and
        [string]$Evidence.failedBoundary -notin $script:RisePalsNodeBoundaryPathIds)) {
      throw "evidence-schema|-1"
    }
    foreach ($number in @($Evidence.nativeErrorCode, $Evidence.hResult)) {
      if ($null -ne $number -and $number -isnot [int] -and $number -isnot [long]) {
        throw "evidence-schema|-1"
      }
    }
  } elseif ($null -ne $Evidence.failedBoundary -or $null -ne $Evidence.failedOperation -or
    $null -ne $Evidence.sanitizedErrorCategory -or $null -ne $Evidence.nativeErrorCode -or
    $null -ne $Evidence.hResult) {
    throw "evidence-schema|-1"
  }
  if (([string]$Evidence.classification -ceq "unknown-controlled-failure") -ne
    ([string]$Evidence.status -ceq "controlled-failure") -or
    (([string]$Evidence.status -ceq "controlled-failure") -and -not $hasFailure)) {
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
  $boundaries = @($Evidence.boundaries)
  if ($boundaries.Count -ne $script:RisePalsNodeBoundaryPathIds.Count) {
    throw "evidence-boundary-state|-1"
  }
  $ancestorBlocked = $false
  for ($boundaryIndex = 0; $boundaryIndex -lt $boundaries.Count; $boundaryIndex++) {
    $boundary = $boundaries[$boundaryIndex]
    Assert-RisePalsNodeExactProperties -Value $boundary -Names @(
      "pathId", "disposition", "objectType", "canonicalPathMatched", "parentPathMatched",
      "sameVolume", "filesystem", "owner", "accessRulesProtected", "reparsePoint",
      "ancestryValid", "ownerReadSucceeded", "aclReadSucceeded", "accessDenied",
      "explicitAllowAceCount", "inheritedAllowAceCount", "denyAceCount",
      "unexpectedAceCount", "resolvedAcePrincipals", "failedOperation",
      "sanitizedErrorCategory", "nativeErrorCode", "hResult", "protectedWritesAttempted"
    ) -Predicate "evidence-boundary-state" -RecordIndex $boundaryIndex
    if ([string]$boundary.pathId -cne $script:RisePalsNodeBoundaryPathIds[$boundaryIndex] -or
      [string]$boundary.disposition -notin @(
        "inspected", "absent", "access_denied", "controlled_failure", "not_reached"
      ) -or $boundary.protectedWritesAttempted -isnot [bool] -or
      [bool]$boundary.protectedWritesAttempted) {
      throw "evidence-boundary-state|$boundaryIndex"
    }
    if ($ancestorBlocked -and [string]$boundary.disposition -cne "not_reached") {
      throw "evidence-boundary-state|$boundaryIndex"
    }

    $nullableMeasurementNames = @(
      "objectType", "canonicalPathMatched", "parentPathMatched", "sameVolume", "filesystem",
      "owner", "accessRulesProtected", "reparsePoint", "ancestryValid", "ownerReadSucceeded",
      "aclReadSucceeded", "accessDenied", "explicitAllowAceCount", "inheritedAllowAceCount",
      "denyAceCount", "unexpectedAceCount", "resolvedAcePrincipals", "failedOperation",
      "sanitizedErrorCategory", "nativeErrorCode", "hResult"
    )
    if ([string]$boundary.disposition -ceq "not_reached") {
      foreach ($name in $nullableMeasurementNames) {
        if ($null -ne $boundary.$name) { throw "evidence-boundary-state|$boundaryIndex" }
      }
      $ancestorBlocked = $true
      continue
    }

    if ([string]$boundary.disposition -ceq "absent") {
      foreach ($name in @(
        "objectType", "canonicalPathMatched", "parentPathMatched", "sameVolume", "filesystem",
        "owner", "accessRulesProtected", "reparsePoint", "ancestryValid", "ownerReadSucceeded",
        "aclReadSucceeded", "explicitAllowAceCount", "inheritedAllowAceCount", "denyAceCount",
        "unexpectedAceCount", "resolvedAcePrincipals"
      )) {
        if ($null -ne $boundary.$name) { throw "evidence-boundary-state|$boundaryIndex" }
      }
      if ($boundary.accessDenied -isnot [bool] -or [bool]$boundary.accessDenied -or
        [string]$boundary.failedOperation -cne "item-read" -or
        [string]$boundary.sanitizedErrorCategory -cne "not_found") {
        throw "evidence-boundary-state|$boundaryIndex"
      }
      $ancestorBlocked = $true
      continue
    }

    if ([string]$boundary.disposition -in @("access_denied", "controlled_failure")) {
      if ([string]::IsNullOrEmpty([string]$boundary.failedOperation) -or
        [string]::IsNullOrEmpty([string]$boundary.sanitizedErrorCategory) -or
        [string]$boundary.failedOperation -notin $script:RisePalsNodeFailedOperations -or
        [string]$boundary.sanitizedErrorCategory -notin $script:RisePalsNodeSanitizedErrorCategories -or
        $boundary.accessDenied -isnot [bool] -or
        ([string]$boundary.disposition -ceq "access_denied") -ne [bool]$boundary.accessDenied -or
        (([string]$boundary.disposition -ceq "access_denied") -and
          [string]$boundary.sanitizedErrorCategory -cne "access_denied")) {
        throw "evidence-boundary-state|$boundaryIndex"
      }
      if ($boundary.aclReadSucceeded -eq $true) {
        foreach ($name in @(
          "explicitAllowAceCount", "inheritedAllowAceCount", "denyAceCount", "unexpectedAceCount"
        )) {
          if (-not (Test-RisePalsNodeNonnegativeInteger $boundary.$name)) {
            throw "evidence-boundary-state|$boundaryIndex"
          }
        }
        if ($null -eq $boundary.resolvedAcePrincipals) {
          throw "evidence-boundary-state|$boundaryIndex"
        }
      } elseif ($null -ne $boundary.explicitAllowAceCount -or
        $null -ne $boundary.inheritedAllowAceCount -or $null -ne $boundary.denyAceCount -or
        $null -ne $boundary.unexpectedAceCount -or $null -ne $boundary.resolvedAcePrincipals) {
        throw "evidence-boundary-state|$boundaryIndex"
      }
      $ancestorBlocked = $true
      continue
    }

    foreach ($name in @(
      "canonicalPathMatched", "sameVolume", "reparsePoint", "ancestryValid",
      "ownerReadSucceeded", "aclReadSucceeded", "accessDenied"
    )) {
      if ($null -ne $boundary.$name -and $boundary.$name -isnot [bool]) {
        throw "evidence-boundary-state|$boundaryIndex"
      }
    }
    if ($boundaryIndex -eq 0) {
      if ($null -ne $boundary.parentPathMatched) { throw "evidence-boundary-state|0" }
    } elseif ($boundary.parentPathMatched -isnot [bool]) {
      throw "evidence-boundary-state|$boundaryIndex"
    }
    if ([string]$boundary.objectType -notin @("directory", "file", "other") -or
      [string]::IsNullOrWhiteSpace([string]$boundary.filesystem) -or
      [string]$boundary.filesystem -cnotmatch "^[A-Za-z0-9._-]{1,32}$" -or
      $boundary.accessDenied -ne $false) {
      throw "evidence-boundary-state|$boundaryIndex"
    }

    $structuralFailure = -not [bool]$boundary.canonicalPathMatched -or
      ($boundaryIndex -gt 0 -and -not [bool]$boundary.parentPathMatched) -or
      -not [bool]$boundary.sameVolume -or [bool]$boundary.reparsePoint -or
      -not [bool]$boundary.ancestryValid -or
      (($boundaryIndex -lt 4) -and [string]$boundary.objectType -cne "directory") -or
      (($boundaryIndex -eq 4) -and [string]$boundary.objectType -cne "file")
    if ($structuralFailure) {
      if ($null -ne $boundary.owner -or $null -ne $boundary.accessRulesProtected -or
        $null -ne $boundary.ownerReadSucceeded -or $null -ne $boundary.aclReadSucceeded -or
        $null -ne $boundary.explicitAllowAceCount -or $null -ne $boundary.inheritedAllowAceCount -or
        $null -ne $boundary.denyAceCount -or $null -ne $boundary.unexpectedAceCount -or
        $null -ne $boundary.resolvedAcePrincipals -or
        [string]::IsNullOrEmpty([string]$boundary.failedOperation) -or
        [string]::IsNullOrEmpty([string]$boundary.sanitizedErrorCategory)) {
        throw "evidence-boundary-state|$boundaryIndex"
      }
      $ancestorBlocked = $true
      continue
    }

    if ([string]$boundary.owner -cnotmatch "^S-[0-9-]{3,184}$" -or
      $boundary.accessRulesProtected -isnot [bool] -or $boundary.ownerReadSucceeded -ne $true -or
      $boundary.aclReadSucceeded -ne $true) {
      throw "evidence-boundary-state|$boundaryIndex"
    }
    foreach ($name in @(
      "explicitAllowAceCount", "inheritedAllowAceCount", "denyAceCount", "unexpectedAceCount"
    )) {
      if (-not (Test-RisePalsNodeNonnegativeInteger $boundary.$name)) {
        throw "evidence-boundary-state|$boundaryIndex"
      }
    }
    if ($null -eq $boundary.resolvedAcePrincipals) {
      throw "evidence-boundary-state|$boundaryIndex"
    }
    foreach ($principal in @($boundary.resolvedAcePrincipals)) {
      if ([string]$principal -cnotmatch "^S-[0-9-]{3,184}$") {
        throw "evidence-boundary-state|$boundaryIndex"
      }
    }
    $aclPolicyFailure = [int]$boundary.denyAceCount -gt 0 -or
      [int]$boundary.unexpectedAceCount -gt 0
    if ($aclPolicyFailure) {
      if ([string]$boundary.failedOperation -cne "acl-rule-validation" -or
        [string]$boundary.sanitizedErrorCategory -cne "acl_policy") {
        throw "evidence-boundary-state|$boundaryIndex"
      }
      $ancestorBlocked = $true
    } elseif ($null -ne $boundary.failedOperation -or $null -ne $boundary.sanitizedErrorCategory -or
      $null -ne $boundary.nativeErrorCode -or $null -ne $boundary.hResult) {
      throw "evidence-boundary-state|$boundaryIndex"
    }
  }

  $versionBoundary = $boundaries[3]
  $executableBoundary = $boundaries[4]
  if ([string]$comparison.state -ceq "measured" -and
    ([string]$versionBoundary.disposition -cne "inspected" -or
      [string]$versionBoundary.objectType -cne "directory" -or
      [string]$Evidence.destination.state -cne "measured")) {
    throw "evidence-comparison-state|-1"
  }
  if ($Evidence.nodeExeOnlyRepairSafe -isnot [bool]) {
    throw "evidence-repair-state|-1"
  }
  $repairFacts = [string]$Evidence.status -ceq "complete" -and
    [string]$Evidence.classification -ceq "complete-except-node" -and
    [string]$comparison.state -ceq "measured" -and
    [int]$comparison.missingCount -eq 1 -and
    @($comparison.missingPaths).Count -eq 1 -and
    [string]$comparison.missingPaths[0] -ceq "node.exe" -and
    [int]$comparison.unexpectedCount -eq 0 -and [int]$comparison.typeMismatchCount -eq 0 -and
    [int]$comparison.contentMismatchCount -eq 0 -and
    [string]$versionBoundary.disposition -ceq "inspected" -and
    [string]$versionBoundary.objectType -ceq "directory" -and
    [string]$executableBoundary.disposition -ceq "absent" -and
    [string]$executableBoundary.failedOperation -ceq "item-read" -and
    [string]$executableBoundary.sanitizedErrorCategory -ceq "not_found"
  if ($repairFacts) {
    foreach ($boundary in @($boundaries | Select-Object -First 4)) {
      if ([string]$boundary.disposition -cne "inspected" -or
        [bool]$boundary.reparsePoint -or -not [bool]$boundary.ancestryValid -or
        $boundary.ownerReadSucceeded -ne $true -or $boundary.aclReadSucceeded -ne $true -or
        [int]$boundary.denyAceCount -ne 0 -or [int]$boundary.unexpectedAceCount -ne 0) {
        $repairFacts = $false
        break
      }
    }
  }
  if ([bool]$Evidence.nodeExeOnlyRepairSafe -ne [bool]$repairFacts) {
    throw "evidence-repair-state|-1"
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

  if ([string]$Evidence.classification -ceq "version-directory-absent") {
    if (@($boundaries | Select-Object -First 3 | Where-Object {
          [string]$_.disposition -cne "inspected" -or [string]$_.objectType -cne "directory"
        }).Count -ne 0 -or [string]$versionBoundary.disposition -cne "absent" -or
      [string]$executableBoundary.disposition -cne "not_reached" -or
      [string]$Evidence.destination.state -cne "not_reached" -or
      [string]$comparison.state -cne "not_reached") {
      throw "evidence-boundary-state|-1"
    }
  }
  if ([string]$Evidence.classification -ceq "node-already-present") {
    if ([string]$executableBoundary.disposition -cne "inspected" -or
      [string]$executableBoundary.objectType -cne "file" -or
      [string]$comparison.state -cne "measured" -or [int]$comparison.missingCount -ne 0 -or
      [int]$comparison.unexpectedCount -ne 0 -or [int]$comparison.typeMismatchCount -ne 0 -or
      [int]$comparison.contentMismatchCount -ne 0) {
      throw "evidence-boundary-state|-1"
    }
  }

  $failedBoundaryResult = $null
  if ($null -ne $Evidence.failedBoundary) {
    $failedBoundaryResult = @($boundaries | Where-Object {
        [string]$_.pathId -ceq [string]$Evidence.failedBoundary
      })[0]
  }
  if ($null -ne $failedBoundaryResult -and
    [string]$Evidence.firstFailedPredicate -notin @("destination-inventory", "inventory-comparison")) {
    if ([string]$failedBoundaryResult.failedOperation -cne [string]$Evidence.failedOperation -or
      [string]$failedBoundaryResult.sanitizedErrorCategory -cne
        [string]$Evidence.sanitizedErrorCategory -or
      $failedBoundaryResult.nativeErrorCode -ne $Evidence.nativeErrorCode -or
      $failedBoundaryResult.hResult -ne $Evidence.hResult) {
      throw "evidence-failure-provenance|-1"
    }
    $expectedFailurePredicate = switch ([string]$Evidence.failedOperation) {
      "item-read" {
        $script:RisePalsNodeDiagnosticStages[[Array]::IndexOf(
            [object[]]$script:RisePalsNodeBoundaryPathIds, [string]$Evidence.failedBoundary)]
      }
      "owner-read" { "boundary-owner" }
      "acl-read" { "boundary-acl" }
      "acl-rule-validation" { "boundary-acl" }
      "reparse-check" { "boundary-reparse" }
      "canonical-path-validation" { "boundary-canonical" }
      "parent-path-validation" { "boundary-parent" }
      "volume-validation" { "boundary-volume" }
      "filesystem-read" { "boundary-volume" }
      "object-type-validation" { "boundary-object-type" }
      default { $null }
    }
    if ([string]$Evidence.firstFailedPredicate -cne [string]$expectedFailurePredicate) {
      throw "evidence-failure-provenance|-1"
    }
  }
  if ([string]$Evidence.classification -ceq "access-denied") {
    $denied = @($boundaries | Where-Object { [string]$_.disposition -ceq "access_denied" })
    if ($denied.Count -ne 1 -or $null -eq $failedBoundaryResult -or
      [string]$Evidence.sanitizedErrorCategory -cne "access_denied") {
      throw "evidence-failure-provenance|-1"
    }
  }
  if ([string]$Evidence.classification -ceq "ACL-boundary-failure") {
    $aclFailures = @($boundaries | Where-Object {
        [string]$_.failedOperation -ceq "acl-rule-validation" -or
        ([string]$_.disposition -in @("access_denied", "controlled_failure") -and
          [string]$_.failedOperation -in @("owner-read", "acl-read"))
      })
    if ($aclFailures.Count -ne 1) { throw "evidence-failure-provenance|-1" }
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
  "New-RisePalsNodeBoundaryResult",
  "Get-RisePalsNodeExceptionFacts",
  "Invoke-RisePalsNodeSimulationFault",
  "Invoke-RisePalsNodeBoundaryProbe",
  "Get-RisePalsNodeEvidenceDigest",
  "New-RisePalsNodeEvidence",
  "Assert-RisePalsNodeEvidence",
  "Write-RisePalsNodeEvidenceAtomic",
  "Read-RisePalsNodeEvidence"
)
