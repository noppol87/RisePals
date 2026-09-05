Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RisePalsCandidateContractSchema = "rise-pals-candidate-rehearsal-contract-v1"
$script:RisePalsCandidateServiceName = "RisePalsServiceHostCandidate"
$script:RisePalsCandidateAccount = "NT SERVICE\RisePalsServiceHostCandidate"
$script:RisePalsCandidateRetainedServices = @("RisePalsApp", "RisePalsProxy")
$script:RisePalsCandidateRoot = "C:\RisePals"
$script:RisePalsCandidateNodeSource = "C:\RisePals\tools\node\24.18.1\node.exe"

function Get-RisePalsCandidateRepositoryRoot {
  return [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
}

function Get-RisePalsCandidateContract {
  param([string]$RepositoryRoot = (Get-RisePalsCandidateRepositoryRoot))

  $repository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd(
    [IO.Path]::DirectorySeparatorChar
  )
  $contractPath = Join-Path $repository (
    "infra\windows-service-host\candidate-rehearsal-contract.json"
  )
  if (-not [IO.File]::Exists($contractPath)) {
    throw "The candidate rehearsal contract is absent."
  }
  $bytes = [IO.File]::ReadAllBytes($contractPath)
  $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
  $contract = $text | ConvertFrom-Json
  Assert-RisePalsCandidateContract -Contract $contract -RepositoryRoot $repository
  return $contract
}

function Get-RisePalsSha256 {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)

  $stream = [IO.File]::OpenRead([IO.Path]::GetFullPath($LiteralPath))
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = $algorithm.ComputeHash($stream)
    return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
    $stream.Dispose()
  }
}

function Get-RisePalsServiceSid {
  param([Parameter(Mandatory = $true)][string]$ServiceName)

  if ($ServiceName -notmatch "^[A-Za-z][A-Za-z0-9]{2,79}$") {
    throw "The candidate service name is invalid."
  }
  $bytes = [Text.Encoding]::Unicode.GetBytes($ServiceName.ToUpperInvariant())
  $algorithm = [Security.Cryptography.SHA1]::Create()
  try {
    $hash = $algorithm.ComputeHash($bytes)
  } finally {
    $algorithm.Dispose()
  }
  $subAuthorities = @()
  for ($index = 0; $index -lt 5; $index++) {
    $subAuthorities += [BitConverter]::ToUInt32($hash, $index * 4)
  }
  return "S-1-5-80-" + ($subAuthorities -join "-")
}

function Assert-RisePalsCandidateFilePin {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][int64]$ExpectedLength,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$ExpectedSha256,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $exact = [IO.Path]::GetFullPath($Path)
  if (-not [IO.File]::Exists($exact)) {
    throw "$Label is absent."
  }
  $item = Get-Item -LiteralPath $exact -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "$Label must not be a reparse point."
  }
  if ($item.Length -ne $ExpectedLength -or
    (Get-RisePalsSha256 -LiteralPath $exact) -ne $ExpectedSha256) {
    throw "$Label does not match the exact accepted pin."
  }
  return $exact
}

function Assert-RisePalsCandidateNodeMetadata {
  param(
    [Parameter(Mandatory = $true)][object]$Metadata,
    [Parameter(Mandatory = $true)][object]$Contract,
    [switch]$RequireSourcePath
  )

  if (($RequireSourcePath -and -not ([string]$Metadata.path).Equals(
      [string]$Contract.sourcePath,
      [StringComparison]::OrdinalIgnoreCase
    )) -or
    [string]$Metadata.version -cne [string]$Contract.version -or
    [int64]$Metadata.executableLength -ne [int64]$Contract.executableLength -or
    [string]$Metadata.executableSha256 -cne [string]$Contract.executableSha256 -or
    [string]$Metadata.authenticode -cne [string]$Contract.authenticode -or
    [string]$Metadata.signerSubject -cne [string]$Contract.signerSubject -or
    [string]$Metadata.signerThumbprint -cne [string]$Contract.signerThumbprint) {
    throw "Node executable metadata does not match the exact accepted pin."
  }
}

