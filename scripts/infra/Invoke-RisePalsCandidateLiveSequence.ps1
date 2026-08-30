[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$RepositoryHead,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce,
  [Parameter(Mandatory = $true)][ValidatePattern("^RP-TURN-019-R4-LIVE-[A-F0-9]{8}$")]
  [string]$FutureAuthorizationId,
  [Parameter(Mandatory = $true)][string]$CandidateExecutableSource,
  [Parameter(Mandatory = $true)][string]$NodeExecutableSource,
  [Parameter(Mandatory = $true)][string]$StructuredStatePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")
. (Join-Path $PSScriptRoot "candidate-rehearsal-contract.ps1")
. (Join-Path $PSScriptRoot "candidate-rehearsal-result.ps1")

function Invoke-RisePalsCandidateSc {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)

  $sc = Join-Path $env:SystemRoot "System32\sc.exe"
  $process = Start-Process -FilePath $sc -ArgumentList $Arguments -WindowStyle Hidden `
    -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    throw "A candidate SCM operation failed with a nonzero exit code."
  }
}

function Set-RisePalsCandidatePreshutdownTimeout {
  param(
    [Parameter(Mandatory = $true)][string]$ServiceName,
    [Parameter(Mandatory = $true)][uint32]$Milliseconds
  )

  if (-not ("RisePalsCandidateNative.ServiceConfiguration" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
namespace RisePalsCandidateNative {
  public sealed class PreshutdownRegistration {
    public uint TimeoutMilliseconds { get; set; }
    public bool AcceptsPreshutdown { get; set; }
  }
  public static class ServiceConfiguration {
    private const uint SERVICE_CHANGE_CONFIG = 0x0002;
    private const uint SERVICE_QUERY_CONFIG = 0x0001;
    private const uint SERVICE_QUERY_STATUS = 0x0004;
    private const uint SERVICE_CONFIG_PRESHUTDOWN_INFO = 7;
    private const uint SERVICE_ACCEPT_PRESHUTDOWN = 0x00000100;
    private const int SC_STATUS_PROCESS_INFO = 0;
    [StructLayout(LayoutKind.Sequential)]
    private struct SERVICE_PRESHUTDOWN_INFO { public uint dwPreshutdownTimeout; }
    [StructLayout(LayoutKind.Sequential)]
    private struct SERVICE_STATUS_PROCESS {
      public uint dwServiceType;
      public uint dwCurrentState;
      public uint dwControlsAccepted;
      public uint dwWin32ExitCode;
      public uint dwServiceSpecificExitCode;
      public uint dwCheckPoint;
      public uint dwWaitHint;
      public uint dwProcessId;
      public uint dwServiceFlags;
    }
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr OpenSCManager(string machineName, string databaseName, uint access);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr OpenService(IntPtr manager, string serviceName, uint access);
    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool ChangeServiceConfig2(IntPtr service, uint infoLevel, ref SERVICE_PRESHUTDOWN_INFO info);
    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool QueryServiceConfig2(IntPtr service, uint infoLevel, IntPtr buffer, uint bufferSize, out uint bytesNeeded);
    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool QueryServiceStatusEx(IntPtr service, int infoLevel, IntPtr buffer, uint bufferSize, out uint bytesNeeded);
    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool CloseServiceHandle(IntPtr handle);
    public static void Set(string serviceName, uint milliseconds) {
      IntPtr manager = OpenSCManager(null, null, 0x0001);
      if (manager == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
      try {
        IntPtr service = OpenService(manager, serviceName, SERVICE_CHANGE_CONFIG);
        if (service == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        try {
          var info = new SERVICE_PRESHUTDOWN_INFO { dwPreshutdownTimeout = milliseconds };
          if (!ChangeServiceConfig2(service, SERVICE_CONFIG_PRESHUTDOWN_INFO, ref info))
            throw new Win32Exception(Marshal.GetLastWin32Error());
        } finally { CloseServiceHandle(service); }
      } finally { CloseServiceHandle(manager); }
    }
    public static PreshutdownRegistration Query(string serviceName) {
      IntPtr manager = OpenSCManager(null, null, 0x0001);
      if (manager == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
      try {
        IntPtr service = OpenService(manager, serviceName, SERVICE_QUERY_CONFIG | SERVICE_QUERY_STATUS);
        if (service == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        try {
          int configSize = Marshal.SizeOf(typeof(SERVICE_PRESHUTDOWN_INFO));
          IntPtr configBuffer = Marshal.AllocHGlobal(configSize);
          int statusSize = Marshal.SizeOf(typeof(SERVICE_STATUS_PROCESS));
          IntPtr statusBuffer = Marshal.AllocHGlobal(statusSize);
          try {
            uint needed;
            if (!QueryServiceConfig2(service, SERVICE_CONFIG_PRESHUTDOWN_INFO, configBuffer, (uint)configSize, out needed))
              throw new Win32Exception(Marshal.GetLastWin32Error());
            if (!QueryServiceStatusEx(service, SC_STATUS_PROCESS_INFO, statusBuffer, (uint)statusSize, out needed))
              throw new Win32Exception(Marshal.GetLastWin32Error());
            var config = (SERVICE_PRESHUTDOWN_INFO)Marshal.PtrToStructure(configBuffer, typeof(SERVICE_PRESHUTDOWN_INFO));
            var status = (SERVICE_STATUS_PROCESS)Marshal.PtrToStructure(statusBuffer, typeof(SERVICE_STATUS_PROCESS));
            return new PreshutdownRegistration {
              TimeoutMilliseconds = config.dwPreshutdownTimeout,
              AcceptsPreshutdown = (status.dwControlsAccepted & SERVICE_ACCEPT_PRESHUTDOWN) != 0
            };
          } finally {
            Marshal.FreeHGlobal(configBuffer);
            Marshal.FreeHGlobal(statusBuffer);
          }
        } finally { CloseServiceHandle(service); }
      } finally { CloseServiceHandle(manager); }
    }
  }
}
"@
  }
  [RisePalsCandidateNative.ServiceConfiguration]::Set($ServiceName, $Milliseconds)
}

function Get-RisePalsCandidatePreshutdownRegistration {
  param([Parameter(Mandatory = $true)][string]$ServiceName)

  return [RisePalsCandidateNative.ServiceConfiguration]::Query($ServiceName)
}

function Write-RisePalsCandidateLiveState {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Status,
    [Parameter(Mandatory = $true)][string[]]$CompletedStages,
    [AllowNull()][string]$FailedStage,
    [AllowNull()][string]$FailureCode,
    [Parameter(Mandatory = $true)][bool]$CleanupCompleted,
    [Parameter(Mandatory = $true)][object]$FinalState
  )

  $state = [ordered]@{
    schemaVersion = "rise-pals-candidate-live-state-v1"
    status = $Status
    completedStages = @($CompletedStages)
    failedStage = if ([string]::IsNullOrWhiteSpace($FailedStage)) { $null } else { $FailedStage }
    sanitizedFailureCode = if ([string]::IsNullOrWhiteSpace($FailureCode)) {
      $null
    } else {
      $FailureCode
    }
    cleanupCompleted = $CleanupCompleted
    finalState = $FinalState
  }
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
    (($state | ConvertTo-Json -Depth 6) + "`n")
  )
  $exact = [IO.Path]::GetFullPath($Path)
  $stream = [IO.FileStream]::new(
    $exact,
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
}

