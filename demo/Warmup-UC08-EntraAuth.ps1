<#
.SYNOPSIS
  Warm up UC8 — Entra authentication troubleshooting (enterprise-operations agent).

.DESCRIPTION
  Dataset scenario: the entra-authentication skill and its synthetic sign-in
  dataset are installed once during one-time setup (Invoke-OneTimeSetup.ps1).
  This script prints the exact prompt. Use -EnsureSkill to (re)install the skill.

  Underlying one-time script: labs/enterprise-operations/scripts/Add-EntraAuthSkill.ps1

.EXAMPLE
  ./demo/Warmup-UC08-EntraAuth.ps1
.EXAMPLE
  ./demo/Warmup-UC08-EntraAuth.ps1 -EnsureSkill
#>
[CmdletBinding()]
param(
    [switch]$EnsureSkill,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

$prompt = 'Use the entra-authentication skill. Investigate authentication failures for Zava Inventory Sync and Zava Operations Portal from 2026-08-24T07:00:00Z to 2026-08-24T11:00:00Z. Aggregate by result code and principal, redact PII and IPs, classify each cluster (auth/token/Conditional Access/consent/RBAC), correlate preceding credential/CA changes, and recommend safe fixes. Read-only.'

Write-DemoBanner -Number 8 -Title 'Entra authentication troubleshooting' -Agent 'enterprise-operations agent'

$labPath = Join-Path (Get-DemoRepoRoot) 'labs/enterprise-operations'

if ($EnsureSkill) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Write-DemoStep 'Installing the entra-authentication skill + dataset (Add-EntraAuthSkill.ps1)...'
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Add-EntraAuthSkill.ps1'
}
else {
    Write-DemoInfo 'No live seed — the skill/dataset load during one-time setup. Add -EnsureSkill to reinstall.'
}

Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'Correlates the secret rotation -> invalid-secret spike (~95%) and the CA policy edit -> device-compliance blocks.'
Write-DemoReset -Text 'None — dataset-only scenario.'