function Assert-RisePalsCandidatePreshutdownRegistration {
  param(
    [Parameter(Mandatory = $true)][object]$Registration,
    [Parameter(Mandatory = $true)][object]$Contract
  )

  if ([uint32]$Registration.TimeoutMilliseconds -ne
      [uint32]$Contract.timing.preshutdownTimeoutMilliseconds -or
    -not [bool]$Registration.AcceptsPreshutdown) {
    throw "The running candidate did not advertise the exact Preshutdown registration."
  }
}

function Assert-RisePalsCandidateRetainedSnapshot {
  param(
    [Parameter(Mandatory = $true)][object[]]$Snapshot,
    [Parameter(Mandatory = $true)][object]$Contract
  )

  $expectedServices = @($Contract.retainedServices)
  if (@($Snapshot).Count -ne $expectedServices.Count -or $expectedServices.Count -ne 2) {
    throw "The retained-service inventory is missing or contains an additional service."
  }
  $activePids = @($Snapshot | Where-Object { [int]$_.processId -ne 0 } |
    ForEach-Object { [int]$_.processId })
  if (@($activePids | Sort-Object -Unique).Count -ne $activePids.Count) {
    throw "Retained services share a process identifier."
  }
  foreach ($expected in $expectedServices) {
    $actual = @($Snapshot | Where-Object { $_.name -ceq $expected.serviceName })
    if ($actual.Count -ne 1 -or
      [string]$actual[0].serviceType -cne [string]$expected.serviceType -or
      [string]$actual[0].startName -cne [string]$expected.virtualAccount -or
      [string]$actual[0].pathName -cne [string]$expected.pathName -or
      [string]$actual[0].executablePath -cne [string]$expected.executablePath -or
      [int64]$actual[0].executableLength -ne [int64]$expected.executableLength -or
      [string]$actual[0].executableSha256 -cne [string]$expected.executableSha256 -or
      [string]$actual[0].state -cne [string]$expected.expectedState -or
      [string]$actual[0].startMode -cne [string]$expected.expectedStartMode -or
      [int]$actual[0].processId -ne [int]$expected.expectedProcessId) {
      throw "A retained service differs from its exact accepted definition or state."
    }
  }
}

function Assert-RisePalsCandidateRetainedSnapshotEquality {
  param(
    [Parameter(Mandatory = $true)][object[]]$Before,
    [Parameter(Mandatory = $true)][object[]]$After
  )

  $beforeJson = @($Before | Sort-Object name) | ConvertTo-Json -Depth 4 -Compress
  $afterJson = @($After | Sort-Object name) | ConvertTo-Json -Depth 4 -Compress
  if ($beforeJson -cne $afterJson) {
    throw "The complete retained-service snapshot changed."
  }
}

