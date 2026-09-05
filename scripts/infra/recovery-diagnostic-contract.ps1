Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# DIAG7 is a future-only evidence protocol. This file has no host operations.
$script:RisePalsRecoveryRecordKeys = @(
  "schemaVersion", "kind", "executionMode", "authorizationId", "invocationNonce", "repositoryHead",
  "parentScriptSha256", "childScriptSha256", "liveScriptSha256", "contractScriptSha256",
  "requestDigest", "sequence", "previousDigest", "evidenceDigest", "stage", "stageCompleted", "category", "exitCode", "hResult", "nativeCode",
  "cleanupCompleted", "invocationEnvelopeDigest", "entryAdapterDigest", "recordedAtUtc", "recordDigest"
)
$script:RisePalsRecoveryStageOrders = @{
  request = @("request-created")
  parent = @(
    "parent-entry", "arguments-validated", "request-write-attempted", "request-written",
    "request-reopened", "child-launch-attempted", "child-process-created",
    "child-started-marker-observed", "child-result-observed", "child-process-exited",
    "parent-result-written", "parent-result-reopened"
  )
  child = @("child-started", "dependencies-loaded", "recovery-preflight", "recovery-result")
  live = @(
    "live-process-entry", "raw-arguments-validated", "security-bootstrap-started",
    "security-bootstrap-complete", "contracts-loaded", "path-plan-validated",
    "administrator-boundary-validated", "live-state-write-attempted", "live-state-written"
  )
}
$script:RisePalsRecoveryCategories = @(
  "none", "uac-cancelled", "process-creation-failure", "wait-failure",
  "child-exit-before-marker", "evidence-invalid", "child-failure", "child-success",
  "dependency-failure", "security-bootstrap-failure", "contract-load-failure",
  "path-plan-failure", "administrator-failure", "state-persistence-failure",
  "parent-persistence-failure", "recovery-unverified", "bootstrap-process-not-created",
  "bootstrap-exit-before-marker", "bootstrap-marker-without-child",
  "child-script-exit-before-entry-marker", "child-script-failure", "entry-adapter-process-not-created",
  "entry-adapter-exit-before-marker", "invocation-envelope-invalid", "child-source-parse-failure",
  "child-parameter-binding-failure", "child-invocation-failure", "child-entry-marker-missing",
  "child-entry-marker-invalid", "entry-marker-persistence-failure", "entry-marker-reopen-failure",
  "entry-result-persistence-failure", "entry-result-reopen-failure", "controlled-unclassified-failure"
)

function Get-RisePalsRecoveryHash {
  param([Parameter(Mandatory = $true)][string]$LiteralPath)
  $stream = [IO.File]::OpenRead($LiteralPath)
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace("-", "").ToLowerInvariant()
  } finally { $stream.Dispose(); $algorithm.Dispose() }
}

function Get-RisePalsRecoveryRecordDigest {
  param([Parameter(Mandatory = $true)][object]$Record)
  $body = [ordered]@{}
  foreach ($key in $script:RisePalsRecoveryRecordKeys) {
    if ($key -ne "recordDigest") { $body[$key] = $Record.$key }
  }
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($body | ConvertTo-Json -Depth 4 -Compress))
    return ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
  } finally { $algorithm.Dispose() }
}

