[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][ValidateSet("ElevationProbe")][string]$Mode,
  [Parameter(Mandatory = $true)][string]$SimulationScenario,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{40}$")][string]$RepositoryHead,
  [Parameter(Mandatory = $true)][string]$AuthorizationId,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$LauncherScriptSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$BootstrapScriptSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$TransportScriptSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{64}$")][string]$ChildScriptSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-f0-9]{32}$")][string]$InvocationNonce,
  [Parameter(Mandatory = $true)][string]$ResultRoot,
  [Parameter(Mandatory = $true)][string]$InvocationDirectory,
  [Parameter(Mandatory = $true)][string]$RepositoryRoot,
  [Parameter(Mandatory = $true)][string]$LauncherScriptPath,
  [Parameter(Mandatory = $true)][string]$BootstrapScriptPath,
  [Parameter(Mandatory = $true)][string]$TransportScriptPath,
  [Parameter(Mandatory = $true)][string]$ChildScriptPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RisePalsElevationProbeSha256 {
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

function Get-RisePalsElevationProbeIntegrityLevel {
  try {
    if (-not ("RisePalsElevationProbeNative" -as [type])) {
      Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class RisePalsElevationProbeNative
{
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll")]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetTokenInformation(
        IntPtr token,
        int informationClass,
        IntPtr information,
        int informationLength,
        out int returnLength);

    [DllImport("advapi32.dll")]
    private static extern IntPtr GetSidSubAuthorityCount(IntPtr sid);

    [DllImport("advapi32.dll")]
    private static extern IntPtr GetSidSubAuthority(IntPtr sid, uint index);

    public static int GetIntegrityRid()
    {
        const uint Query = 0x0008;
        const int IntegrityLevel = 25;
        IntPtr token;
        if (!OpenProcessToken(GetCurrentProcess(), Query, out token)) return -1;
        try
        {
            int length;
            GetTokenInformation(token, IntegrityLevel, IntPtr.Zero, 0, out length);
            if (length <= 0) return -1;
            IntPtr buffer = Marshal.AllocHGlobal(length);
            try
            {
                if (!GetTokenInformation(token, IntegrityLevel, buffer, length, out length)) return -1;
                IntPtr sid = Marshal.ReadIntPtr(buffer);
                IntPtr countPointer = GetSidSubAuthorityCount(sid);
                if (countPointer == IntPtr.Zero) return -1;
                byte count = Marshal.ReadByte(countPointer);
                if (count == 0) return -1;
                IntPtr ridPointer = GetSidSubAuthority(sid, (uint)(count - 1));
                return ridPointer == IntPtr.Zero ? -1 : Marshal.ReadInt32(ridPointer);
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
            }
        }
        finally
        {
            CloseHandle(token);
        }
    }
}
'@
    }
    $rid = [RisePalsElevationProbeNative]::GetIntegrityRid()
    if ($rid -ge 0x4000) { return "system" }
    if ($rid -ge 0x3000) { return "high" }
    if ($rid -ge 0) { return "insufficient" }
  } catch {
    # Only the closed unavailable state is retained.
  }
  return "unavailable"
}

$approvedRepository = "C:\Codex PC SG2\Jeff\risepals"
$exactRepository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd(
  [IO.Path]::DirectorySeparatorChar
)
$expectedScripts = Join-Path $exactRepository "scripts\infra"
$expectedLauncher = Join-Path $expectedScripts "Invoke-RisePalsCandidateRehearsal.ps1"
$expectedBootstrap = Join-Path $expectedScripts "Invoke-RisePalsCandidateElevatedBootstrap.ps1"
$expectedTransport = Join-Path $expectedScripts "candidate-rehearsal-transport.ps1"
$expectedChild = Join-Path $expectedScripts "Invoke-RisePalsCandidateElevationProbeChild.ps1"
$git = "C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
$safe = "safe.directory=C:/Codex PC SG2/Jeff/risepals"

$repositoryHeadMatched = $false
$authorizationMatched = $AuthorizationId -match "^RP-TURN-019-R4-PROBE-[A-F0-9]{8}$"
$invocationNonceMatched = $InvocationNonce -match "^[a-f0-9]{32}$"
$launcherHashMatched = $false
$bootstrapHashMatched = $false
$transportHashMatched = $false
$childHashMatched = $false