function Assert-RisePalsCandidateContract {
  param(
    [Parameter(Mandatory = $true)][object]$Contract,
    [Parameter(Mandatory = $true)][string]$RepositoryRoot
  )

  if ($Contract.schemaVersion -ne $script:RisePalsCandidateContractSchema -or
    $Contract.candidate.serviceName -ne $script:RisePalsCandidateServiceName -or
    $Contract.candidate.virtualAccount -ne $script:RisePalsCandidateAccount -or
    $Contract.candidate.serviceType -ne "SERVICE_WIN32_OWN_PROCESS" -or
    $Contract.candidate.startMode -ne "demand") {
    throw "The candidate service identity contract is invalid."
  }
  if (@($Contract.candidate.retainedServices).Count -ne 2 -or
    @($Contract.candidate.retainedServices | Where-Object {
      $_ -notin $script:RisePalsCandidateRetainedServices
    }).Count -ne 0 -or
    $Contract.candidate.serviceName -in $Contract.candidate.retainedServices) {
    throw "Candidate and retained service identities collide."
  }
  $derivedSid = Get-RisePalsServiceSid -ServiceName $Contract.candidate.serviceName
  if ($derivedSid -ne $Contract.candidate.serviceSid) {
    throw "The candidate virtual-account SID derivation is invalid."
  }
  if ($Contract.prototype.executableLength -ne 73606961 -or
    $Contract.prototype.executableSha256 -ne
      "f353a61f5a91751602dc37f7dbe6b0dbad9ab4ce5a59f84d8a3ff1cfd70a27bb" -or
    $Contract.prototype.authenticode -ne "NotSigned") {
    throw "The accepted unsigned prototype pin changed."
  }
  $artifactIdentity = $Contract.prototype.artifactIdentity
  if ($artifactIdentity.version -cne "0.1.0-rp19-prototype" -or
    $artifactIdentity.assemblyVersion -cne "0.1.0.0" -or
    $artifactIdentity.fileVersion -cne "0.1.0.0" -or
    $artifactIdentity.informationalVersion -cne "0.1.0-rp19-prototype" -or
    [bool]$artifactIdentity.includeSourceRevisionInInformationalVersion -or
    $artifactIdentity.serviceHostProductionSourceTree -cne
      "775a10c75fb70aa121350707ee1240c9d1739fa2" -or
    -not [bool]$artifactIdentity.volatileOuterRepositoryCommitMetadataExcluded) {
    throw "The context-independent service-host artifact identity policy changed."
  }
  if ($Contract.node.version -cne "v24.18.1" -or
    $Contract.node.sourcePath -cne $script:RisePalsCandidateNodeSource -or
    [int64]$Contract.node.executableLength -ne 92540232 -or
    $Contract.node.executableSha256 -cne
      "ac51903c4c111815d52280b1fdcc8da067cbb37e2fe1a765097b85c3292c8582" -or
    $Contract.node.authenticode -cne "Valid" -or
    $Contract.node.signerSubject -cne
      "CN=OpenJS Foundation, O=OpenJS Foundation, L=San Francisco, S=California, C=US" -or
    $Contract.node.signerThumbprint -cne "285AE8801AFDD52B8F7B9B6436B50052911AF7C2") {
    throw "The accepted Node executable metadata pin changed."
  }
  $retainedDefinitions = @($Contract.retainedServices)
  if ($retainedDefinitions.Count -ne 2) {
    throw "The exact retained-service definition count changed."
  }
  $app = @($retainedDefinitions | Where-Object { $_.serviceName -ceq "RisePalsApp" })
  $proxy = @($retainedDefinitions | Where-Object { $_.serviceName -ceq "RisePalsProxy" })
  if ($app.Count -ne 1 -or $proxy.Count -ne 1 -or
    $app[0].serviceType -cne "Own Process" -or
    $app[0].virtualAccount -cne "NT SERVICE\RisePalsApp" -or
    $app[0].pathName -cne '"C:\RisePals\tools\winsw\2.12.0\RisePalsApp.exe"' -or
    $app[0].executablePath -cne "C:\RisePals\tools\winsw\2.12.0\RisePalsApp.exe" -or
    [int64]$app[0].executableLength -ne 18243033 -or
    $app[0].executableSha256 -cne
      "05b82d46ad331cc16bdc00de5c6332c1ef818df8ceefcd49c726553209b3a0da" -or
    $proxy[0].serviceType -cne "Own Process" -or
    $proxy[0].virtualAccount -cne "NT SERVICE\RisePalsProxy" -or
    $proxy[0].pathName -cne
      "C:\RisePals\tools\caddy\2.11.4\caddy.exe run --config C:\RisePals\shared\config\Caddyfile --adapter caddyfile" -or
    $proxy[0].executablePath -cne "C:\RisePals\tools\caddy\2.11.4\caddy.exe" -or
    [int64]$proxy[0].executableLength -ne 49535488 -or
    $proxy[0].executableSha256 -cne
      "5cb9ab71e5756ce72840b8234177a2f40c8b4ab47a806b8e841e2b784e9df62b" -or
    @($retainedDefinitions | Where-Object {
      $_.expectedState -cne "Stopped" -or $_.expectedStartMode -cne "Disabled" -or
        [int]$_.expectedProcessId -ne 0
    }).Count -ne 0) {
    throw "An exact retained-service definition pin changed."
  }

  $schemaPath = Join-Path $RepositoryRoot $Contract.prototype.schemaRelativePath
  [void](Assert-RisePalsCandidateFilePin -Path $schemaPath `
    -ExpectedLength ([int64]$Contract.prototype.schemaLength) `
    -ExpectedSha256 ([string]$Contract.prototype.schemaSha256) `
    -Label "Service-host configuration schema")
  $manifestPath = Join-Path $RepositoryRoot $Contract.prototype.dependencyManifestRelativePath
  [void](Assert-RisePalsCandidateFilePin -Path $manifestPath `
    -ExpectedLength ([int64]$Contract.prototype.dependencyManifestLength) `
    -ExpectedSha256 ([string]$Contract.prototype.dependencyManifestSha256) `
    -Label "Service-host dependency manifest")

  if ($Contract.paths.root -ne $script:RisePalsCandidateRoot -or
    $Contract.network.address -ne "127.0.0.1" -or
    [bool]$Contract.network.publicListenersAllowed) {
    throw "The candidate root or loopback-only network boundary changed."
  }
  $completeStopMilliseconds = 1000 * (
    [int]$Contract.timing.drainTimeoutSeconds + [int]$Contract.timing.exitTimeoutSeconds
  )
  if ([int]$Contract.timing.preshutdownTimeoutMilliseconds -le $completeStopMilliseconds -or
    [int]$Contract.timing.preshutdownMarginMilliseconds -ne
      ([int]$Contract.timing.preshutdownTimeoutMilliseconds - $completeStopMilliseconds)) {
    throw "The Preshutdown timeout must retain a documented margin above drain plus exit."
  }
  if (@($Contract.aclPlan).Count -ne 4) {
    throw "The candidate ACL plan must contain exactly four path classes."
  }
  foreach ($acl in $Contract.aclPlan) {
    $principals = @($acl.rights.PSObject.Properties.Name | Sort-Object)
    $expectedPrincipals = @(
      "BUILTIN\Administrators",
      "NT SERVICE\RisePalsServiceHostCandidate",
      "SYSTEM"
    ) | Sort-Object
    if (@(Compare-Object -ReferenceObject $expectedPrincipals `
      -DifferenceObject $principals).Count -ne 0) {
      throw "An ACL path class contains an unexpected principal."
    }
    $candidateRights = [string]$acl.rights.($script:RisePalsCandidateAccount)
    if (($acl.pathKind -eq "mutable-log" -and $candidateRights -ne "Modify") -or
      ($acl.pathKind -ne "mutable-log" -and $candidateRights -ne "ReadAndExecute")) {
      throw "The candidate ACL rights are outside the exact least-privilege plan."
    }
  }
  if (-not [bool]$Contract.authorization.repositoryOnly -or
    [bool]$Contract.authorization.liveExecutionAuthorized -or
    [bool]$Contract.authorization.productionApproved) {
    throw "The repository-only authorization boundary changed."
  }
}

function Expand-RisePalsCandidateTaskPath {
  param(
    [Parameter(Mandatory = $true)][string]$Template,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$Nonce
  )

  $expanded = $Template.Replace("{nonce}", $Nonce)
  if ($expanded.Contains("{") -or $expanded.Contains("}")) {
    throw "A candidate task path contains an unresolved placeholder."
  }
  return [IO.Path]::GetFullPath($expanded)
}

function Assert-RisePalsCandidateAuthorizedPath {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string[]]$ApprovedRoots
  )

  $exactPath = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  foreach ($root in $ApprovedRoots) {
    $exactRoot = [IO.Path]::GetFullPath($root).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $prefix = $exactRoot + [IO.Path]::DirectorySeparatorChar
    if ($exactPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
      return $exactPath
    }
  }
  throw "A candidate path is outside every exact authorized root."
}

function New-RisePalsCandidatePathPlan {
  param(
    [Parameter(Mandatory = $true)][object]$Contract,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$Nonce
  )

  $templates = [ordered]@{
    stagedHost = $Contract.paths.stagedHostTemplate
    stagedRuntime = $Contract.paths.stagedRuntimeTemplate
    stagedReleaseRoot = $Contract.paths.stagedReleaseRootTemplate
    stagedRelease = $Contract.paths.stagedReleaseTemplate
    configDirectory = $Contract.paths.configDirectoryTemplate
    configPath = $Contract.paths.configPathTemplate
    evidenceDirectory = $Contract.paths.structuredEvidenceDirectoryTemplate
    logDirectory = $Contract.paths.logDirectoryTemplate
  }
  $approvedRoots = @(
    [string]$Contract.paths.stagingRoot,
    [string]$Contract.paths.rehearsalRoot,
    [string]$Contract.paths.logRoot
  )
  $plan = [ordered]@{}
  foreach ($entry in $templates.GetEnumerator()) {
    $expanded = Expand-RisePalsCandidateTaskPath -Template ([string]$entry.Value) -Nonce $Nonce
    $plan[$entry.Key] = Assert-RisePalsCandidateAuthorizedPath -Path $expanded `
      -ApprovedRoots $approvedRoots
  }
  return [pscustomobject]$plan
}

function New-RisePalsCandidateInstallationPlan {
  param(
    [Parameter(Mandatory = $true)][object]$Contract,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$Nonce,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$LauncherScriptSha256
  )

  $paths = New-RisePalsCandidatePathPlan -Contract $Contract -Nonce $Nonce
  return [pscustomobject][ordered]@{
    schemaVersion = "rise-pals-candidate-installation-plan-v1"
    repositoryHead = $RepositoryHead
    launcherScriptSha256 = $LauncherScriptSha256
    invocationNonce = $Nonce
    serviceName = [string]$Contract.candidate.serviceName
    virtualAccount = [string]$Contract.candidate.virtualAccount
    serviceType = [string]$Contract.candidate.serviceType
    startMode = [string]$Contract.candidate.startMode
    paths = $paths
    aclPlan = @($Contract.aclPlan)
    preshutdownTimeoutMilliseconds = [int]$Contract.timing.preshutdownTimeoutMilliseconds
    rehearsalStages = @($Contract.rehearsalStages)
    cleanup = $Contract.cleanup
    liveExecutionAuthorized = $false
  }
}

function Assert-RisePalsCandidateRepositorySnapshot {
  param(
    [Parameter(Mandatory = $true)][object]$Snapshot,
    [Parameter(Mandatory = $true)][object]$Contract,
    [Parameter(Mandatory = $true)][string]$ExpectedHead
  )

  if ($Snapshot.branch -ne $Contract.repository.branch -or
    $Snapshot.head -ne $ExpectedHead -or
    $Snapshot.mainHead -ne $Contract.repository.mainCommit -or
    -not [bool]$Snapshot.clean -or
    -not [bool]$Snapshot.envLocalIgnored -or
    [bool]$Snapshot.envLocalTracked) {
    throw "The exact clean repository preflight failed."
  }
}

function Assert-RisePalsCandidateHostSnapshot {
  param(
    [Parameter(Mandatory = $true)][object]$Snapshot,
    [Parameter(Mandatory = $true)][object]$Contract
  )

  if ([bool]$Snapshot.candidateServiceExists) {
    throw "The candidate service name already exists."
  }
  if (@($Snapshot.unexpectedRisePalsServices).Count -ne 0) {
    throw "An unexpected Rise Pals service exists."
  }
  Assert-RisePalsCandidateRetainedSnapshot -Snapshot @($Snapshot.retainedServices) `
    -Contract $Contract
  if (@($Snapshot.relevantListeners).Count -ne 0 -or
    @($Snapshot.processesUnderRoot).Count -ne 0 -or
    @($Snapshot.unexpectedPaths).Count -ne 0 -or
    @($Snapshot.reparsePaths).Count -ne 0 -or
    @($Snapshot.unexpectedAclEntries).Count -ne 0) {
    throw "Unexpected listener, process, path, reparse point or ACL state exists."
  }
  if ([int64]$Snapshot.candidateExecutableLength -ne
      [int64]$Contract.prototype.executableLength -or
    [string]$Snapshot.candidateExecutableSha256 -ne
      [string]$Contract.prototype.executableSha256 -or
    [string]$Snapshot.candidateAuthenticode -ne "NotSigned") {
    throw "The candidate executable is not the exact accepted unsigned prototype."
  }
}

function Assert-RisePalsCandidateCleanupSnapshot {
  param(
    [Parameter(Mandatory = $true)][object]$Snapshot,
    [Parameter(Mandatory = $true)][object]$PathPlan
  )

  if ($Snapshot.serviceState -ne "Stopped" -or $Snapshot.startMode -ne "Disabled" -or
    [int]$Snapshot.processId -ne 0 -or [int]$Snapshot.ownedJobProcessCount -ne 0) {
    throw "Candidate cleanup cannot proceed before Stopped/Disabled/PID 0 and an empty Job."
  }
  if (@($Snapshot.reparsePaths).Count -ne 0 -or
    @($Snapshot.uncertainPaths).Count -ne 0 -or
    @($Snapshot.nonemptyUnexpectedPaths).Count -ne 0) {
    throw "Candidate cleanup found an uncertain, reparse or unexpectedly nonempty path."
  }
  $allowed = @(
    [string]$PathPlan.stagedHost,
    [string]$PathPlan.stagedRuntime,
    [string]$PathPlan.stagedReleaseRoot,
    [string]$PathPlan.stagedRelease,
    [string]$PathPlan.configDirectory,
    [string]$PathPlan.configPath,
    [string]$PathPlan.evidenceDirectory,
    [string]$PathPlan.logDirectory
  )
  foreach ($path in @($Snapshot.cleanupTargets)) {
    $exact = [IO.Path]::GetFullPath([string]$path)
    $contained = $false
    foreach ($candidate in $allowed) {
      $candidateExact = [IO.Path]::GetFullPath($candidate).TrimEnd(
        [IO.Path]::DirectorySeparatorChar
      )
      if ($exact.Equals($candidateExact, [StringComparison]::OrdinalIgnoreCase) -or
        $exact.StartsWith(
          $candidateExact + [IO.Path]::DirectorySeparatorChar,
          [StringComparison]::OrdinalIgnoreCase
        )) {
        $contained = $true
        break
      }
    }
    if (-not $contained) {
      throw "Candidate cleanup target escapes the exact task plan."
    }
  }
}

function Assert-RisePalsCandidateTaskTreeInventory {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string[]]$AllowedRelativePaths
  )

  $root = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  if (-not [IO.Directory]::Exists($root)) {
    return
  }
  $rootItem = Get-Item -LiteralPath $root -Force
  if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "A candidate cleanup root is a reparse point."
  }

  $allowed = @{}
  foreach ($relativePath in $AllowedRelativePaths) {
    if ([string]::IsNullOrWhiteSpace($relativePath) -or
      [IO.Path]::IsPathRooted($relativePath)) {
      throw "A candidate cleanup inventory entry is not a relative path."
    }
    $resolved = [IO.Path]::GetFullPath((Join-Path $root $relativePath))
    if (-not $resolved.StartsWith(
      $root + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase
    )) {
      throw "A candidate cleanup inventory entry escapes its exact root."
    }
    $normalized = $resolved.Substring($root.Length + 1)
    if ($allowed.ContainsKey($normalized)) {
      throw "A candidate cleanup inventory entry is duplicated."
    }
    $allowed[$normalized] = $true
  }

  $pendingDirectories = [Collections.Generic.Stack[string]]::new()
  $pendingDirectories.Push($root)
  while ($pendingDirectories.Count -gt 0) {
    $directory = $pendingDirectories.Pop()
    foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force)) {
      $resolvedItem = [IO.Path]::GetFullPath($item.FullName)
      if (-not $resolvedItem.StartsWith(
        $root + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
      ) -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "A candidate cleanup child is outside the exact non-reparse tree."
      }
      $relative = $resolvedItem.Substring($root.Length + 1)
      if (-not $allowed.ContainsKey($relative)) {
        throw "A candidate cleanup tree contains an unexpected child."
      }
      if ($item.PSIsContainer) {
        $pendingDirectories.Push($resolvedItem)
      }
    }
  }
}

function Get-RisePalsCandidateFailureCodeForStage {
  param(
    [Parameter(Mandatory = $true)][object]$Contract,
    [Parameter(Mandatory = $true)][string]$Stage
  )

  $stages = @($Contract.rehearsalStages)
  $codes = @($Contract.sanitizedFailureCodes)
  $index = [Array]::IndexOf($stages, $Stage)
  if ($index -lt 0 -or $index -ge $codes.Count) {
    throw "The candidate failure stage is not modeled."
  }
  return [string]$codes[$index]
}
