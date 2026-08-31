Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RisePalsCandidateMarkerSchema = "rise-pals-candidate-transport-marker-v1"
$script:RisePalsCandidateParentCheckpointSchema = "rise-pals-candidate-parent-checkpoint-v1"
$script:RisePalsCandidateParentResultSchema = "rise-pals-candidate-parent-result-v3"
$script:RisePalsCandidateMarkerTypes = @(
  "bootstrap-started",
  "child-launch-attempted",
  "child-started",
  "live-started",
  "bootstrap-failure"
)
$script:RisePalsCandidateMarkerProperties = @(
  "schemaVersion",
  "markerType",
  "invocationNonce",
  "authorizationId",
  "repositoryHead",
  "launcherScriptSha256",
  "bootstrapScriptSha256",
  "transportScriptSha256",
  "childScriptSha256",
  "recordedAtUtc",
  "sanitizedFailureCode",
  "markerDigest"
)
$script:RisePalsCandidateParentCheckpointProperties = @(
  "schemaVersion",
  "invocationNonce",
  "authorizationId",
  "repositoryHead",
  "launcherScriptSha256",
  "bootstrapScriptSha256",
  "transportScriptSha256",
  "childScriptSha256",
  "launchDisposition",
  "classification",
  "status",
  "processLaunched",
  "elevatedExitCode",
  "bootstrapEntered",
  "bootstrapStarted",
  "bootstrapFailurePresent",
  "childLaunchAttempted",
  "childStarted",
  "liveStarted",
  "finalPresent",
  "finalValidated",
  "finalStatus",
  "generatedAtUtc",
  "checkpointDigest"
)
$script:RisePalsCandidateParentResultProperties = @(
  "schemaVersion",
  "invocationNonce",
  "authorizationId",
  "repositoryHead",
  "launcherScriptSha256",
  "bootstrapScriptSha256",
  "transportScriptSha256",
  "childScriptSha256",
  "checkpointFileName",
  "checkpointDigest",
  "launchDisposition",
  "processLaunched",
  "elevatedExitCode",
  "bootstrapEntered",
  "bootstrapStarted",
  "bootstrapFailurePresent",
  "childLaunchAttempted",
  "childStarted",
  "liveStarted",
  "finalPresent",
  "finalValidated",
  "functionalClassification",
  "finalChildStatus",
  "durableCheckpointValidated",
  "transientCleanupAttempted",
  "transientCleanupCompleted",
  "invocationDirectoryAbsent",
  "remainingTransientObjectCount",
  "remainingTemporaryObjectCount",
  "remainingTransientRelativePaths",
  "overallStatus",
  "generatedAtUtc",
  "resultDigest"
)

function Assert-RisePalsCandidateTransportExactPropertySet {
  param(
    [Parameter(Mandatory = $true)][object]$Value,
    [Parameter(Mandatory = $true)][string[]]$Expected,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if ($null -eq $Value) {
    throw "$Label is absent."
  }
  $actual = @($Value.PSObject.Properties.Name | Sort-Object)
  $wanted = @($Expected | Sort-Object)
  if (@(Compare-Object -ReferenceObject $wanted -DifferenceObject $actual).Count -ne 0) {
    throw "$Label has an unexpected property set."
  }
}

function Get-RisePalsCandidateTransportSha256 {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)

  $stream = [IO.File]::OpenRead([IO.Path]::GetFullPath($LiteralPath))
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace(
      "-",
      ""
    ).ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
    $stream.Dispose()
  }
}

function Get-RisePalsCandidateObjectDigest {
  param([Parameter(Mandatory = $true)][object]$Canonical)

  $json = $Canonical | ConvertTo-Json -Depth 7 -Compress
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace(
      "-",
      ""
    ).ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
  }
}

function ConvertTo-RisePalsCandidateCanonicalMarker {
  param([Parameter(Mandatory = $true)][object]$Marker)

  return [pscustomobject][ordered]@{
    schemaVersion = [string]$Marker.schemaVersion
    markerType = [string]$Marker.markerType
    invocationNonce = [string]$Marker.invocationNonce
    authorizationId = [string]$Marker.authorizationId
    repositoryHead = [string]$Marker.repositoryHead
    launcherScriptSha256 = [string]$Marker.launcherScriptSha256
    bootstrapScriptSha256 = [string]$Marker.bootstrapScriptSha256
    transportScriptSha256 = [string]$Marker.transportScriptSha256
    childScriptSha256 = [string]$Marker.childScriptSha256
    recordedAtUtc = [string]$Marker.recordedAtUtc
    sanitizedFailureCode = if ($null -eq $Marker.sanitizedFailureCode) {
      $null
    } else {
      [string]$Marker.sanitizedFailureCode
    }
  }
}

function Get-RisePalsCandidateMarkerDigest {
  param([Parameter(Mandatory = $true)][object]$Marker)

  return Get-RisePalsCandidateObjectDigest -Canonical (
    ConvertTo-RisePalsCandidateCanonicalMarker -Marker $Marker
  )
}

function New-RisePalsCandidateMarker {
  param(
    [Parameter(Mandatory = $true)][string]$MarkerType,
    [Parameter(Mandatory = $true)][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][string]$AuthorizationId,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][string]$LauncherScriptSha256,
    [Parameter(Mandatory = $true)][string]$BootstrapScriptSha256,
    [Parameter(Mandatory = $true)][string]$TransportScriptSha256,
    [Parameter(Mandatory = $true)][string]$ChildScriptSha256,
    [AllowNull()][string]$SanitizedFailureCode,
    [DateTimeOffset]$RecordedAtUtc = [DateTimeOffset]::UtcNow
  )

  if ($MarkerType -notin $script:RisePalsCandidateMarkerTypes) {
    throw "The candidate transport marker type is invalid."
  }
  $marker = [ordered]@{
    schemaVersion = $script:RisePalsCandidateMarkerSchema
    markerType = $MarkerType
    invocationNonce = $InvocationNonce
    authorizationId = $AuthorizationId
    repositoryHead = $RepositoryHead
    launcherScriptSha256 = $LauncherScriptSha256
    bootstrapScriptSha256 = $BootstrapScriptSha256
    transportScriptSha256 = $TransportScriptSha256
    childScriptSha256 = $ChildScriptSha256
    recordedAtUtc = $RecordedAtUtc.ToString("o")
    sanitizedFailureCode = if ([string]::IsNullOrWhiteSpace($SanitizedFailureCode)) {
      $null
    } else {
      $SanitizedFailureCode
    }
    markerDigest = ""
  }
  $marker.markerDigest = Get-RisePalsCandidateMarkerDigest -Marker $marker
  return [pscustomobject]$marker
}

