[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
  [string]$Root = "C:\RisePals",
  [string]$RepositoryRoot = "",
  [ValidatePattern("^$|^[a-f0-9]{40}$")][string]$ReleaseSourceCommit = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

function Get-RisePalsCurrentReleaseId {
  param([Parameter(Mandatory = $true)][string]$ValidatedRoot)

  $current = Join-Path $ValidatedRoot "current"
  if (-not (Test-Path -LiteralPath $current -PathType Container)) {
    return ""
  }
  $item = Get-Item -LiteralPath $current -Force
  if ($item.LinkType -ne "Junction") {
    throw "The current release boundary is not an NTFS junction."
  }
  $releases = Join-Path $ValidatedRoot "releases"
  $target = [IO.Path]::GetFullPath([string]$item.Target)
  [void](Get-RisePalsValidatedChildPath -Root $releases -Path $target)
  return (Split-Path -Leaf $target)
}

function Get-RisePalsRootProcesses {
  param([Parameter(Mandatory = $true)][string]$ValidatedRoot)

  return @(Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and
      $_.ExecutablePath.StartsWith($ValidatedRoot, [StringComparison]::OrdinalIgnoreCase)
  })
}

function Get-RisePalsNodeProcess {
  param([Parameter(Mandatory = $true)][string]$ValidatedRoot)

  $node = Join-Path $ValidatedRoot "tools\node\24.18.1\node.exe"
  return @(Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath.Equals($node, [StringComparison]::OrdinalIgnoreCase)
  })
}

