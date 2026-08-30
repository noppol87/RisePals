Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RisePalsCandidateMarkerSchema = "rise-pals-candidate-transport-marker-v1"
$script:RisePalsCandidateParentResultSchema = "rise-pals-candidate-parent-result-v1"
$script:RisePalsCandidateMarkerTypes = @(
  "bootstrap-started",
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
$script:RisePalsCandidateParentResultProperties = @(
  "schemaVersion",
  "invocationNonce",
  "authorizationId",
  "repositoryHead",
  "launcherScriptSha256",
  "classification",
  "status",
  "processLaunched",
  "elevatedExitCode",
  "bootstrapStarted",
  "childStarted",
  "liveStarted",
  "finalValidated",
  "finalStatus",
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
  $acl = Get-Acl -LiteralPath $exact
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
    throw "The candidate invocation directory ACL contract is invalid."
  }
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
    ($ChildStarted -and -not $BootstrapEntered) -or
    ($LiveStarted -and -not $ChildStarted) -or
    ($FinalValidated -and (-not $BootstrapEntered -or -not $ChildStarted -or
        -not $LiveStarted -or $FinalStatus -notin @("success", "failure")))) {
    return "final-invalid-or-inconsistent"
  }
  if (-not $BootstrapEntered) {
    return "elevated-child-never-entered-bootstrap"
  }
  if (-not $ChildStarted) {
    return "bootstrap-entered-child-not-started"
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

function ConvertTo-RisePalsCandidateCanonicalParentResult {
  param([Parameter(Mandatory = $true)][object]$Result)

  return [pscustomobject][ordered]@{
    schemaVersion = [string]$Result.schemaVersion
    invocationNonce = [string]$Result.invocationNonce
    authorizationId = [string]$Result.authorizationId
    repositoryHead = [string]$Result.repositoryHead
    launcherScriptSha256 = [string]$Result.launcherScriptSha256
    classification = [string]$Result.classification
    status = [string]$Result.status
    processLaunched = [bool]$Result.processLaunched
    elevatedExitCode = [int]$Result.elevatedExitCode
    bootstrapStarted = [bool]$Result.bootstrapStarted
    childStarted = [bool]$Result.childStarted
    liveStarted = [bool]$Result.liveStarted
    finalValidated = [bool]$Result.finalValidated
    finalStatus = if ($null -eq $Result.finalStatus) { $null } else { [string]$Result.finalStatus }
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
    [Parameter(Mandatory = $true)][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][string]$AuthorizationId,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][string]$LauncherScriptSha256,
    [Parameter(Mandatory = $true)][string]$Classification,
    [Parameter(Mandatory = $true)][bool]$ProcessLaunched,
    [Parameter(Mandatory = $true)][int]$ElevatedExitCode,
    [Parameter(Mandatory = $true)][bool]$BootstrapStarted,
    [Parameter(Mandatory = $true)][bool]$ChildStarted,
    [Parameter(Mandatory = $true)][bool]$LiveStarted,
    [Parameter(Mandatory = $true)][bool]$FinalValidated,
    [AllowNull()][string]$FinalStatus
  )

  $status = if ($Classification -eq "final-present-validated" -and
    $FinalStatus -eq "success") { "success" } else { "failure" }
  $result = [ordered]@{
    schemaVersion = $script:RisePalsCandidateParentResultSchema
    invocationNonce = $InvocationNonce
    authorizationId = $AuthorizationId
    repositoryHead = $RepositoryHead
    launcherScriptSha256 = $LauncherScriptSha256
    classification = $Classification
    status = $status
    processLaunched = $ProcessLaunched
    elevatedExitCode = $ElevatedExitCode
    bootstrapStarted = $BootstrapStarted
    childStarted = $ChildStarted
    liveStarted = $LiveStarted
    finalValidated = $FinalValidated
    finalStatus = if ([string]::IsNullOrWhiteSpace($FinalStatus)) { $null } else { $FinalStatus }
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("o")
    resultDigest = ""
  }
  $result.resultDigest = Get-RisePalsCandidateParentResultDigest -Result $result
  return [pscustomobject]$result
}

function Assert-RisePalsCandidateParentResult {
  param([Parameter(Mandatory = $true)][object]$Result)

  Assert-RisePalsCandidateTransportExactPropertySet -Value $Result `
    -Expected $script:RisePalsCandidateParentResultProperties -Label "Candidate parent result"
  if ($Result.schemaVersion -ne $script:RisePalsCandidateParentResultSchema -or
    $Result.classification -notin @(
      "uac-not-launched",
      "uac-cancelled",
      "elevated-process-launch-failure",
      "elevated-child-never-entered-bootstrap",
      "bootstrap-entered-child-not-started",
      "child-started-failed-before-live",
      "live-started-failed",
      "final-present-validated",
      "final-invalid-or-inconsistent"
    ) -or $Result.status -notin @("success", "failure") -or
    ($Result.status -eq "success" -and (
      $Result.classification -ne "final-present-validated" -or
      -not [bool]$Result.finalValidated -or $Result.finalStatus -ne "success"
    )) -or
    ($Result.status -eq "failure" -and $Result.finalStatus -eq "success" -and
      $Result.classification -eq "final-present-validated") -or
    $Result.resultDigest -ne (Get-RisePalsCandidateParentResultDigest -Result $Result)) {
    throw "The candidate parent result is invalid or internally inconsistent."
  }
  [void](ConvertFrom-RisePalsCandidateUtc -Value ([string]$Result.generatedAtUtc))
  return $true
}