function ConvertFrom-RisePalsRecoveryJson {
  param([Parameter(Mandatory = $true)][string]$Json)
  $parsed = $Json | ConvertFrom-Json
  # Match decoded property identities, never raw substrings. Arrays/objects
  # are not part of this flat record schema and are rejected by type checks.
  $tokens = [regex]::Matches($Json, '"(?:[^"\\]|\\.)*"|[{}\[\]:]')
  $stack = [Collections.Generic.Stack[object]]::new()
  for ($index = 0; $index -lt $tokens.Count; $index++) {
    $token = $tokens[$index].Value
    if ($token -in @("{", "[")) {
      $stack.Push([pscustomobject]@{ kind = $token; keys = @{} })
    } elseif ($token -in @("}", "]")) {
      if ($stack.Count -eq 0) { throw "Recovery JSON nesting rejected." }
      [void]$stack.Pop()
    } elseif ($token.StartsWith('"') -and $index + 1 -lt $tokens.Count -and
      $tokens[$index + 1].Value -eq ":") {
      if ($stack.Count -eq 0 -or $stack.Peek().kind -ne "{") { throw "Recovery JSON property rejected." }
      $decoded = ("[" + $token + "]") | ConvertFrom-Json
      $key = [string]$decoded[0]
      if ($stack.Peek().keys.ContainsKey($key)) { throw "Recovery duplicate property rejected." }
      $stack.Peek().keys[$key] = $true
    }
  }
  if ($stack.Count -ne 0) { throw "Recovery JSON incomplete." }
  return $parsed
}