function Write-RisePalsCandidateJsonAtomic {
  param(
    [Parameter(Mandatory = $true)][object]$Value,
    [Parameter(Mandatory = $true)][string]$ResultPath,
    [Parameter(Mandatory = $true)][string]$TemporaryPath
  )

  $exactResult = [IO.Path]::GetFullPath($ResultPath)
  $exactTemporary = [IO.Path]::GetFullPath($TemporaryPath)
  if (-not [IO.Path]::GetDirectoryName($exactResult).Equals(
    [IO.Path]::GetDirectoryName($exactTemporary),
    [StringComparison]::OrdinalIgnoreCase
  ) -or [IO.File]::Exists($exactResult) -or [IO.File]::Exists($exactTemporary)) {
    throw "Candidate atomic result paths are not fresh and single-directory."
  }
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
    (($Value | ConvertTo-Json -Depth 7) + "`n")
  )
  $stream = [IO.FileStream]::new(
    $exactTemporary,
    [IO.FileMode]::CreateNew,
    [IO.FileAccess]::Write,
    [IO.FileShare]::None
  )
  try {
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush($true)
  } finally {
    $stream.Dispose()
  }
  [IO.File]::Move($exactTemporary, $exactResult)
}

function Write-RisePalsCandidateMarkerAtomic {
  param(
    [Parameter(Mandatory = $true)][object]$Marker,
    [Parameter(Mandatory = $true)][string]$InvocationDirectory
  )

  $name = ([string]$Marker.markerType) + ".json"
  $path = Join-Path $InvocationDirectory $name
  $temporary = Join-Path $InvocationDirectory ($name + ".tmp")
  Write-RisePalsCandidateJsonAtomic -Value $Marker -ResultPath $path `
    -TemporaryPath $temporary
}

function Protect-RisePalsCandidateInvocationDirectory {
  param([Parameter(Mandatory = $true)][string]$Path)

  $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
  $sids = @(
    $currentSid,
    [Security.Principal.SecurityIdentifier]::new("S-1-5-18"),
    [Security.Principal.SecurityIdentifier]::new("S-1-5-32-544")
  )
  $security = [Security.AccessControl.DirectorySecurity]::new()
  $security.SetAccessRuleProtection($true, $false)
  foreach ($sid in $sids) {
    $rule = [Security.AccessControl.FileSystemAccessRule]::new(
      $sid,
      [Security.AccessControl.FileSystemRights]::FullControl,
      [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [Security.AccessControl.InheritanceFlags]::ObjectInherit,
      [Security.AccessControl.PropagationFlags]::None,
      [Security.AccessControl.AccessControlType]::Allow
    )
    [void]$security.AddAccessRule($rule)
  }
  [IO.Directory]::SetAccessControl([IO.Path]::GetFullPath($Path), $security)
}

function Protect-RisePalsCandidateEvidenceDirectory {
  param([Parameter(Mandatory = $true)][string]$Path)

  Protect-RisePalsCandidateInvocationDirectory -Path $Path
}

function Assert-RisePalsCandidateProtectedAcl {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $acl = Get-Acl -LiteralPath $Path
  $rules = @($acl.GetAccessRules(
    $true,
    $false,
    [Security.Principal.SecurityIdentifier]
  ))
  $expectedSids = @(
    [string][Security.Principal.WindowsIdentity]::GetCurrent().User.Value,
    "S-1-5-18",
    "S-1-5-32-544"
  ) | Sort-Object -Unique
  $actualSids = @($rules | ForEach-Object { [string]$_.IdentityReference.Value } |
    Sort-Object -Unique)
  if (-not $acl.AreAccessRulesProtected -or
    @(Compare-Object -ReferenceObject $expectedSids -DifferenceObject $actualSids).Count -ne 0 -or
    @($rules | Where-Object {
      $_.IsInherited -or
      $_.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
      ([int]$_.FileSystemRights -band [int][Security.AccessControl.FileSystemRights]::FullControl) -ne
        [int][Security.AccessControl.FileSystemRights]::FullControl
    }).Count -ne 0) {
    throw "$Label ACL contract is invalid."
  }
}

function Assert-RisePalsCandidateEvidenceDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][ValidateSet("Simulation", "Live")][string]$Mode
  )

  $exact = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $authorizedRoot = if ($Mode -eq "Live") {
    "C:\Users\Administrator\Documents\Codex"
  } else {
    [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
      [IO.Path]::DirectorySeparatorChar
    )
  }
  $prefix = $authorizedRoot + [IO.Path]::DirectorySeparatorChar
  if (-not $exact.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or
    -not [IO.Directory]::Exists($authorizedRoot) -or
    -not [IO.Directory]::Exists($exact)) {
    throw "The durable evidence directory is outside the authorized root or absent."
  }
  $authorizedRootItem = Get-Item -LiteralPath $authorizedRoot -Force
  if (($authorizedRootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
    -not [string]::IsNullOrWhiteSpace([string]$authorizedRootItem.LinkType)) {
    throw "The authorized durable evidence root is linked."
  }
  $cursor = $exact
  while ($cursor.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    $item = Get-Item -LiteralPath $cursor -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      -not [string]::IsNullOrWhiteSpace([string]$item.LinkType)) {
      throw "The durable evidence directory contains a linked path segment."
    }
    $cursor = [IO.Path]::GetDirectoryName($cursor)
  }
  Assert-RisePalsCandidateProtectedAcl -Path $exact -Label "Durable evidence directory"
  return $exact
}

function Initialize-RisePalsCandidateEvidenceDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][ValidateSet("Simulation", "Live")][string]$Mode
  )

  $exact = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $authorizedRoot = if ($Mode -eq "Live") {
    "C:\Users\Administrator\Documents\Codex"
  } else {
    [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
      [IO.Path]::DirectorySeparatorChar
    )
  }
  if (-not $exact.StartsWith(
    $authorizedRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
  )) {
    throw "The durable evidence directory escapes the authorized root."
  }
  if ([IO.File]::Exists($exact)) {
    throw "The durable evidence directory path is occupied by a file."
  }
  if (-not [IO.Directory]::Exists($exact)) {
    $parent = [IO.Path]::GetDirectoryName($exact)
    if (-not [IO.Directory]::Exists($parent)) {
      throw "The durable evidence directory parent must already exist."
    }
    $parentItem = Get-Item -LiteralPath $parent -Force
    if (($parentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      -not [string]::IsNullOrWhiteSpace([string]$parentItem.LinkType)) {
      throw "The durable evidence directory parent is linked."
    }
    [IO.Directory]::CreateDirectory($exact) | Out-Null
    Protect-RisePalsCandidateEvidenceDirectory -Path $exact
  }
  return Assert-RisePalsCandidateEvidenceDirectory -Path $exact -Mode $Mode
}

function Assert-RisePalsCandidateInvocationDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedRoot,
    [Parameter(Mandatory = $true)][string]$InvocationNonce
  )

  $root = [IO.Path]::GetFullPath($ExpectedRoot).TrimEnd(
    [IO.Path]::DirectorySeparatorChar
  )
  $exact = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $expected = [IO.Path]::GetFullPath((Join-Path $root ("invocation-" + $InvocationNonce)))
  if (-not $exact.Equals($expected, [StringComparison]::OrdinalIgnoreCase) -or
    -not [IO.Directory]::Exists($root) -or -not [IO.Directory]::Exists($exact)) {
    throw "The candidate invocation directory is not the exact explicit result-root child."
  }
  foreach ($candidate in @($root, $exact)) {
    $item = Get-Item -LiteralPath $candidate -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      -not [string]::IsNullOrWhiteSpace([string]$item.LinkType)) {
      throw "The candidate result root or invocation directory is unexpectedly linked."
    }
  }
  Assert-RisePalsCandidateProtectedAcl -Path $exact `
    -Label "Candidate invocation directory"
  return $exact
}

