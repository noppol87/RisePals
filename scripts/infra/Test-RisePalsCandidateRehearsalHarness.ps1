[CmdletBinding()]
param(
  [string]$RepositoryRoot = "C:\Codex PC SG2\Jeff\risepals"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repository = [IO.Path]::GetFullPath($RepositoryRoot)
$scripts = Join-Path $repository "scripts\infra"
. (Join-Path $scripts "candidate-rehearsal-contract.ps1")
. (Join-Path $scripts "candidate-rehearsal-result.ps1")

function Assert-RisePalsCandidateThrows {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Action,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $threw = $false
  try {
    & $Action
  } catch {
    $threw = $true
  }
  if (-not $threw) {
    throw "$Label was not rejected."
  }
}

function New-RisePalsCandidateValidRepositorySnapshot {
  param([Parameter(Mandatory = $true)][object]$Contract)

  return [pscustomobject]@{
    branch = [string]$Contract.repository.branch
    head = "1111111111111111111111111111111111111111"
    mainHead = [string]$Contract.repository.mainCommit
    clean = $true
    envLocalIgnored = $true
    envLocalTracked = $false
  }
}

function New-RisePalsCandidateValidHostSnapshot {
  param([Parameter(Mandatory = $true)][object]$Contract)

  return [pscustomobject]@{
    candidateServiceExists = $false
    unexpectedRisePalsServices = @()
    retainedServices = @(
      [pscustomobject]@{ name = "RisePalsApp"; state = "Stopped"; startMode = "Disabled"; processId = 0 },
      [pscustomobject]@{ name = "RisePalsProxy"; state = "Stopped"; startMode = "Disabled"; processId = 0 }
    )
    relevantListeners = @()
    processesUnderRoot = @()
    unexpectedPaths = @()
    reparsePaths = @()
    unexpectedAclEntries = @()
    candidateExecutableLength = [int64]$Contract.prototype.executableLength
    candidateExecutableSha256 = [string]$Contract.prototype.executableSha256
    candidateAuthenticode = "NotSigned"
  }
}

function New-RisePalsCandidateValidResult {
  param(
    [string]$Nonce = "0123456789abcdef0123456789abcdef",
    [string]$Head = "1111111111111111111111111111111111111111",
    [string]$ScriptHash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    [string]$Status = "success",
    [int]$ExitCode = 0,
    [bool]$CleanupCompleted = $true,
    [object]$FinalState = (New-RisePalsCandidateFinalState)
  )

  $now = [DateTimeOffset]::UtcNow
  return New-RisePalsCandidateResult -InvocationNonce $Nonce -RepositoryHead $Head `
    -LauncherScriptSha256 $ScriptHash -StartedAtUtc $now.ToString("o") `
    -CompletedAtUtc $now.AddMilliseconds(10).ToString("o") -Status $Status `
    -ChildExitCode $ExitCode -CompletedStages @("child-started", "streams-separated") `
    -FailedStage $(if ($Status -eq "failure") { "native-child" } else { $null }) `
    -SanitizedFailureCode $(if ($Status -eq "failure") { "native-child-exit-nonzero" } else { $null }) `
    -CleanupCompleted $CleanupCompleted -FinalState $FinalState -StreamEvidence ([ordered]@{
      stdoutObserved = $true
      stderrObserved = $true
      streamsSeparated = $true
      rawOutputPersisted = $false
    })
}

$contract = Get-RisePalsCandidateContract -RepositoryRoot $repository
Write-Output "Candidate contract and accepted artifact pins PASS"

$sid = Get-RisePalsServiceSid -ServiceName "RisePalsServiceHostCandidate"
if ($sid -ne $contract.candidate.serviceSid) {
  throw "Candidate SID derivation did not match the fixed contract."
}
Write-Output "Candidate virtual-account SID derivation PASS"

$nonce = "0123456789abcdef0123456789abcdef"
$plan = New-RisePalsCandidateInstallationPlan -Contract $contract -Nonce $nonce `
  -RepositoryHead "1111111111111111111111111111111111111111" `
  -LauncherScriptSha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
if ([bool]$plan.liveExecutionAuthorized -or $plan.serviceName -ne "RisePalsServiceHostCandidate" -or
  $plan.serviceType -ne "SERVICE_WIN32_OWN_PROCESS" -or $plan.startMode -ne "demand" -or
  @($plan.rehearsalStages).Count -ne @($contract.rehearsalStages).Count) {
  throw "The repository-only candidate plan changed its fixed boundary."
}
$before = @(Get-CimInstance Win32_Service -Filter "Name LIKE 'RisePals%'" | ForEach-Object {
  "{0}|{1}|{2}|{3}" -f $_.Name, $_.State, $_.StartMode, $_.ProcessId
})
$secondPlan = New-RisePalsCandidateInstallationPlan -Contract $contract -Nonce $nonce `
  -RepositoryHead "1111111111111111111111111111111111111111" `
  -LauncherScriptSha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
$after = @(Get-CimInstance Win32_Service -Filter "Name LIKE 'RisePals%'" | ForEach-Object {
  "{0}|{1}|{2}|{3}" -f $_.Name, $_.State, $_.StartMode, $_.ProcessId
})
if (($plan | ConvertTo-Json -Depth 8 -Compress) -ne
  ($secondPlan | ConvertTo-Json -Depth 8 -Compress) -or
  @(Compare-Object -ReferenceObject $before -DifferenceObject $after).Count -ne 0) {
  throw "Candidate plan mode was not deterministic and zero-mutation."
}
Write-Output "Deterministic WhatIf/plan zero-service-mutation PASS"

$repositorySnapshot = New-RisePalsCandidateValidRepositorySnapshot -Contract $contract
Assert-RisePalsCandidateRepositorySnapshot -Snapshot $repositorySnapshot `
  -Contract $contract -ExpectedHead $repositorySnapshot.head
foreach ($property in @("branch", "head", "mainHead", "clean", "envLocalIgnored", "envLocalTracked")) {
  $invalid = New-RisePalsCandidateValidRepositorySnapshot -Contract $contract
  switch ($property) {
    "branch" { $invalid.branch = "main" }
    "head" { $invalid.head = "2222222222222222222222222222222222222222" }
    "mainHead" { $invalid.mainHead = "2222222222222222222222222222222222222222" }
    "clean" { $invalid.clean = $false }
    "envLocalIgnored" { $invalid.envLocalIgnored = $false }
    "envLocalTracked" { $invalid.envLocalTracked = $true }
  }
  Assert-RisePalsCandidateThrows -Label ("Repository snapshot " + $property) -Action {
    Assert-RisePalsCandidateRepositorySnapshot -Snapshot $invalid -Contract $contract `
      -ExpectedHead "1111111111111111111111111111111111111111"
  }
}
Write-Output "Repository head/branch/clean/main/.env boundary PASS"