function Wait-RisePalsReady {
  param(
    [Parameter(Mandatory = $true)][bool]$ExpectedReady,
    [int]$TimeoutSeconds = 30
  )

  $expectedCode = if ($ExpectedReady) { "200" } else { "503" }
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    $code = & curl.exe --silent --output NUL --write-out "%{http_code}" `
      "http://127.0.0.1:3100/health/ready"
    if ($LASTEXITCODE -eq 0 -and $code -eq $expectedCode) {
      return
    }
    Start-Sleep -Milliseconds 250
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "Loopback readiness did not reach the expected bounded state."
}

function Wait-RisePalsReplacementNode {
  param(
    [Parameter(Mandatory = $true)][string]$ValidatedRoot,
    [Parameter(Mandatory = $true)][uint32]$PreviousProcessId,
    [int]$TimeoutSeconds = 35
  )

  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    $nodes = @(Get-RisePalsNodeProcess -ValidatedRoot $ValidatedRoot)
    $service = Get-CimInstance Win32_Service -Filter "Name='RisePalsApp'"
    $replacement = @($nodes | Where-Object { $_.ProcessId -ne $PreviousProcessId })
    if ($service.State -eq "Running" -and $replacement.Count -eq 1) {
      Wait-RisePalsReady -ExpectedReady $true
      return [uint32]$replacement[0].ProcessId
    }
    Start-Sleep -Milliseconds 500
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "The bounded application crash restart did not recover exactly one Node process."
}

function Assert-RisePalsExactAclPrincipals {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string[]]$ExpectedPrincipals
  )

  $acl = Get-Acl -LiteralPath $Path
  if (-not $acl.AreAccessRulesProtected) {
    throw "A protected Rise Pals ACL was expected."
  }
  $actual = @($acl.Access | ForEach-Object { $_.IdentityReference.Value } | Sort-Object -Unique)
  $expected = @($ExpectedPrincipals | Sort-Object -Unique)
  if (($actual -join "|") -ne ($expected -join "|")) {
    throw "The exact Rise Pals ACL principal set does not match the approved model."
  }
}

function Assert-RisePalsAclModel {
  param(
    [Parameter(Mandatory = $true)][string]$ValidatedRoot,
    [Parameter(Mandatory = $true)][string]$ReleaseId,
    [Parameter(Mandatory = $true)][string]$Repository
  )

  $systemAdmin = @("BUILTIN\Administrators", "NT AUTHORITY\SYSTEM")
  Assert-RisePalsExactAclPrincipals -Path (Join-Path $ValidatedRoot "releases\$ReleaseId") `
    -ExpectedPrincipals ($systemAdmin + "NT SERVICE\RisePalsApp")
  Assert-RisePalsExactAclPrincipals -Path (Join-Path $ValidatedRoot "shared\config") `
    -ExpectedPrincipals ($systemAdmin + @("NT SERVICE\RisePalsApp", "NT SERVICE\RisePalsProxy"))
  Assert-RisePalsExactAclPrincipals -Path (Join-Path $ValidatedRoot "shared\secrets\rehearsal.canary") `
    -ExpectedPrincipals ($systemAdmin + "NT SERVICE\RisePalsApp")
  Assert-RisePalsExactAclPrincipals -Path (Join-Path $ValidatedRoot "shared\secrets") `
    -ExpectedPrincipals ($systemAdmin + "NT SERVICE\RisePalsApp")
  $secretDirectoryAcl = Get-Acl -LiteralPath (Join-Path $ValidatedRoot "shared\secrets")
  $secretTraverse = @($secretDirectoryAcl.Access | Where-Object {
    $_.IdentityReference.Value -eq "NT SERVICE\RisePalsApp"
  })
  if ($secretTraverse.Count -ne 1 -or
    (($secretTraverse[0].FileSystemRights -band [Security.AccessControl.FileSystemRights]::Traverse) -eq 0) -or
    $secretTraverse[0].InheritanceFlags -ne [Security.AccessControl.InheritanceFlags]::None) {
    throw "The application secret-directory rule is not exact non-inheriting Traverse."
  }
  Assert-RisePalsExactAclPrincipals -Path (Join-Path $ValidatedRoot "shared\cache\caddy") `
    -ExpectedPrincipals ($systemAdmin + "NT SERVICE\RisePalsProxy")
  Assert-RisePalsExactAclPrincipals -Path (Join-Path $ValidatedRoot "logs\app") `
    -ExpectedPrincipals ($systemAdmin + "NT SERVICE\RisePalsApp")
  Assert-RisePalsExactAclPrincipals -Path (Join-Path $ValidatedRoot "logs\proxy") `
    -ExpectedPrincipals ($systemAdmin + "NT SERVICE\RisePalsProxy")

  $releaseAcl = Get-Acl -LiteralPath (Join-Path $ValidatedRoot "releases\$ReleaseId")
  $applicationRule = @($releaseAcl.Access | Where-Object {
    $_.IdentityReference.Value -eq "NT SERVICE\RisePalsApp"
  })
  $writeMask = [Security.AccessControl.FileSystemRights]::WriteData -bor
    [Security.AccessControl.FileSystemRights]::AppendData -bor
    [Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
    [Security.AccessControl.FileSystemRights]::WriteAttributes -bor
    [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
    [Security.AccessControl.FileSystemRights]::Delete -bor
    [Security.AccessControl.FileSystemRights]::ChangePermissions -bor
    [Security.AccessControl.FileSystemRights]::TakeOwnership
  if ($applicationRule.Count -ne 1 -or (($applicationRule[0].FileSystemRights -band $writeMask) -ne 0)) {
    throw "The application identity can modify an immutable release."
  }

  $repositoryAcl = Get-Acl -LiteralPath $Repository
  $runtimeRules = @($repositoryAcl.Access | Where-Object {
    $_.IdentityReference.Value -in @("NT SERVICE\RisePalsApp", "NT SERVICE\RisePalsProxy")
  })
  if ($runtimeRules.Count -ne 0) {
    throw "A Rise Pals runtime identity has an explicit Git-workspace ACL."
  }
}

function Test-RisePalsByteSequence {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Haystack,
    [Parameter(Mandatory = $true)][byte[]]$Needle
  )

  if ($Needle.Length -eq 0 -or $Haystack.Length -lt $Needle.Length) {
    return $false
  }
  for ($offset = 0; $offset -le $Haystack.Length - $Needle.Length; $offset++) {
    $matched = $true
    for ($index = 0; $index -lt $Needle.Length; $index++) {
      if ($Haystack[$offset + $index] -ne $Needle[$index]) {
        $matched = $false
        break
      }
    }
    if ($matched) {
      return $true
    }
  }
  return $false
}

function Assert-RisePalsCanaryNotExposed {
  param(
    [Parameter(Mandatory = $true)][string]$ValidatedRoot,
    [Parameter(Mandatory = $true)][string]$Repository
  )

  $secretPath = Join-Path $ValidatedRoot "shared\secrets\rehearsal.canary"
  $secretBytes = [IO.File]::ReadAllBytes($secretPath)
  if ($secretBytes.Length -ne 64) {
    throw "The synthetic canary length is not exact."
  }
  $base64 = [Convert]::ToBase64String($secretBytes)
  $hex = (($secretBytes | ForEach-Object { $_.ToString("x2") }) -join "")
  $textNeedles = @($base64, $hex)
  $files = [Collections.Generic.List[string]]::new()
  $git = "C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
  $tracked = @(& $git -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $Repository ls-files)
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to inventory tracked files for the canary scan."
  }
  foreach ($relative in $tracked) {
    [void]$files.Add((Join-Path $Repository $relative))
  }
  foreach ($relative in @("logs\app", "logs\proxy", "logs\deploy")) {
    Get-ChildItem -LiteralPath (Join-Path $ValidatedRoot $relative) -File -Recurse | ForEach-Object {
      [void]$files.Add($_.FullName)
    }
  }
  foreach ($path in $files) {
    $bytes = [IO.File]::ReadAllBytes($path)
    if (Test-RisePalsByteSequence -Haystack $bytes -Needle $secretBytes) {
      throw "The synthetic canary was found in a prohibited file boundary."
    }
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    foreach ($needle in $textNeedles) {
      if ($text.Contains($needle)) {
        throw "An encoded synthetic canary was found in a prohibited file boundary."
      }
    }
  }
  $commands = @(
    Get-CimInstance Win32_Process | ForEach-Object { [string]$_.CommandLine }
    Get-CimInstance Win32_Service -Filter "Name='RisePalsApp' OR Name='RisePalsProxy'" |
      ForEach-Object { [string]$_.PathName }
  )
  foreach ($command in $commands) {
    foreach ($needle in $textNeedles) {
      if ($command.Contains($needle)) {
        throw "An encoded synthetic canary was found in process or service arguments."
      }
    }
  }
  [Array]::Clear($secretBytes, 0, $secretBytes.Length)
  $base64 = ""
  $hex = ""
}

