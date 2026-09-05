[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
  [Parameter(Mandatory = $true)][ValidateSet("Create", "Rotate", "Revoke", "Delete")][string]$Action,
  [string]$Root = "C:\RisePals"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$secretDirectory = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $validatedRoot "shared\secrets"
)
$secretPath = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $secretDirectory "rehearsal.canary"
)
$adminRules = @(
  @{ Identity = "NT AUTHORITY\SYSTEM"; Rights = "FullControl" },
  @{ Identity = "BUILTIN\Administrators"; Rights = "FullControl" }
)
$appReadRules = @(
  $adminRules[0],
  $adminRules[1],
  @{ Identity = "NT SERVICE\RisePalsApp"; Rights = "Read" }
)

if (-not $PSCmdlet.ShouldProcess($secretPath, "$Action the synthetic rehearsal canary without displaying it")) {
  Write-Output "Synthetic rehearsal secret $Action dry-run PASS"
  return
}

Assert-RisePalsAdministrator

switch ($Action) {
  "Create" {
    if (Test-Path -LiteralPath $secretPath) {
      throw "The synthetic rehearsal secret already exists."
    }
    $bytes = [byte[]]::new(64)
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
      $generator.GetBytes($bytes)
    } finally {
      $generator.Dispose()
    }
    [IO.File]::WriteAllBytes($secretPath, $bytes)
    [Array]::Clear($bytes, 0, $bytes.Length)
    Set-RisePalsProtectedAcl -Path $secretPath -Rules $appReadRules
  }
  "Rotate" {
    if (-not (Test-Path -LiteralPath $secretPath -PathType Leaf)) {
      throw "The synthetic rehearsal secret does not exist."
    }
    $temporary = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
      Join-Path $secretDirectory ("rehearsal.canary.next." + [guid]::NewGuid().ToString("N"))
    )
    $previous = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
      Join-Path $secretDirectory ("rehearsal.canary.previous." + [guid]::NewGuid().ToString("N"))
    )
    $bytes = [byte[]]::new(64)
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
      $generator.GetBytes($bytes)
    } finally {
      $generator.Dispose()
    }
    [IO.File]::WriteAllBytes($temporary, $bytes)
    [Array]::Clear($bytes, 0, $bytes.Length)
    Set-RisePalsProtectedAcl -Path $temporary -Rules $appReadRules
    try {
      Move-Item -LiteralPath $secretPath -Destination $previous
      Move-Item -LiteralPath $temporary -Destination $secretPath
      Remove-RisePalsValidatedChild -Root $validatedRoot -Path $previous
    } catch {
      if (-not (Test-Path -LiteralPath $secretPath) -and (Test-Path -LiteralPath $previous)) {
        Move-Item -LiteralPath $previous -Destination $secretPath
      }
      if (Test-Path -LiteralPath $temporary) {
        Remove-RisePalsValidatedChild -Root $validatedRoot -Path $temporary
      }
      throw
    }
  }
  "Revoke" {
    if (-not (Test-Path -LiteralPath $secretPath -PathType Leaf)) {
      throw "The synthetic rehearsal secret does not exist."
    }
    Set-RisePalsProtectedAcl -Path $secretPath -Rules $adminRules
  }
  "Delete" {
    Remove-RisePalsValidatedChild -Root $validatedRoot -Path $secretPath
  }
}

Write-Output "Synthetic rehearsal secret $Action PASS; no value was displayed."