function Get-RisePalsCandidateNodeMetadata {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][object]$Contract,
    [switch]$RequireSourcePath
  )

  $exact = Assert-RisePalsCandidateFilePin -Path $Path `
    -ExpectedLength ([int64]$Contract.executableLength) `
    -ExpectedSha256 ([string]$Contract.executableSha256) -Label "Node executable"
  $signature = Get-AuthenticodeSignature -LiteralPath $exact
  $metadata = [pscustomobject][ordered]@{
    path = $exact
    version = [string]$Contract.version
    executableLength = [int64](Get-Item -LiteralPath $exact -Force).Length
    executableSha256 = Get-RisePalsSha256 -LiteralPath $exact
    authenticode = [string]$signature.Status
    signerSubject = if ($null -eq $signature.SignerCertificate) {
      ""
    } else {
      [string]$signature.SignerCertificate.Subject
    }
    signerThumbprint = if ($null -eq $signature.SignerCertificate) {
      ""
    } else {
      [string]$signature.SignerCertificate.Thumbprint
    }
  }
  Assert-RisePalsCandidateNodeMetadata -Metadata $metadata -Contract $Contract `
    -RequireSourcePath:$RequireSourcePath
  $versionOutput = @(& $exact --version)
  if ($LASTEXITCODE -ne 0 -or $versionOutput.Count -ne 1) {
    throw "The pinned Node executable did not report one version."
  }
  $metadata.version = ([string]$versionOutput[0]).Trim()
  Assert-RisePalsCandidateNodeMetadata -Metadata $metadata -Contract $Contract `
    -RequireSourcePath:$RequireSourcePath
  return $metadata
}

function Get-RisePalsCandidateRetainedSnapshot {
  param([Parameter(Mandatory = $true)][object]$Contract)

  $result = @()
  foreach ($expected in @($Contract.retainedServices | Sort-Object serviceName)) {
    $name = [string]$expected.serviceName
    $service = @(Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction Stop)
    if ($service.Count -ne 1) {
      throw "An exact retained service is missing or ambiguous."
    }
    $executable = Get-Item -LiteralPath ([string]$expected.executablePath) -Force
    if (($executable.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "A retained service executable is a reparse point."
    }
    $result += [pscustomobject][ordered]@{
      name = [string]$service[0].Name
      serviceType = [string]$service[0].ServiceType
      startName = [string]$service[0].StartName
      pathName = [string]$service[0].PathName
      executablePath = [string]$executable.FullName
      executableLength = [int64]$executable.Length
      executableSha256 = Get-RisePalsSha256 -LiteralPath $executable.FullName
      state = [string]$service[0].State
      startMode = [string]$service[0].StartMode
      processId = [int]$service[0].ProcessId
    }
  }
  return $result
}

function Assert-RisePalsCandidateExactAcl {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][Security.AccessControl.FileSystemRights]$CandidateRights,
    [Parameter(Mandatory = $true)][string]$CandidateSid
  )

  $acl = Get-Acl -LiteralPath $Path
  if (-not $acl.AreAccessRulesProtected) {
    throw "A candidate ACL still inherits unexpected access."
  }
  $rules = @($acl.GetAccessRules(
    $true,
    $false,
    [Security.Principal.SecurityIdentifier]
  ))
  $expected = [ordered]@{
    "S-1-5-18" = [Security.AccessControl.FileSystemRights]::FullControl
    "S-1-5-32-544" = [Security.AccessControl.FileSystemRights]::FullControl
    $CandidateSid = $CandidateRights
  }
  if ($rules.Count -ne 3) {
    throw "A candidate ACL has an unexpected ACE count."
  }
  foreach ($rule in $rules) {
    $sid = [string]$rule.IdentityReference.Value
    if (-not $expected.Contains($sid) -or $rule.IsInherited -or
      $rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
      [int]$rule.FileSystemRights -ne [int]$expected[$sid]) {
      throw "A candidate ACL contains an unexpected principal or right."
    }
  }
}

