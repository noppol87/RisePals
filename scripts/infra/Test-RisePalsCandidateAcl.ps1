[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -cne "Desktop" -or $PSVersionTable.PSVersion.Major -ne 5 -or
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "Non-elevated PS5.1 required." }
. (Join-Path $PSScriptRoot "common.ps1")
. (Join-Path $PSScriptRoot "candidate-rehearsal-contract.ps1")
$contract = Get-RisePalsCandidateContract
$sid = [Security.Principal.SecurityIdentifier]::new([string]$contract.candidate.serviceSid)

# Load only the validator definition, never the operational Live script body.
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile(
  (Join-Path $PSScriptRoot "Invoke-RisePalsCandidateLiveSequence.ps1"), [ref]$tokens, [ref]$errors)
$definitions=@($ast.FindAll({param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
  $node.Name -ceq "Assert-RisePalsCandidateExactAcl"
}, $true))
if ($errors.Count -ne 0 -or $definitions.Count -ne 1) { throw "ACL validator definition rejected." }
. ([scriptblock]::Create($definitions[0].Extent.Text))

# Explicit in-memory doubles: no OS ACL is written or read by these commands.
$script:capturedAcl=$null; $script:setCount=0
function Set-Acl {
  param([string]$LiteralPath, $AclObject)
  if ($LiteralPath -cne $PSScriptRoot) { throw "Unexpected ACL test target." }
  $script:capturedAcl=$AclObject; $script:setCount++
}
function Get-Acl {
  param([string]$LiteralPath)
  if ($LiteralPath -cne $PSScriptRoot -or $null -eq $script:capturedAcl) { throw "Missing in-memory ACL." }
  return $script:capturedAcl
}
$passed=0
foreach ($rights in @("ReadAndExecute", "Modify")) {
  $rules=@(
    @{Identity=[Security.Principal.SecurityIdentifier]::new("S-1-5-18");Rights="FullControl"},
    @{Identity=[Security.Principal.SecurityIdentifier]::new("S-1-5-32-544");Rights="FullControl"},
    @{Identity=$sid;Rights=$rights}
  )
  Set-RisePalsProtectedAcl -Path $PSScriptRoot -Rules $rules
  Assert-RisePalsCandidateExactAcl -Path $PSScriptRoot -CandidateRights $rights -CandidateSid $sid.Value
  $aces=@($script:capturedAcl.GetAccessRules($true,$false,[Security.Principal.SecurityIdentifier]))
  $candidate=@($aces|Where-Object {$_.IdentityReference.Value -ceq $sid.Value})
  if ($aces.Count -ne 3 -or $candidate.Count -ne 1 -or
    [int]$candidate[0].FileSystemRights -ne ([int][Security.AccessControl.FileSystemRights]$rights -bor 1048576) -or
    $candidate[0].InheritanceFlags -ne ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
      [Security.AccessControl.InheritanceFlags]::ObjectInherit)) { throw "Pinned ACL construction failed." }
  $passed++
  $extra=[Security.AccessControl.FileSystemAccessRule]::new(
    [Security.Principal.SecurityIdentifier]::new("S-1-1-0"), "ReadAndExecute", "Allow")
  [void]$script:capturedAcl.AddAccessRule($extra)
  $rejected=$false
  try { Assert-RisePalsCandidateExactAcl -Path $PSScriptRoot -CandidateRights $rights -CandidateSid $sid.Value } catch { $rejected=$true }
  if (-not $rejected) { throw "Additional principal accepted." }
  $passed++
}
$rules[2].Rights="FullControl"
Set-RisePalsProtectedAcl -Path $PSScriptRoot -Rules $rules
$rejected=$false
try { Assert-RisePalsCandidateExactAcl -Path $PSScriptRoot -CandidateRights Modify -CandidateSid $sid.Value } catch { $rejected=$true }
if (-not $rejected) { throw "Broader candidate rights accepted." }
$passed++
Set-RisePalsProtectedAcl -Path $PSScriptRoot -Rules @(@{Identity="SYSTEM";Rights="FullControl"})
$legacy=@($script:capturedAcl.GetAccessRules($true,$false,[Security.Principal.SecurityIdentifier]))
if ($legacy.Count -ne 1 -or $legacy[0].IdentityReference.Value -cne "S-1-5-18") { throw "Existing account-name behavior changed." }
$passed++
$before=$script:setCount
$rejected=$false
try { Set-RisePalsProtectedAcl -Path $PSScriptRoot -Rules @(@{Identity="RP19-NoSuch-"+[guid]::NewGuid().ToString("N");Rights="ReadAndExecute"}) } catch { $rejected=$true }
if (-not $rejected -or $script:setCount -ne $before) { throw "Unresolvable account did not fail before Set-Acl." }
$passed++
Write-Output ("Candidate ACL in-memory PASS: {0}/7; pinned SID; canonical Allow masks; extra principal/broader rights rejected; host ACL writes=0; UAC=0; residue=0." -f $passed)
