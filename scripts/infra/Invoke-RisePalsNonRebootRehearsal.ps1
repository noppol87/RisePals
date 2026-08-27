[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
  [string]$Root = "C:\RisePals",
  [string]$RepositoryRoot = "",
  [ValidatePattern("^$|^[a-f0-9]{40}$")][string]$ReleaseSourceCommit = "",
  [switch]$LauncherAuthorized,
  [ValidatePattern("^$|^[a-f0-9-]{36}$")][string]$LauncherInvocationNonce = ""
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
  Assert-RisePalsExactAclPrincipals -Path (Join-Path $ValidatedRoot "shared\control") `
    -ExpectedPrincipals ($systemAdmin + "NT SERVICE\RisePalsApp")
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

function Read-RisePalsSharedFileBytes {
  param([Parameter(Mandatory = $true)][string]$Path)

  $stream = [IO.FileStream]::new(
    $Path,
    [IO.FileMode]::Open,
    [IO.FileAccess]::Read,
    ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
  )
  $memory = [IO.MemoryStream]::new()
  try {
    $stream.CopyTo($memory)
    return ,$memory.ToArray()
  } finally {
    $memory.Dispose()
    $stream.Dispose()
  }
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
    [byte[]]$bytes = Read-RisePalsSharedFileBytes -Path $path
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
  $startedMarker = Join-Path $ValidatedRoot "rehearsal\graceful-stream.started"
  $streamResultPath = Join-Path $ValidatedRoot "rehearsal\graceful-stream.result.json"
  $rejectionResultPath = Join-Path $ValidatedRoot "rehearsal\drain-rejection.result.json"
  $firstStopOutput = Join-Path $ValidatedRoot "rehearsal\stop-service-first.out"
  $firstStopError = Join-Path $ValidatedRoot "rehearsal\stop-service-first.err"
  $secondStopOutput = Join-Path $ValidatedRoot "rehearsal\stop-service-second.out"
  $secondStopError = Join-Path $ValidatedRoot "rehearsal\stop-service-second.err"
  $drainStatePath = Join-Path $ValidatedRoot "shared\control\app-drain-state.json"
  $probe = Join-Path $ValidatedRoot "rehearsal\loopback-https-probe.mjs"
  $probeSource = Join-Path $PSScriptRoot "loopback-https-probe.mjs"
  foreach ($path in @(
    $output,
    $errorOutput,
    $startedMarker,
    $streamResultPath,
    $rejectionResultPath,
    $firstStopOutput,
    $firstStopError,
    $secondStopOutput,
    $secondStopError,
    $probe
  )) {
    if (Test-Path -LiteralPath $path) {
      throw "A graceful-stop probe path unexpectedly exists."
    }
  }
  [IO.File]::WriteAllBytes($probe, [IO.File]::ReadAllBytes($probeSource))
  if ((Get-FileHash -LiteralPath $probe -Algorithm SHA256).Hash -ne
    (Get-FileHash -LiteralPath $probeSource -Algorithm SHA256).Hash) {
    throw "The copied graceful-stop probe does not match the reviewed helper."
  }
  $process = $null
  $firstStop = $null
  $secondStop = $null
  try {
  $node = Join-Path $ValidatedRoot "tools\node\24.18.1\node.exe"
  $expectedBody = [Convert]::ToBase64String(
    [Text.Encoding]::UTF8.GetBytes("probe-start`nprobe-mid`nprobe-end`n")
  )
  $process = Start-Process -FilePath $node -ArgumentList @(
    $probe, "--ca", $ca, "--url", "https://127.0.0.1:8443/health/stream",
    "--status", "200", "--body-base64", $expectedBody,
    "--first-byte-marker", $startedMarker,
    "--result-path", $streamResultPath
  ) -RedirectStandardOutput $output -RedirectStandardError $errorOutput -PassThru
  $streamStarted = $false
  $streamDeadline = [DateTime]::UtcNow.AddSeconds(15)
  do {
    if (Test-Path -LiteralPath $startedMarker -PathType Leaf) {
      $marker = [Text.Encoding]::UTF8.GetString(
        (Read-RisePalsSharedFileBytes -Path $startedMarker)
      )
      if ($marker -ne "started`n") {
        throw "The graceful-stop first-byte marker is invalid."
      }
      $streamStarted = $true
      break
    }
    if ($process.HasExited) {
      break
    }
    Start-Sleep -Milliseconds 25
  } while ([DateTime]::UtcNow -lt $streamDeadline)
  if (-not $streamStarted) {
    if (-not $process.HasExited) {
      Stop-Process -Id $process.Id -Force
    }
    throw "The in-flight streaming request did not start within the bounded window."
  }
  $stopStartedAt = [DateTime]::UtcNow
  $powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
  $stopHelper = Join-Path $PSScriptRoot "Invoke-RisePalsServiceStop.ps1"
  $quotedStopHelper = '"' + $stopHelper + '"'
  $firstStop = Start-Process -FilePath $powerShell -ArgumentList @(
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $quotedStopHelper,
    "-ServiceName",
    "RisePalsApp"
  ) -RedirectStandardOutput $firstStopOutput -RedirectStandardError $firstStopError -PassThru

  $drainDeadline = [DateTime]::UtcNow.AddSeconds(5)
  $draining = $null
  do {
    if (Test-Path -LiteralPath $drainStatePath -PathType Leaf) {
      $candidate = Get-Content -LiteralPath $drainStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($candidate.schemaVersion -eq "rise-pals-drain-state-v1" -and
        $candidate.state -eq "draining") {
        $draining = $candidate
        break
      }
    }
    Start-Sleep -Milliseconds 25
  } while ([DateTime]::UtcNow -lt $drainDeadline)
  if ($null -eq $draining) {
    throw "Direct Stop-Service did not enter the exact local Draining state."
  }
  $drainAclChecker = Join-Path $ValidatedRoot "current\drain-control.mjs"
  & $node $drainAclChecker --assert-state $drainStatePath
  if ($LASTEXITCODE -ne 0) {
    throw "The live drain state did not pass the exact canonical ACL model."
  }

  $secondStop = Start-Process -FilePath $powerShell -ArgumentList @(
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $quotedStopHelper,
    "-ServiceName",
    "RisePalsApp",
    "-IgnoreAlreadyStopped"
  ) -RedirectStandardOutput $secondStopOutput -RedirectStandardError $secondStopError -PassThru

  $expectedDrainingBody = [Convert]::ToBase64String(
    [Text.Encoding]::UTF8.GetBytes("{`"status`":`"draining`"}`n")
  )
  & $node $probe --ca $ca --url "https://127.0.0.1:8443/th" --status 503 `
    --body-base64 $expectedDrainingBody --response-header "Retry-After: 5" `
    --result-path $rejectionResultPath
  if ($LASTEXITCODE -ne 0) {
    throw "A new request was not rejected deterministically during drain."
  }

  (Get-Service -Name "RisePalsApp").WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
  if (-not $firstStop.WaitForExit(30000) -or -not $secondStop.WaitForExit(30000)) {
    throw "A repeated Stop-Service command did not complete within the bounded window."
  }
  if ($firstStop.ExitCode -ne 0 -or $secondStop.ExitCode -ne 0) {
    throw "A direct or repeated Stop-Service command failed."
  }
  if (-not $process.WaitForExit(30000)) {
    Stop-Process -Id $process.Id -Force
    throw "The in-flight streaming request did not end within the graceful-stop bound."
  }
  $probeResult = [Text.Encoding]::UTF8.GetString(
    (Read-RisePalsSharedFileBytes -Path $output)
  ).Trim()
  if ($process.ExitCode -ne 0 -or
    $probeResult -ne "Explicit-local-CA loopback HTTPS probe PASS") {
    throw "The in-flight request did not complete during the configured graceful stop."
  }
  if (@(Get-RisePalsNodeProcess -ValidatedRoot $ValidatedRoot).Count -ne 0) {
    throw "Graceful stop left an orphan Node process."
  }
  $stopped = Get-Content -LiteralPath $drainStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($stopped.schemaVersion -ne "rise-pals-drain-state-v1" -or
    $stopped.state -ne "stopped" -or
    $stopped.startedAtUtc -ne $draining.startedAtUtc -or
    $stopped.deadlineAtUtc -ne $draining.deadlineAtUtc) {
    throw "The repeated stop changed or corrupted the original drain transition."
  }
  $stopElapsedMs = [Math]::Round(([DateTime]::UtcNow - $stopStartedAt).TotalMilliseconds)
  if ($stopElapsedMs -gt 20000) {
    throw "The complete graceful service-stop path exceeded 20 seconds."
  }
  $streamResult = Get-Content -LiteralPath $streamResultPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $rejectionResult = Get-Content -LiteralPath $rejectionResultPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
  if ($streamResult.status -ne 200 -or $streamResult.bodyBytes -ne 32 -or
    $rejectionResult.status -ne 503) {
    throw "Graceful-stream or drain-rejection evidence is incomplete."
  }
  Start-Service -Name "RisePalsApp"
  (Get-Service -Name "RisePalsApp").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
  Wait-RisePalsReady -ExpectedReady $true
  $ready = Get-Content -LiteralPath $drainStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($ready.schemaVersion -ne "rise-pals-drain-state-v1" -or $ready.state -ne "ready") {
    throw "Startup did not reconcile the stopped drain state before readiness."
  }
  return [ordered]@{
    stopElapsedMs = $stopElapsedMs
    streamFirstByteMs = [int]$streamResult.firstByteMs
    streamTotalMs = [int]$streamResult.totalMs
    streamBodyBytes = [int]$streamResult.bodyBytes
    drainRejectionStatus = [int]$rejectionResult.status
    repeatedStopPreservedDeadline = $true
    startupReconciledToReady = $true
  }
  } finally {
    if ($null -ne $process -and -not $process.HasExited) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    foreach ($stopProcess in @($firstStop, $secondStop)) {
      if ($null -ne $stopProcess -and -not $stopProcess.HasExited) {
        if (-not $stopProcess.WaitForExit(20000)) {
          Stop-Process -Id $stopProcess.Id -Force -ErrorAction SilentlyContinue
        }
      }
    }
  }
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
  $drainStatePath = Join-Path $ValidatedRoot "shared\control\app-drain-state.json"
  $appLogs = Join-Path $ValidatedRoot "logs\app"
  $invalidMarker = "rise-pals-lifecycle startup-state-invalid fail-closed"
  $countInvalidMarkers = {
    $count = 0
    Get-ChildItem -LiteralPath $appLogs -File -ErrorAction SilentlyContinue | ForEach-Object {
      try {
        $text = [Text.Encoding]::UTF8.GetString((Read-RisePalsSharedFileBytes -Path $_.FullName))
        $count += [regex]::Matches($text, [regex]::Escape($invalidMarker)).Count
      } catch {
        # A concurrently rotated log is skipped; the bounded state/process assertions remain authoritative.
      }
    }
    return $count
  }

  Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @(
    "failure",
    "RisePalsApp",
    "reset=",
    "1",
    "actions=",
    "restart/5000/restart/15000//0"
  )
  try {
    Start-Sleep -Seconds 2
    $first = [uint32]$node[0].ProcessId
    Stop-Process -Id $first -Force
    $second = Wait-RisePalsReplacementNode -ValidatedRoot $ValidatedRoot -PreviousProcessId $first
    $afterCrash = Get-Content -LiteralPath $drainStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($afterCrash.schemaVersion -ne "rise-pals-drain-state-v1" -or
      $afterCrash.state -ne "ready") {
      throw "Unexpected process exit did not recover through a fresh Ready lifecycle."
    }

    Start-Sleep -Seconds 2
    Stop-Service -Name "RisePalsApp"
    (Get-Service -Name "RisePalsApp").WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
    if (@(Get-RisePalsNodeProcess -ValidatedRoot $ValidatedRoot).Count -ne 0) {
      throw "The pre-failure intentional drain left a Node process."
    }

    $beforeInvalid = & $countInvalidMarkers
    [IO.File]::WriteAllText(
      $drainStatePath,
      "{`"schemaVersion`":`"rise-pals-drain-state-v1`",`"state`":`"invalid`"}`n",
      [Text.UTF8Encoding]::new($false)
    )
    try {
      Start-Service -Name "RisePalsApp" -ErrorAction SilentlyContinue
      $failureDeadline = [DateTime]::UtcNow.AddSeconds(50)
      do {
        $service = Get-CimInstance Win32_Service -Filter "Name='RisePalsApp'"
        $nodeCount = @(Get-RisePalsNodeProcess -ValidatedRoot $ValidatedRoot).Count
        $invalidAttempts = (& $countInvalidMarkers) - $beforeInvalid
        if ($service.State -eq "Stopped" -and $nodeCount -eq 0 -and $invalidAttempts -ge 3) {
          break
        }
        Start-Sleep -Milliseconds 500
      } while ([DateTime]::UtcNow -lt $failureDeadline)
      if ($service.State -ne "Stopped" -or $nodeCount -ne 0 -or $invalidAttempts -ne 3) {
        throw "Persistent startup failure did not reach the exact bounded three-attempt terminal state."
      }
    } finally {
      if (Test-Path -LiteralPath $drainStatePath -PathType Leaf) {
        Remove-RisePalsValidatedChild -Root $ValidatedRoot -Path $drainStatePath
      }
    }

    Start-Service -Name "RisePalsApp"
    (Get-Service -Name "RisePalsApp").WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
    Wait-RisePalsReady -ExpectedReady $true
    return [ordered]@{
      unexpectedExitRecovered = $true
      replacementProcessChanged = $second -ne $first
      persistentStartupAttempts = $invalidAttempts
      persistentFailureTerminalState = "Stopped"
      intentionalDrainSeparated = $true
    }
  } finally {
    Invoke-RisePalsNativeCommand -FilePath "sc.exe" -Arguments @(
      "failure",
      "RisePalsApp",
      "reset=",
      "3600",
      "actions=",
      "restart/5000/restart/15000//0"
    )
  }
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

$launcherAuthorizationIsValid = $LauncherAuthorized -and
  $LauncherInvocationNonce -match "^[a-f0-9-]{36}$"
if ($LauncherAuthorized -and -not $launcherAuthorizationIsValid) {
  throw "The versioned launcher authorization is incomplete."
}
if (-not $launcherAuthorizationIsValid -and
  -not $PSCmdlet.ShouldProcess($validatedRoot, "Run the bounded non-reboot Rise Pals host rehearsal")) {
  Write-Output "Non-reboot host rehearsal dry-run PASS"
  return
}

Assert-RisePalsAdministrator
$node = Join-Path $validatedRoot "tools\node\24.18.1\node.exe"
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
  gracefulStopDetails = $null
  boundedCrashRecovery = $false
  crashRecoveryDetails = $null
  certificateReissueAndReload = $false
  secretLifecycleAndNoLeak = $false
  loopbackProxyHealth = $false
  finalServiceState = "pending"
  finalRootProcessCount = -1
  finalListenerCount = -1
  finalEnabledFirewallRuleCount = -1
  finalStagingChildCount = -1
  finalRehearsalChildCount = -1
  finalDrainStateCount = -1
  finalAtomicTemporaryCount = -1
  finalDrainLockCount = -1
  finalSyntheticCanaryCount = -1
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
  & (Join-Path $PSScriptRoot "Update-RisePalsDrainControl.ps1") `
    -Root $validatedRoot -RepositoryRoot $repository -Confirm:$false
  & (Join-Path $PSScriptRoot "Repair-RisePalsSecretTraversal.ps1") `
    -Root $validatedRoot -Confirm:$false
  $existingListeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalPort -in @(80, 443, 2019, 3100, 8080, 8443) })
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

  $releaseDrainAclChecker = Join-Path $validatedRoot "releases\$lastKnownGood\drain-control.mjs"
  $controlDirectory = Join-Path $validatedRoot "shared\control"
  & $node $releaseDrainAclChecker --assert-parent $controlDirectory
  if ($LASTEXITCODE -ne 0) {
    throw "The release drain checker rejected the exact protected control ACL."
  }

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
  $evidence.gracefulStopDetails = Invoke-RisePalsGracefulStopProbe `
    -ValidatedRoot $validatedRoot
  $evidence.gracefulStop = $true
  $evidence.crashRecoveryDetails = Invoke-RisePalsCrashRecoveryProbe `
    -ValidatedRoot $validatedRoot
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
    Where-Object { $_.LocalPort -in @(80, 443, 2019, 3100, 8080, 8443) })
  $firewallRules = @(Get-NetFirewallRule -Enabled True -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "Rise Pals*" })
  $stagingChildren = @(Get-ChildItem -LiteralPath (Join-Path $validatedRoot "staging") `
    -Force -ErrorAction SilentlyContinue)
  $rehearsalChildren = @(Get-ChildItem -LiteralPath (Join-Path $validatedRoot "rehearsal") `
    -Force -ErrorAction SilentlyContinue)
  $controlDirectory = Join-Path $validatedRoot "shared\control"
  $drainState = @(Get-Item -LiteralPath (Join-Path $controlDirectory "app-drain-state.json") `
    -Force -ErrorAction SilentlyContinue)
  $drainTemporary = @(Get-ChildItem -LiteralPath $controlDirectory -File -Force `
    -ErrorAction SilentlyContinue | Where-Object {
      $_.Name -match "^\.app-drain-state\.[0-9]+\.[a-f0-9-]{36}\.tmp$"
    })
  $drainLock = @(Get-Item -LiteralPath (Join-Path $controlDirectory "app-drain-state.json.lock") `
    -Force -ErrorAction SilentlyContinue)
  $syntheticCanary = @(Get-Item -LiteralPath (
    Join-Path $validatedRoot "shared\secrets\rehearsal.canary"
  ) -Force -ErrorAction SilentlyContinue)
  $evidence.finalServiceState = if (@($services | Where-Object {
    $_.State -ne "Stopped" -or $_.StartMode -ne "Disabled"
  }).Count -eq 0) { "Stopped/Disabled" } else { "unexpected" }
  $evidence.finalRootProcessCount = $rootProcesses.Count
  $evidence.finalListenerCount = $listeners.Count
  $evidence.finalEnabledFirewallRuleCount = $firewallRules.Count
  $evidence.finalStagingChildCount = $stagingChildren.Count
  $evidence.finalRehearsalChildCount = $rehearsalChildren.Count
  $evidence.finalDrainStateCount = $drainState.Count
  $evidence.finalAtomicTemporaryCount = $drainTemporary.Count
  $evidence.finalDrainLockCount = $drainLock.Count
  $evidence.finalSyntheticCanaryCount = $syntheticCanary.Count
  $evidence.completedAtUtc = [DateTime]::UtcNow.ToString("o")
  [IO.File]::WriteAllText(
    $evidencePath,
    (($evidence | ConvertTo-Json -Depth 5) + "`n"),
    [Text.UTF8Encoding]::new($false)
  )
}

if (-not $evidence.completed -or $evidence.finalServiceState -ne "Stopped/Disabled" -or
  $evidence.finalRootProcessCount -ne 0 -or $evidence.finalListenerCount -ne 0 -or
  $evidence.finalEnabledFirewallRuleCount -ne 0 -or $evidence.finalStagingChildCount -ne 0 -or
  $evidence.finalRehearsalChildCount -ne 0 -or $evidence.finalDrainStateCount -ne 0 -or
  $evidence.finalAtomicTemporaryCount -ne 0 -or $evidence.finalDrainLockCount -ne 0 -or
  $evidence.finalSyntheticCanaryCount -ne 0) {
  throw "The non-reboot host rehearsal did not reach its required final state."
}

Write-Output "Rise Pals complete non-reboot infrastructure rehearsal PASS; sanitized evidence was recorded."