function Read-RisePalsCandidateTransportJson {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$InvocationDirectory,
    [Parameter(Mandatory = $true)][string]$ExpectedName
  )

  $directory = [IO.Path]::GetFullPath($InvocationDirectory).TrimEnd(
    [IO.Path]::DirectorySeparatorChar
  )
  $exact = [IO.Path]::GetFullPath($Path)
  $expected = [IO.Path]::GetFullPath((Join-Path $directory $ExpectedName))
  if (-not $exact.Equals($expected, [StringComparison]::OrdinalIgnoreCase) -or
    -not [IO.File]::Exists($exact)) {
    throw "A candidate transport marker is absent or outside the exact result root."
  }
  $item = Get-Item -LiteralPath $exact -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
    -not [string]::IsNullOrWhiteSpace([string]$item.LinkType)) {
    throw "A candidate transport marker is unexpectedly linked."
  }
  $bytes = [IO.File]::ReadAllBytes($exact)
  if ($bytes.Length -eq 0 -or $bytes.Length -gt 16384) {
    throw "A candidate transport marker has an invalid byte length."
  }
  return ([Text.UTF8Encoding]::new($false, $true).GetString($bytes) | ConvertFrom-Json)
}

function Get-RisePalsCandidateDurableParentCheckpointPath {
  param(
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce
  )

  return [IO.Path]::GetFullPath((Join-Path $EvidenceDirectory (
    "candidate-parent-checkpoint-" + $InvocationNonce + ".json"
  )))
}

function Get-RisePalsCandidateDurableParentResultPath {
  param(
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce
  )

  return [IO.Path]::GetFullPath((Join-Path $EvidenceDirectory (
    "candidate-parent-result-" + $InvocationNonce + ".json"
  )))
}

function Assert-RisePalsCandidateEvidenceFileAcl {
  param([Parameter(Mandatory = $true)][string]$Path)

  $rules = @((Get-Acl -LiteralPath $Path).GetAccessRules(
    $true,
    $true,
    [Security.Principal.SecurityIdentifier]
  ))
  $expectedSids = @(
    [string][Security.Principal.WindowsIdentity]::GetCurrent().User.Value,
    "S-1-5-18",
    "S-1-5-32-544"
  ) | Sort-Object -Unique
  $actualSids = @($rules | ForEach-Object { [string]$_.IdentityReference.Value } |
    Sort-Object -Unique)
  if (@(Compare-Object -ReferenceObject $expectedSids -DifferenceObject $actualSids).Count -ne 0 -or
    @($rules | Where-Object {
      $_.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
      ([int]$_.FileSystemRights -band [int][Security.AccessControl.FileSystemRights]::FullControl) -ne
        [int][Security.AccessControl.FileSystemRights]::FullControl
    }).Count -ne 0) {
    throw "The durable parent-result file ACL contract is invalid."
  }
}

function Read-RisePalsCandidateDurableEvidenceRecord {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][ValidateSet("Simulation", "Live")][string]$Mode,
    [Parameter(Mandatory = $true)][ValidateSet("Checkpoint", "Result")][string]$RecordType
  )

  $directory = Assert-RisePalsCandidateEvidenceDirectory -Path $EvidenceDirectory `
    -Mode $Mode
  $exact = [IO.Path]::GetFullPath($Path)
  $expected = if ($RecordType -eq "Checkpoint") {
    Get-RisePalsCandidateDurableParentCheckpointPath `
      -EvidenceDirectory $directory -InvocationNonce $InvocationNonce
  } else {
    Get-RisePalsCandidateDurableParentResultPath `
      -EvidenceDirectory $directory -InvocationNonce $InvocationNonce
  }
  if (-not $exact.Equals($expected, [StringComparison]::OrdinalIgnoreCase) -or
    -not [IO.File]::Exists($exact)) {
    throw "The durable parent evidence record is absent or outside the exact evidence directory."
  }
  $item = Get-Item -LiteralPath $exact -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
    -not [string]::IsNullOrWhiteSpace([string]$item.LinkType)) {
    throw "The durable parent evidence record is unexpectedly linked."
  }
  Assert-RisePalsCandidateEvidenceFileAcl -Path $exact
  $bytes = [IO.File]::ReadAllBytes($exact)
  if ($bytes.Length -eq 0 -or $bytes.Length -gt 32768) {
    throw "The durable parent evidence record has an invalid byte length."
  }
  return ([Text.UTF8Encoding]::new($false, $true).GetString($bytes) | ConvertFrom-Json)
}

function Read-RisePalsCandidateDurableParentCheckpoint {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][ValidateSet("Simulation", "Live")][string]$Mode
  )

  return Read-RisePalsCandidateDurableEvidenceRecord -Path $Path `
    -EvidenceDirectory $EvidenceDirectory -InvocationNonce $InvocationNonce `
    -Mode $Mode -RecordType Checkpoint
}

function Read-RisePalsCandidateDurableParentResult {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][ValidateSet("Simulation", "Live")][string]$Mode
  )

  return Read-RisePalsCandidateDurableEvidenceRecord -Path $Path `
    -EvidenceDirectory $EvidenceDirectory -InvocationNonce $InvocationNonce `
    -Mode $Mode -RecordType Result
}

function Write-RisePalsCandidateDurableParentCheckpointAtomic {
  param(
    [Parameter(Mandatory = $true)][object]$Checkpoint,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][ValidateSet("Simulation", "Live")][string]$Mode
  )

  $directory = Assert-RisePalsCandidateEvidenceDirectory -Path $EvidenceDirectory `
    -Mode $Mode
  $path = Get-RisePalsCandidateDurableParentCheckpointPath `
    -EvidenceDirectory $directory -InvocationNonce ([string]$Checkpoint.invocationNonce)
  Write-RisePalsCandidateJsonAtomic -Value $Checkpoint -ResultPath $path `
    -TemporaryPath ($path + ".tmp")
  return $path
}