function Assert-RisePalsRecoveryRecord {
  param(
    [Parameter(Mandatory = $true)][object]$Record,
    [Parameter(Mandatory = $true)][object]$Binding,
    [AllowNull()][object]$Previous,
    [DateTimeOffset]$ValidationUtc = [DateTimeOffset]::UtcNow
  )
  $actual = @($Record.PSObject.Properties.Name)
  if ($actual.Count -ne $script:RisePalsRecoveryRecordKeys.Count -or
    @(Compare-Object $actual $script:RisePalsRecoveryRecordKeys).Count -ne 0) {
    throw "Recovery record property set rejected."
  }
  foreach ($key in @("schemaVersion", "kind", "executionMode", "authorizationId", "invocationNonce", "repositoryHead",
    "parentScriptSha256", "childScriptSha256", "liveScriptSha256", "contractScriptSha256",
    "stage", "category", "recordedAtUtc", "recordDigest")) {
    if ($Record.$key -isnot [string]) { throw "Recovery record string type rejected." }
  }
  if ($Record.schemaVersion -cne "rise-pals-recovery-diagnostic-v1" -or
    $Record.executionMode -cnotin @("Simulation", "Recovery", "Live") -or
    -not $script:RisePalsRecoveryStageOrders.ContainsKey($Record.kind) -or
    $Record.stage -cnotin $script:RisePalsRecoveryStageOrders[$Record.kind] -or
    $Record.category -cnotin $script:RisePalsRecoveryCategories -or
    $Record.invocationNonce -cnotmatch '^[a-f0-9]{32}$' -or
    $Record.repositoryHead -cnotmatch '^[a-f0-9]{40}$' -or
    $Record.authorizationId -cnotmatch '^RP-TURN-019-R4-(RECOVERY|LIVE)-[A-F0-9]{8}$') {
    throw "Recovery record vocabulary rejected."
  }
  foreach ($key in @("executionMode", "authorizationId", "invocationNonce", "repositoryHead", "parentScriptSha256",
    "childScriptSha256", "liveScriptSha256", "contractScriptSha256")) {
    if ($Record.$key -cne $Binding.$key) { throw "Recovery record binding rejected." }
  }
  foreach ($key in @("parentScriptSha256", "childScriptSha256", "liveScriptSha256", "contractScriptSha256", "recordDigest")) {
    if ($Record.$key -cnotmatch '^[a-f0-9]{64}$') { throw "Recovery hash type rejected." }
  }
  foreach ($key in @("requestDigest", "previousDigest", "evidenceDigest", "invocationEnvelopeDigest", "entryAdapterDigest")) {
    if ($null -ne $Record.$key -and ($Record.$key -isnot [string] -or $Record.$key -cnotmatch '^[a-f0-9]{64}$')) {
      throw "Recovery optional digest rejected."
    }
  }
  if (($Record.sequence -isnot [int] -and $Record.sequence -isnot [long]) -or
    $Record.sequence -lt 0 -or $Record.sequence -gt 32) { throw "Recovery sequence rejected." }
  foreach ($key in @("exitCode", "hResult", "nativeCode")) {
    if ($null -ne $Record.$key -and (($Record.$key -isnot [int] -and $Record.$key -isnot [long]) -or
      $Record.$key -lt [int]::MinValue -or $Record.$key -gt [int]::MaxValue)) {
      throw "Recovery numeric provenance rejected."
    }
  }
  if ($Record.stageCompleted -isnot [bool] -or
    (-not $Record.stageCompleted -and ($Record.category -ceq "none" -or $Record.cleanupCompleted -eq $true))) {
    throw "Recovery stage completion rejected."
  }
  if ($null -ne $Record.cleanupCompleted -and $Record.cleanupCompleted -isnot [bool]) {
    throw "Recovery cleanup type rejected."
  }
  $time = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParseExact($Record.recordedAtUtc, "o", [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::None, [ref]$time) -or $time.Offset -ne [TimeSpan]::Zero -or
    ($ValidationUtc - $time).TotalSeconds -gt 300 -or ($time - $ValidationUtc).TotalSeconds -gt 30) {
    throw "Recovery timestamp rejected."
  }
  if ($Record.kind -eq "request") {
    if ($Record.sequence -ne 0 -or $null -ne $Previous -or $null -ne $Record.requestDigest -or
      $null -ne $Record.previousDigest -or $Record.category -cne "none" -or
      $null -ne $Record.exitCode -or -not $Record.stageCompleted -or
      $null -ne $Record.hResult -or $null -ne $Record.nativeCode) { throw "Recovery request chain rejected." }
  } else {
    if ($Record.requestDigest -cne $Binding.recordDigest) { throw "Recovery request digest rejected." }
    $order = $script:RisePalsRecoveryStageOrders[$Record.kind]
    if ($null -eq $Previous) {
      if ($Record.sequence -ne 0 -or $null -ne $Record.previousDigest -or $Record.stage -cne $order[0]) {
        throw "Recovery initial stage rejected."
      }
    } else {
      $finalAfterFailure = $Record.kind -ceq "parent" -and $Record.stage -ceq "parent-result-written" -and
        $Previous.category -cne "none" -and -not $Previous.stageCompleted -and $Record.stageCompleted
      if ($Record.kind -cne $Previous.kind -or $Record.sequence -ne ($Previous.sequence + 1) -or
        $Record.previousDigest -cne $Previous.recordDigest -or
        $time -lt [DateTimeOffset]::ParseExact($Previous.recordedAtUtc, "o", [Globalization.CultureInfo]::InvariantCulture) -or
        (-not $finalAfterFailure -and ($Previous.category -cne "none" -or -not $Previous.stageCompleted -or
          [array]::IndexOf($order, $Record.stage) -ne ([array]::IndexOf($order, $Previous.stage) + 1)))) {
        throw "Recovery stage progression rejected."
      }
    }
  }
  if ($Record.kind -ne "child" -or $Record.stage -ne "recovery-result") {
    if ($null -ne $Record.cleanupCompleted) { throw "Non-result cleanup claim rejected." }
  } elseif ($Record.cleanupCompleted -eq $true -and
    ($Record.category -cne "child-success" -or $Record.exitCode -ne 0)) {
    throw "Recovery success evidence rejected."
  }
  if ($Record.recordDigest -cne (Get-RisePalsRecoveryRecordDigest $Record)) { throw "Recovery digest rejected." }
  return $Record
}