function Invoke-RisePalsCertificateReissue {
  param([Parameter(Mandatory = $true)][string]$ValidatedRoot)

  $cache = Join-Path $ValidatedRoot "shared\cache\caddy"
  $certificates = Join-Path $cache "certificates"
  $before = @(Get-ChildItem -LiteralPath $certificates -Filter "*.crt" -File -Recurse)
  if ($before.Count -lt 1) {
    throw "The initial local rehearsal certificate is absent."
  }
  $beforeHash = (Get-FileHash -LiteralPath $before[0].FullName -Algorithm SHA256).Hash
  Stop-Service -Name "RisePalsProxy"
  (Get-Service -Name "RisePalsProxy").WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
  Remove-RisePalsValidatedChild -Root $ValidatedRoot -Path $certificates -Recurse
  Start-Service -Name "RisePalsProxy"
  (Get-Service -Name "RisePalsProxy").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
  & (Join-Path $PSScriptRoot "Test-RisePalsHealth.ps1") -Root $ValidatedRoot
  $after = @(Get-ChildItem -LiteralPath $certificates -Filter "*.crt" -File -Recurse)
  if ($after.Count -lt 1) {
    throw "The local rehearsal certificate was not reissued."
  }
  $afterHash = (Get-FileHash -LiteralPath $after[0].FullName -Algorithm SHA256).Hash
  if ($afterHash -eq $beforeHash) {
    throw "The local rehearsal certificate did not change after bounded reissue."
  }
}

function Invoke-RisePalsGracefulStopProbe {
  param([Parameter(Mandatory = $true)][string]$ValidatedRoot)

  $ca = Join-Path $ValidatedRoot "shared\cache\caddy\pki\authorities\local\root.crt"
  $output = Join-Path $ValidatedRoot "rehearsal\graceful-stream.out"
  $errorOutput = Join-Path $ValidatedRoot "rehearsal\graceful-stream.err"
  $process = Start-Process -FilePath "curl.exe" -ArgumentList @(
    "--silent", "--show-error", "--no-buffer", "--cacert", $ca,
    "https://127.0.0.1:8443/health/stream"
  ) -RedirectStandardOutput $output -RedirectStandardError $errorOutput -PassThru
  Start-Sleep -Milliseconds 200
  Stop-Service -Name "RisePalsApp"
  (Get-Service -Name "RisePalsApp").WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
  if (-not $process.WaitForExit(30000)) {
    Stop-Process -Id $process.Id -Force
    throw "The in-flight streaming request did not end within the graceful-stop bound."
  }
  $body = Get-Content -LiteralPath $output -Raw -Encoding UTF8
  if ($process.ExitCode -ne 0 -or $body -ne "probe-start`nprobe-mid`nprobe-end`n") {
    throw "The in-flight request did not complete during the configured graceful stop."
  }
  if (@(Get-RisePalsNodeProcess -ValidatedRoot $ValidatedRoot).Count -ne 0) {
    throw "Graceful stop left an orphan Node process."
  }
  Start-Service -Name "RisePalsApp"
  (Get-Service -Name "RisePalsApp").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
  Wait-RisePalsReady -ExpectedReady $true
}