try {
  if ($exactRepository.Equals($approvedRepository, [StringComparison]::OrdinalIgnoreCase) -and
    [IO.File]::Exists($git)) {
    $actualHead = (& $git -c $safe -C $exactRepository rev-parse HEAD).Trim()
    $repositoryHeadMatched = $LASTEXITCODE -eq 0 -and $actualHead -eq $RepositoryHead
  }
  $launcherHashMatched = [IO.Path]::GetFullPath($LauncherScriptPath).Equals(
    $expectedLauncher,
    [StringComparison]::OrdinalIgnoreCase
  ) -and [IO.File]::Exists($expectedLauncher) -and
    (Get-RisePalsElevationProbeSha256 -LiteralPath $expectedLauncher) -eq
      $LauncherScriptSha256
  $bootstrapHashMatched = [IO.Path]::GetFullPath($BootstrapScriptPath).Equals(
    $expectedBootstrap,
    [StringComparison]::OrdinalIgnoreCase
  ) -and [IO.File]::Exists($expectedBootstrap) -and
    (Get-RisePalsElevationProbeSha256 -LiteralPath $expectedBootstrap) -eq
      $BootstrapScriptSha256
  $transportHashMatched = [IO.Path]::GetFullPath($TransportScriptPath).Equals(
    $expectedTransport,
    [StringComparison]::OrdinalIgnoreCase
  ) -and [IO.File]::Exists($expectedTransport) -and
    (Get-RisePalsElevationProbeSha256 -LiteralPath $expectedTransport) -eq
      $TransportScriptSha256
  $childHashMatched = [IO.Path]::GetFullPath($ChildScriptPath).Equals(
    $expectedChild,
    [StringComparison]::OrdinalIgnoreCase
  ) -and [IO.Path]::GetFullPath($PSCommandPath).Equals(
    $expectedChild,
    [StringComparison]::OrdinalIgnoreCase
  ) -and [IO.File]::Exists($expectedChild) -and
    (Get-RisePalsElevationProbeSha256 -LiteralPath $expectedChild) -eq
      $ChildScriptSha256
} catch {
  # Individual closed booleans remain false; raw failure data is not retained.
}

if (-not $transportHashMatched) {
  exit 94
}
if (-not $PSCmdlet.ShouldProcess(
    $InvocationDirectory,
    "Write the authenticated non-mutating elevation-probe marker and result"
  )) {
  exit 96
}
. $expectedTransport

$directory = Assert-RisePalsCandidateInvocationDirectory -Path $InvocationDirectory `
  -ExpectedRoot $ResultRoot -InvocationNonce $InvocationNonce
$childStartedMarker = New-RisePalsCandidateMarker -MarkerType "child-started" `
  -InvocationNonce $InvocationNonce -AuthorizationId $AuthorizationId `
  -RepositoryHead $RepositoryHead -LauncherScriptSha256 $LauncherScriptSha256 `
  -BootstrapScriptSha256 $BootstrapScriptSha256 `
  -TransportScriptSha256 $TransportScriptSha256 `
  -ChildScriptSha256 $ChildScriptSha256 -SanitizedFailureCode $null
Write-RisePalsCandidateMarkerAtomic -Marker $childStartedMarker `
  -InvocationDirectory $directory

$administratorRoleConfirmed = $false
try {
  $principal = [Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()
  )
  $administratorRoleConfirmed = $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
  )
} catch {
  $administratorRoleConfirmed = $false
}
$integrityLevel = Get-RisePalsElevationProbeIntegrityLevel
$provenanceMatched = $repositoryHeadMatched -and $authorizationMatched -and
  $invocationNonceMatched -and $launcherHashMatched -and $bootstrapHashMatched -and
  $transportHashMatched -and $childHashMatched
$elevationMatched = $administratorRoleConfirmed -and
  $integrityLevel -in @("high", "system")
$probeStatus = if ($provenanceMatched -and $elevationMatched) { "success" } else { "failure" }
$failedStage = if (-not $provenanceMatched) {
  "probe-entry-validation"
} elseif (-not $elevationMatched) {
  "probe-elevation-validation"
} else {
  $null
}
$failureCode = if ($failedStage -eq "probe-entry-validation") {
  "probe-provenance-mismatch"
} elseif ($failedStage -eq "probe-elevation-validation") {
  "probe-insufficient-elevation"
} else {
  $null
}
$diagnostic = New-RisePalsCandidateProbeDiagnostic -ProbeStatus $probeStatus `
  -FailedStage $failedStage -SanitizedFailureCode $failureCode `
  -ElevatedChildEntered $true `
  -AdministratorRoleConfirmed $administratorRoleConfirmed `
  -IntegrityLevel $integrityLevel -RepositoryHeadMatched $repositoryHeadMatched `
  -AuthorizationMatched $authorizationMatched `
  -InvocationNonceMatched $invocationNonceMatched `
  -LauncherHashMatched $launcherHashMatched `
  -BootstrapHashMatched $bootstrapHashMatched `
  -TransportHashMatched $transportHashMatched -ChildHashMatched $childHashMatched `
  -LiveSequenceInvoked $false -HostMutationAttempted $false
$resultPath = Join-Path $directory "probe-result.json"
$temporaryPath = Join-Path $directory "probe-result.tmp"
try {
  Write-RisePalsCandidateJsonAtomic -Value $diagnostic -ResultPath $resultPath `
    -TemporaryPath $temporaryPath
} catch {
  exit 95
}
if ($probeStatus -eq "success") { exit 0 }
exit 93