function Write-RisePalsCandidateDurableParentResultAtomic {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][ValidateSet("Simulation", "Live")][string]$Mode
  )

  $directory = Assert-RisePalsCandidateEvidenceDirectory -Path $EvidenceDirectory `
    -Mode $Mode
  $path = Get-RisePalsCandidateDurableParentResultPath `
    -EvidenceDirectory $directory -InvocationNonce ([string]$Result.invocationNonce)
  $temporary = $path + ".tmp"
  Write-RisePalsCandidateJsonAtomic -Value $Result -ResultPath $path `
    -TemporaryPath $temporary
  return $path
}

function Assert-RisePalsCandidateMarker {
  param(
    [Parameter(Mandatory = $true)][object]$Marker,
    [Parameter(Mandatory = $true)][string]$ExpectedType,
    [Parameter(Mandatory = $true)][string]$ExpectedNonce,
    [Parameter(Mandatory = $true)][string]$ExpectedAuthorizationId,
    [Parameter(Mandatory = $true)][string]$ExpectedHead,
    [Parameter(Mandatory = $true)][string]$ExpectedLauncherScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedBootstrapScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedTransportScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedChildScriptSha256,
    [Parameter(Mandatory = $true)][DateTimeOffset]$InvocationStartedAtUtc,
    [Parameter(Mandatory = $true)][hashtable]$ConsumedMarkers,
    [DateTimeOffset]$ValidationNowUtc = [DateTimeOffset]::UtcNow
  )

  Assert-RisePalsCandidateTransportExactPropertySet -Value $Marker `
    -Expected $script:RisePalsCandidateMarkerProperties -Label "Candidate transport marker"
  if ($Marker.schemaVersion -ne $script:RisePalsCandidateMarkerSchema -or
    $Marker.markerType -ne $ExpectedType -or
    $Marker.markerType -notin $script:RisePalsCandidateMarkerTypes -or
    $Marker.invocationNonce -ne $ExpectedNonce -or
    $Marker.invocationNonce -notmatch "^[a-f0-9]{32}$" -or
    $Marker.authorizationId -ne $ExpectedAuthorizationId -or
    $Marker.repositoryHead -ne $ExpectedHead -or
    $Marker.repositoryHead -notmatch "^[a-f0-9]{40}$" -or
    $Marker.launcherScriptSha256 -ne $ExpectedLauncherScriptSha256 -or
    $Marker.bootstrapScriptSha256 -ne $ExpectedBootstrapScriptSha256 -or
    $Marker.transportScriptSha256 -ne $ExpectedTransportScriptSha256 -or
    $Marker.childScriptSha256 -ne $ExpectedChildScriptSha256 -or
    $Marker.launcherScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Marker.bootstrapScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Marker.transportScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Marker.childScriptSha256 -notmatch "^[a-f0-9]{64}$") {
    throw "The candidate transport marker provenance is invalid."
  }
  $key = [string]$Marker.markerType + ":" + [string]$Marker.invocationNonce
  if ($ConsumedMarkers.ContainsKey($key)) {
    throw "The candidate transport marker was replayed."
  }
  $recorded = ConvertFrom-RisePalsCandidateUtc -Value ([string]$Marker.recordedAtUtc)
  if ($recorded -lt $InvocationStartedAtUtc.AddSeconds(-2) -or
    $recorded -gt $ValidationNowUtc.AddMinutes(1) -or
    ($recorded - $InvocationStartedAtUtc) -gt [TimeSpan]::FromMinutes(30)) {
    throw "The candidate transport marker is stale or temporally incoherent."
  }
  if (($ExpectedType -eq "bootstrap-failure" -and
      [string]$Marker.sanitizedFailureCode -notmatch "^[a-z0-9-]+$") -or
    ($ExpectedType -ne "bootstrap-failure" -and $null -ne $Marker.sanitizedFailureCode)) {
    throw "The candidate transport marker failure classification is invalid."
  }
  if ($Marker.markerDigest -ne (Get-RisePalsCandidateMarkerDigest -Marker $Marker)) {
    throw "The candidate transport marker digest is invalid."
  }
  $json = $Marker | ConvertTo-Json -Depth 7 -Compress
  if ($json -match "(?i)(set-cookie|bearer[ ]|password|credential|request[ -]?body|@[a-z0-9.-]+\.[a-z]{2,}|(sk|pk)_(live|test)_)") {
    throw "The candidate transport marker contains a prohibited privacy marker."
  }
  $ConsumedMarkers[$key] = $true
  return $true
}

function Resolve-RisePalsCandidateParentClassification {
  param(
    [Parameter(Mandatory = $true)][ValidateSet(
      "not-launched",
      "cancelled",
      "launch-failure",
      "launched"
    )][string]$LaunchDisposition,
    [Parameter(Mandatory = $true)][bool]$BootstrapEntered,
    [Parameter(Mandatory = $true)][bool]$ChildLaunchAttempted,
    [Parameter(Mandatory = $true)][bool]$ChildStarted,
    [Parameter(Mandatory = $true)][bool]$LiveStarted,
    [Parameter(Mandatory = $true)][bool]$FinalPresent,
    [Parameter(Mandatory = $true)][bool]$FinalValidated,
    [Parameter(Mandatory = $true)][bool]$EvidenceInvalid,
    [AllowNull()][string]$FinalStatus
  )

  switch ($LaunchDisposition) {
    "not-launched" { return "uac-not-launched" }
    "cancelled" { return "uac-cancelled" }
    "launch-failure" { return "elevated-process-launch-failure" }
  }
  if ($EvidenceInvalid -or ($FinalPresent -and -not $FinalValidated) -or
    ($ChildLaunchAttempted -and -not $BootstrapEntered) -or
    ($ChildStarted -and -not $ChildLaunchAttempted) -or
    ($LiveStarted -and -not $ChildStarted) -or
    ($FinalValidated -and (-not $BootstrapEntered -or -not $ChildLaunchAttempted -or
        -not $ChildStarted -or -not $LiveStarted -or
        $FinalStatus -notin @("success", "failure")))) {
    return "final-invalid-or-inconsistent"
  }
  if (-not $BootstrapEntered) {
    return "elevated-child-never-entered-bootstrap"
  }
  if (-not $ChildLaunchAttempted) {
    return "bootstrap-entered-child-launch-not-attempted"
  }
  if (-not $ChildStarted) {
    return "child-launch-attempted-child-not-started"
  }
  if (-not $LiveStarted) {
    return "child-started-failed-before-live"
  }
  if (-not $FinalPresent) {
    return "live-started-failed"
  }
  if ($FinalValidated) {
    return "final-present-validated"
  }
  return "final-invalid-or-inconsistent"
}