function Invoke-RisePalsCrashRecoveryProbe {
  param([Parameter(Mandatory = $true)][string]$ValidatedRoot)

  $failureOutput = @(& sc.exe qfailure RisePalsApp)
  if ($LASTEXITCODE -ne 0 -or ($failureOutput -join "`n") -notmatch "5000" -or
    ($failureOutput -join "`n") -notmatch "15000") {
    throw "The application service bounded restart plan is unavailable."
  }
  $node = @(Get-RisePalsNodeProcess -ValidatedRoot $ValidatedRoot)
  if ($node.Count -ne 1) {
    throw "Exactly one application Node process was expected before crash recovery."
  }
  $first = [uint32]$node[0].ProcessId
  Stop-Process -Id $first -Force
  $second = Wait-RisePalsReplacementNode -ValidatedRoot $ValidatedRoot -PreviousProcessId $first
  Stop-Process -Id $second -Force
  $third = Wait-RisePalsReplacementNode -ValidatedRoot $ValidatedRoot -PreviousProcessId $second
  Stop-Process -Id $third -Force

  $deadline = [DateTime]::UtcNow.AddSeconds(35)
  do {
    $service = Get-CimInstance Win32_Service -Filter "Name='RisePalsApp'"
    $nodeCount = @(Get-RisePalsNodeProcess -ValidatedRoot $ValidatedRoot).Count
    if ($service.State -eq "Stopped" -and $nodeCount -eq 0) {
      break
    }
    Start-Sleep -Milliseconds 500
  } while ([DateTime]::UtcNow -lt $deadline)
  if ($service.State -ne "Stopped" -or $nodeCount -ne 0) {
    throw "The third application crash entered an unbounded restart path."
  }

  Start-Service -Name "RisePalsApp"
  (Get-Service -Name "RisePalsApp").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
  Wait-RisePalsReady -ExpectedReady $true
}

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$RepositoryRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
} else {
  $RepositoryRoot
}
$repository = [IO.Path]::GetFullPath($RepositoryRoot)
$git = "C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
$head = (& $git -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $repository rev-parse HEAD).Trim()
$branch = (& $git -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $repository branch --show-current).Trim()
$worktree = @(& $git -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $repository status --porcelain --untracked-files=all)
if ($LASTEXITCODE -ne 0 -or $head -notmatch "^[a-f0-9]{40}$" -or
  $branch -ne "agent/windows-vps-infrastructure-readiness" -or $worktree.Count -ne 0) {
  throw "The exact clean RP-TURN-019 feature branch is required."
}
$releaseSource = if ([string]::IsNullOrWhiteSpace($ReleaseSourceCommit)) {
  $head
} else {
  $ReleaseSourceCommit
}
& $git -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $repository `
  merge-base --is-ancestor $releaseSource $head
if ($LASTEXITCODE -ne 0) {
  throw "The rehearsal release source is not a committed ancestor of the current feature head."
}
$short = $releaseSource.Substring(0, 12)
$lastKnownGood = "rp19-lkg-$short"
$forward = "rp19-forward-$short"
$failed = "rp19-fail-$short"
$evidencePath = Join-Path $validatedRoot "logs\deploy\non-reboot-rehearsal.json"

if (-not $PSCmdlet.ShouldProcess($validatedRoot, "Run the bounded non-reboot Rise Pals host rehearsal")) {
  Write-Output "Non-reboot host rehearsal dry-run PASS"
  return
}

Assert-RisePalsAdministrator
$evidence = [ordered]@{
  schemaVersion = "rise-pals-non-reboot-rehearsal-v1"
  orchestratorCommit = $head
  sourceCommit = $releaseSource
  startedAtUtc = [DateTime]::UtcNow.ToString("o")
  completed = $false
  releases = @($lastKnownGood, $forward, $failed)
  serviceIdentity = $false
  aclModel = $false
  forwardSwitch = $false
  automaticRollback = $false
  manualRollback = $false
  independentRestart = $false
  gracefulStop = $false
  boundedCrashRecovery = $false
  certificateReissueAndReload = $false
  secretLifecycleAndNoLeak = $false
  loopbackProxyHealth = $false
  finalServiceState = "pending"
  finalRootProcessCount = -1
  finalListenerCount = -1
  finalEnabledFirewallRuleCount = -1
}

try {
  foreach ($name in @("RisePalsApp", "RisePalsProxy")) {
    $service = Assert-RisePalsServiceIsAbsentOrOwned -Name $name -Root $validatedRoot
    if ($null -eq $service -or $service.StartName -ne "NT SERVICE\$name" -or
      $service.StartMode -ne "Disabled" -or $service.State -ne "Stopped") {
      throw "The approved disabled virtual-account service precondition failed."
    }
  }
  $evidence.serviceIdentity = $true
  & (Join-Path $PSScriptRoot "Repair-RisePalsSecretTraversal.ps1") `
    -Root $validatedRoot -Confirm:$false
  $existingListeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalPort -in @(2019, 3100, 8080, 8443) })
  $existingCurrent = Get-RisePalsCurrentReleaseId -ValidatedRoot $validatedRoot
  $existingCurrentIsVerifiedAncestor = $true
  if ($existingCurrent -ne "" -and $existingCurrent -notin $evidence.releases) {
    $existingRelease = Join-Path $validatedRoot "releases\$existingCurrent"
    $existingManifestPath = Join-Path $existingRelease "release-manifest.json"
    $existingCurrentIsVerifiedAncestor = $false
    if (Test-Path -LiteralPath $existingManifestPath -PathType Leaf) {
      $existingManifest = Get-Content -LiteralPath $existingManifestPath -Raw -Encoding UTF8 |
        ConvertFrom-Json
      if ($existingManifest.schemaVersion -eq "rise-pals-release-manifest-v1" -and
        $existingManifest.releaseId -eq $existingCurrent -and
        [string]$existingManifest.sourceCommit -match "^[a-f0-9]{40}$") {
        & $git -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $repository `
          merge-base --is-ancestor ([string]$existingManifest.sourceCommit) $head
        if ($LASTEXITCODE -eq 0) {
          $runtimeNode = Join-Path $validatedRoot "tools\node\24.18.1\node.exe"
          $releaseManifestTool = Join-Path $repository "scripts\infra\release-manifest.mjs"
          & $runtimeNode $releaseManifestTool --mode verify --root $existingRelease `
            --source-commit ([string]$existingManifest.sourceCommit) `
            --release-id $existingCurrent
          $existingCurrentIsVerifiedAncestor = $LASTEXITCODE -eq 0
        }
      }
    }
  }
  if ($existingListeners.Count -ne 0 -or -not $existingCurrentIsVerifiedAncestor) {
    throw "A pre-existing listener or unrelated current release conflicts with the rehearsal."
  }
  $rootProcesses = @(Get-RisePalsRootProcesses -ValidatedRoot $validatedRoot)
  if ($rootProcesses.Count -ne 0) {
    throw "A Rise Pals process is unexpectedly active before staging recovery."
  }
  & (Join-Path $PSScriptRoot "Test-RisePalsCaddyConfig.ps1") -RepositoryRoot $repository
  if ($LASTEXITCODE -ne 0) {
    throw "The reviewed Caddy configuration did not validate before host synchronization."
  }
  $reviewedCaddyConfig = Join-Path $repository "infra\windows\caddy\Caddyfile"
  $installedCaddyConfig = Join-Path $validatedRoot "shared\config\Caddyfile"
  [IO.File]::WriteAllBytes($installedCaddyConfig, [IO.File]::ReadAllBytes($reviewedCaddyConfig))
  if ((Get-FileHash -LiteralPath $installedCaddyConfig -Algorithm SHA256).Hash -ne
    (Get-FileHash -LiteralPath $reviewedCaddyConfig -Algorithm SHA256).Hash) {
    throw "The installed Caddy configuration does not match the reviewed template."
  }
  Write-Output "Reviewed stopped-service Caddy configuration synchronization PASS"
  $stagingRoot = Join-Path $validatedRoot "staging"
  Get-ChildItem -LiteralPath $stagingRoot -Directory -Force | Where-Object {
    $_.Name -match "^build-[a-f0-9]{32}$"
  } | ForEach-Object {
    $abandonedBuild = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path $_.FullName
    Remove-RisePalsValidatedChild -Root $validatedRoot -Path $abandonedBuild -Recurse
  }
  & (Join-Path $PSScriptRoot "Write-RisePalsHostManifest.ps1") -Root $validatedRoot -Confirm:$false
  & (Join-Path $PSScriptRoot "Set-RisePalsRehearsalSecret.ps1") `
    -Action Create -Root $validatedRoot -Confirm:$false
  & (Join-Path $PSScriptRoot "New-RisePalsRelease.ps1") `
    -ReleaseId $lastKnownGood -Root $validatedRoot -RepositoryRoot $repository `
    -SourceCommit $releaseSource -ReuseExactExisting -Confirm:$false
  & (Join-Path $PSScriptRoot "New-RisePalsRelease.ps1") `
    -ReleaseId $forward -Root $validatedRoot -RepositoryRoot $repository `
    -SourceCommit $releaseSource -ReuseExactExisting -Confirm:$false
  & (Join-Path $PSScriptRoot "New-RisePalsRelease.ps1") `
    -ReleaseId $failed -Root $validatedRoot -RepositoryRoot $repository `
    -SourceCommit $releaseSource -RehearsalDenyManifestRead -ReuseExactExisting -Confirm:$false

  Assert-RisePalsAclModel -ValidatedRoot $validatedRoot -ReleaseId $lastKnownGood `
    -Repository $repository
  Assert-RisePalsExactAclPrincipals -Path (Join-Path $validatedRoot "releases\$forward") `
    -ExpectedPrincipals @(
      "BUILTIN\Administrators",
      "NT AUTHORITY\SYSTEM",
      "NT SERVICE\RisePalsApp"
    )
  Assert-RisePalsExactAclPrincipals `
    -Path (Join-Path $validatedRoot "releases\$failed\release-manifest.json") `
    -ExpectedPrincipals @("BUILTIN\Administrators", "NT AUTHORITY\SYSTEM")
  $evidence.aclModel = $true
  Assert-RisePalsCanaryNotExposed -ValidatedRoot $validatedRoot -Repository $repository

  & (Join-Path $PSScriptRoot "Switch-RisePalsRelease.ps1") `
    -ReleaseId $lastKnownGood -Root $validatedRoot -SkipHealthCheck -Confirm:$false
  & (Join-Path $PSScriptRoot "Start-RisePalsRehearsal.ps1") -Root $validatedRoot -Confirm:$false
  $evidence.loopbackProxyHealth = $true

  $proxyBefore = (Get-CimInstance Win32_Service -Filter "Name='RisePalsProxy'").ProcessId
  Restart-Service -Name "RisePalsApp"
  (Get-Service -Name "RisePalsApp").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
  Wait-RisePalsReady -ExpectedReady $true
  $proxyAfter = (Get-CimInstance Win32_Service -Filter "Name='RisePalsProxy'").ProcessId
  if ($proxyBefore -ne $proxyAfter) {
    throw "Restarting the app also restarted the proxy."
  }
  $appBefore = (Get-CimInstance Win32_Service -Filter "Name='RisePalsApp'").ProcessId
  Restart-Service -Name "RisePalsProxy"
  (Get-Service -Name "RisePalsProxy").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
  & (Join-Path $PSScriptRoot "Test-RisePalsHealth.ps1") -Root $validatedRoot
  $appAfter = (Get-CimInstance Win32_Service -Filter "Name='RisePalsApp'").ProcessId
  if ($appBefore -ne $appAfter) {
    throw "Restarting the proxy also restarted the app."
  }
  $evidence.independentRestart = $true

  & (Join-Path $PSScriptRoot "Set-RisePalsRehearsalSecret.ps1") `
    -Action Rotate -Root $validatedRoot -Confirm:$false
  Restart-Service -Name "RisePalsApp"
  (Get-Service -Name "RisePalsApp").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
  Wait-RisePalsReady -ExpectedReady $true
  Assert-RisePalsCanaryNotExposed -ValidatedRoot $validatedRoot -Repository $repository

  & (Join-Path $PSScriptRoot "Switch-RisePalsRelease.ps1") `
    -ReleaseId $forward -Root $validatedRoot -Confirm:$false
  if ((Get-RisePalsCurrentReleaseId -ValidatedRoot $validatedRoot) -ne $forward) {
    throw "The successful forward release is not current."
  }
  $evidence.forwardSwitch = $true

  $expectedFailure = $false
  try {
    & (Join-Path $PSScriptRoot "Switch-RisePalsRelease.ps1") `
      -ReleaseId $failed -Root $validatedRoot -Confirm:$false
  } catch {
    $expectedFailure = $true
  }
  if (-not $expectedFailure -or
    (Get-RisePalsCurrentReleaseId -ValidatedRoot $validatedRoot) -ne $forward) {
    throw "The failed candidate did not automatically restore the prior release."
  }
  Wait-RisePalsReady -ExpectedReady $true
  $evidence.automaticRollback = $true

  & (Join-Path $PSScriptRoot "Rollback-RisePalsRelease.ps1") `
    -LastKnownGoodReleaseId $lastKnownGood -Root $validatedRoot -Confirm:$false
  if ((Get-RisePalsCurrentReleaseId -ValidatedRoot $validatedRoot) -ne $lastKnownGood) {
    throw "The manual rollback did not restore the last-known-good release."
  }
  $evidence.manualRollback = $true

  Invoke-RisePalsCertificateReissue -ValidatedRoot $validatedRoot
  $evidence.certificateReissueAndReload = $true
  Invoke-RisePalsGracefulStopProbe -ValidatedRoot $validatedRoot
  $evidence.gracefulStop = $true
  Invoke-RisePalsCrashRecoveryProbe -ValidatedRoot $validatedRoot
  $evidence.boundedCrashRecovery = $true

  & (Join-Path $PSScriptRoot "Set-RisePalsRehearsalSecret.ps1") `
    -Action Revoke -Root $validatedRoot -Confirm:$false
  Wait-RisePalsReady -ExpectedReady $false
  & (Join-Path $PSScriptRoot "Set-RisePalsRehearsalSecret.ps1") `
    -Action Delete -Root $validatedRoot -Confirm:$false
  if (Test-Path -LiteralPath (Join-Path $validatedRoot "shared\secrets\rehearsal.canary")) {
    throw "The synthetic canary remains after deletion."
  }
  $evidence.secretLifecycleAndNoLeak = $true
  $evidence.completed = $true
} finally {
  & (Join-Path $PSScriptRoot "Clear-RisePalsRehearsal.ps1") `
    -Root $validatedRoot -Confirm:$false
  $services = @(Get-CimInstance Win32_Service -Filter "Name='RisePalsApp' OR Name='RisePalsProxy'")
  $rootProcesses = @(Get-RisePalsRootProcesses -ValidatedRoot $validatedRoot)
  $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalPort -in @(2019, 3100, 8080, 8443) })
  $firewallRules = @(Get-NetFirewallRule -Enabled True -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "Rise Pals*" })
  $evidence.finalServiceState = if (@($services | Where-Object {
    $_.State -ne "Stopped" -or $_.StartMode -ne "Disabled"
  }).Count -eq 0) { "Stopped/Disabled" } else { "unexpected" }
  $evidence.finalRootProcessCount = $rootProcesses.Count
  $evidence.finalListenerCount = $listeners.Count
  $evidence.finalEnabledFirewallRuleCount = $firewallRules.Count
  $evidence.completedAtUtc = [DateTime]::UtcNow.ToString("o")
  [IO.File]::WriteAllText(
    $evidencePath,
    (($evidence | ConvertTo-Json -Depth 5) + "`n"),
    [Text.UTF8Encoding]::new($false)
  )
}

if (-not $evidence.completed -or $evidence.finalServiceState -ne "Stopped/Disabled" -or
  $evidence.finalRootProcessCount -ne 0 -or $evidence.finalListenerCount -ne 0 -or
  $evidence.finalEnabledFirewallRuleCount -ne 0) {
  throw "The non-reboot host rehearsal did not reach its required final state."
}

Write-Output "Rise Pals complete non-reboot infrastructure rehearsal PASS; sanitized evidence was recorded."
