[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string]$Mode = "",
  [string]$SimulationScenario = "",
  [string]$RepositoryRoot = "",
  [string]$RepositoryHead = "",
  [string]$AuthorizationId = "",
  [string]$InvocationNonce = "",
  [string]$ResultRoot = "",
  [string]$InvocationDirectory = "",
  [string]$LauncherScriptPath = "",
  [string]$LauncherScriptSha256 = "",
  [string]$BootstrapScriptSha256 = "",
  [string]$TransportScriptPath = "",
  [string]$TransportScriptSha256 = "",
  [string]$ChildScriptPath = "",
  [string]$ChildScriptSha256 = "",
  [string]$FutureAuthorizationId = "",
  [string]$CandidateExecutableSource = "",
  [string]$NodeExecutableSource = ""
)

# This boundary is intentionally self-contained. It must be able to emit the
# first durable marker before loading any committed child or helper script.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RisePalsBootstrapSha256 {
  param([string]$LiteralPath)

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

function ConvertTo-RisePalsBootstrapCanonicalMarker {
  param([object]$Marker)

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

function Get-RisePalsBootstrapMarkerDigest {
  param([object]$Marker)

  $canonical = ConvertTo-RisePalsBootstrapCanonicalMarker -Marker $Marker
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
    ($canonical | ConvertTo-Json -Depth 5 -Compress)
  )
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

function New-RisePalsBootstrapMarker {
  param(
    [string]$MarkerType,
    [AllowNull()][string]$FailureCode
  )

  $marker = [ordered]@{
    schemaVersion = "rise-pals-candidate-transport-marker-v1"
    markerType = $MarkerType
    invocationNonce = $InvocationNonce
    authorizationId = $AuthorizationId
    repositoryHead = $RepositoryHead
    launcherScriptSha256 = $LauncherScriptSha256
    bootstrapScriptSha256 = $BootstrapScriptSha256
    transportScriptSha256 = $TransportScriptSha256
    childScriptSha256 = $ChildScriptSha256
    recordedAtUtc = [DateTimeOffset]::UtcNow.ToString("o")
    sanitizedFailureCode = if ([string]::IsNullOrWhiteSpace($FailureCode)) {
      $null
    } else {
      $FailureCode
    }
    markerDigest = ""
  }
  $marker.markerDigest = Get-RisePalsBootstrapMarkerDigest -Marker $marker
  return [pscustomobject]$marker
}

function Write-RisePalsBootstrapMarkerAtomic {
  param(
    [object]$Marker,
    [string]$Directory
  )

  $name = ([string]$Marker.markerType) + ".json"
  $path = [IO.Path]::GetFullPath((Join-Path $Directory $name))
  $temporary = [IO.Path]::GetFullPath((Join-Path $Directory ($name + ".tmp")))
  if ([IO.File]::Exists($path) -or [IO.File]::Exists($temporary)) {
    throw "The bootstrap marker path is not fresh."
  }
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
    (($Marker | ConvertTo-Json -Depth 5) + "`n")
  )
  $stream = [IO.FileStream]::new(
    $temporary,
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
  [IO.File]::Move($temporary, $path)
}

function Assert-RisePalsBootstrapDirectory {
  param(
    [string]$Path,
    [string]$Root
  )

  $exactRoot = [IO.Path]::GetFullPath($Root).TrimEnd(
    [IO.Path]::DirectorySeparatorChar
  )
  $exact = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $expected = [IO.Path]::GetFullPath(
    (Join-Path $exactRoot ("invocation-" + $InvocationNonce))
  )
  if (-not $exact.Equals($expected, [StringComparison]::OrdinalIgnoreCase) -or
    -not [IO.Directory]::Exists($exactRoot) -or -not [IO.Directory]::Exists($exact)) {
    throw "The explicit bootstrap result directory is invalid."
  }
  foreach ($candidate in @($exactRoot, $exact)) {
    $item = Get-Item -LiteralPath $candidate -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      -not [string]::IsNullOrWhiteSpace([string]$item.LinkType)) {
      throw "The bootstrap result directory is unexpectedly linked."
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
    throw "The bootstrap result-directory ACL contract is invalid."
  }
  return $exact
}

function ConvertTo-RisePalsBootstrapProcessArgument {
  param([string]$Value)

  if ($Value.Contains('"')) {
    throw "A bootstrap process argument contains a prohibited quote."
  }
  return '"' + $Value + '"'
}

$safeDirectory = $null
$failureCode = "bootstrap-validation-failed"
$bootstrapMarkerWritten = $false
$childLaunchAttemptedMarkerWritten = $false
$childExitCode = 92

try {
  if ($Mode -notin @("Simulation", "Live") -or
    $InvocationNonce -notmatch "^[a-f0-9]{32}$" -or
    $RepositoryHead -notmatch "^[a-f0-9]{40}$" -or
    $LauncherScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $BootstrapScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $TransportScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    $ChildScriptSha256 -notmatch "^[a-f0-9]{64}$" -or
    (($Mode -eq "Live") -and
      $AuthorizationId -notmatch "^RP-TURN-019-R4-LIVE-[A-F0-9]{8}$") -or
    (($Mode -eq "Simulation") -and
      $AuthorizationId -ne "RP-TURN-019-R4-DIAG1-SIMULATION")) {
    throw "The primitive bootstrap arguments are invalid."
  }
  $approvedRepository = "C:\Codex PC SG2\Jeff\risepals"
  $exactRepository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd(
    [IO.Path]::DirectorySeparatorChar
  )
  if (-not $exactRepository.Equals(
    $approvedRepository,
    [StringComparison]::OrdinalIgnoreCase
  )) {
    throw "The bootstrap repository root is not exact."
  }
  $safeDirectory = Assert-RisePalsBootstrapDirectory -Path $InvocationDirectory `
    -Root $ResultRoot

  $pins = @(
    @{ Path = $LauncherScriptPath; Hash = $LauncherScriptSha256 },
    @{ Path = $PSCommandPath; Hash = $BootstrapScriptSha256 },
    @{ Path = $TransportScriptPath; Hash = $TransportScriptSha256 },
    @{ Path = $ChildScriptPath; Hash = $ChildScriptSha256 }
  )
  foreach ($pin in $pins) {
    $exactPath = [IO.Path]::GetFullPath([string]$pin.Path)
    if (-not $exactPath.StartsWith(
      $exactRepository + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase
    ) -or -not [IO.File]::Exists($exactPath) -or
      (Get-RisePalsBootstrapSha256 -LiteralPath $exactPath) -ne [string]$pin.Hash) {
      throw "A committed bootstrap script pin is invalid."
    }
  }

  Write-RisePalsBootstrapMarkerAtomic -Marker (
    New-RisePalsBootstrapMarker -MarkerType "bootstrap-started" -FailureCode $null
  ) -Directory $safeDirectory
  $bootstrapMarkerWritten = $true

  $failureCode = "committed-child-launch-not-attempted"
  $powerShell = if ($Mode -eq "Simulation" -and
    $SimulationScenario -eq "ChildProcessLaunchFailure") {
    Join-Path $safeDirectory "absent-powershell.exe"
  } else {
    Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
  }
  $childRepositoryHead = if ($Mode -eq "Simulation" -and
    $SimulationScenario -eq "ChildExitsBeforeStartMarker") {
    "invalid"
  } else {
    $RepositoryHead
  }
  $arguments = @(
    "-NoLogo",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (ConvertTo-RisePalsBootstrapProcessArgument -Value $ChildScriptPath),
    "-Mode",
    $Mode,
    "-SimulationScenario",
    $SimulationScenario,
    "-RepositoryHead",
    $childRepositoryHead,
    "-AuthorizationId",
    $AuthorizationId,
    "-LauncherScriptSha256",
    $LauncherScriptSha256,
    "-BootstrapScriptSha256",
    $BootstrapScriptSha256,
    "-TransportScriptSha256",
    $TransportScriptSha256,
    "-ChildScriptSha256",
    $ChildScriptSha256,
    "-InvocationNonce",
    $InvocationNonce,
    "-ResultRoot",
    (ConvertTo-RisePalsBootstrapProcessArgument -Value $ResultRoot),
    "-InvocationDirectory",
    (ConvertTo-RisePalsBootstrapProcessArgument -Value $safeDirectory),
    "-FutureAuthorizationId",
    (ConvertTo-RisePalsBootstrapProcessArgument -Value $FutureAuthorizationId),
    "-CandidateExecutableSource",
    (ConvertTo-RisePalsBootstrapProcessArgument -Value $CandidateExecutableSource),
    "-NodeExecutableSource",
    (ConvertTo-RisePalsBootstrapProcessArgument -Value $NodeExecutableSource)
  )
  Write-RisePalsBootstrapMarkerAtomic -Marker (
    New-RisePalsBootstrapMarker -MarkerType "child-launch-attempted" -FailureCode $null
  ) -Directory $safeDirectory
  $childLaunchAttemptedMarkerWritten = $true
  $failureCode = "committed-child-invocation-failed"
  $process = Start-Process -FilePath $powerShell -ArgumentList $arguments `
    -WindowStyle Hidden -Wait -PassThru
  $childExitCode = [int]$process.ExitCode
  if (-not [IO.File]::Exists((Join-Path $safeDirectory "result.json"))) {
    $failureCode = if ([IO.File]::Exists((Join-Path $safeDirectory "live-started.json"))) {
      "live-child-exited-without-final"
    } else {
      "committed-child-exited-before-live"
    }
    throw "The committed child exited without a final marker."
  }
} catch {
  if ($null -ne $safeDirectory -and
    -not [IO.File]::Exists((Join-Path $safeDirectory "bootstrap-failure.json"))) {
    try {
      Write-RisePalsBootstrapMarkerAtomic -Marker (
        New-RisePalsBootstrapMarker -MarkerType "bootstrap-failure" `
          -FailureCode $failureCode
      ) -Directory $safeDirectory
    } catch {
      # The parent classifies missing or malformed bootstrap evidence fail-closed.
    }
  }
  $childExitCode = 92
} finally {
  if ($bootstrapMarkerWritten -and -not $childLaunchAttemptedMarkerWritten -and
    $null -ne $safeDirectory -and
    -not [IO.File]::Exists((Join-Path $safeDirectory "bootstrap-failure.json"))) {
    try {
      Write-RisePalsBootstrapMarkerAtomic -Marker (
        New-RisePalsBootstrapMarker -MarkerType "bootstrap-failure" `
          -FailureCode "bootstrap-finalization-failed"
      ) -Directory $safeDirectory
    } catch {
      # The parent still observes bootstrap-started and fails closed.
    }
  }
}

exit $childExitCode