function New-RisePalsRecoveryRecord {
  param([object]$Binding, [string]$Kind, [string]$Stage, [AllowNull()][object]$Previous,
    [string]$Category = "none", [AllowNull()][object]$ExitCode,
    [AllowNull()][object]$CleanupCompleted, [bool]$StageCompleted = $true,
    [AllowNull()][object]$HResult, [AllowNull()][object]$NativeCode,
    [AllowNull()][object]$EvidenceDigest, [AllowNull()][object]$InvocationEnvelopeDigest,
    [AllowNull()][object]$EntryAdapterDigest)
  $record = [ordered]@{
    schemaVersion = "rise-pals-recovery-diagnostic-v1"
    kind = $Kind
    executionMode = $Binding.executionMode
    authorizationId = $Binding.authorizationId
    invocationNonce = $Binding.invocationNonce
    repositoryHead = $Binding.repositoryHead
    parentScriptSha256 = $Binding.parentScriptSha256
    childScriptSha256 = $Binding.childScriptSha256
    liveScriptSha256 = $Binding.liveScriptSha256
    contractScriptSha256 = $Binding.contractScriptSha256
    requestDigest = if ($Kind -eq "request") { $null } else { $Binding.recordDigest }
    sequence = if ($null -eq $Previous) { 0 } else { [int]$Previous.sequence + 1 }
    previousDigest = if ($null -eq $Previous) { $null } else { $Previous.recordDigest }
    evidenceDigest = $EvidenceDigest
    stage = $Stage
    stageCompleted = $StageCompleted
    category = $Category
    exitCode = $ExitCode
    hResult = $HResult
    nativeCode = $NativeCode
    cleanupCompleted = $CleanupCompleted
    invocationEnvelopeDigest = $InvocationEnvelopeDigest
    entryAdapterDigest = $EntryAdapterDigest
    recordedAtUtc = [DateTimeOffset]::UtcNow.ToString("o")
    recordDigest = ""
  }
  $record.recordDigest = Get-RisePalsRecoveryRecordDigest $record
  return Assert-RisePalsRecoveryRecord ([pscustomobject]$record) $Binding $Previous
}

function Assert-RisePalsRecoveryFileBoundary {
  param([string]$Path, [string]$Directory)
  $root = [IO.Path]::GetFullPath($Directory)
  $exact = [IO.Path]::GetFullPath($Path)
  if ($root.StartsWith("C:\RisePals", [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetDirectoryName($exact) -cne $root -or
    [IO.Path]::GetFileName($root) -cnotmatch '^diag7-[a-f0-9]{32}$') { throw "Recovery evidence path rejected." }
  $ancestor = $root
  while ($ancestor) {
    $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction Stop
    if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      throw "Recovery evidence ancestor rejected."
    }
    $ancestor = [IO.Path]::GetDirectoryName($ancestor)
  }
  return $exact
}

function Write-RisePalsRecoveryRecord {
  param([object]$Record, [string]$Directory)
  $name = "{0}-{1:D2}.json" -f $Record.kind, [int]$Record.sequence
  $path = Assert-RisePalsRecoveryFileBoundary (Join-Path $Directory $name) $Directory
  $temporary = $path + ".tmp"
  if ([IO.File]::Exists($path) -or [IO.File]::Exists($temporary)) { throw "Recovery evidence replay rejected." }
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Record | ConvertTo-Json -Depth 4 -Compress))
  $stream = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
  try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
  [IO.File]::Move($temporary, $path)
  return $path
}

function Read-RisePalsRecoveryRecord {
  param([string]$Path, [string]$Directory, [object]$Binding, [AllowNull()][object]$Previous,
    [DateTimeOffset]$ValidationUtc = [DateTimeOffset]::UtcNow)
  $exact = Assert-RisePalsRecoveryFileBoundary $Path $Directory
  $item = Get-Item -LiteralPath $exact -Force -ErrorAction Stop
  if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
    $item.Length -eq 0 -or $item.Length -gt 16384) { throw "Recovery evidence object rejected." }
  $bytes = [IO.File]::ReadAllBytes($exact)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
    throw "Recovery UTF-8 BOM rejected."
  }
  $record = ConvertFrom-RisePalsRecoveryJson ([Text.UTF8Encoding]::new($false, $true).GetString($bytes))
  [void](Assert-RisePalsRecoveryRecord $record $Binding $Previous $ValidationUtc)
  if ($item.Name -cne ("{0}-{1:D2}.json" -f $record.kind, [int]$record.sequence)) {
    throw "Recovery filename sequence rejected."
  }
  return $record
}