function Assert-RisePalsCandidateMarkerOrdering {
  param([Parameter(Mandatory = $true)][hashtable]$MarkerTimes)

  $sequence = @(
    "bootstrap-started",
    "child-launch-attempted",
    "child-started",
    "live-started"
  )
  $lastTime = $null
  $missingPredecessor = $false
  foreach ($markerType in $sequence) {
    if (-not $MarkerTimes.ContainsKey($markerType)) {
      $missingPredecessor = $true
      continue
    }
    if ($missingPredecessor) {
      throw "A candidate marker exists without its required predecessor."
    }
    $recorded = [DateTimeOffset]$MarkerTimes[$markerType]
    if ($null -ne $lastTime -and $recorded -lt $lastTime) {
      throw "Candidate marker timestamps violate the required order."
    }
    $lastTime = $recorded
  }
  if ($MarkerTimes.ContainsKey("bootstrap-failure") -and $null -ne $lastTime -and
    [DateTimeOffset]$MarkerTimes["bootstrap-failure"] -lt $lastTime) {
    throw "The bootstrap failure marker predates an observed stage marker."
  }
  return $true
}

function Assert-RisePalsCandidateParentRecordPrivacy {
  param([Parameter(Mandatory = $true)][object]$Record)

  $json = $Record | ConvertTo-Json -Depth 8 -Compress
  if ($json -match "(?i)(set-cookie|bearer[ ]|password|credential|request[ -]?body|@[a-z0-9.-]+\.[a-z]{2,}|(sk|pk)_(live|test)_)") {
    throw "The durable parent record contains a prohibited privacy marker."
  }
}

function ConvertTo-RisePalsCandidateCanonicalParentCheckpoint {
  param([Parameter(Mandatory = $true)][object]$Checkpoint)

  return [pscustomobject][ordered]@{
    schemaVersion = [string]$Checkpoint.schemaVersion
    invocationNonce = [string]$Checkpoint.invocationNonce
    authorizationId = [string]$Checkpoint.authorizationId
    repositoryHead = [string]$Checkpoint.repositoryHead
    launcherScriptSha256 = [string]$Checkpoint.launcherScriptSha256
    bootstrapScriptSha256 = [string]$Checkpoint.bootstrapScriptSha256
    transportScriptSha256 = [string]$Checkpoint.transportScriptSha256
    childScriptSha256 = [string]$Checkpoint.childScriptSha256
    launchDisposition = [string]$Checkpoint.launchDisposition
    classification = [string]$Checkpoint.classification
    status = [string]$Checkpoint.status
    processLaunched = [bool]$Checkpoint.processLaunched
    elevatedExitCode = [int]$Checkpoint.elevatedExitCode
    bootstrapEntered = [bool]$Checkpoint.bootstrapEntered
    bootstrapStarted = [bool]$Checkpoint.bootstrapStarted
    bootstrapFailurePresent = [bool]$Checkpoint.bootstrapFailurePresent
    childLaunchAttempted = [bool]$Checkpoint.childLaunchAttempted
    childStarted = [bool]$Checkpoint.childStarted
    liveStarted = [bool]$Checkpoint.liveStarted
    finalPresent = [bool]$Checkpoint.finalPresent
    finalValidated = [bool]$Checkpoint.finalValidated
    finalStatus = if ($null -eq $Checkpoint.finalStatus) { $null } else { [string]$Checkpoint.finalStatus }
    generatedAtUtc = [string]$Checkpoint.generatedAtUtc
  }
}

function Get-RisePalsCandidateParentCheckpointDigest {
  param([Parameter(Mandatory = $true)][object]$Checkpoint)

  return Get-RisePalsCandidateObjectDigest -Canonical (
    ConvertTo-RisePalsCandidateCanonicalParentCheckpoint -Checkpoint $Checkpoint
  )
}