function Wait-RisePalsCandidateServiceState {
  param(
    [Parameter(Mandatory = $true)][string]$ExpectedState,
    [int]$TimeoutSeconds = 30
  )

  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  $samples = @()
  do {
    $service = Get-CimInstance Win32_Service `
      -Filter "Name='$script:RisePalsCandidateServiceName'" -ErrorAction Stop
    $samples += [pscustomobject]@{
      state = [string]$service.State
      checkpoint = [uint32]$service.CheckPoint
      waitHint = [uint32]$service.WaitHint
      processId = [int]$service.ProcessId
    }
    if ($service.State -eq $ExpectedState) {
      return [pscustomobject]@{ service = $service; samples = $samples }
    }
    Start-Sleep -Milliseconds 100
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "The candidate service did not reach its bounded expected state."
}

function Start-RisePalsCandidateProbe {
  param(
    [Parameter(Mandatory = $true)][string]$NodePath,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
    [Parameter(Mandatory = $true)][ValidateSet("ready", "stream", "new-work", "crash")]
    [string]$Mode,
    [Parameter(Mandatory = $true)][string]$Name,
    [switch]$FirstByte
  )

  $probe = Join-Path $PSScriptRoot "candidate-rehearsal-probe.mjs"
  $result = Join-Path $EvidenceDirectory ($Name + ".json")
  $firstBytePath = Join-Path $EvidenceDirectory ($Name + ".first-byte")
  foreach ($path in @($result, $firstBytePath)) {
    if ([IO.File]::Exists($path)) {
      throw "A candidate probe path is not fresh."
    }
  }
  $path = switch ($Mode) {
    "ready" { "/health/ready" }
    "stream" { "/health/stream" }
    "new-work" { "/health/stream" }
    "crash" { "/fixture/crash" }
  }
  $arguments = @(
    ('"' + $probe + '"'),
    "--mode",
    $Mode,
    "--url",
    ("http://127.0.0.1:3100" + $path),
    "--result",
    ('"' + $result + '"')
  )
  if ($FirstByte) {
    $arguments += @("--first-byte", ('"' + $firstBytePath + '"'))
  }
  $process = Start-Process -FilePath $NodePath -ArgumentList $arguments `
    -WindowStyle Hidden -PassThru
  return [pscustomobject]@{
    process = $process
    resultPath = $result
    firstBytePath = $firstBytePath
  }
}

function Complete-RisePalsCandidateProbe {
  param(
    [Parameter(Mandatory = $true)][object]$Probe,
    [int]$TimeoutSeconds = 15
  )

  if (-not $Probe.process.WaitForExit($TimeoutSeconds * 1000) -or
    $Probe.process.ExitCode -ne 0 -or -not [IO.File]::Exists($Probe.resultPath)) {
    throw "A candidate loopback probe failed."
  }
  $result = [Text.UTF8Encoding]::new($false, $true).GetString(
    [IO.File]::ReadAllBytes($Probe.resultPath)
  ) | ConvertFrom-Json
  [IO.File]::Delete($Probe.resultPath)
  if ([IO.File]::Exists($Probe.firstBytePath)) {
    [IO.File]::Delete($Probe.firstBytePath)
  }
  return $result
}

function Wait-RisePalsCandidateProbeMarker {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$TimeoutSeconds = 10
  )

  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  while (-not [IO.File]::Exists($Path)) {
    if ([DateTime]::UtcNow -ge $deadline) {
      throw "The candidate first-byte marker was not created in time."
    }
    Start-Sleep -Milliseconds 50
  }
}

