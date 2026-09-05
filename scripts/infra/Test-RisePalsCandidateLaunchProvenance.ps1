[CmdletBinding()]
param([string]$RepositoryRoot = "C:\Codex PC SG2\Jeff\risepals")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -cne "Desktop" -or $PSVersionTable.PSVersion.Major -ne 5 -or
  $PSVersionTable.PSVersion.Minor -ne 1) { throw "Windows PowerShell 5.1 required." }
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Launch provenance tests must not be elevated."
}
. (Join-Path $RepositoryRoot "scripts\infra\candidate-rehearsal-contract.ps1")
. (Join-Path $RepositoryRoot "scripts\infra\candidate-rehearsal-result.ps1")
. (Join-Path $RepositoryRoot "scripts\infra\candidate-rehearsal-transport.ps1")

# The harness calls pure constructors/validators only, never the parent launcher.
function Start-Process { throw "Process launch forbidden in provenance fixtures." }
function Check([bool]$Condition, [string]$Label) {
  if (-not $Condition) { throw "Launch provenance assertion failed: $Label" }
}
function Reject([scriptblock]$Action) {
  $rejected = $false
  try { $null = & $Action } catch { $rejected = $true }
  Check $rejected "invalid fixture must fail closed"
}
function Copy-Value([object]$Value) { return ($Value | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json) }
function Fixture-Record([AllowNull()][object]$Exception) {
  return [pscustomobject]@{
    Exception = $Exception
    FullyQualifiedErrorId = "InvalidOperationException,Microsoft.PowerShell.Commands.StartProcessCommand"
    CategoryInfo = [pscustomobject]@{ Category = "InvalidOperation"; Reason = "InvalidOperationException" }
    TargetObject = "DO-NOT-PERSIST-target"
    ErrorDetails = [pscustomobject]@{ Message = "DO-NOT-PERSIST-details"; RecommendedAction = "DO-NOT-PERSIST-action" }
    ScriptStackTrace = "DO-NOT-PERSIST-stack"
    InvocationInfo = "DO-NOT-PERSIST-arguments"
  }
}
function Diagnostic([object]$Evidence) {
  $code = Get-RisePalsCandidateSanitizedLaunchFailureCode -NativeErrorCode $Evidence.nativeErrorCode
  $disposition = if ($Evidence.nativeErrorCode -eq 1223) { "cancelled" } else { "launch-failure" }
  return New-RisePalsCandidateLaunchDiagnostic -LaunchAttempted $true -ProcessCreated $false `
    -LaunchDisposition $disposition -SanitizedLaunchFailureCode $code `
    -NativeErrorCode $Evidence.nativeErrorCode -HResult $Evidence.hResult `
    -ExceptionDepth $Evidence.exceptionDepth -Provenance $Evidence.provenance `
    -LauncherExecutableExists $true -LauncherSignatureStatus valid -LaunchVerb None `
    -ArgumentCount 2 -CanonicalArgumentDigest ("a" * 64)
}

$cancel = [ComponentModel.Win32Exception]::new(1223)
$invalid = [InvalidOperationException]::new("DO-NOT-PERSIST-message")
$wrapped = [InvalidOperationException]::new("DO-NOT-PERSIST-wrapper", $cancel)
$realRecord = [Management.Automation.ErrorRecord]::new($wrapped,
  "InvalidOperationException,Microsoft.PowerShell.Commands.StartProcessCommand",
  [Management.Automation.ErrorCategory]::InvalidOperation, "DO-NOT-PERSIST-target")
$cases = @(
  @{ name = "top-level-1223"; args = @{ Exception = $cancel }; native = 1223; depth = 1; source = "top-level-exception" },
  @{ name = "wrapped-1223"; args = @{ Exception = $wrapped }; native = 1223; depth = 2; source = "inner-exception" },
  @{ name = "non-cancellation"; args = @{ Exception = [ComponentModel.Win32Exception]::new(5) }; native = 5; depth = 1; source = "top-level-exception" },
  @{ name = "invalid-operation"; args = @{ Exception = $invalid }; native = $null; depth = 1; source = "unavailable" },
  @{ name = "runtime-wrapper"; args = @{ Exception = [Management.Automation.RuntimeException]::new("DO-NOT-PERSIST-runtime", $invalid) }; native = $null; depth = 2; source = "unavailable" },
  @{ name = "real-error-record-inner"; args = @{ ErrorRecord = $realRecord }; native = 1223; depth = 2; source = "error-record-inner-exception" },
  @{ name = "null-record-exception"; args = @{ ErrorRecord = (Fixture-Record $null) }; native = $null; depth = 0; source = "unavailable" },
  @{ name = "missing-record"; args = @{}; native = $null; depth = 0; source = "unavailable" }
)
foreach ($case in $cases) {
  $parameters = $case.args
  $e = Get-RisePalsCandidateLaunchExceptionEvidence @parameters
  Check ($e.nativeErrorCode -eq $case.native -and $e.exceptionDepth -eq $case.depth -and
    $e.provenance.nativeCodeSource -ceq $case.source) $case.name
  $d = Diagnostic $e
  [void](Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $d)
  Check (($d | ConvertTo-Json -Depth 10 -Compress) -notmatch "DO-NOT-PERSIST|Win32Exception|System\.") "privacy"
  Write-Output ("PASS " + $case.name)
}
$record = Fixture-Record $invalid
$record.FullyQualifiedErrorId = "DO-NOT-PERSIST-unknown-id"
$record.CategoryInfo.Reason = "DO-NOT-PERSIST-unknown-type"
$e = Get-RisePalsCandidateLaunchExceptionEvidence -ErrorRecord $record
Check ($e.provenance.fullyQualifiedErrorDisposition -ceq "other-controlled" -and
  $e.provenance.errorReasonDisposition -ceq "other-controlled") "unknown fields closed"
$record.CategoryInfo = $null
$e = Get-RisePalsCandidateLaunchExceptionEvidence -ErrorRecord $record
Check ($e.provenance.errorCategoryDisposition -ceq "unavailable" -and
  $e.provenance.errorReasonDisposition -ceq "unavailable") "null category"
Write-Output "PASS unknown-id-reason-and-null-category"

$deep = $cancel
for ($i = 0; $i -lt 4; $i++) { $deep = [InvalidOperationException]::new("DO-NOT-PERSIST-depth", $deep) }
$e = Get-RisePalsCandidateLaunchExceptionEvidence -Exception $deep
Check ($e.exceptionDepth -eq 4 -and $null -eq $e.nativeErrorCode) "bounded depth excludes fifth native code"
foreach ($value in @("1223", 1223.5, $true, [int64]::MaxValue)) {
  $shape = [pscustomobject]@{ NativeErrorCode = $value; HResult = $value; InnerException = $null }
  $e = Get-RisePalsCandidateLaunchExceptionEvidence -ErrorRecord (Fixture-Record $shape)
  Check ($null -eq $e.nativeErrorCode -and $null -eq $e.hResult) "non integral/out-of-range ignored"
}
$shape = [pscustomobject]@{ NativeErrorCode = 5; HResult = -2146233079; InnerException = $cancel }
$e = Get-RisePalsCandidateLaunchExceptionEvidence -Exception $shape
Check ($e.nativeErrorCode -eq 1223 -and $e.provenance.nativeCodeSource -ceq "inner-exception") "native cancellation precedence"
$shape.InnerException = [ComponentModel.Win32Exception]::new(31)
$e = Get-RisePalsCandidateLaunchExceptionEvidence -Exception $shape
Check ($e.nativeErrorCode -eq 5) "first native precedence without cancellation"
$e = Get-RisePalsCandidateLaunchExceptionEvidence -Exception ([Exception]::new("DO-NOT-PERSIST-unknown"))
Check ($e.provenance.exceptionTypeDisposition -ceq "other-controlled") "unknown exception type"
Write-Output "PASS bounded-types-depth-and-native-precedence"

$record = Fixture-Record $invalid
$e = Get-RisePalsCandidateLaunchExceptionEvidence -ErrorRecord $record
$diagnostic = Diagnostic $e
Check ($diagnostic.sanitizedLaunchFailureCode -ceq "launcher-exception-unknown" -and
  $e.provenance.exceptionTypeDisposition -ceq "invalid-operation-exception" -and
  $e.provenance.fullyQualifiedErrorDisposition -ceq "start-process-failed") "no guessed native cause"
foreach ($field in $script:RisePalsCandidateLaunchProvenanceProperties) {
  $bad = Copy-Value $diagnostic
  $bad.provenance.PSObject.Properties.Remove($field)
  Reject { Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $bad }
  $bad = Copy-Value $diagnostic
  $bad.provenance.$field = @("wrong-type")
  Reject { Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $bad }
}
foreach ($change in @("extra", "enum", "digest", "negative", "overflow", "source", "presence")) {
  $bad = Copy-Value $diagnostic
  switch ($change) {
    "extra" { $bad.provenance | Add-Member -NotePropertyName rawMessage -NotePropertyValue "DO-NOT-PERSIST" }
    "enum" { $bad.provenance.errorCategoryDisposition = "unrecognized" }
    "digest" { $bad.provenance.provenanceDigest = "f" * 64 }
    "negative" { $bad.provenance.examinedExceptionCount = -1 }
    "overflow" { $bad.provenance.examinedExceptionCount = 5 }
    "source" { $bad.provenance.nativeCodeSource = "error-record-exception" }
    "presence" { $bad.provenance.errorRecordPresent = $false }
  }
  if ($change -ne "digest") { $bad.provenance.provenanceDigest = Get-RisePalsCandidateLaunchProvenanceDigest -Provenance $bad.provenance }
  $bad.diagnosticDigest = Get-RisePalsCandidateLaunchDiagnosticDigest -Diagnostic $bad
  Reject { Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $bad }
}
$json = $diagnostic | ConvertTo-Json -Depth 10 -Compress
foreach ($duplicate in @('"errorRecordPresent":true,"errorRecordPresent":true', '"errorRecordPresent":true,"\u0065rrorRecordPresent":true')) {
  $badJson = $json.Replace('"errorRecordPresent":true', $duplicate)
  Reject { ConvertFrom-RisePalsCandidateUniqueJson -Json $badJson }
}
[void](Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic (ConvertFrom-RisePalsCandidateUniqueJson -Json $json))
Write-Output "PASS exact-provenance-schema-digest-duplicates-and-privacy"

$historical = Copy-Value $diagnostic
$historical.PSObject.Properties.Remove("provenance")
$historical.schemaVersion = "rise-pals-candidate-launch-diagnostic-v1"
$historical.diagnosticDigest = Get-RisePalsCandidateLaunchDiagnosticDigest -Diagnostic $historical
[void](Assert-RisePalsCandidateLaunchDiagnostic -Diagnostic $historical)
Check ($historical.sanitizedLaunchFailureCode -ceq "launcher-exception-unknown" -and
  $historical.hResult -eq -2146233079 -and -not $historical.processCreated) "historical LIVE10-shaped meaning"
Write-Output "PASS historical-v1-meaning-preserved"
Write-Output "Launch provenance synthetic suite PASS; UAC=0; elevatedChildren=0; hostMutation=0; temporaryObjects=0"