function New-RisePalsCandidateParentCheckpoint {
  param(
    [Parameter(Mandatory = $true)][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][string]$AuthorizationId,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][string]$LauncherScriptSha256,
    [Parameter(Mandatory = $true)][string]$BootstrapScriptSha256,
    [Parameter(Mandatory = $true)][string]$TransportScriptSha256,
    [Parameter(Mandatory = $true)][string]$ChildScriptSha256,
    [Parameter(Mandatory = $true)][string]$LaunchDisposition,
    [Parameter(Mandatory = $true)][string]$Classification,
    [Parameter(Mandatory = $true)][bool]$ProcessLaunched,
    [Parameter(Mandatory = $true)][int]$ElevatedExitCode,
    [Parameter(Mandatory = $true)][bool]$BootstrapEntered,
    [Parameter(Mandatory = $true)][bool]$BootstrapStarted,
    [Parameter(Mandatory = $true)][bool]$BootstrapFailurePresent,
    [Parameter(Mandatory = $true)][bool]$ChildLaunchAttempted,
    [Parameter(Mandatory = $true)][bool]$ChildStarted,
    [Parameter(Mandatory = $true)][bool]$LiveStarted,
    [Parameter(Mandatory = $true)][bool]$FinalPresent,
    [Parameter(Mandatory = $true)][bool]$FinalValidated,
    [AllowNull()][string]$FinalStatus
  )

  $status = if ($Classification -eq "final-present-validated" -and
    $FinalStatus -eq "success") { "success" } else { "failure" }
  $checkpoint = [ordered]@{
    schemaVersion = $script:RisePalsCandidateParentCheckpointSchema
    invocationNonce = $InvocationNonce
    authorizationId = $AuthorizationId
    repositoryHead = $RepositoryHead
    launcherScriptSha256 = $LauncherScriptSha256
    bootstrapScriptSha256 = $BootstrapScriptSha256
    transportScriptSha256 = $TransportScriptSha256
    childScriptSha256 = $ChildScriptSha256
    launchDisposition = $LaunchDisposition
    classification = $Classification
    status = $status
    processLaunched = $ProcessLaunched
    elevatedExitCode = $ElevatedExitCode
    bootstrapEntered = $BootstrapEntered
    bootstrapStarted = $BootstrapStarted
    bootstrapFailurePresent = $BootstrapFailurePresent
    childLaunchAttempted = $ChildLaunchAttempted
    childStarted = $ChildStarted
    liveStarted = $LiveStarted
    finalPresent = $FinalPresent
    finalValidated = $FinalValidated
    finalStatus = if ([string]::IsNullOrWhiteSpace($FinalStatus)) { $null } else { $FinalStatus }
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("o")
    checkpointDigest = ""
  }
  $checkpoint.checkpointDigest = Get-RisePalsCandidateParentCheckpointDigest `
    -Checkpoint $checkpoint
  return [pscustomobject]$checkpoint
}

function Assert-RisePalsCandidateParentCheckpoint {
  param(
    [Parameter(Mandatory = $true)][object]$Checkpoint,
    [Parameter(Mandatory = $true)][string]$ExpectedNonce,
    [Parameter(Mandatory = $true)][string]$ExpectedAuthorizationId,
    [Parameter(Mandatory = $true)][string]$ExpectedHead,
    [Parameter(Mandatory = $true)][string]$ExpectedLauncherScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedBootstrapScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedTransportScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedChildScriptSha256,
    [Parameter(Mandatory = $true)][DateTimeOffset]$InvocationStartedAtUtc,
    [Parameter(Mandatory = $true)][hashtable]$ConsumedNonces,
    [DateTimeOffset]$ValidationNowUtc = [DateTimeOffset]::UtcNow
  )

  Assert-RisePalsCandidateTransportExactPropertySet -Value $Checkpoint `
    -Expected $script:RisePalsCandidateParentCheckpointProperties `
    -Label "Candidate parent checkpoint"
  if ($Checkpoint.schemaVersion -ne $script:RisePalsCandidateParentCheckpointSchema -or
    $Checkpoint.classification -notin @(
      "uac-not-launched", "uac-cancelled", "elevated-process-launch-failure",
      "elevated-child-never-entered-bootstrap",
      "bootstrap-entered-child-launch-not-attempted",
      "child-launch-attempted-child-not-started",
      "child-started-failed-before-live", "live-started-failed",
      "final-present-validated", "final-invalid-or-inconsistent"
    ) -or $Checkpoint.status -notin @("success", "failure") -or
    $Checkpoint.invocationNonce -ne $ExpectedNonce -or
    $Checkpoint.invocationNonce -notmatch "^[a-f0-9]{32}$" -or
    $ConsumedNonces.ContainsKey([string]$Checkpoint.invocationNonce) -or
    $Checkpoint.authorizationId -ne $ExpectedAuthorizationId -or
    $Checkpoint.repositoryHead -ne $ExpectedHead -or
    $Checkpoint.launcherScriptSha256 -ne $ExpectedLauncherScriptSha256 -or
    $Checkpoint.bootstrapScriptSha256 -ne $ExpectedBootstrapScriptSha256 -or
    $Checkpoint.transportScriptSha256 -ne $ExpectedTransportScriptSha256 -or
    $Checkpoint.childScriptSha256 -ne $ExpectedChildScriptSha256 -or
    $Checkpoint.launcherScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Checkpoint.bootstrapScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Checkpoint.transportScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Checkpoint.childScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Checkpoint.launchDisposition -notin @("not-launched", "cancelled", "launch-failure", "launched") -or
    ([bool]$Checkpoint.processLaunched -ne ($Checkpoint.launchDisposition -eq "launched")) -or
    ((
      ([bool]$Checkpoint.bootstrapStarted -and -not [bool]$Checkpoint.bootstrapEntered) -or
      ([bool]$Checkpoint.childLaunchAttempted -and -not [bool]$Checkpoint.bootstrapStarted) -or
      ([bool]$Checkpoint.childStarted -and -not [bool]$Checkpoint.childLaunchAttempted) -or
      ([bool]$Checkpoint.liveStarted -and -not [bool]$Checkpoint.childStarted) -or
      ([bool]$Checkpoint.finalValidated -and (-not [bool]$Checkpoint.finalPresent -or
        -not [bool]$Checkpoint.liveStarted))
    ) -and $Checkpoint.classification -ne "final-invalid-or-inconsistent") -or
    ($Checkpoint.status -eq "success" -and (
      $Checkpoint.classification -ne "final-present-validated" -or
      -not [bool]$Checkpoint.finalValidated -or $Checkpoint.finalStatus -ne "success"
    )) -or
    ($Checkpoint.status -eq "failure" -and $Checkpoint.finalStatus -eq "success" -and
      $Checkpoint.classification -eq "final-present-validated") -or
    $Checkpoint.checkpointDigest -ne (
      Get-RisePalsCandidateParentCheckpointDigest -Checkpoint $Checkpoint
    )) {
    throw "The candidate parent checkpoint is invalid or internally inconsistent."
  }
  $generated = ConvertFrom-RisePalsCandidateUtc -Value ([string]$Checkpoint.generatedAtUtc)
  if ($generated -lt $InvocationStartedAtUtc.AddSeconds(-2) -or
    $generated -gt $ValidationNowUtc.AddMinutes(1) -or
    ($generated - $InvocationStartedAtUtc) -gt [TimeSpan]::FromMinutes(31)) {
    throw "The durable parent checkpoint timestamp is stale or incoherent."
  }
  $expectedClassification = Resolve-RisePalsCandidateParentClassification `
    -LaunchDisposition ([string]$Checkpoint.launchDisposition) `
    -BootstrapEntered ([bool]$Checkpoint.bootstrapEntered) `
    -ChildLaunchAttempted ([bool]$Checkpoint.childLaunchAttempted) `
    -ChildStarted ([bool]$Checkpoint.childStarted) `
    -LiveStarted ([bool]$Checkpoint.liveStarted) `
    -FinalPresent ([bool]$Checkpoint.finalPresent) `
    -FinalValidated ([bool]$Checkpoint.finalValidated) `
    -EvidenceInvalid ($Checkpoint.classification -eq "final-invalid-or-inconsistent") `
    -FinalStatus $Checkpoint.finalStatus
  if ($Checkpoint.classification -ne $expectedClassification) {
    throw "The durable checkpoint classification disagrees with its marker state."
  }
  Assert-RisePalsCandidateParentRecordPrivacy -Record $Checkpoint
  $ConsumedNonces[[string]$Checkpoint.invocationNonce] = $true
  return $true
}

