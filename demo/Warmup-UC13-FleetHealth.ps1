<#
.SYNOPSIS
  Warm up UC13 — Multi-subscription operational health overview (enterprise-operations agent).

.DESCRIPTION
  Dataset/query scenario: the fleet-health skill installs once during one-time
  setup, and the agent needs read-only RBAC across the three scopes named in the
  prompt. This script prints the exact prompt. Use -EnsureSkill to (re)install.

  IMPORTANT: Replace the Scope B/C subscription IDs in the prompt with your own
  same-tenant subscriptions before recording.

  Underlying one-time command:
    Install-AgentSkill.ps1 -SkillName fleet-health
      -SkillPath .\sre-config\skills\fleet-health\SKILL.md

.EXAMPLE
  ./demo/Warmup-UC13-FleetHealth.ps1
#>
[CmdletBinding()]
param(
    [switch]$EnsureSkill,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

$prompt = 'Use the fleet-health skill. Consolidated health overview across three scopes for the last 24 hours: Scope A = rg-sre-eops-lab, Scope B = rg-eops-uc6-lifecycle (subscription 09e7c1cb-53ca-4d05-bcf0-8881c42e680e), Scope C = subscription 11111111-2222-3333-4444-555555555555. Coverage-check each scope first, normalize severity, dedupe, and give one estate status. Do not mark unknown or critical scopes as healthy. Read-only.'

Write-DemoBanner -Number 13 -Title 'Multi-subscription operational health overview' -Agent 'enterprise-operations agent'

$labPath = Join-Path (Get-DemoRepoRoot) 'labs/enterprise-operations'

if ($EnsureSkill) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Write-DemoStep 'Installing the fleet-health skill...'
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Install-AgentSkill.ps1' -Arguments @(
        '-SkillName', 'fleet-health',
        '-SkillPath', '.\sre-config\skills\fleet-health\SKILL.md'
    )
}
else {
    Write-DemoInfo 'No live seed — the skill loads during one-time setup. Add -EnsureSkill to reinstall.'
}

Write-DemoWarn 'Replace the Scope B/C subscription IDs with your own same-tenant subscriptions before pasting.'
Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'Scope C reported as a blind spot (Unknown, not green); estate not healthy while a scope is unknown; A healthy vs B degraded.'
Write-DemoReset -Text 'None — query-only scenario.'
