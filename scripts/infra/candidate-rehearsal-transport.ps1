Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "windows-powershell-security-bootstrap.ps1")
[void](Initialize-RisePalsWindowsPowerShellSecurityModule)

$script:RisePalsCandidateMarkerSchema = "rise-pals-candidate-transport-marker-v1"
$script:RisePalsCandidateParentCheckpointSchema = "rise-pals-candidate-parent-checkpoint-v4"
$script:RisePalsCandidateParentResultSchema = "rise-pals-candidate-parent-result-v6"
$script:RisePalsCandidateLaunchDiagnosticSchema = "rise-pals-candidate-launch-diagnostic-v1"
$script:RisePalsCandidateLaunchDiagnosticSchemaV2 = "rise-pals-candidate-launch-diagnostic-v2"
$script:RisePalsCandidateLaunchProvenanceProperties = @(
  "errorRecordPresent", "exceptionTypeDisposition", "errorCategoryDisposition",
  "errorReasonDisposition", "fullyQualifiedErrorDisposition", "nativeCodeSource",
  "hResultSource", "examinedExceptionCount", "provenanceDigest"
)
$script:RisePalsCandidateProbeDiagnosticSchema = "rise-pals-candidate-elevation-probe-diagnostic-v1"
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
$script:RisePalsCandidateLaunchDiagnosticProperties = @(
  "schemaVersion",
  "launchAttempted",
  "processCreated",
  "launchDisposition",
  "sanitizedLaunchFailureCode",
  "nativeErrorCode",
  "hResult",
  "exceptionDepth",
  "launcherExecutableBasename",
  "launcherExecutableExists",
  "launcherSignatureStatus",
  "launchVerb",
  "argumentCount",
  "canonicalArgumentDigest",
  "waitRequested",
  "hiddenWindowRequested",
  "diagnosticDigest"
)
$script:RisePalsCandidateProbeDiagnosticProperties = @(
  "schemaVersion",
  "probeStatus",
  "failedStage",
  "sanitizedFailureCode",
  "elevatedChildEntered",
  "administratorRoleConfirmed",
  "integrityLevel",
  "repositoryHeadMatched",
  "authorizationMatched",
  "invocationNonceMatched",
  "launcherHashMatched",
  "bootstrapHashMatched",
  "transportHashMatched",
  "childHashMatched",
  "liveSequenceInvoked",
  "hostMutationAttempted",
  "probeDigest"
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
  "executionMode",
  "launchDiagnostic",
  "probeDiagnostic",
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
  "childDiagnostic",
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
  "executionMode",
  "checkpointFileName",
  "checkpointDigest",
  "launchDiagnostic",
  "probeDiagnostic",
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
  "childDiagnostic",
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

function Test-RisePalsCandidateIntegralValue {
  param([AllowNull()][object]$Value)

  if ($null -eq $Value) {
    return $false
  }
  return $Value.GetType() -in @(
    [byte], [sbyte], [int16], [uint16], [int32], [uint32], [int64]
  )
}

function Get-RisePalsCandidateCanonicalArgumentDigest {
  param([AllowEmptyCollection()][string[]]$Arguments = @())

  $values = @($Arguments | ForEach-Object { [string]$_ })
  return Get-RisePalsCandidateObjectDigest -Canonical ([pscustomobject][ordered]@{
    schemaVersion = "rise-pals-candidate-launch-arguments-v1"
    argumentCount = $values.Count
    arguments = $values
  })
}

function Assert-RisePalsCandidateModeAuthorization {
  param(
    [Parameter(Mandatory = $true)][ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$ExecutionMode,
    [Parameter(Mandatory = $true)][string]$AuthorizationId
  )

  $valid = switch ($ExecutionMode) {
    "Simulation" { $AuthorizationId -eq "RP-TURN-019-R4-DIAG2-SIMULATION" }
    "Live" { $AuthorizationId -match "^RP-TURN-019-R4-LIVE-[A-F0-9]{8}$" }
    "ElevationProbe" {
      $AuthorizationId -match "^RP-TURN-019-R4-PROBE-[A-F0-9]{8}$"
    }
  }
  if (-not $valid) {
    throw "The authorization identifier does not match the closed execution mode."
  }
  return $true
}

function ConvertTo-RisePalsCandidateLaunchArgument {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Value
  )

  if ($Value.Contains('"')) {
    throw "A candidate launch argument contains a prohibited quote."
  }
  return '"' + $Value + '"'
}

function New-RisePalsCandidateCanonicalLaunchRequest {
  param(
    [Parameter(Mandatory = $true)][ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$ExecutionMode,
    [Parameter(Mandatory = $true)][string]$SimulationScenario,
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][string]$AuthorizationId,
    [Parameter(Mandatory = $true)][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][string]$ResultRoot,
    [Parameter(Mandatory = $true)][string]$InvocationDirectory,
    [Parameter(Mandatory = $true)][string]$LauncherScriptPath,
    [Parameter(Mandatory = $true)][string]$LauncherScriptSha256,
    [Parameter(Mandatory = $true)][string]$BootstrapScriptPath,
    [Parameter(Mandatory = $true)][string]$BootstrapScriptSha256,
    [Parameter(Mandatory = $true)][string]$TransportScriptPath,
    [Parameter(Mandatory = $true)][string]$TransportScriptSha256,
    [Parameter(Mandatory = $true)][string]$ChildScriptPath,
    [Parameter(Mandatory = $true)][string]$ChildScriptSha256,
    [AllowEmptyString()][string]$CandidateExecutableSource = "",
    [AllowEmptyString()][string]$NodeExecutableSource = ""
  )

  [void](Assert-RisePalsCandidateModeAuthorization -ExecutionMode $ExecutionMode `
    -AuthorizationId $AuthorizationId)
  if ($RepositoryHead -notmatch "^[a-f0-9]{40}$" -or
    $InvocationNonce -notmatch "^[a-f0-9]{32}$" -or
    @(@(
      $LauncherScriptSha256,
      $BootstrapScriptSha256,
      $TransportScriptSha256,
      $ChildScriptSha256
    ) | Where-Object { $_ -notmatch "^[a-f0-9]{64}$" }).Count -ne 0 -or
    ($ExecutionMode -eq "ElevationProbe" -and (
      -not [string]::IsNullOrWhiteSpace($CandidateExecutableSource) -or
      -not [string]::IsNullOrWhiteSpace($NodeExecutableSource)
    ))) {
    throw "The canonical candidate launch request is malformed."
  }
  $quotedValues = @(
    $BootstrapScriptPath, $RepositoryRoot, $ResultRoot, $InvocationDirectory,
    $LauncherScriptPath, $TransportScriptPath, $ChildScriptPath,
    $CandidateExecutableSource, $NodeExecutableSource
  )
  if (@($quotedValues | Where-Object { ([string]$_).Contains('"') }).Count -ne 0) {
    throw "The canonical candidate launch request contains a prohibited quote."
  }
  $arguments = @(
    "-NoLogo",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (ConvertTo-RisePalsCandidateLaunchArgument -Value $BootstrapScriptPath),
    "-Mode",
    $ExecutionMode,
    "-SimulationScenario",
    $SimulationScenario,
    "-RepositoryRoot",
    (ConvertTo-RisePalsCandidateLaunchArgument -Value $RepositoryRoot),
    "-RepositoryHead",
    $RepositoryHead,
    "-AuthorizationId",
    $AuthorizationId,
    "-InvocationNonce",
    $InvocationNonce,
    "-ResultRoot",
    (ConvertTo-RisePalsCandidateLaunchArgument -Value $ResultRoot),
    "-InvocationDirectory",
    (ConvertTo-RisePalsCandidateLaunchArgument -Value $InvocationDirectory),
    "-LauncherScriptPath",
    (ConvertTo-RisePalsCandidateLaunchArgument -Value $LauncherScriptPath),
    "-LauncherScriptSha256",
    $LauncherScriptSha256,
    "-BootstrapScriptSha256",
    $BootstrapScriptSha256,
    "-TransportScriptPath",
    (ConvertTo-RisePalsCandidateLaunchArgument -Value $TransportScriptPath),
    "-TransportScriptSha256",
    $TransportScriptSha256,
    "-ChildScriptPath",
    (ConvertTo-RisePalsCandidateLaunchArgument -Value $ChildScriptPath),
    "-ChildScriptSha256",
    $ChildScriptSha256,
    "-FutureAuthorizationId",
    (ConvertTo-RisePalsCandidateLaunchArgument -Value $AuthorizationId),
    "-CandidateExecutableSource",
    (ConvertTo-RisePalsCandidateLaunchArgument -Value $CandidateExecutableSource),
    "-NodeExecutableSource",
    (ConvertTo-RisePalsCandidateLaunchArgument -Value $NodeExecutableSource)
  )
  $powerShell = Join-Path $env:SystemRoot `
    "System32\WindowsPowerShell\v1.0\powershell.exe"
  $verb = if ($ExecutionMode -in @("Live", "ElevationProbe")) { "RunAs" } else { "None" }
  return [pscustomobject][ordered]@{
    executionMode = $ExecutionMode
    filePath = $powerShell
    launcherExecutableBasename = "powershell.exe"
    verb = $verb
    windowStyle = "Hidden"
    waitRequested = $true
    passThruRequested = $true
    arguments = $arguments
    argumentCount = $arguments.Count
    canonicalArgumentDigest = Get-RisePalsCandidateCanonicalArgumentDigest `
      -Arguments $arguments
  }
}

function ConvertTo-RisePalsCandidateCanonicalLaunchDiagnostic {
  param([Parameter(Mandatory = $true)][object]$Diagnostic)

  $canonical = [ordered]@{
    schemaVersion = [string]$Diagnostic.schemaVersion
    launchAttempted = [bool]$Diagnostic.launchAttempted
    processCreated = [bool]$Diagnostic.processCreated
    launchDisposition = [string]$Diagnostic.launchDisposition
    sanitizedLaunchFailureCode = [string]$Diagnostic.sanitizedLaunchFailureCode
    nativeErrorCode = if ($null -eq $Diagnostic.nativeErrorCode) {
      $null
    } else {
      [int]$Diagnostic.nativeErrorCode
    }
    hResult = if ($null -eq $Diagnostic.hResult) { $null } else { [int]$Diagnostic.hResult }
    exceptionDepth = [int]$Diagnostic.exceptionDepth
    launcherExecutableBasename = [string]$Diagnostic.launcherExecutableBasename
    launcherExecutableExists = [bool]$Diagnostic.launcherExecutableExists
    launcherSignatureStatus = [string]$Diagnostic.launcherSignatureStatus
    launchVerb = [string]$Diagnostic.launchVerb
    argumentCount = [int]$Diagnostic.argumentCount
    canonicalArgumentDigest = [string]$Diagnostic.canonicalArgumentDigest
    waitRequested = [bool]$Diagnostic.waitRequested
    hiddenWindowRequested = [bool]$Diagnostic.hiddenWindowRequested
  }
  if ($Diagnostic.schemaVersion -ceq $script:RisePalsCandidateLaunchDiagnosticSchemaV2) {
    $canonical.provenance = $Diagnostic.provenance
  }
  return [pscustomobject]$canonical
}

function Get-RisePalsCandidateLaunchDiagnosticDigest {
  param([Parameter(Mandatory = $true)][object]$Diagnostic)

  return Get-RisePalsCandidateObjectDigest -Canonical (
    ConvertTo-RisePalsCandidateCanonicalLaunchDiagnostic -Diagnostic $Diagnostic
  )
}

function Get-RisePalsCandidateLauncherSignatureStatus {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)

  if (-not [IO.File]::Exists([IO.Path]::GetFullPath($LiteralPath))) {
    return "unavailable"
  }
  try {
    $status = [string](Get-AuthenticodeSignature -LiteralPath $LiteralPath).Status
    switch ($status) {
      "Valid" { return "valid" }
      "NotSigned" { return "not-signed" }
      "HashMismatch" { return "invalid" }
      "NotTrusted" { return "invalid" }
      default { return "unavailable" }
    }
  } catch {
    return "unavailable"
  }
}

function Get-RisePalsCandidateLaunchExceptionEvidence {
  param(
    [AllowNull()][object]$Exception,
    [AllowNull()][object]$ErrorRecord
  )

  $nativeCodes = @()
  $hResult = $null
  $hResultSource = "unavailable"
  $depth = 0
  $recordPresent = $null -ne $ErrorRecord
  $cursor = if ($recordPresent) {
    Get-RisePalsCandidateOptionalProperty -Value $ErrorRecord -Name "Exception"
  } else { $Exception }
  $typeDisposition = Get-RisePalsCandidateExceptionTypeDisposition -Value $cursor
  while ($null -ne $cursor -and $depth -lt 4) {
    $source = if ($recordPresent) {
      if ($depth -eq 0) { "error-record-exception" } else { "error-record-inner-exception" }
    } else {
      if ($depth -eq 0) { "top-level-exception" } else { "inner-exception" }
    }
    $depth++
    $nativeValue = Get-RisePalsCandidateOptionalProperty -Value $cursor -Name "NativeErrorCode"
    if ((Test-RisePalsCandidateIntegralValue -Value $nativeValue) -and
      $nativeValue -ge [int]::MinValue -and $nativeValue -le [int]::MaxValue) {
      $nativeCodes += [pscustomobject]@{ code = [int]$nativeValue; source = $source }
    }
    if ($null -eq $hResult) {
      $hResultValue = Get-RisePalsCandidateOptionalProperty -Value $cursor -Name "HResult"
      if ((Test-RisePalsCandidateIntegralValue -Value $hResultValue) -and
        $hResultValue -ge [int]::MinValue -and $hResultValue -le [int]::MaxValue) {
        $hResult = [int]$hResultValue
        $hResultSource = $source
      }
    }
    $cursor = Get-RisePalsCandidateOptionalProperty -Value $cursor -Name "InnerException"
  }
  $selected = $null
  foreach ($entry in $nativeCodes) {
    if ($null -eq $selected) { $selected = $entry }
    if ($entry.code -eq 1223) { $selected = $entry; break }
  }
  $category = Get-RisePalsCandidateOptionalProperty -Value $ErrorRecord -Name "CategoryInfo"
  $categoryValue = Get-RisePalsCandidateOptionalProperty -Value $category -Name "Category"
  $reason = Get-RisePalsCandidateOptionalProperty -Value $category -Name "Reason"
  $errorId = Get-RisePalsCandidateOptionalProperty -Value $ErrorRecord -Name "FullyQualifiedErrorId"
  $categoryDisposition = if ($null -eq $categoryValue) { "unavailable" } else {
    switch -CaseSensitive ([string]$categoryValue) {
      "OperationStopped" { "operation-stopped" }
      "InvalidOperation" { "invalid-operation" }
      "PermissionDenied" { "permission-denied" }
      "ResourceUnavailable" { "resource-unavailable" }
      "NotSpecified" { "not-specified" }
      default { "other-controlled" }
    }
  }
  $idDisposition = if ($null -eq $errorId -or $errorId -ceq "") { "unavailable" } else {
    switch -CaseSensitive ($errorId) {
      "InvalidOperationException,Microsoft.PowerShell.Commands.StartProcessCommand" { "start-process-failed" }
      "NativeCommandFailed" { "native-command-failed" }
      default { "other-controlled" }
    }
  }
  $provenance = [pscustomobject][ordered]@{
    errorRecordPresent = $recordPresent
    exceptionTypeDisposition = $typeDisposition
    errorCategoryDisposition = $categoryDisposition
    errorReasonDisposition = Get-RisePalsCandidateExceptionTypeDisposition -TypeBasename $reason
    fullyQualifiedErrorDisposition = $idDisposition
    nativeCodeSource = if ($null -eq $selected) { "unavailable" } else { $selected.source }
    hResultSource = $hResultSource
    examinedExceptionCount = $depth
    provenanceDigest = ""
  }
  $provenance.provenanceDigest = Get-RisePalsCandidateLaunchProvenanceDigest -Provenance $provenance
  return [pscustomobject][ordered]@{
    nativeErrorCode = if ($null -eq $selected) { $null } else { $selected.code }
    hResult = $hResult
    exceptionDepth = $depth
    provenance = $provenance
  }
}

function Get-RisePalsCandidateOptionalProperty {
  param([AllowNull()][object]$Value, [string]$Name)
  if ($null -eq $Value) { return $null }
  $property = $Value.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Get-RisePalsCandidateExceptionTypeDisposition {
  param([AllowNull()][object]$Value, [AllowNull()][object]$TypeBasename)
  if ($Value -is [Exception]) { $TypeBasename = $Value.GetType().Name }
  if ($null -eq $TypeBasename -or $TypeBasename -ceq "") { return "unavailable" }
  switch -CaseSensitive ($TypeBasename) {
    "Win32Exception" { return "win32-exception" }
    "InvalidOperationException" { return "invalid-operation-exception" }
    "RuntimeException" { return "runtime-exception" }
    default { return "other-controlled" }
  }
}

function Get-RisePalsCandidateLaunchProvenanceDigest {
  param([Parameter(Mandatory = $true)][object]$Provenance)
  $canonical = [ordered]@{}
  foreach ($name in $script:RisePalsCandidateLaunchProvenanceProperties) {
    if ($name -cne "provenanceDigest") { $canonical[$name] = $Provenance.$name }
  }
  return Get-RisePalsCandidateObjectDigest -Canonical ([pscustomobject]$canonical)
}

function Assert-RisePalsCandidateLaunchProvenance {
  param([Parameter(Mandatory = $true)][object]$Diagnostic)
  $p = $Diagnostic.provenance
  Assert-RisePalsCandidateTransportExactPropertySet -Value $p `
    -Expected $script:RisePalsCandidateLaunchProvenanceProperties -Label "Launch provenance"
  $types = @("win32-exception", "invalid-operation-exception", "runtime-exception", "other-controlled", "unavailable")
  $sources = @("top-level-exception", "inner-exception", "error-record-exception", "error-record-inner-exception", "unavailable")
  foreach ($name in $script:RisePalsCandidateLaunchProvenanceProperties) {
    if ($name -notin @("errorRecordPresent", "examinedExceptionCount") -and $p.$name -isnot [string]) {
      throw "Launch provenance has a non-string disposition."
    }
  }
  if ($p.errorRecordPresent -isnot [bool] -or
    -not (Test-RisePalsCandidateIntegralValue -Value $p.examinedExceptionCount) -or
    $p.examinedExceptionCount -lt 0 -or $p.examinedExceptionCount -gt 4 -or
    $p.examinedExceptionCount -ne $Diagnostic.exceptionDepth -or
    $p.exceptionTypeDisposition -cnotin $types -or $p.errorReasonDisposition -cnotin $types -or
    $p.errorCategoryDisposition -cnotin @("operation-stopped", "invalid-operation", "permission-denied", "resource-unavailable", "not-specified", "other-controlled", "unavailable") -or
    $p.fullyQualifiedErrorDisposition -cnotin @("start-process-failed", "native-command-failed", "other-controlled", "unavailable") -or
    $p.nativeCodeSource -cnotin $sources -or $p.hResultSource -cnotin $sources -or
    $p.provenanceDigest -cne (Get-RisePalsCandidateLaunchProvenanceDigest -Provenance $p)) {
    throw "Launch provenance schema or digest is invalid."
  }
  foreach ($pair in @(@("nativeErrorCode", "nativeCodeSource"), @("hResult", "hResultSource"))) {
    $source = $p.($pair[1])
    if (($null -eq $Diagnostic.($pair[0])) -ne ($source -ceq "unavailable") -or
      ($source -cne "unavailable" -and ($p.examinedExceptionCount -lt 1 -or
        ($source.StartsWith("error-record-")) -ne $p.errorRecordPresent)) -or
      ($source -in @("inner-exception", "error-record-inner-exception") -and $p.examinedExceptionCount -lt 2)) {
      throw "Launch provenance numeric source is inconsistent."
    }
  }
  if ((-not $p.errorRecordPresent -and ($p.errorCategoryDisposition -cne "unavailable" -or
      $p.errorReasonDisposition -cne "unavailable" -or $p.fullyQualifiedErrorDisposition -cne "unavailable")) -or
    ($p.examinedExceptionCount -eq 0 -and $p.exceptionTypeDisposition -cne "unavailable")) {
    throw "Launch provenance record presence is inconsistent."
  }
}

function Get-RisePalsCandidateSanitizedLaunchFailureCode {
  param([AllowNull()][object]$NativeErrorCode)

  if ($null -eq $NativeErrorCode) {
    return "launcher-exception-unknown"
  }
  switch ([int]$NativeErrorCode) {
    1223 { return "uac-cancelled" }
    2 { return "launcher-target-not-found" }
    3 { return "launcher-target-not-found" }
    5 { return "launcher-access-denied" }
    31 { return "shell-execute-failed" }
    1155 { return "shell-execute-failed" }
    87 { return "malformed-launch-request" }
    8 { return "process-start-failed" }
    14 { return "process-start-failed" }
    193 { return "process-start-failed" }
    206 { return "process-start-failed" }
    267 { return "process-start-failed" }
    740 { return "process-start-failed" }
    default { return "launcher-exception-unknown" }
  }
}

function New-RisePalsCandidateLaunchDiagnostic {
  param(
    [Parameter(Mandatory = $true)][bool]$LaunchAttempted,
    [Parameter(Mandatory = $true)][bool]$ProcessCreated,
    [Parameter(Mandatory = $true)][ValidateSet(
      "not-launched", "cancelled", "launch-failure", "launched"
    )][string]$LaunchDisposition,
    [Parameter(Mandatory = $true)][ValidateSet(
      "none", "uac-cancelled", "launcher-target-not-found",
      "launcher-access-denied", "shell-execute-failed",
      "malformed-launch-request", "process-start-failed",
      "launcher-exception-unknown"
    )][string]$SanitizedLaunchFailureCode,
    [AllowNull()][object]$NativeErrorCode,
    [AllowNull()][object]$HResult,
    [Parameter(Mandatory = $true)][int]$ExceptionDepth,
    [Parameter(Mandatory = $true)][bool]$LauncherExecutableExists,
    [Parameter(Mandatory = $true)][ValidateSet(
      "valid", "not-signed", "invalid", "unavailable"
    )][string]$LauncherSignatureStatus,
    [Parameter(Mandatory = $true)][ValidateSet("None", "RunAs")][string]$LaunchVerb,
    [Parameter(Mandatory = $true)][int]$ArgumentCount,
    [Parameter(Mandatory = $true)][string]$CanonicalArgumentDigest,
    [bool]$WaitRequested = $true,
    [bool]$HiddenWindowRequested = $true,
    [AllowNull()][object]$Provenance
  )

  $diagnostic = [ordered]@{
    schemaVersion = $script:RisePalsCandidateLaunchDiagnosticSchema
    launchAttempted = $LaunchAttempted
    processCreated = $ProcessCreated
    launchDisposition = $LaunchDisposition
    sanitizedLaunchFailureCode = $SanitizedLaunchFailureCode
    nativeErrorCode = if ($null -eq $NativeErrorCode) { $null } else { [int]$NativeErrorCode }
    hResult = if ($null -eq $HResult) { $null } else { [int]$HResult }
    exceptionDepth = $ExceptionDepth
    launcherExecutableBasename = "powershell.exe"
    launcherExecutableExists = $LauncherExecutableExists
    launcherSignatureStatus = $LauncherSignatureStatus
    launchVerb = $LaunchVerb
    argumentCount = $ArgumentCount
    canonicalArgumentDigest = $CanonicalArgumentDigest
    waitRequested = $WaitRequested
    hiddenWindowRequested = $HiddenWindowRequested
    diagnosticDigest = ""
  }
  if ($null -ne $Provenance) {
    $diagnostic.schemaVersion = $script:RisePalsCandidateLaunchDiagnosticSchemaV2
    $diagnostic.provenance = $Provenance
  }
  $diagnostic.diagnosticDigest = Get-RisePalsCandidateLaunchDiagnosticDigest `
    -Diagnostic $diagnostic
  return [pscustomobject]$diagnostic
}

function Assert-RisePalsCandidateLaunchDiagnostic {
  param([Parameter(Mandatory = $true)][object]$Diagnostic)

  $properties = $script:RisePalsCandidateLaunchDiagnosticProperties
  if ($Diagnostic.schemaVersion -ceq $script:RisePalsCandidateLaunchDiagnosticSchemaV2) {
    $properties = @($properties) + @("provenance")
  }
  Assert-RisePalsCandidateTransportExactPropertySet -Value $Diagnostic `
    -Expected $properties `
    -Label "Candidate launch diagnostic"
  if ($Diagnostic.schemaVersion -ceq $script:RisePalsCandidateLaunchDiagnosticSchemaV2) {
    Assert-RisePalsCandidateLaunchProvenance -Diagnostic $Diagnostic
    foreach ($name in @("schemaVersion", "launchDisposition", "sanitizedLaunchFailureCode",
      "launcherExecutableBasename", "launcherSignatureStatus", "launchVerb",
      "canonicalArgumentDigest", "diagnosticDigest")) {
      if ($Diagnostic.$name -isnot [string]) { throw "A launch diagnostic string is mistyped." }
    }
  }
  $failureCodes = @(
    "none", "uac-cancelled", "launcher-target-not-found",
    "launcher-access-denied", "shell-execute-failed", "malformed-launch-request",
    "process-start-failed", "launcher-exception-unknown"
  )
  $nativeIsIntegral = $null -eq $Diagnostic.nativeErrorCode -or
    (Test-RisePalsCandidateIntegralValue -Value $Diagnostic.nativeErrorCode)
  $hResultIsIntegral = $null -eq $Diagnostic.hResult -or
    (Test-RisePalsCandidateIntegralValue -Value $Diagnostic.hResult)
  $nativeCode = if ($null -eq $Diagnostic.nativeErrorCode) {
    $null
  } else {
    [int]$Diagnostic.nativeErrorCode
  }
  $mappedCode = if ($null -eq $nativeCode) {
    $null
  } else {
    Get-RisePalsCandidateSanitizedLaunchFailureCode -NativeErrorCode $nativeCode
  }
  $basicInvalid = $Diagnostic.schemaVersion -cnotin @($script:RisePalsCandidateLaunchDiagnosticSchema, $script:RisePalsCandidateLaunchDiagnosticSchemaV2) -or
    $Diagnostic.launchAttempted -isnot [bool] -or
    $Diagnostic.processCreated -isnot [bool] -or
    $Diagnostic.launcherExecutableExists -isnot [bool] -or
    $Diagnostic.waitRequested -isnot [bool] -or
    $Diagnostic.hiddenWindowRequested -isnot [bool] -or
    -not $nativeIsIntegral -or -not $hResultIsIntegral -or
    -not (Test-RisePalsCandidateIntegralValue -Value $Diagnostic.exceptionDepth) -or
    -not (Test-RisePalsCandidateIntegralValue -Value $Diagnostic.argumentCount) -or
    $Diagnostic.launchDisposition -notin @(
      "not-launched", "cancelled", "launch-failure", "launched"
    ) -or $Diagnostic.sanitizedLaunchFailureCode -notin $failureCodes -or
    $Diagnostic.launcherExecutableBasename -cne "powershell.exe" -or
    $Diagnostic.launcherSignatureStatus -notin @(
      "valid", "not-signed", "invalid", "unavailable"
    ) -or $Diagnostic.launchVerb -notin @("None", "RunAs") -or
    [int]$Diagnostic.exceptionDepth -lt 0 -or [int]$Diagnostic.exceptionDepth -gt 4 -or
    [int]$Diagnostic.argumentCount -lt 0 -or [int]$Diagnostic.argumentCount -gt 64 -or
    $Diagnostic.canonicalArgumentDigest -notmatch "^[a-f0-9]{64}$" -or
    -not [bool]$Diagnostic.waitRequested -or
    -not [bool]$Diagnostic.hiddenWindowRequested -or
    ([bool]$Diagnostic.processCreated -and -not [bool]$Diagnostic.launchAttempted) -or
    $Diagnostic.diagnosticDigest -ne (
      Get-RisePalsCandidateLaunchDiagnosticDigest -Diagnostic $Diagnostic
    )
  if ($basicInvalid) {
    throw "The candidate launch diagnostic schema or digest is invalid."
  }
  switch ([string]$Diagnostic.launchDisposition) {
    "not-launched" {
      if ([bool]$Diagnostic.launchAttempted -or [bool]$Diagnostic.processCreated -or
        $Diagnostic.sanitizedLaunchFailureCode -ne "none" -or
        $null -ne $Diagnostic.nativeErrorCode -or $null -ne $Diagnostic.hResult -or
        [int]$Diagnostic.exceptionDepth -ne 0) {
        throw "The not-launched diagnostic is inconsistent."
      }
    }
    "cancelled" {
      if (-not [bool]$Diagnostic.launchAttempted -or [bool]$Diagnostic.processCreated -or
        $Diagnostic.sanitizedLaunchFailureCode -ne "uac-cancelled" -or
        $nativeCode -ne 1223 -or [int]$Diagnostic.exceptionDepth -lt 1 -or
        -not [bool]$Diagnostic.launcherExecutableExists -or
        $Diagnostic.launcherSignatureStatus -ne "valid") {
        throw "The cancelled launch diagnostic is inconsistent."
      }
    }
    "launch-failure" {
      if ([bool]$Diagnostic.processCreated -or
        $Diagnostic.sanitizedLaunchFailureCode -in @("none", "uac-cancelled")) {
        throw "The failed launch diagnostic is inconsistent."
      }
      if ($null -ne $nativeCode -and $Diagnostic.sanitizedLaunchFailureCode -ne $mappedCode) {
        throw "The failed launch diagnostic native-code mapping is inconsistent."
      }
      if ([bool]$Diagnostic.launchAttempted -and $null -eq $nativeCode -and
        [int]$Diagnostic.exceptionDepth -gt 0 -and
        $Diagnostic.sanitizedLaunchFailureCode -ne "launcher-exception-unknown") {
        throw "The failed launch diagnostic without a native code is inconsistent."
      }
      $preflightInconsistent = $false
      if (-not [bool]$Diagnostic.launchAttempted) {
        switch ([string]$Diagnostic.sanitizedLaunchFailureCode) {
          "launcher-target-not-found" {
            $preflightInconsistent = [bool]$Diagnostic.launcherExecutableExists -or
              $Diagnostic.launcherSignatureStatus -ne "unavailable"
          }
          "launcher-access-denied" {
            $preflightInconsistent = -not [bool]$Diagnostic.launcherExecutableExists -or
              $Diagnostic.launcherSignatureStatus -ne "unavailable"
          }
          "shell-execute-failed" {
            $preflightInconsistent = -not [bool]$Diagnostic.launcherExecutableExists -or
              $Diagnostic.launcherSignatureStatus -notin @("not-signed", "invalid")
          }
          "malformed-launch-request" { $preflightInconsistent = $false }
          default { $preflightInconsistent = $true }
        }
      }
      if ((-not [bool]$Diagnostic.launchAttempted -and (
          [int]$Diagnostic.exceptionDepth -ne 0 -or
          $null -ne $Diagnostic.nativeErrorCode -or $null -ne $Diagnostic.hResult
        )) -or ([bool]$Diagnostic.launchAttempted -and (
          -not [bool]$Diagnostic.launcherExecutableExists -or
          $Diagnostic.launcherSignatureStatus -ne "valid"
        )) -or
        ([bool]$Diagnostic.launchAttempted -and [int]$Diagnostic.exceptionDepth -eq 0 -and (
          ($Diagnostic.sanitizedLaunchFailureCode -ne "process-start-failed" -and
            -not ($Diagnostic.schemaVersion -ceq $script:RisePalsCandidateLaunchDiagnosticSchemaV2 -and
              $Diagnostic.sanitizedLaunchFailureCode -ceq "launcher-exception-unknown")) -or
          $null -ne $Diagnostic.nativeErrorCode -or $null -ne $Diagnostic.hResult
        )) -or $preflightInconsistent) {
        throw "The failed launch diagnostic preflight or exception boundary is inconsistent."
      }
    }
    "launched" {
      if (-not [bool]$Diagnostic.launchAttempted -or
        -not [bool]$Diagnostic.processCreated -or
        $Diagnostic.sanitizedLaunchFailureCode -ne "none" -or
        $null -ne $Diagnostic.nativeErrorCode -or $null -ne $Diagnostic.hResult -or
        [int]$Diagnostic.exceptionDepth -ne 0 -or
        -not [bool]$Diagnostic.launcherExecutableExists -or
        $Diagnostic.launcherSignatureStatus -ne "valid") {
        throw "The successful launch diagnostic is inconsistent."
      }
    }
  }
  Assert-RisePalsCandidateParentRecordPrivacy -Record $Diagnostic
  return $true
}

function ConvertTo-RisePalsCandidateCanonicalProbeDiagnostic {
  param([Parameter(Mandatory = $true)][object]$Diagnostic)

  return [pscustomobject][ordered]@{
    schemaVersion = [string]$Diagnostic.schemaVersion
    probeStatus = [string]$Diagnostic.probeStatus
    failedStage = if ($null -eq $Diagnostic.failedStage) {
      $null
    } else {
      [string]$Diagnostic.failedStage
    }
    sanitizedFailureCode = if ($null -eq $Diagnostic.sanitizedFailureCode) {
      $null
    } else {
      [string]$Diagnostic.sanitizedFailureCode
    }
    elevatedChildEntered = [bool]$Diagnostic.elevatedChildEntered
    administratorRoleConfirmed = [bool]$Diagnostic.administratorRoleConfirmed
    integrityLevel = [string]$Diagnostic.integrityLevel
    repositoryHeadMatched = [bool]$Diagnostic.repositoryHeadMatched
    authorizationMatched = [bool]$Diagnostic.authorizationMatched
    invocationNonceMatched = [bool]$Diagnostic.invocationNonceMatched
    launcherHashMatched = [bool]$Diagnostic.launcherHashMatched
    bootstrapHashMatched = [bool]$Diagnostic.bootstrapHashMatched
    transportHashMatched = [bool]$Diagnostic.transportHashMatched
    childHashMatched = [bool]$Diagnostic.childHashMatched
    liveSequenceInvoked = [bool]$Diagnostic.liveSequenceInvoked
    hostMutationAttempted = [bool]$Diagnostic.hostMutationAttempted
  }
}

function Get-RisePalsCandidateProbeDiagnosticDigest {
  param([Parameter(Mandatory = $true)][object]$Diagnostic)

  return Get-RisePalsCandidateObjectDigest -Canonical (
    ConvertTo-RisePalsCandidateCanonicalProbeDiagnostic -Diagnostic $Diagnostic
  )
}

function New-RisePalsCandidateProbeDiagnostic {
  param(
    [Parameter(Mandatory = $true)][ValidateSet("success", "failure")][string]$ProbeStatus,
    [AllowNull()][string]$FailedStage,
    [AllowNull()][string]$SanitizedFailureCode,
    [Parameter(Mandatory = $true)][bool]$ElevatedChildEntered,
    [Parameter(Mandatory = $true)][bool]$AdministratorRoleConfirmed,
    [Parameter(Mandatory = $true)][ValidateSet(
      "high", "system", "insufficient", "unavailable"
    )][string]$IntegrityLevel,
    [Parameter(Mandatory = $true)][bool]$RepositoryHeadMatched,
    [Parameter(Mandatory = $true)][bool]$AuthorizationMatched,
    [Parameter(Mandatory = $true)][bool]$InvocationNonceMatched,
    [Parameter(Mandatory = $true)][bool]$LauncherHashMatched,
    [Parameter(Mandatory = $true)][bool]$BootstrapHashMatched,
    [Parameter(Mandatory = $true)][bool]$TransportHashMatched,
    [Parameter(Mandatory = $true)][bool]$ChildHashMatched,
    [bool]$LiveSequenceInvoked = $false,
    [bool]$HostMutationAttempted = $false
  )

  $diagnostic = [ordered]@{
    schemaVersion = $script:RisePalsCandidateProbeDiagnosticSchema
    probeStatus = $ProbeStatus
    failedStage = if ([string]::IsNullOrWhiteSpace($FailedStage)) { $null } else { $FailedStage }
    sanitizedFailureCode = if ([string]::IsNullOrWhiteSpace($SanitizedFailureCode)) {
      $null
    } else {
      $SanitizedFailureCode
    }
    elevatedChildEntered = $ElevatedChildEntered
    administratorRoleConfirmed = $AdministratorRoleConfirmed
    integrityLevel = $IntegrityLevel
    repositoryHeadMatched = $RepositoryHeadMatched
    authorizationMatched = $AuthorizationMatched
    invocationNonceMatched = $InvocationNonceMatched
    launcherHashMatched = $LauncherHashMatched
    bootstrapHashMatched = $BootstrapHashMatched
    transportHashMatched = $TransportHashMatched
    childHashMatched = $ChildHashMatched
    liveSequenceInvoked = $LiveSequenceInvoked
    hostMutationAttempted = $HostMutationAttempted
    probeDigest = ""
  }
  $diagnostic.probeDigest = Get-RisePalsCandidateProbeDiagnosticDigest `
    -Diagnostic $diagnostic
  $diagnosticObject = [pscustomobject]$diagnostic
  [void](Assert-RisePalsCandidateProbeDiagnostic -Diagnostic $diagnosticObject)
  return $diagnosticObject
}

function Assert-RisePalsCandidateProbeDiagnostic {
  param([Parameter(Mandatory = $true)][object]$Diagnostic)

  Assert-RisePalsCandidateTransportExactPropertySet -Value $Diagnostic `
    -Expected $script:RisePalsCandidateProbeDiagnosticProperties `
    -Label "Candidate elevation-probe diagnostic"
  $booleanProperties = @(
    "elevatedChildEntered", "administratorRoleConfirmed", "repositoryHeadMatched",
    "authorizationMatched", "invocationNonceMatched", "launcherHashMatched",
    "bootstrapHashMatched", "transportHashMatched", "childHashMatched",
    "liveSequenceInvoked", "hostMutationAttempted"
  )
  if ($Diagnostic.schemaVersion -ne $script:RisePalsCandidateProbeDiagnosticSchema -or
    $Diagnostic.probeStatus -notin @("success", "failure") -or
    $Diagnostic.integrityLevel -notin @("high", "system", "insufficient", "unavailable") -or
    @($booleanProperties | Where-Object {
      $Diagnostic.$_ -isnot [bool]
    }).Count -ne 0 -or
    -not [bool]$Diagnostic.elevatedChildEntered -or
    [bool]$Diagnostic.liveSequenceInvoked -or
    [bool]$Diagnostic.hostMutationAttempted -or
    $Diagnostic.probeDigest -notmatch "^[a-f0-9]{64}$" -or
    $Diagnostic.probeDigest -ne (
      Get-RisePalsCandidateProbeDiagnosticDigest -Diagnostic $Diagnostic
    )) {
    throw "The elevation-probe diagnostic schema, safety state, or digest is invalid."
  }
  $provenanceMatched = [bool]$Diagnostic.repositoryHeadMatched -and
    [bool]$Diagnostic.authorizationMatched -and
    [bool]$Diagnostic.invocationNonceMatched -and
    [bool]$Diagnostic.launcherHashMatched -and
    [bool]$Diagnostic.bootstrapHashMatched -and
    [bool]$Diagnostic.transportHashMatched -and
    [bool]$Diagnostic.childHashMatched
  $elevationMatched = [bool]$Diagnostic.administratorRoleConfirmed -and
    $Diagnostic.integrityLevel -in @("high", "system")
  if ($Diagnostic.probeStatus -eq "success") {
    if ($null -ne $Diagnostic.failedStage -or
      $null -ne $Diagnostic.sanitizedFailureCode -or
      -not $provenanceMatched -or -not $elevationMatched) {
      throw "A successful elevation-probe diagnostic lacks exact provenance or elevation proof."
    }
  } else {
    $failureMap = [ordered]@{
      "probe-entry-validation" = "probe-provenance-mismatch"
      "probe-elevation-validation" = "probe-insufficient-elevation"
      "probe-result-finalization" = "probe-finalization-failed"
    }
    if (-not $failureMap.Contains([string]$Diagnostic.failedStage) -or
      [string]$Diagnostic.sanitizedFailureCode -ne
        [string]$failureMap[[string]$Diagnostic.failedStage] -or
      ($Diagnostic.failedStage -eq "probe-entry-validation" -and $provenanceMatched) -or
      ($Diagnostic.failedStage -eq "probe-elevation-validation" -and
        (-not $provenanceMatched -or $elevationMatched)) -or
      ($Diagnostic.failedStage -eq "probe-result-finalization" -and
        (-not $provenanceMatched -or -not $elevationMatched))) {
      throw "A failed elevation-probe diagnostic lacks exact sanitized provenance."
    }
  }
  Assert-RisePalsCandidateParentRecordPrivacy -Record $Diagnostic
  return $true
}

function Test-RisePalsCandidateProbeDiagnosticSuccess {
  param([AllowNull()][object]$Diagnostic)

  if ($null -eq $Diagnostic) {
    return $false
  }
  [void](Assert-RisePalsCandidateProbeDiagnostic -Diagnostic $Diagnostic)
  return $Diagnostic.probeStatus -eq "success"
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
    [Parameter(Mandatory = $true)][ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$Mode
  )

  $exact = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $authorizedRoot = if ($Mode -eq "Simulation") {
    [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
      [IO.Path]::DirectorySeparatorChar
    )
  } else {
    "C:\Users\Administrator\Documents\Codex"
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
    [Parameter(Mandatory = $true)][ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$Mode
  )

  $exact = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $authorizedRoot = if ($Mode -eq "Simulation") {
    [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
      [IO.Path]::DirectorySeparatorChar
    )
  } else {
    "C:\Users\Administrator\Documents\Codex"
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

function ConvertFrom-RisePalsCandidateUniqueJson {
  param([Parameter(Mandatory = $true)][string]$Json)

  # Syntax belongs to the JSON parser; reject duplicate decoded keys before its
  # object conversion can discard them. Strings are tokenized, never searched
  # as raw field-name substrings. This adds no transport or launch behavior.
  $parsed = $Json | ConvertFrom-Json
  $tokens = [regex]::Matches($Json, '"(?:[^"\\]|\\.)*"|[{}\[\]:]')
  $stack = [Collections.Generic.Stack[object]]::new()
  for ($index = 0; $index -lt $tokens.Count; $index++) {
    $token = $tokens[$index].Value
    if ($token -eq "{" -or $token -eq "[") {
      $stack.Push([pscustomobject]@{ kind = $token; keys = @{} })
    } elseif ($token -eq "}" -or $token -eq "]") {
      if ($stack.Count -eq 0) { throw "Candidate JSON nesting is invalid." }
      [void]$stack.Pop()
    } elseif ($token.StartsWith('"') -and $index + 1 -lt $tokens.Count -and
      $tokens[$index + 1].Value -eq ":") {
      if ($stack.Count -eq 0 -or $stack.Peek().kind -ne "{") {
        throw "Candidate JSON property nesting is invalid."
      }
      $decoded = ('[' + $token + ']') | ConvertFrom-Json
      $key = [string]$decoded[0]
      if ($stack.Peek().keys.ContainsKey($key)) {
        throw "Candidate JSON contains a duplicate property."
      }
      $stack.Peek().keys[$key] = $true
    }
  }
  if ($stack.Count -ne 0) { throw "Candidate JSON nesting is incomplete." }
  return $parsed
}

function Read-RisePalsCandidateDurableEvidenceRecord {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$Mode,
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
  return ConvertFrom-RisePalsCandidateUniqueJson -Json (
    [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
  )
}

function Read-RisePalsCandidateDurableParentCheckpoint {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce,
    [Parameter(Mandatory = $true)][ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$Mode
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
    [Parameter(Mandatory = $true)][ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$Mode
  )

  return Read-RisePalsCandidateDurableEvidenceRecord -Path $Path `
    -EvidenceDirectory $EvidenceDirectory -InvocationNonce $InvocationNonce `
    -Mode $Mode -RecordType Result
}

function Write-RisePalsCandidateDurableParentCheckpointAtomic {
  param(
    [Parameter(Mandatory = $true)][object]$Checkpoint,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$Mode
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
    [Parameter(Mandatory = $true)][ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$Mode
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
      "Simulation", "Live", "ElevationProbe"
    )][string]$ExecutionMode,
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
    [AllowNull()][string]$FinalStatus,
    [AllowNull()][object]$ProbeDiagnostic
  )

  switch ($LaunchDisposition) {
    "not-launched" { return "uac-not-launched" }
    "cancelled" { return "uac-cancelled" }
    "launch-failure" { return "elevated-process-launch-failure" }
  }
  if ($EvidenceInvalid -or ($FinalPresent -and -not $FinalValidated) -or
    ($ChildLaunchAttempted -and -not $BootstrapEntered) -or
    ($ChildStarted -and -not $ChildLaunchAttempted) -or
    ($LiveStarted -and -not $ChildStarted)) {
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
  if ($ExecutionMode -eq "ElevationProbe") {
    if ($LiveStarted -or ($FinalValidated -and (
        $FinalStatus -notin @("success", "failure") -or
        $null -eq $ProbeDiagnostic
      ))) {
      return "final-invalid-or-inconsistent"
    }
    if (-not $FinalPresent) {
      return "elevation-probe-child-failed"
    }
    if (-not $FinalValidated) {
      return "final-invalid-or-inconsistent"
    }
    if (Test-RisePalsCandidateProbeDiagnosticSuccess -Diagnostic $ProbeDiagnostic) {
      return "elevation-probe-success"
    }
    return "elevation-probe-failure"
  }
  if (-not $LiveStarted) {
    return "child-started-failed-before-live"
  }
  if ($FinalValidated -and (-not $BootstrapEntered -or
      -not $ChildLaunchAttempted -or -not $ChildStarted -or
      $FinalStatus -notin @("success", "failure"))) {
    return "final-invalid-or-inconsistent"
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
    executionMode = [string]$Checkpoint.executionMode
    launchDiagnostic = ConvertTo-RisePalsCandidateCanonicalLaunchDiagnostic `
      -Diagnostic $Checkpoint.launchDiagnostic
    probeDiagnostic = if ($null -eq $Checkpoint.probeDiagnostic) {
      $null
    } else {
      ConvertTo-RisePalsCandidateCanonicalProbeDiagnostic `
        -Diagnostic $Checkpoint.probeDiagnostic
    }
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
    childDiagnostic = ConvertTo-RisePalsCandidateCanonicalChildDiagnostic `
      -Diagnostic $Checkpoint.childDiagnostic
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
    [Parameter(Mandatory = $true)][ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$ExecutionMode,
    [Parameter(Mandatory = $true)][object]$LaunchDiagnostic,
    [AllowNull()][object]$ProbeDiagnostic,
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
    [AllowNull()][string]$FinalStatus,
    [Parameter(Mandatory = $true)][object]$ChildDiagnostic
  )

  $functionalSuccess = $Classification -eq "final-present-validated" -and
    $LaunchDisposition -eq "launched" -and
    [bool]$LaunchDiagnostic.processCreated -and
    $FinalStatus -eq "success" -and
    (Test-RisePalsCandidateDiagnosticFunctionalSuccess -Diagnostic $ChildDiagnostic)
  $probeSuccess = $ExecutionMode -eq "ElevationProbe" -and
    $Classification -eq "elevation-probe-success" -and
    $LaunchDisposition -eq "launched" -and
    [bool]$LaunchDiagnostic.processCreated -and
    $FinalStatus -eq "success" -and
    (Test-RisePalsCandidateProbeDiagnosticSuccess -Diagnostic $ProbeDiagnostic)
  $status = if ($functionalSuccess -or $probeSuccess) {
    "success"
  } else {
    "failure"
  }
  $checkpoint = [ordered]@{
    schemaVersion = $script:RisePalsCandidateParentCheckpointSchema
    invocationNonce = $InvocationNonce
    authorizationId = $AuthorizationId
    repositoryHead = $RepositoryHead
    launcherScriptSha256 = $LauncherScriptSha256
    bootstrapScriptSha256 = $BootstrapScriptSha256
    transportScriptSha256 = $TransportScriptSha256
    childScriptSha256 = $ChildScriptSha256
    executionMode = $ExecutionMode
    launchDiagnostic = $LaunchDiagnostic
    probeDiagnostic = $ProbeDiagnostic
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
    childDiagnostic = $ChildDiagnostic
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
    [Parameter(Mandatory = $true)][string]$ExpectedLaunchDiagnosticDigest,
    [AllowNull()][object]$ExpectedProbeDiagnosticDigest,
    [ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$ExpectedExecutionMode = "Simulation",
    [Parameter(Mandatory = $true)][DateTimeOffset]$InvocationStartedAtUtc,
    [Parameter(Mandatory = $true)][hashtable]$ConsumedNonces,
    [DateTimeOffset]$ValidationNowUtc = [DateTimeOffset]::UtcNow
  )

  Assert-RisePalsCandidateTransportExactPropertySet -Value $Checkpoint `
    -Expected $script:RisePalsCandidateParentCheckpointProperties `
    -Label "Candidate parent checkpoint"
  [void](Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $Checkpoint.launchDiagnostic)
  [void](Assert-RisePalsCandidateChildDiagnostic -Diagnostic $Checkpoint.childDiagnostic)
  if ($null -ne $Checkpoint.probeDiagnostic) {
    [void](Assert-RisePalsCandidateProbeDiagnostic -Diagnostic $Checkpoint.probeDiagnostic)
  }
  $diagnosticSuccess = Test-RisePalsCandidateDiagnosticFunctionalSuccess `
    -Diagnostic $Checkpoint.childDiagnostic
  $probeSuccess = Test-RisePalsCandidateProbeDiagnosticSuccess `
    -Diagnostic $Checkpoint.probeDiagnostic
  $actualProbeDigest = if ($null -eq $Checkpoint.probeDiagnostic) {
    $null
  } else {
    [string]$Checkpoint.probeDiagnostic.probeDigest
  }
  if ($Checkpoint.schemaVersion -ne $script:RisePalsCandidateParentCheckpointSchema -or
    $Checkpoint.executionMode -ne $ExpectedExecutionMode -or
    $Checkpoint.childDiagnostic.executionMode -ne $ExpectedExecutionMode -or
    $Checkpoint.classification -notin @(
      "uac-not-launched", "uac-cancelled", "elevated-process-launch-failure",
      "elevated-child-never-entered-bootstrap",
      "bootstrap-entered-child-launch-not-attempted",
      "child-launch-attempted-child-not-started",
      "child-started-failed-before-live", "live-started-failed",
      "elevation-probe-child-failed", "elevation-probe-failure",
      "elevation-probe-success", "final-present-validated",
      "final-invalid-or-inconsistent"
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
    $Checkpoint.launchDiagnostic.diagnosticDigest -ne $ExpectedLaunchDiagnosticDigest -or
    $actualProbeDigest -ne $ExpectedProbeDiagnosticDigest -or
    $Checkpoint.launcherScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Checkpoint.bootstrapScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Checkpoint.transportScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Checkpoint.childScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $Checkpoint.launchDisposition -notin @("not-launched", "cancelled", "launch-failure", "launched") -or
    $Checkpoint.launchDisposition -ne $Checkpoint.launchDiagnostic.launchDisposition -or
    ([bool]$Checkpoint.processLaunched -ne ($Checkpoint.launchDisposition -eq "launched")) -or
    ([bool]$Checkpoint.processLaunched -ne [bool]$Checkpoint.launchDiagnostic.processCreated) -or
    ($Checkpoint.executionMode -in @("Live", "ElevationProbe") -and
      $Checkpoint.launchDiagnostic.launchVerb -ne "RunAs") -or
    ($Checkpoint.executionMode -eq "Simulation" -and
      $Checkpoint.launchDiagnostic.launchVerb -ne "None") -or
    ($Checkpoint.launchDisposition -ne "launched" -and (
      [bool]$Checkpoint.bootstrapEntered -or [bool]$Checkpoint.bootstrapStarted -or
      [bool]$Checkpoint.bootstrapFailurePresent -or
      [bool]$Checkpoint.childLaunchAttempted -or [bool]$Checkpoint.childStarted -or
      [bool]$Checkpoint.liveStarted -or [bool]$Checkpoint.finalPresent -or
      [bool]$Checkpoint.finalValidated
    )) -or
    ((
      ([bool]$Checkpoint.bootstrapStarted -and -not [bool]$Checkpoint.bootstrapEntered) -or
      ([bool]$Checkpoint.childLaunchAttempted -and -not [bool]$Checkpoint.bootstrapStarted) -or
      ([bool]$Checkpoint.childStarted -and -not [bool]$Checkpoint.childLaunchAttempted) -or
      ([bool]$Checkpoint.liveStarted -and -not [bool]$Checkpoint.childStarted) -or
      ([bool]$Checkpoint.finalValidated -and (-not [bool]$Checkpoint.finalPresent -or
        ($Checkpoint.executionMode -ne "ElevationProbe" -and
          -not [bool]$Checkpoint.liveStarted)))
    ) -and $Checkpoint.classification -ne "final-invalid-or-inconsistent") -or
    ($Checkpoint.executionMode -eq "ElevationProbe" -and (
      [bool]$Checkpoint.liveStarted -or
      (($null -ne $Checkpoint.probeDiagnostic) -ne [bool]$Checkpoint.finalValidated) -or
      $null -ne $Checkpoint.childDiagnostic.childResultDigest -or
      $null -ne $Checkpoint.childDiagnostic.childStatus -or
      $diagnosticSuccess
    )) -or
    ($Checkpoint.executionMode -ne "ElevationProbe" -and
      $null -ne $Checkpoint.probeDiagnostic) -or
    ($Checkpoint.status -eq "success" -and (
      -not [bool]$Checkpoint.finalValidated -or $Checkpoint.finalStatus -ne "success" -or
      (($Checkpoint.executionMode -eq "ElevationProbe") -and (
        $Checkpoint.classification -ne "elevation-probe-success" -or
        -not $probeSuccess
      )) -or
      (($Checkpoint.executionMode -ne "ElevationProbe") -and (
        $Checkpoint.classification -ne "final-present-validated" -or
        -not $diagnosticSuccess
      ))
    )) -or
    ($Checkpoint.status -eq "failure" -and $Checkpoint.finalStatus -eq "success" -and
      $Checkpoint.classification -in @("final-present-validated", "elevation-probe-success")) -or
    ($Checkpoint.executionMode -ne "ElevationProbe" -and (
      ([bool]$Checkpoint.finalValidated -and (
        $null -eq $Checkpoint.childDiagnostic.childResultDigest -or
        $Checkpoint.childDiagnostic.childStatus -ne $Checkpoint.finalStatus
      )) -or
      (-not [bool]$Checkpoint.finalValidated -and
        $null -ne $Checkpoint.childDiagnostic.childResultDigest)
    )) -or
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
    -ExecutionMode $Checkpoint.executionMode `
    -LaunchDisposition ([string]$Checkpoint.launchDisposition) `
    -BootstrapEntered ([bool]$Checkpoint.bootstrapEntered) `
    -ChildLaunchAttempted ([bool]$Checkpoint.childLaunchAttempted) `
    -ChildStarted ([bool]$Checkpoint.childStarted) `
    -LiveStarted ([bool]$Checkpoint.liveStarted) `
    -FinalPresent ([bool]$Checkpoint.finalPresent) `
    -FinalValidated ([bool]$Checkpoint.finalValidated) `
    -EvidenceInvalid ($Checkpoint.classification -eq "final-invalid-or-inconsistent") `
    -FinalStatus $Checkpoint.finalStatus -ProbeDiagnostic $Checkpoint.probeDiagnostic
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
    executionMode = [string]$Result.executionMode
    checkpointFileName = [string]$Result.checkpointFileName
    checkpointDigest = if ($null -eq $Result.checkpointDigest) { $null } else { [string]$Result.checkpointDigest }
    launchDiagnostic = ConvertTo-RisePalsCandidateCanonicalLaunchDiagnostic `
      -Diagnostic $Result.launchDiagnostic
    probeDiagnostic = if ($null -eq $Result.probeDiagnostic) {
      $null
    } else {
      ConvertTo-RisePalsCandidateCanonicalProbeDiagnostic `
        -Diagnostic $Result.probeDiagnostic
    }
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
    childDiagnostic = ConvertTo-RisePalsCandidateCanonicalChildDiagnostic `
      -Diagnostic $Result.childDiagnostic
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
    $Checkpoint.launchDisposition -eq "launched" -and
    [bool]$Checkpoint.launchDiagnostic.processCreated -and
    [bool]$Checkpoint.finalValidated -and $Checkpoint.finalStatus -eq "success" -and
    (Test-RisePalsCandidateDiagnosticFunctionalSuccess `
      -Diagnostic $Checkpoint.childDiagnostic)
  $probeSuccess = $Checkpoint.executionMode -eq "ElevationProbe" -and
    $Checkpoint.classification -eq "elevation-probe-success" -and
    $Checkpoint.launchDisposition -eq "launched" -and
    [bool]$Checkpoint.launchDiagnostic.processCreated -and
    [bool]$Checkpoint.finalValidated -and $Checkpoint.finalStatus -eq "success" -and
    (Test-RisePalsCandidateProbeDiagnosticSuccess `
      -Diagnostic $Checkpoint.probeDiagnostic)
  $overallStatus = if (($functionalSuccess -or $probeSuccess) -and
    $DurableCheckpointValidated -and
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
    executionMode = [string]$Checkpoint.executionMode
    checkpointFileName = $CheckpointFileName
    checkpointDigest = if ([string]::IsNullOrWhiteSpace($CheckpointDigest)) { $null } else { $CheckpointDigest }
    launchDiagnostic = $Checkpoint.launchDiagnostic
    probeDiagnostic = $Checkpoint.probeDiagnostic
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
    childDiagnostic = $Checkpoint.childDiagnostic
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
    [AllowNull()][object]$ExpectedCheckpointDigest,
    [Parameter(Mandatory = $true)][string]$ExpectedLaunchDiagnosticDigest,
    [Parameter(Mandatory = $true)][string]$ExpectedChildDiagnosticDigest,
    [AllowNull()][object]$ExpectedProbeDiagnosticDigest,
    [ValidateSet(
      "Simulation", "Live", "ElevationProbe"
    )][string]$ExpectedExecutionMode = "Simulation",
    [Parameter(Mandatory = $true)][DateTimeOffset]$InvocationStartedAtUtc,
    [Parameter(Mandatory = $true)][hashtable]$ConsumedNonces,
    [DateTimeOffset]$ValidationNowUtc = [DateTimeOffset]::UtcNow
  )

  Assert-RisePalsCandidateTransportExactPropertySet -Value $Result `
    -Expected $script:RisePalsCandidateParentResultProperties -Label "Candidate parent result"
  [void](Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $Result.launchDiagnostic)
  [void](Assert-RisePalsCandidateChildDiagnostic -Diagnostic $Result.childDiagnostic)
  if ($null -ne $Result.probeDiagnostic) {
    [void](Assert-RisePalsCandidateProbeDiagnostic -Diagnostic $Result.probeDiagnostic)
  }
  $paths = @($Result.remainingTransientRelativePaths)
  $invalidPaths = @($paths | Where-Object {
    $_ -notmatch "^[a-z0-9][a-z0-9.-]{0,127}$" -or $_.Contains("..")
  })
  $functionalSuccess = $Result.functionalClassification -eq "final-present-validated" -and
    $Result.launchDisposition -eq "launched" -and
    [bool]$Result.launchDiagnostic.processCreated -and
    [bool]$Result.finalValidated -and $Result.finalChildStatus -eq "success" -and
    (Test-RisePalsCandidateDiagnosticFunctionalSuccess `
      -Diagnostic $Result.childDiagnostic)
  $probeSuccess = $Result.executionMode -eq "ElevationProbe" -and
    $Result.functionalClassification -eq "elevation-probe-success" -and
    $Result.launchDisposition -eq "launched" -and
    [bool]$Result.launchDiagnostic.processCreated -and
    [bool]$Result.finalValidated -and $Result.finalChildStatus -eq "success" -and
    (Test-RisePalsCandidateProbeDiagnosticSuccess -Diagnostic $Result.probeDiagnostic)
  $actualProbeDigest = if ($null -eq $Result.probeDiagnostic) {
    $null
  } else {
    [string]$Result.probeDiagnostic.probeDigest
  }
  $overallSuccess = ($functionalSuccess -or $probeSuccess) -and
    [bool]$Result.durableCheckpointValidated -and
    [bool]$Result.transientCleanupAttempted -and [bool]$Result.transientCleanupCompleted -and
    [bool]$Result.invocationDirectoryAbsent -and
    [int]$Result.remainingTransientObjectCount -eq 0 -and
    [int]$Result.remainingTemporaryObjectCount -eq 0 -and $paths.Count -eq 0
  if ($Result.schemaVersion -ne $script:RisePalsCandidateParentResultSchema -or
    $Result.executionMode -ne $ExpectedExecutionMode -or
    $Result.childDiagnostic.executionMode -ne $ExpectedExecutionMode -or
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
    $Result.launchDiagnostic.diagnosticDigest -ne $ExpectedLaunchDiagnosticDigest -or
    $Result.childDiagnostic.diagnosticDigest -ne $ExpectedChildDiagnosticDigest -or
    $actualProbeDigest -ne $ExpectedProbeDiagnosticDigest -or
    ([bool]$Result.durableCheckpointValidated -and
      $Result.checkpointDigest -notmatch "^[a-f0-9]{64}$") -or
    (-not [bool]$Result.durableCheckpointValidated -and $null -ne $Result.checkpointDigest) -or
    $Result.launchDisposition -notin @("not-launched", "cancelled", "launch-failure", "launched") -or
    $Result.launchDisposition -ne $Result.launchDiagnostic.launchDisposition -or
    ([bool]$Result.processLaunched -ne ($Result.launchDisposition -eq "launched")) -or
    ([bool]$Result.processLaunched -ne [bool]$Result.launchDiagnostic.processCreated) -or
    ($Result.executionMode -in @("Live", "ElevationProbe") -and
      $Result.launchDiagnostic.launchVerb -ne "RunAs") -or
    ($Result.executionMode -eq "Simulation" -and
      $Result.launchDiagnostic.launchVerb -ne "None") -or
    ($Result.launchDisposition -ne "launched" -and (
      [bool]$Result.bootstrapEntered -or [bool]$Result.bootstrapStarted -or
      [bool]$Result.bootstrapFailurePresent -or
      [bool]$Result.childLaunchAttempted -or [bool]$Result.childStarted -or
      [bool]$Result.liveStarted -or [bool]$Result.finalPresent -or
      [bool]$Result.finalValidated
    )) -or
    $Result.functionalClassification -notin @(
      "uac-not-launched", "uac-cancelled", "elevated-process-launch-failure",
      "elevated-child-never-entered-bootstrap",
      "bootstrap-entered-child-launch-not-attempted",
      "child-launch-attempted-child-not-started",
      "child-started-failed-before-live", "live-started-failed",
      "elevation-probe-child-failed", "elevation-probe-failure",
      "elevation-probe-success", "final-present-validated",
      "final-invalid-or-inconsistent"
    ) -or $Result.finalChildStatus -notin @($null, "success", "failure") -or
    ($Result.executionMode -eq "ElevationProbe" -and (
      [bool]$Result.liveStarted -or
      (($null -ne $Result.probeDiagnostic) -ne [bool]$Result.finalValidated) -or
      $null -ne $Result.childDiagnostic.childResultDigest -or
      $null -ne $Result.childDiagnostic.childStatus -or
      $functionalSuccess
    )) -or
    ($Result.executionMode -ne "ElevationProbe" -and (
      $null -ne $Result.probeDiagnostic -or
      ([bool]$Result.finalValidated -and (
        $null -eq $Result.childDiagnostic.childResultDigest -or
        $Result.childDiagnostic.childStatus -ne $Result.finalChildStatus
      )) -or
      (-not [bool]$Result.finalValidated -and
        $null -ne $Result.childDiagnostic.childResultDigest)
    )) -or
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
    -ExecutionMode $Result.executionMode `
    -LaunchDisposition ([string]$Result.launchDisposition) `
    -BootstrapEntered ([bool]$Result.bootstrapEntered) `
    -ChildLaunchAttempted ([bool]$Result.childLaunchAttempted) `
    -ChildStarted ([bool]$Result.childStarted) -LiveStarted ([bool]$Result.liveStarted) `
    -FinalPresent ([bool]$Result.finalPresent) `
    -FinalValidated ([bool]$Result.finalValidated) `
    -EvidenceInvalid ($Result.functionalClassification -eq "final-invalid-or-inconsistent") `
    -FinalStatus $Result.finalChildStatus -ProbeDiagnostic $Result.probeDiagnostic
  if ($Result.functionalClassification -ne $expectedClassification) {
    throw "The authoritative result classification disagrees with its marker state."
  }
  Assert-RisePalsCandidateParentRecordPrivacy -Record $Result
  $ConsumedNonces[[string]$Result.invocationNonce] = $true
  return $true
}