function ConvertTo-RisePalsCandidateCanonicalParentResult {
  param([Parameter(Mandatory = $true)][object]$Result)

  return [pscustomobject][ordered]@{
    schemaVersion = [string]$Result.schemaVersion
    invocationNonce = [string]$Result.invocationNonce
    authorizationId = [string]$Result.authorizationId
    repositoryHead = [string]$Result.repositoryHead
    launcherScriptSha256 = [string]$Result.launcherScriptSha256
    bootstrapScriptSha256 = [string]$Result.bootstrapScriptSha256
    transportScriptSha256 = [string]$Result.transportScriptSha256
    childScriptSha256 = [string]$Result.childScriptSha256
    checkpointFileName = [string]$Result.checkpointFileName
    checkpointDigest = if ($null -eq $Result.checkpointDigest) { $null } else { [string]$Result.checkpointDigest }
    launchDisposition = [string]$Result.launchDisposition
    processLaunched = [bool]$Result.processLaunched
    elevatedExitCode = [int]$Result.elevatedExitCode
    bootstrapEntered = [bool]$Result.bootstrapEntered
    bootstrapStarted = [bool]$Result.bootstrapStarted
    bootstrapFailurePresent = [bool]$Result.bootstrapFailurePresent
    childLaunchAttempted = [bool]$Result.childLaunchAttempted
    childStarted = [bool]$Result.childStarted
    liveStarted = [bool]$Result.liveStarted
    finalPresent = [bool]$Result.finalPresent
    finalValidated = [bool]$Result.finalValidated
    functionalClassification = [string]$Result.functionalClassification
    finalChildStatus = if ($null -eq $Result.finalChildStatus) { $null } else { [string]$Result.finalChildStatus }
    durableCheckpointValidated = [bool]$Result.durableCheckpointValidated
    transientCleanupAttempted = [bool]$Result.transientCleanupAttempted
    transientCleanupCompleted = [bool]$Result.transientCleanupCompleted
    invocationDirectoryAbsent = [bool]$Result.invocationDirectoryAbsent
    remainingTransientObjectCount = [int]$Result.remainingTransientObjectCount
    remainingTemporaryObjectCount = [int]$Result.remainingTemporaryObjectCount
    remainingTransientRelativePaths = @($Result.remainingTransientRelativePaths)
    overallStatus = [string]$Result.overallStatus
    generatedAtUtc = [string]$Result.generatedAtUtc
  }
}

function Get-RisePalsCandidateParentResultDigest {
  param([Parameter(Mandatory = $true)][object]$Result)

  return Get-RisePalsCandidateObjectDigest -Canonical (
    ConvertTo-RisePalsCandidateCanonicalParentResult -Result $Result
  )
}

function New-RisePalsCandidateParentResult {
  param(
    [Parameter(Mandatory = $true)][object]$Checkpoint,
    [Parameter(Mandatory = $true)][string]$CheckpointFileName,
    [AllowNull()][string]$CheckpointDigest,
    [Parameter(Mandatory = $true)][bool]$DurableCheckpointValidated,
    [Parameter(Mandatory = $true)][bool]$TransientCleanupAttempted,
    [Parameter(Mandatory = $true)][bool]$TransientCleanupCompleted,
    [Parameter(Mandatory = $true)][bool]$InvocationDirectoryAbsent,
    [Parameter(Mandatory = $true)][int]$RemainingTransientObjectCount,
    [Parameter(Mandatory = $true)][int]$RemainingTemporaryObjectCount,
    [string[]]$RemainingTransientRelativePaths = @()
  )

  $functionalSuccess = $Checkpoint.classification -eq "final-present-validated" -and
    [bool]$Checkpoint.finalValidated -and $Checkpoint.finalStatus -eq "success"
  $overallStatus = if ($functionalSuccess -and $DurableCheckpointValidated -and
    $TransientCleanupAttempted -and $TransientCleanupCompleted -and
    $InvocationDirectoryAbsent -and $RemainingTransientObjectCount -eq 0 -and
    $RemainingTemporaryObjectCount -eq 0) { "success" } else { "failure" }
  $result = [ordered]@{
    schemaVersion = $script:RisePalsCandidateParentResultSchema
    invocationNonce = [string]$Checkpoint.invocationNonce
    authorizationId = [string]$Checkpoint.authorizationId
    repositoryHead = [string]$Checkpoint.repositoryHead
    launcherScriptSha256 = [string]$Checkpoint.launcherScriptSha256
    bootstrapScriptSha256 = [string]$Checkpoint.bootstrapScriptSha256
    transportScriptSha256 = [string]$Checkpoint.transportScriptSha256
    childScriptSha256 = [string]$Checkpoint.childScriptSha256
    checkpointFileName = $CheckpointFileName
    checkpointDigest = if ([string]::IsNullOrWhiteSpace($CheckpointDigest)) { $null } else { $CheckpointDigest }
    launchDisposition = [string]$Checkpoint.launchDisposition
    processLaunched = [bool]$Checkpoint.processLaunched
    elevatedExitCode = [int]$Checkpoint.elevatedExitCode
    bootstrapEntered = [bool]$Checkpoint.bootstrapEntered
    bootstrapStarted = [bool]$Checkpoint.bootstrapStarted
    bootstrapFailurePresent = [bool]$Checkpoint.bootstrapFailurePresent
    childLaunchAttempted = [bool]$Checkpoint.childLaunchAttempted
    childStarted = [bool]$Checkpoint.childStarted
    liveStarted = [bool]$Checkpoint.liveStarted
    finalPresent = [bool]$Checkpoint.finalPresent
    finalValidated = [bool]$Checkpoint.finalValidated
    functionalClassification = [string]$Checkpoint.classification
    finalChildStatus = if ($null -eq $Checkpoint.finalStatus) { $null } else { [string]$Checkpoint.finalStatus }
    durableCheckpointValidated = $DurableCheckpointValidated
    transientCleanupAttempted = $TransientCleanupAttempted
    transientCleanupCompleted = $TransientCleanupCompleted
    invocationDirectoryAbsent = $InvocationDirectoryAbsent
    remainingTransientObjectCount = $RemainingTransientObjectCount
    remainingTemporaryObjectCount = $RemainingTemporaryObjectCount
    remainingTransientRelativePaths = @($RemainingTransientRelativePaths | Sort-Object -Unique)
    overallStatus = $overallStatus
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("o")
    resultDigest = ""
  }
  $result.resultDigest = Get-RisePalsCandidateParentResultDigest -Result $result
  return [pscustomobject]$result
}