$hostSnapshot = New-RisePalsCandidateValidHostSnapshot -Contract $contract
Assert-RisePalsCandidateHostSnapshot -Snapshot $hostSnapshot -Contract $contract
$hostFailures = @(
  "candidateServiceExists",
  "unexpectedRisePalsServices",
  "retainedServiceState",
  "relevantListeners",
  "processesUnderRoot",
  "unexpectedPaths",
  "reparsePaths",
  "unexpectedAclEntries",
  "candidateExecutableLength",
  "candidateExecutableSha256",
  "candidateAuthenticode"
)
foreach ($failure in $hostFailures) {
  $invalid = New-RisePalsCandidateValidHostSnapshot -Contract $contract
  switch ($failure) {
    "candidateServiceExists" { $invalid.candidateServiceExists = $true }
    "unexpectedRisePalsServices" { $invalid.unexpectedRisePalsServices = @("RisePalsOther") }
    "retainedServiceState" { $invalid.retainedServices[0].state = "Running" }
    "relevantListeners" { $invalid.relevantListeners = @(3100) }
    "processesUnderRoot" { $invalid.processesUnderRoot = @(1234) }
    "unexpectedPaths" { $invalid.unexpectedPaths = @("unexpected") }
    "reparsePaths" { $invalid.reparsePaths = @("reparse") }
    "unexpectedAclEntries" { $invalid.unexpectedAclEntries = @("Users") }
    "candidateExecutableLength" { $invalid.candidateExecutableLength++ }
    "candidateExecutableSha256" {
      $invalid.candidateExecutableSha256 = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    }
    "candidateAuthenticode" { $invalid.candidateAuthenticode = "Valid" }
  }
  Assert-RisePalsCandidateThrows -Label ("Host snapshot " + $failure) -Action {
    Assert-RisePalsCandidateHostSnapshot -Snapshot $invalid -Contract $contract
  }
}
Write-Output "Service collision/executable/path/ACL/listener preflight rejections PASS"

