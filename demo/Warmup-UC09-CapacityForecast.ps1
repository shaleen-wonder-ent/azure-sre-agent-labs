<#
.SYNOPSIS
  Warm up UC9 — Capacity exhaustion prediction (enterprise-operations agent).

.DESCRIPTION
  Dataset scenario: the capacity-forecast skill and fixture install once during
  one-time setup. This script prints the exact prompt. Use -EnsureSkill to
  (re)install the skill and fixture.

  Underlying one-time command:
    Install-AgentSkill.ps1 -SkillName capacity-forecast
      -SkillPath .\sre-config\skills\capacity-forecast\SKILL.md
      -FixturePath .\docs\capacity-forecast-fixture.json

.EXAMPLE
  ./demo/Warmup-UC09-CapacityForecast.ps1
#>
[CmdletBinding()]
param(
    [switch]$EnsureSkill,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

$prompt = 'Use the capacity-forecast skill. Forecast capacity exhaustion for the Zava Orders SQL database over the next 21 days using the daily history available. Assess data quality, report current/limit/headroom/growth/forecast range/confidence per dimension, model weekly seasonality where supported and forecast the seasonal peak, rank the dimension closest to exhaustion, and distinguish resource limit from quota. Read-only.'

Write-DemoBanner -Number 9 -Title 'Capacity exhaustion prediction' -Agent 'enterprise-operations agent'

$labPath = Join-Path (Get-DemoRepoRoot) 'labs/enterprise-operations'

if ($EnsureSkill) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Write-DemoStep 'Installing the capacity-forecast skill + fixture...'
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Install-AgentSkill.ps1' -Arguments @(
        '-SkillName', 'capacity-forecast',
        '-SkillPath', '.\sre-config\skills\capacity-forecast\SKILL.md',
        '-FixturePath', '.\docs\capacity-forecast-fixture.json'
    )
}
else {
    Write-DemoInfo 'No live seed — the skill/fixture load during one-time setup. Add -EnsureSkill to reinstall.'
}

Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'Storage critical in ~2 days (R2 ~ 1.0); connections modeled with weekly seasonality; resource limit != quota.'
Write-DemoReset -Text 'None — dataset-only scenario.'