function Assert-RisePalsCandidateParentResult {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][string]$ExpectedNonce,
    [Parameter(Mandatory = $true)][string]$ExpectedAuthorizationId,
    [Parameter(Mandatory = $true)][string]$ExpectedHead,
    [Parameter(Mandatory = $true)][string]$ExpectedLauncherScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedBootstrapScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedTransportScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedChildScriptSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedCheckpointFileName,
    [AllowNull()][string]$ExpectedCheckpointDigest,
    [Parameter(Mandatory = $true)][DateTimeOffset]$InvocationStartedAtUtc,
    [Parameter(Mandatory = $true)][hashtable]$ConsumedNonces,
    [DateTimeOffset]$ValidationNowUtc = [DateTimeOffset]::UtcNow
  )

  Assert-RisePalsCandidateTransportExactPropertySet -Value $Result `
    -Expected $script:RisePalsCandidateParentResultProperties -Label "Candidate parent result"
  $paths = @($Result.remainingTransientRelativePaths)
  $invalidPaths = @($paths | Where-Object {
    $_ -notmatch "^[a-z0-9][a-z0-9.-]{0,127}$" -or $_.Contains("..")
  })
  $functionalSuccess = $Result.functionalClassification -eq "final-present-validated" -and
    [bool]$Result.finalValidated -and $Result.finalChildStatus -eq "success"
  $overallSuccess = $functionalSuccess -and [bool]$Result.durableCheckpointValidated -and
    [bool]$Result.transientCleanupAttempted -and [bool]$Result.transientCleanupCompleted -and
    [bool]$Result.invocationDirectoryAbsent -and
    [int]$Result.remainingTransientObjectCount -eq 0 -and
    [int]$Result.remainingTemporaryObjectCount -eq 0 -and $paths.Count -eq 0
  if ($Result.schemaVersion -ne $script:RisePalsCandidateParentResultSchema -or
    $Result.invocationNonce -ne $ExpectedNonce -or
    $Result.invocationNonce -notmatch "^[a-f0-9]{32}$" -or
    $ConsumedNonces.ContainsKey([string]$Result.invocationNonce) -or
    $Result.authorizationId -ne $ExpectedAuthorizationId -or
    $Result.repositoryHead -ne $ExpectedHead -or
    $Result.launcherScriptSha256 -ne $ExpectedLauncherScriptSha256 -or
    $Result.bootstrapScriptSha256 -ne $ExpectedBootstrapScriptSha256 -or
    $Result.transportScriptSha256 -ne $ExpectedTransportScriptSha256 -or
    $Result.childScriptSha256 -ne $ExpectedChildScriptSha256 -or
    $Result.checkpointFileName -ne $ExpectedCheckpointFileName -or
    $Result.checkpointDigest -ne $ExpectedCheckpointDigest -or
    ([bool]$Result.durableCheckpointValidated -and
      $Result.checkpointDigest -notmatch "^[a-f0-9]{64}$") -or
    (-not [bool]$Result.durableCheckpointValidated -and $null -ne $Result.checkpointDigest) -or
    $Result.launchDisposition -notin @("not-launched", "cancelled", "launch-failure", "launched") -or
    ([bool]$Result.processLaunched -ne ($Result.launchDisposition -eq "launched")) -or
    $Result.functionalClassification -notin @(
      "uac-not-launched", "uac-cancelled", "elevated-process-launch-failure",
      "elevated-child-never-entered-bootstrap",
      "bootstrap-entered-child-launch-not-attempted",
      "child-launch-attempted-child-not-started",
      "child-started-failed-before-live", "live-started-failed",
      "final-present-validated", "final-invalid-or-inconsistent"
    ) -or $Result.finalChildStatus -notin @($null, "success", "failure") -or
    [int]$Result.remainingTransientObjectCount -lt 0 -or
    [int]$Result.remainingTransientObjectCount -gt 64 -or
    [int]$Result.remainingTemporaryObjectCount -lt 0 -or
    [int]$Result.remainingTemporaryObjectCount -gt [int]$Result.remainingTransientObjectCount -or
    $paths.Count -gt [int]$Result.remainingTransientObjectCount -or
    $invalidPaths.Count -ne 0 -or
    ([bool]$Result.transientCleanupAttempted -and
      -not [bool]$Result.durableCheckpointValidated) -or
    ([bool]$Result.transientCleanupCompleted -and (
      -not [bool]$Result.transientCleanupAttempted -or
      -not [bool]$Result.invocationDirectoryAbsent -or
      [int]$Result.remainingTransientObjectCount -ne 0 -or
      [int]$Result.remainingTemporaryObjectCount -ne 0 -or $paths.Count -ne 0
    )) -or
    ([bool]$Result.invocationDirectoryAbsent -and
      [int]$Result.remainingTransientObjectCount -ne 0) -or
    $Result.overallStatus -notin @("success", "failure") -or
    ($Result.overallStatus -eq "success" -and -not $overallSuccess) -or
    ($Result.overallStatus -eq "failure" -and $overallSuccess) -or
    $Result.resultDigest -ne (Get-RisePalsCandidateParentResultDigest -Result $Result)) {
    throw "The authoritative candidate parent result is invalid or inconsistent."
  }
  $generated = ConvertFrom-RisePalsCandidateUtc -Value ([string]$Result.generatedAtUtc)
  if ($generated -lt $InvocationStartedAtUtc.AddSeconds(-2) -or
    $generated -gt $ValidationNowUtc.AddMinutes(1) -or
    ($generated - $InvocationStartedAtUtc) -gt [TimeSpan]::FromMinutes(31)) {
    throw "The authoritative parent-result timestamp is stale or incoherent."
  }
  $expectedClassification = Resolve-RisePalsCandidateParentClassification `
    -LaunchDisposition ([string]$Result.launchDisposition) `
    -BootstrapEntered ([bool]$Result.bootstrapEntered) `
    -ChildLaunchAttempted ([bool]$Result.childLaunchAttempted) `
    -ChildStarted ([bool]$Result.childStarted) -LiveStarted ([bool]$Result.liveStarted) `
    -FinalPresent ([bool]$Result.finalPresent) `
    -FinalValidated ([bool]$Result.finalValidated) `
    -EvidenceInvalid ($Result.functionalClassification -eq "final-invalid-or-inconsistent") `
    -FinalStatus $Result.finalChildStatus
  if ($Result.functionalClassification -ne $expectedClassification) {
    throw "The authoritative result classification disagrees with its marker state."
  }
  Assert-RisePalsCandidateParentRecordPrivacy -Record $Result
  $ConsumedNonces[[string]$Result.invocationNonce] = $true
  return $true
}