Assert-RisePalsCandidateThrows -Label "Path traversal" -Action {
  Assert-RisePalsCandidateAuthorizedPath -Path "C:\Windows\candidate" `
    -ApprovedRoots @($contract.paths.stagingRoot)
}
Write-Output "Exact candidate path containment PASS"

$cleanupSnapshot = [pscustomobject]@{
  serviceState = "Stopped"
  startMode = "Disabled"
  processId = 0
  ownedJobProcessCount = 0
  reparsePaths = @()
  uncertainPaths = @()
  nonemptyUnexpectedPaths = @()
  cleanupTargets = @($plan.paths.configPath, $plan.paths.logDirectory)
}
Assert-RisePalsCandidateCleanupSnapshot -Snapshot $cleanupSnapshot -PathPlan $plan.paths
Assert-RisePalsCandidateCleanupSnapshot -Snapshot $cleanupSnapshot -PathPlan $plan.paths
$escapedCleanup = $cleanupSnapshot.PSObject.Copy()
$escapedCleanup.cleanupTargets = @("C:\RisePals\shared\secrets")
Assert-RisePalsCandidateThrows -Label "Cleanup escape" -Action {
  Assert-RisePalsCandidateCleanupSnapshot -Snapshot $escapedCleanup -PathPlan $plan.paths
}
$uncertainCleanup = $cleanupSnapshot.PSObject.Copy()
$uncertainCleanup.uncertainPaths = @("unknown")
Assert-RisePalsCandidateThrows -Label "Uncertain cleanup" -Action {
  Assert-RisePalsCandidateCleanupSnapshot -Snapshot $uncertainCleanup -PathPlan $plan.paths
}
Write-Output "Cleanup containment and idempotent validation PASS"

$inventoryRoot = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-candidate-inventory-" + [guid]::NewGuid().ToString("N")
)
try {
  [IO.Directory]::CreateDirectory((Join-Path $inventoryRoot "expected")) | Out-Null
  [IO.File]::WriteAllText(
    (Join-Path $inventoryRoot "expected\known.txt"),
    "synthetic",
    [Text.UTF8Encoding]::new($false)
  )
  Assert-RisePalsCandidateTaskTreeInventory -Path $inventoryRoot `
    -AllowedRelativePaths @("expected", "expected\known.txt")
  [IO.File]::WriteAllText(
    (Join-Path $inventoryRoot "expected\unexpected.txt"),
    "synthetic",
    [Text.UTF8Encoding]::new($false)
  )
  Assert-RisePalsCandidateThrows -Label "Unexpected nested cleanup child" -Action {
    Assert-RisePalsCandidateTaskTreeInventory -Path $inventoryRoot `
      -AllowedRelativePaths @("expected", "expected\known.txt")
  }
} finally {
  if ([IO.Directory]::Exists($inventoryRoot)) {
    [IO.Directory]::Delete($inventoryRoot, $true)
  }
}
Write-Output "Recursive cleanup inventory rejection PASS"

$expectedNonce = "0123456789abcdef0123456789abcdef"
$expectedHead = "1111111111111111111111111111111111111111"
$expectedHash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
$started = [DateTimeOffset]::UtcNow.AddSeconds(-1)
$result = New-RisePalsCandidateValidResult
$consumed = @{}
[void](Assert-RisePalsCandidateResult -Result $result -ExpectedNonce $expectedNonce `
  -ExpectedHead $expectedHead -ExpectedLauncherScriptSha256 $expectedHash `
  -ObservedExitCode 0 -InvocationStartedAtUtc $started -ConsumedNonces $consumed)

$atomicRoot = Join-Path ([IO.Path]::GetTempPath()) (
  "risepals-candidate-result-" + [guid]::NewGuid().ToString("N")
)
try {
  [IO.Directory]::CreateDirectory($atomicRoot) | Out-Null
  $atomicResult = Join-Path $atomicRoot "result.json"
  $atomicTemporary = Join-Path $atomicRoot "result.tmp"
  Write-RisePalsCandidateResultAtomic -Result $result -ResultPath $atomicResult `
    -TemporaryPath $atomicTemporary
  $roundTrip = [Text.UTF8Encoding]::new($false, $true).GetString(
    [IO.File]::ReadAllBytes($atomicResult)
  ) | ConvertFrom-Json
  [void](Assert-RisePalsCandidateResult -Result $roundTrip -ExpectedNonce $expectedNonce `
    -ExpectedHead $expectedHead -ExpectedLauncherScriptSha256 $expectedHash `
    -ObservedExitCode 0 -InvocationStartedAtUtc $started -ConsumedNonces @{})
  if ([IO.File]::Exists($atomicTemporary)) {
    throw "The atomic candidate result left its temporary file."
  }
} finally {
  if ([IO.File]::Exists((Join-Path $atomicRoot "result.json"))) {
    [IO.File]::Delete((Join-Path $atomicRoot "result.json"))
  }
  if ([IO.File]::Exists((Join-Path $atomicRoot "result.tmp"))) {
    [IO.File]::Delete((Join-Path $atomicRoot "result.tmp"))
  }
  if ([IO.Directory]::Exists($atomicRoot)) {
    [IO.Directory]::Delete($atomicRoot, $false)
  }
}
Write-Output "Atomic structured-result round trip PASS"
if (-not [bool]$result.streamEvidence.stderrObserved) {
  throw "Informational stderr was not preserved as bounded stream evidence."
}
Assert-RisePalsCandidateThrows -Label "Structured-result replay" -Action {
  Assert-RisePalsCandidateResult -Result $result -ExpectedNonce $expectedNonce `
    -ExpectedHead $expectedHead -ExpectedLauncherScriptSha256 $expectedHash `
    -ObservedExitCode 0 -InvocationStartedAtUtc $started -ConsumedNonces $consumed
}
Write-Output "Structured success/informational-stderr/single-use result PASS"

$failureResult = New-RisePalsCandidateValidResult -Status "failure" -ExitCode 7 `
  -CleanupCompleted $true
[void](Assert-RisePalsCandidateResult -Result $failureResult -ExpectedNonce $expectedNonce `
  -ExpectedHead $expectedHead -ExpectedLauncherScriptSha256 $expectedHash `
  -ObservedExitCode 7 -InvocationStartedAtUtc $started -ConsumedNonces @{})
Write-Output "Explicit native nonzero result classification PASS"

$invalidCases = @("malformed", "stale", "wrong-head", "wrong-script", "partial", "digest")
foreach ($case in $invalidCases) {
  $invalid = New-RisePalsCandidateValidResult
  switch ($case) {
    "malformed" { $invalid.PSObject.Properties.Remove("cleanupCompleted") }
    "stale" {
      $invalid.startedAtUtc = [DateTimeOffset]::UtcNow.AddHours(-2).ToString("o")
      $invalid.completedAtUtc = [DateTimeOffset]::UtcNow.AddHours(-2).AddSeconds(1).ToString("o")
      $invalid.resultDigest = Get-RisePalsCandidateResultDigest -Result $invalid
    }
    "wrong-head" {
      $invalid.repositoryHead = "2222222222222222222222222222222222222222"
      $invalid.resultDigest = Get-RisePalsCandidateResultDigest -Result $invalid
    }
    "wrong-script" {
      $invalid.launcherScriptSha256 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      $invalid.resultDigest = Get-RisePalsCandidateResultDigest -Result $invalid
    }
    "partial" { $invalid.completedStages = @("child-started", "child-started") }
    "digest" { $invalid.resultDigest = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" }
  }
  Assert-RisePalsCandidateThrows -Label ("Structured result " + $case) -Action {
    Assert-RisePalsCandidateResult -Result $invalid -ExpectedNonce $expectedNonce `
      -ExpectedHead $expectedHead -ExpectedLauncherScriptSha256 $expectedHash `
      -ObservedExitCode 0 -InvocationStartedAtUtc $started -ConsumedNonces @{}
  }
}
Write-Output "Malformed/stale/provenance/partial/digest result rejections PASS"

$stages = @($contract.rehearsalStages)
$codes = @($contract.sanitizedFailureCodes)
if ($stages.Count -ne $codes.Count) {
  throw "Every modeled candidate stage requires one fixed failure classification."
}
for ($index = 0; $index -lt $stages.Count; $index++) {
  if ((Get-RisePalsCandidateFailureCodeForStage -Contract $contract -Stage $stages[$index]) -ne
    $codes[$index]) {
    throw "A candidate modeled stage lacks deterministic failure handling."
  }
}
Write-Output ("Modeled-stage failure classification PASS ({0} stages)" -f $stages.Count)

$liveSource = [IO.File]::ReadAllText(
  (Join-Path $scripts "Invoke-RisePalsCandidateLiveSequence.ps1")
)
if (-not $liveSource.Contains("Get-RisePalsCandidateFailureCodeForStage") -or
  -not $liveSource.Contains("Assert-RisePalsCandidateTaskTreeInventory") -or
  -not $liveSource.Contains("The elevated candidate preflight no longer matches")) {
  throw "The live source does not consume the exact stage, tree and repository boundaries."
}
Write-Output "Live-stage code/tree/repository fail-closed wiring PASS"

$parseTargets = @(
  "candidate-rehearsal-contract.ps1",
  "candidate-rehearsal-result.ps1",
  "Invoke-RisePalsCandidateRehearsal.ps1",
  "Invoke-RisePalsCandidateRehearsalChild.ps1",
  "Invoke-RisePalsCandidateLiveSequence.ps1",
  "Test-RisePalsCandidateRehearsalHarness.ps1"
)
foreach ($name in $parseTargets) {
  $tokens = $null
  $errors = $null
  [void][Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $scripts $name),
    [ref]$tokens,
    [ref]$errors
  )
  if (@($errors).Count -ne 0) {
    throw "$name is not PowerShell 5.1 AST compatible."
  }
}
$suiteTokens = $null
$suiteErrors = $null
$suiteAst = [Management.Automation.Language.Parser]::ParseFile(
  $PSCommandPath,
  [ref]$suiteTokens,
  [ref]$suiteErrors
)
$mutatingCommands = @($suiteAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -in @(
      "Start-Process",
      "Start-Service",
      "Stop-Service",
      "New-Service",
      "Remove-Service"
    )
}, $true))
if ($mutatingCommands.Count -ne 0) {
  throw "Repository tests contain a reachable live or elevated command."
}
Write-Output "PowerShell 5.1 AST and no-live-test reachability PASS"

$identitySource = [IO.File]::ReadAllText(
  (Join-Path $repository "infra\windows-service-host\RisePals.ServiceHost\ServiceRegistrationIdentity.cs")
)
$orchestratorSource = [IO.File]::ReadAllText(
  (Join-Path $repository "infra\windows-service-host\RisePals.ServiceHost\ServiceOrchestrator.cs")
)
$evidenceSource = [IO.File]::ReadAllText(
  (Join-Path $repository "infra\windows-service-host\RisePals.ServiceHost\ProcessAdapters.cs")
)
if (-not $identitySource.Contains('CandidateServiceName = "RisePalsServiceHostCandidate"') -or
  -not $identitySource.Contains('RetainedApplicationServiceName = "RisePalsApp"') -or
  -not $identitySource.Contains('RetainedProxyServiceName = "RisePalsProxy"') -or
  -not $orchestratorSource.Contains("CleanupAttemptAsync") -or
  -not $orchestratorSource.Contains("OwnedProcessCleanupFailed") -or
  -not $evidenceSource.Contains("do not copy, classify, hash or measure raw child text")) {
  throw "An accepted R3-R1 correction contract is no longer present."
}
Write-Output "R3-R1 identity/startup-cleanup/evidence preservation PASS"
Write-Output "Rise Pals candidate rehearsal harness suite PASS."