function Set-RisePalsCandidateFixtureMode {
  param(
    [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Configuration,
    [Parameter(Mandatory = $true)][string]$Mode,
    [Parameter(Mandatory = $true)][string]$ConfigPath
  )

  $Configuration.arguments = @($Mode, "--fixture-http-port", "3100")
  [IO.File]::WriteAllText(
    $ConfigPath,
    (($Configuration | ConvertTo-Json -Depth 5) + "`n"),
    [Text.UTF8Encoding]::new($false)
  )
}

function Get-RisePalsCandidateSanitizedEvents {
  param([Parameter(Mandatory = $true)][string]$LogDirectory)

  $events = @()
  foreach ($file in @(Get-ChildItem -LiteralPath $LogDirectory -File -Force | Where-Object {
    $_.Name -match "^service-host(\.[1-3])?\.jsonl$"
  } | Sort-Object Name)) {
    foreach ($line in [IO.File]::ReadAllLines($file.FullName, [Text.UTF8Encoding]::new($false, $true))) {
      if ($line.Length -gt 512) {
        throw "A sanitized candidate evidence event exceeded its fixed bound."
      }
      $event = $line | ConvertFrom-Json
      $properties = @($event.PSObject.Properties.Name | Sort-Object)
      $expected = @("count", "eventName", "outcome", "stream", "timestampUtc") | Sort-Object
      if (@(Compare-Object -ReferenceObject $expected -DifferenceObject $properties).Count -ne 0) {
        throw "A candidate evidence event contains an unexpected field."
      }
      $events += $event
    }
  }
  return $events
}

$repository = Get-RisePalsCandidateRepositoryRoot
$contract = Get-RisePalsCandidateContract -RepositoryRoot $repository
$powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$paths = New-RisePalsCandidatePathPlan -Contract $contract -Nonce $InvocationNonce
$structuredState = [IO.Path]::GetFullPath($StructuredStatePath)
$stateParent = [IO.Path]::GetDirectoryName($structuredState)
$expectedStateParent = [IO.Path]::GetFullPath((Join-Path (
  Join-Path ([IO.Path]::GetTempPath()) "risepals-candidate-launcher"
) ("invocation-" + $InvocationNonce)))
if (-not $stateParent.Equals($expectedStateParent, [StringComparison]::OrdinalIgnoreCase) -or
  -not [IO.Directory]::Exists($stateParent) -or
  -not [IO.Path]::GetFileName($structuredState).Equals(
    "live-state.json",
    [StringComparison]::OrdinalIgnoreCase
  )) {
  throw "The live structured-state path is outside the exact launcher boundary."
}
Assert-RisePalsAdministrator
if (-not $PSCmdlet.ShouldProcess(
  $script:RisePalsCandidateServiceName,
  ("Run separately authorized candidate rehearsal {0}" -f $FutureAuthorizationId)
)) {
  Write-Output "Rise Pals candidate live sequence dry-run PASS"
  return
}

$completed = @()
$failedStage = $null
$failureCode = $null
$cleanupCompleted = $false
$sequenceSucceeded = $false
$createdService = $false
$stagingTaskRoot = [IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($paths.stagedHost))
$rehearsalTaskRoot = [IO.Path]::GetDirectoryName($paths.configDirectory)
$logTaskRoot = $paths.logDirectory
$finalState = New-RisePalsCandidateFinalState -CandidateState "Unknown" `
  -CandidateStartMode "Unknown"

try {
  $failedStage = "preflight"
  $git = "C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
  if (-not [IO.File]::Exists($git)) {
    throw "The pinned repository Git executable is absent."
  }
  $safe = "safe.directory=C:/Codex PC SG2/Jeff/risepals"
  $currentHead = (& $git -c $safe -C $repository rev-parse HEAD).Trim()
  $currentBranch = (& $git -c $safe -C $repository branch --show-current).Trim()
  $currentMain = (& $git -c $safe -C $repository rev-parse main).Trim()
  $currentStatus = @(& $git -c $safe -C $repository status --porcelain --untracked-files=all)
  $gitStatusExit = $LASTEXITCODE
  $null = & $git -c $safe -C $repository check-ignore -q -- .env.local
  $envLocalIgnored = $LASTEXITCODE -eq 0
  $envLocalTracked = @(& $git -c $safe -C $repository ls-files -- .env.local).Count -ne 0
  if ($gitStatusExit -ne 0 -or $currentHead -ne $RepositoryHead -or
    $currentBranch -ne $contract.repository.branch -or
    $currentMain -ne $contract.repository.mainCommit -or $currentStatus.Count -ne 0 -or
    -not $envLocalIgnored -or $envLocalTracked) {
    throw "The elevated candidate preflight no longer matches the exact clean reviewed repository."
  }
  [void](Assert-RisePalsCandidateFilePin -Path $CandidateExecutableSource `
    -ExpectedLength ([int64]$contract.prototype.executableLength) `
    -ExpectedSha256 ([string]$contract.prototype.executableSha256) `
    -Label "Candidate executable")
  $signature = Get-AuthenticodeSignature -LiteralPath $CandidateExecutableSource
  if ($signature.Status.ToString() -ne "NotSigned") {
    throw "The candidate executable signature state differs from the accepted prototype."
  }
  $nodeSource = [IO.Path]::GetFullPath($NodeExecutableSource)
  [void](Get-RisePalsCandidateNodeMetadata -Path $nodeSource -Contract $contract.node `
    -RequireSourcePath)
  $candidateService = Get-CimInstance Win32_Service `
    -Filter "Name='$script:RisePalsCandidateServiceName'" -ErrorAction SilentlyContinue
  if ($null -ne $candidateService) {
    throw "The candidate service name already exists."
  }
  $unexpectedServices = @(Get-CimInstance Win32_Service -Filter "Name LIKE 'RisePals%'" | Where-Object {
    $_.Name -notin $script:RisePalsCandidateRetainedServices
  })
  if ($unexpectedServices.Count -ne 0) {
    throw "An unexpected Rise Pals service exists."
  }
  $retainedBefore = Get-RisePalsCandidateRetainedSnapshot -Contract $contract
  Assert-RisePalsCandidateRetainedSnapshot -Snapshot $retainedBefore -Contract $contract
  $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object {
    $_.LocalPort -in @($contract.network.relevantPorts)
  })
  if ($listeners.Count -ne 0) {
    throw "A relevant listener exists before candidate staging."
  }
  $rootProcesses = @(Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath.StartsWith(
      $script:RisePalsCandidateRoot + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase
    )
  })
  if ($rootProcesses.Count -ne 0) {
    throw "A process is already executing beneath the Rise Pals root."
  }
  foreach ($rootPath in @(
    [string]$contract.paths.stagingRoot,
    [string]$contract.paths.rehearsalRoot,
    [string]$contract.paths.logRoot
  )) {
    if ([IO.Directory]::Exists($rootPath)) {
      $rootItem = Get-Item -LiteralPath $rootPath -Force
      if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "An authorized candidate root is a reparse point."
      }
    }
  }
  foreach ($taskPath in @($stagingTaskRoot, $rehearsalTaskRoot, $logTaskRoot)) {
    if ([IO.Directory]::Exists($taskPath) -or [IO.File]::Exists($taskPath)) {
      throw "A nonce-scoped candidate task path already exists."
    }
  }
  $completed += "preflight"

  $failedStage = "stage-immutable-inputs"
  foreach ($directory in @(
    [IO.Path]::GetDirectoryName($paths.stagedHost),
    $paths.stagedRuntime,
    $paths.stagedRelease,
    $paths.configDirectory,
    $paths.evidenceDirectory,
    $paths.logDirectory
  )) {
    [IO.Directory]::CreateDirectory($directory) | Out-Null
  }
  [IO.File]::Copy($CandidateExecutableSource, $paths.stagedHost, $false)
  [IO.File]::Copy($nodeSource, (Join-Path $paths.stagedRuntime "node.exe"), $false)
  $fixture = Join-Path $repository "infra\windows-service-host\fixtures\node-service-fixture.mjs"
  [IO.File]::Copy($fixture, (Join-Path $paths.stagedRelease "node-service-fixture.mjs"), $false)
  [void](Assert-RisePalsCandidateFilePin -Path $paths.stagedHost `
    -ExpectedLength ([int64]$contract.prototype.executableLength) `
    -ExpectedSha256 ([string]$contract.prototype.executableSha256) `
    -Label "Staged candidate executable")
  [void](Get-RisePalsCandidateNodeMetadata -Path (Join-Path $paths.stagedRuntime "node.exe") `
    -Contract $contract.node)
  $completed += "stage-immutable-inputs"

  $failedStage = "apply-exact-acls"
  $readRules = @(
    @{ Identity = "SYSTEM"; Rights = "FullControl" },
    @{ Identity = "BUILTIN\Administrators"; Rights = "FullControl" },
    @{ Identity = $script:RisePalsCandidateAccount; Rights = "ReadAndExecute" }
  )
  $logRules = @(
    @{ Identity = "SYSTEM"; Rights = "FullControl" },
    @{ Identity = "BUILTIN\Administrators"; Rights = "FullControl" },
    @{ Identity = $script:RisePalsCandidateAccount; Rights = "Modify" }
  )
  Set-RisePalsProtectedAcl -Path $stagingTaskRoot -Rules $readRules
  Set-RisePalsProtectedAcl -Path $rehearsalTaskRoot -Rules $readRules
  Set-RisePalsProtectedAcl -Path $logTaskRoot -Rules $logRules
  Assert-RisePalsCandidateExactAcl -Path $stagingTaskRoot `
    -CandidateRights ([Security.AccessControl.FileSystemRights]::ReadAndExecute) `
    -CandidateSid ([string]$contract.candidate.serviceSid)
  Assert-RisePalsCandidateExactAcl -Path $rehearsalTaskRoot `
    -CandidateRights ([Security.AccessControl.FileSystemRights]::ReadAndExecute) `
    -CandidateSid ([string]$contract.candidate.serviceSid)
  Assert-RisePalsCandidateExactAcl -Path $logTaskRoot `
    -CandidateRights ([Security.AccessControl.FileSystemRights]::Modify) `
    -CandidateSid ([string]$contract.candidate.serviceSid)
  $completed += "apply-exact-acls"

  $failedStage = "validate-candidate-config"
  $configuration = [ordered]@{
    approvedNodeRoot = $paths.stagedRuntime
    approvedReleaseRoot = $paths.stagedReleaseRoot
    nodeExecutable = (Join-Path $paths.stagedRuntime "node.exe")
    releaseDirectory = $paths.stagedRelease
    entrypoint = (Join-Path $paths.stagedRelease "node-service-fixture.mjs")
    logDirectory = $paths.logDirectory
    arguments = @("normal", "--fixture-http-port", "3100")
    startTimeoutSeconds = [int]$contract.timing.startTimeoutSeconds
    drainTimeoutSeconds = [int]$contract.timing.drainTimeoutSeconds
    exitTimeoutSeconds = [int]$contract.timing.exitTimeoutSeconds
    healthyResetSeconds = [int]$contract.timing.healthyResetSeconds
    restartLimit = [int]$contract.timing.restartLimit
    initialRestartDelayMilliseconds = [int]$contract.timing.initialRestartDelayMilliseconds
    maximumRestartDelayMilliseconds = [int]$contract.timing.maximumRestartDelayMilliseconds
  }
  [IO.File]::WriteAllText(
    $paths.configPath,
    (($configuration | ConvertTo-Json -Depth 5) + "`n"),
    [Text.UTF8Encoding]::new($false)
  )
  $validation = Start-Process -FilePath $paths.stagedHost -ArgumentList @(
    "--validate-config",
    ('"' + $paths.configPath + '"')
  ) -WindowStyle Hidden -Wait -PassThru
  if ($validation.ExitCode -ne 0) {
    throw "Candidate configuration validation failed."
  }
  $completed += "validate-candidate-config"

  $failedStage = "create-own-process-service"
  $binaryPath = '"' + $paths.stagedHost + '" --config "' + $paths.configPath + '"'
  Invoke-RisePalsCandidateSc -Arguments @(
    "create",
    $script:RisePalsCandidateServiceName,
    "type=",
    "own",
    "start=",
    "demand",
    "obj=",
    $script:RisePalsCandidateAccount,
    "DisplayName=",
    "Rise Pals Service Host Candidate",
    "binPath=",
    $binaryPath
  )
  $createdService = $true
  $installed = Get-CimInstance Win32_Service `
    -Filter "Name='$script:RisePalsCandidateServiceName'" -ErrorAction Stop
  if ($installed.ServiceType -ne "Own Process" -or $installed.StartMode -ne "Manual" -or
    $installed.StartName -ne $script:RisePalsCandidateAccount -or
    $installed.PathName -ne $binaryPath) {
    throw "The installed candidate identity or Own Process/Manual definition differs."
  }
  $completed += "create-own-process-service"

  $failedStage = "configure-service-sid"
  Invoke-RisePalsCandidateSc -Arguments @(
    "sidtype",
    $script:RisePalsCandidateServiceName,
    "unrestricted"
  )
  $completed += "configure-service-sid"

  $failedStage = "configure-preshutdown-timeout"
  Set-RisePalsCandidatePreshutdownTimeout -ServiceName $script:RisePalsCandidateServiceName `
    -Milliseconds ([uint32]$contract.timing.preshutdownTimeoutMilliseconds)
  $completed += "configure-preshutdown-timeout"

  $stagedNode = Join-Path $paths.stagedRuntime "node.exe"
  $controlScript = Join-Path $PSScriptRoot "Invoke-RisePalsCandidateServiceControl.ps1"

  $failedStage = "start-and-ready"
  Start-Service -Name $script:RisePalsCandidateServiceName
  [void](Wait-RisePalsCandidateServiceState -ExpectedState "Running" -TimeoutSeconds 20)
  $ready = Complete-RisePalsCandidateProbe -Probe (
    Start-RisePalsCandidateProbe -NodePath $stagedNode `
      -EvidenceDirectory $paths.evidenceDirectory -Mode "ready" -Name "ready-initial"
  )
  if ($ready.statusCode -ne 200) {
    throw "Candidate loopback readiness did not return 200."
  }
  $completed += "start-and-ready"

  $failedStage = "stream-first-byte"
  $streamProbe = Start-RisePalsCandidateProbe -NodePath $stagedNode `
    -EvidenceDirectory $paths.evidenceDirectory -Mode "stream" -Name "stream-stop" `
    -FirstByte
  Wait-RisePalsCandidateProbeMarker -Path $streamProbe.firstBytePath
  $completed += "stream-first-byte"

  $failedStage = "direct-stop"
  $stopProcess = Start-Process -FilePath $powerShell -ArgumentList @(
    "-NoLogo",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    ('"' + $controlScript + '"'),
    "-Control",
    "Stop",
    "-Confirm:`$false"
  ) -WindowStyle Hidden -PassThru
  $stopPending = Wait-RisePalsCandidateServiceState -ExpectedState "Stop Pending" `
    -TimeoutSeconds 10
  $completed += "direct-stop"

  $failedStage = "reject-new-work-during-drain"
  $rejected = Complete-RisePalsCandidateProbe -Probe (
    Start-RisePalsCandidateProbe -NodePath $stagedNode `
      -EvidenceDirectory $paths.evidenceDirectory -Mode "new-work" -Name "drain-rejection"
  )
  if ($rejected.statusCode -ne 503 -or $rejected.retryAfter -ne "5") {
    throw "New work was not rejected with fixed 503 and Retry-After during drain."
  }
  $completed += "reject-new-work-during-drain"

  $failedStage = "complete-three-chunk-stream"
  $streamResult = Complete-RisePalsCandidateProbe -Probe $streamProbe
  if ($streamResult.statusCode -ne 200 -or $streamResult.chunkCount -ne 3 -or
    -not [bool]$streamResult.exactChunks) {
    throw "The accepted synthetic stream did not complete exactly three chunks."
  }
  if (-not $stopProcess.WaitForExit(20000) -or $stopProcess.ExitCode -ne 0) {
    throw "Direct Stop-Service did not complete inside the reviewed bound."
  }
  [void](Wait-RisePalsCandidateServiceState -ExpectedState "Stopped" -TimeoutSeconds 5)
  $completed += "complete-three-chunk-stream"

  $failedStage = "duplicate-stop"
  $repeatStop = Start-Process -FilePath $powerShell -ArgumentList @(
    "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    ('"' + $controlScript + '"'), "-Control", "Stop", "-Confirm:`$false"
  ) -WindowStyle Hidden -Wait -PassThru
  if ($repeatStop.ExitCode -ne 0) {
    throw "Repeated candidate stop was not idempotent."
  }
  $completed += "duplicate-stop"

  $failedStage = "verify-stop-checkpoints"
  $pendingSamples = @($stopPending.samples | Where-Object { $_.state -eq "Stop Pending" })
  if ($pendingSamples.Count -eq 0 -or @($pendingSamples | Where-Object {
    $_.checkpoint -gt 0 -and $_.waitHint -gt 0
  }).Count -eq 0) {
    throw "Direct stop did not expose bounded checkpoint and wait-hint progress."
  }
  $completed += "verify-stop-checkpoints"

  $failedStage = "verify-preshutdown-registration"
  Start-Service -Name $script:RisePalsCandidateServiceName
  [void](Wait-RisePalsCandidateServiceState -ExpectedState "Running" -TimeoutSeconds 20)
  $preshutdownRegistration = Get-RisePalsCandidatePreshutdownRegistration `
    -ServiceName $script:RisePalsCandidateServiceName
  Assert-RisePalsCandidatePreshutdownRegistration -Registration $preshutdownRegistration `
    -Contract $contract
  Stop-Service -Name $script:RisePalsCandidateServiceName -ErrorAction Stop
  [void](Wait-RisePalsCandidateServiceState -ExpectedState "Stopped" -TimeoutSeconds 20)
  $completed += "verify-preshutdown-registration"

  $failedStage = "verify-graceful-zero-job"
  $ownedAfterStop = @(Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath.StartsWith(
      $stagingTaskRoot + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase
    )
  })
  if ($ownedAfterStop.Count -ne 0) {
    throw "Graceful stop left a process beneath the candidate staging root."
  }
  $completed += "verify-graceful-zero-job"

  $failedStage = "verify-timeout-cleanup"
  Set-RisePalsCandidateFixtureMode -Configuration $configuration -Mode "never-drain" `
    -ConfigPath $paths.configPath
  Start-Service -Name $script:RisePalsCandidateServiceName
  [void](Wait-RisePalsCandidateServiceState -ExpectedState "Running" -TimeoutSeconds 20)
  $timeoutStop = Start-Process -FilePath $powerShell -ArgumentList @(
    "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    ('"' + $controlScript + '"'), "-Control", "Stop", "-Confirm:`$false"
  ) -WindowStyle Hidden -PassThru
  [void](Wait-RisePalsCandidateServiceState -ExpectedState "Stopped" -TimeoutSeconds 25)
  [void]$timeoutStop.WaitForExit(5000)
  if (@(Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath.StartsWith(
      $stagingTaskRoot + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase
    )
  }).Count -ne 0) {
    throw "Timeout cleanup did not empty the owned candidate tree."
  }
  $timeoutEvents = Get-RisePalsCandidateSanitizedEvents -LogDirectory $paths.logDirectory
  if (@($timeoutEvents | Where-Object {
    $_.eventName -eq "service.stop.failed" -and $_.outcome -eq "timeout"
  }).Count -eq 0) {
    throw "Timeout cleanup lacks the fixed sanitized timeout classification."
  }
  $completed += "verify-timeout-cleanup"

  $failedStage = "verify-bounded-crash-restart"
  Set-RisePalsCandidateFixtureMode -Configuration $configuration -Mode "normal" `
    -ConfigPath $paths.configPath
  Start-Service -Name $script:RisePalsCandidateServiceName
  $running = Wait-RisePalsCandidateServiceState -ExpectedState "Running" -TimeoutSeconds 20
  $hostPid = [int]$running.service.ProcessId
  $firstChild = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$hostPid")
  if ($firstChild.Count -ne 1) {
    throw "Candidate service did not own exactly one direct Node child."
  }
  $crash = Complete-RisePalsCandidateProbe -Probe (
    Start-RisePalsCandidateProbe -NodePath $stagedNode `
      -EvidenceDirectory $paths.evidenceDirectory -Mode "crash" -Name "crash"
  )
  if ($crash.statusCode -ne 202) {
    throw "Synthetic crash trigger was not accepted."
  }
  $restartDeadline = [DateTime]::UtcNow.AddSeconds(15)
  $restartedChild = $null
  do {
    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$hostPid")
    $restartedChild = @($children | Where-Object {
      [int]$_.ProcessId -ne [int]$firstChild[0].ProcessId
    } | Select-Object -First 1)
    if ($restartedChild.Count -eq 1) { break }
    Start-Sleep -Milliseconds 100
  } while ([DateTime]::UtcNow -lt $restartDeadline)
  if ($restartedChild.Count -ne 1) {
    throw "Unexpected Node crash did not produce one bounded restart."
  }
  $completed += "verify-bounded-crash-restart"

  $failedStage = "verify-process-ownership"
  if (-not ([string]$restartedChild[0].ExecutablePath).Equals(
    $stagedNode,
    [StringComparison]::OrdinalIgnoreCase
  )) {
    throw "The restarted child is outside the candidate runtime path."
  }
  $completed += "verify-process-ownership"
  Stop-Service -Name $script:RisePalsCandidateServiceName -ErrorAction Stop
  [void](Wait-RisePalsCandidateServiceState -ExpectedState "Stopped" -TimeoutSeconds 20)

  $failedStage = "verify-persistent-failure-terminal"
  Set-RisePalsCandidateFixtureMode -Configuration $configuration -Mode "startup-failure" `
    -ConfigPath $paths.configPath
  Start-Service -Name $script:RisePalsCandidateServiceName
  [void](Wait-RisePalsCandidateServiceState -ExpectedState "Stopped" -TimeoutSeconds 30)
  $terminalEvents = Get-RisePalsCandidateSanitizedEvents -LogDirectory $paths.logDirectory
  if (@($terminalEvents | Where-Object {
    $_.eventName -eq "service.child.terminal-failure" -and
      $_.outcome -eq "restart-limit-reached"
  }).Count -eq 0) {
    throw "Persistent startup failure did not reach the fixed terminal classification."
  }
  $completed += "verify-persistent-failure-terminal"

  $failedStage = "verify-retained-proxy-independence"
  $retainedAfterBehavior = Get-RisePalsCandidateRetainedSnapshot -Contract $contract
  Assert-RisePalsCandidateRetainedSnapshot -Snapshot $retainedAfterBehavior -Contract $contract
  Assert-RisePalsCandidateRetainedSnapshotEquality -Before $retainedBefore `
    -After $retainedAfterBehavior
  $proxy = @($retainedAfterBehavior | Where-Object { $_.name -ceq "RisePalsProxy" })
  $candidateDefinition = Get-Service -Name $script:RisePalsCandidateServiceName -ErrorAction Stop
  if ($proxy.Count -ne 1 -or $proxy[0].state -cne "Stopped" -or
    $proxy[0].startMode -cne "Disabled" -or [int]$proxy[0].processId -ne 0 -or
    @($candidateDefinition.ServicesDependedOn).Count -ne 0) {
    throw "Retained proxy state or candidate process independence changed."
  }
  $completed += "verify-retained-proxy-independence"

  $sequenceSucceeded = $true
  $failedStage = $null
  $failureCode = $null
} catch {
  $failureCode = Get-RisePalsCandidateFailureCodeForStage -Contract $contract `
    -Stage $failedStage
} finally {
  try {
    if ($createdService) {
      $service = Get-Service -Name $script:RisePalsCandidateServiceName -ErrorAction SilentlyContinue
      if ($null -ne $service -and $service.Status -ne "Stopped") {
        Stop-Service -Name $script:RisePalsCandidateServiceName -Force -ErrorAction Stop
        $service.WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
      }
      Invoke-RisePalsCandidateSc -Arguments @(
        "config",
        $script:RisePalsCandidateServiceName,
        "start=",
        "disabled"
      )
      $serviceState = Get-CimInstance Win32_Service `
        -Filter "Name='$script:RisePalsCandidateServiceName'" -ErrorAction Stop
      if ($serviceState.State -ne "Stopped" -or $serviceState.StartMode -ne "Disabled" -or
        [int]$serviceState.ProcessId -ne 0) {
        throw "Candidate cleanup could not prove Stopped/Disabled/PID 0."
      }
      Invoke-RisePalsCandidateSc -Arguments @("delete", $script:RisePalsCandidateServiceName)
    }
    Assert-RisePalsCandidateTaskTreeInventory -Path $stagingTaskRoot `
      -AllowedRelativePaths @(
        "host",
        "host\RisePals.ServiceHost.exe",
        "runtime",
        "runtime\node.exe",
        "release-root",
        "release-root\synthetic-fixture",
        "release-root\synthetic-fixture\node-service-fixture.mjs"
      )
    Assert-RisePalsCandidateTaskTreeInventory -Path $rehearsalTaskRoot `
      -AllowedRelativePaths @(
        "config",
        "config\service-host-config.json",
        "evidence",
        "evidence\ready-initial.json",
        "evidence\ready-initial.first-byte",
        "evidence\stream-stop.json",
        "evidence\stream-stop.first-byte",
        "evidence\drain-rejection.json",
        "evidence\drain-rejection.first-byte",
        "evidence\crash.json",
        "evidence\crash.first-byte"
      )
    Assert-RisePalsCandidateTaskTreeInventory -Path $logTaskRoot `
      -AllowedRelativePaths @(
        "service-host.jsonl",
        "service-host.1.jsonl",
        "service-host.2.jsonl",
        "service-host.3.jsonl"
      )
    foreach ($target in @($stagingTaskRoot, $rehearsalTaskRoot, $logTaskRoot)) {
      if ([IO.Directory]::Exists($target)) {
        Remove-RisePalsValidatedChild -Root $script:RisePalsCandidateRoot `
          -Path $target -Recurse
      }
    }
    $candidateAfter = Get-CimInstance Win32_Service `
      -Filter "Name='$script:RisePalsCandidateServiceName'" -ErrorAction SilentlyContinue
    $retainedAfter = Get-RisePalsCandidateRetainedSnapshot -Contract $contract
    $finalListeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object {
      $_.LocalPort -in @($contract.network.relevantPorts)
    })
    $finalRootProcesses = @(Get-CimInstance Win32_Process | Where-Object {
      $_.ExecutablePath -and $_.ExecutablePath.StartsWith(
        $script:RisePalsCandidateRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
      )
    })
    Assert-RisePalsCandidateRetainedSnapshot -Snapshot $retainedAfter -Contract $contract
    Assert-RisePalsCandidateRetainedSnapshotEquality -Before $retainedBefore -After $retainedAfter
    if ($null -ne $candidateAfter -or $finalListeners.Count -ne 0 -or
      $finalRootProcesses.Count -ne 0) {
      throw "Final candidate or retained-service cleanup proof failed."
    }
    $cleanupCompleted = $true
    $finalState = New-RisePalsCandidateFinalState
    $completed += "cleanup"
    $completed += "final-read-only-proof"
  } catch {
    $cleanupCompleted = $false
    $finalState = New-RisePalsCandidateFinalState -CandidateState "Unknown" `
      -CandidateStartMode "Unknown" -TemporaryChildren 1
    $failureCode = "cleanup-failed"
  }

  $liveStatus = if ($sequenceSucceeded -and $cleanupCompleted) { "success" } else { "failure" }
  Write-RisePalsCandidateLiveState -Path $structuredState -Status $liveStatus `
    -CompletedStages $completed -FailedStage $failedStage -FailureCode $failureCode `
    -CleanupCompleted $cleanupCompleted -FinalState $finalState
}

if ($sequenceSucceeded -and $cleanupCompleted) {
  exit 0
}
exit 23
