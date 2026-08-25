[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9.-]{2,63}$")][string]$ReleaseId,
  [string]$Root = "C:\RisePals",
  [string]$RepositoryRoot = "",
  [ValidatePattern("^$|^[a-f0-9]{40}$")][string]$SourceCommit = "",
  [switch]$RehearsalDenyManifestRead,
  [switch]$ReuseExactExisting
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$validatedRoot = Get-RisePalsValidatedRoot -Root $Root
$RepositoryRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
} else {
  $RepositoryRoot
}
$repository = [IO.Path]::GetFullPath($RepositoryRoot)
$git = "C:\Users\Administrator\AppData\Local\Programs\PortableGit-2.55.0.3\cmd\git.exe"
if (-not (Test-Path -LiteralPath $git -PathType Leaf)) {
  throw "The verified repository Git executable is unavailable."
}

$headCommit = (& $git -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $repository rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $headCommit -notmatch "^[a-f0-9]{40}$") {
  throw "Unable to resolve the exact source commit."
}
$sourceCommit = if ([string]::IsNullOrWhiteSpace($SourceCommit)) { $headCommit } else { $SourceCommit }
& $git -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $repository `
  merge-base --is-ancestor $sourceCommit $headCommit
if ($LASTEXITCODE -ne 0) {
  throw "The requested release source is not a committed ancestor of the current feature head."
}
$worktree = @(& $git -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $repository status --porcelain --untracked-files=all)
if ($LASTEXITCODE -ne 0 -or $worktree.Count -ne 0) {
  throw "A release may be created only from a clean committed worktree."
}

$staging = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $validatedRoot "staging\$ReleaseId"
)
$destination = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $validatedRoot "releases\$ReleaseId"
)
$stagingExists = Test-Path -LiteralPath $staging
$destinationExists = Test-Path -LiteralPath $destination
if (($stagingExists -or $destinationExists) -and -not $ReuseExactExisting) {
  throw "The release identifier already exists in staging or releases."
}
if ($ReuseExactExisting -and $stagingExists) {
  Assert-RisePalsAdministrator
  Remove-RisePalsValidatedChild -Root $validatedRoot -Path $staging -Recurse
}
if ($ReuseExactExisting -and $destinationExists) {
  Assert-RisePalsAdministrator
  $node = Join-Path $validatedRoot "tools\node\24.18.1\node.exe"
  $manifestTool = Join-Path $repository "scripts\infra\release-manifest.mjs"
  & $node $manifestTool `
    --mode verify `
    --root $destination `
    --source-commit $sourceCommit `
    --release-id $ReleaseId
  if ($LASTEXITCODE -ne 0) {
    throw "The existing release failed exact committed-inventory verification."
  }
  Write-Output "Exact existing committed release reuse PASS: $ReleaseId at $sourceCommit"
  return
}

if (-not $PSCmdlet.ShouldProcess($destination, "Package and publish committed standalone release")) {
  Write-Output "Release packaging dry-run PASS for $ReleaseId"
  return
}

Assert-RisePalsAdministrator
$appService = Assert-RisePalsServiceIsAbsentOrOwned -Name "RisePalsApp" -Root $validatedRoot
if ($null -eq $appService) {
  throw "The approved application service must exist before a release is packaged."
}

[IO.Directory]::CreateDirectory((Join-Path $validatedRoot "staging")) | Out-Null
$buildRoot = Get-RisePalsValidatedChildPath -Root $validatedRoot -Path (
  Join-Path $validatedRoot ("staging\build-" + [guid]::NewGuid().ToString("N"))
)
$source = Join-Path $buildRoot "source"
$archive = Join-Path $buildRoot "source.tar"
[IO.Directory]::CreateDirectory($staging) | Out-Null
[IO.Directory]::CreateDirectory($source) | Out-Null
$destinationCreated = $false
try {
  & $git -c "safe.directory=C:/Codex PC SG2/Jeff/risepals" -C $repository archive `
    --format=tar `
    --output=$archive `
    $sourceCommit
  if ($LASTEXITCODE -ne 0) {
    throw "Exact committed source archive creation failed."
  }
  & tar.exe -xf $archive -C $source
  if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath (Join-Path $source ".env.local"))) {
    throw "Secret-free committed source extraction failed."
  }

  $node = Join-Path $validatedRoot "tools\node\24.18.1\node.exe"
  $npm = Join-Path $validatedRoot "tools\node\24.18.1\npm.cmd"
  foreach ($path in @($node, $npm)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "The pinned Node/npm runtime is unavailable."
    }
  }

  Push-Location $source
  try {
    & $npm ci
    if ($LASTEXITCODE -ne 0) {
      throw "Isolated deterministic dependency installation failed."
    }
    & $npm run build
    if ($LASTEXITCODE -ne 0) {
      throw "Isolated secret-free production build failed."
    }
  } finally {
    Pop-Location
  }

  $standalone = Join-Path $source ".next\standalone"
  if (
    -not (Test-Path -LiteralPath (Join-Path $standalone "server.js") -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $standalone ".next\static") -PathType Container)
  ) {
    throw "The isolated verified Next.js standalone output is absent."
  }
  Get-ChildItem -LiteralPath $standalone -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $staging -Recurse
  }
  $package = Get-Content -LiteralPath (Join-Path $source "package.json") -Raw -Encoding UTF8 |
    ConvertFrom-Json
  $manifestTool = Join-Path $source "scripts\infra\release-manifest.mjs"
  & $node $manifestTool `
    --root $staging `
    --source-commit $sourceCommit `
    --release-id $ReleaseId `
    --node-version "24.18.1" `
    --npm-version "11.16.0" `
    --next-version $package.dependencies.next `
    --configuration-template-version "windows-infra-v1"
  if ($LASTEXITCODE -ne 0) {
    throw "Release-manifest generation failed."
  }

  Move-Item -LiteralPath $staging -Destination $destination
  $destinationCreated = $true
  $cachePath = Join-Path $destination ".next\cache"
  $sharedCache = Join-Path $validatedRoot "shared\cache\next-$ReleaseId"
  [IO.Directory]::CreateDirectory($sharedCache) | Out-Null
  if (Test-Path -LiteralPath $cachePath) {
    Remove-RisePalsValidatedChild -Root $validatedRoot -Path $cachePath -Recurse
  }
  New-Item -ItemType Junction -Path $cachePath -Target $sharedCache | Out-Null

  $systemAdmin = @(
    @{ Identity = "NT AUTHORITY\SYSTEM"; Rights = "FullControl" },
    @{ Identity = "BUILTIN\Administrators"; Rights = "FullControl" }
  )
  Set-RisePalsProtectedAcl -Path $destination -Rules @(
    $systemAdmin[0], $systemAdmin[1],
    @{ Identity = "NT SERVICE\RisePalsApp"; Rights = "ReadAndExecute" }
  )
  Set-RisePalsProtectedAcl -Path $sharedCache -Rules @(
    $systemAdmin[0], $systemAdmin[1],
    @{ Identity = "NT SERVICE\RisePalsApp"; Rights = "Modify" }
  )
  if ($RehearsalDenyManifestRead) {
    Set-RisePalsProtectedAcl -Path (Join-Path $destination "release-manifest.json") `
      -Rules $systemAdmin
  }
  $releaseEvent = if ($RehearsalDenyManifestRead) {
    "release-created-unready"
  } else {
    "release-created"
  }
  Write-RisePalsDeploymentEvent -Root $validatedRoot -Event $releaseEvent `
    -ReleaseId $ReleaseId -SourceCommit $sourceCommit
} catch {
  if (Test-Path -LiteralPath $staging) {
    Remove-RisePalsValidatedChild -Root $validatedRoot -Path $staging -Recurse
  }
  if ($destinationCreated -and (Test-Path -LiteralPath $destination)) {
    Remove-RisePalsValidatedChild -Root $validatedRoot -Path $destination -Recurse
  }
  throw
} finally {
  if (Test-Path -LiteralPath $buildRoot) {
    Remove-RisePalsValidatedChild -Root $validatedRoot -Path $buildRoot -Recurse
  }
}

Write-Output "Committed standalone release PASS: $ReleaseId at $sourceCommit"
