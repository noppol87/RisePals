[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("NativeSuccess", "NativeFailure", "DualStreamSuccess", "Privacy")]
  [string]$Scenario
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

switch ($Scenario) {
  "NativeSuccess" {
    [Console]::Out.WriteLine("fixture stdout")
    [Console]::Error.WriteLine("fixture informational stderr")
    exit 0
  }
  "NativeFailure" {
    [Console]::Out.WriteLine("fixture failure stdout")
    [Console]::Error.WriteLine("fixture controlled failure stderr")
    exit 7
  }
  "DualStreamSuccess" {
    [Console]::Out.WriteLine("fixture distinct stdout stream")
    [Console]::Error.WriteLine("fixture distinct stderr stream")
    exit 0
  }
  "Privacy" {
    [Console]::Out.WriteLine("PRIVATE-MARKER-STDOUT person@example.invalid")
    [Console]::Error.WriteLine("Authorization: redacted-fixture; request-body-fixture")
    exit 0
  }
}
