<#
.SYNOPSIS
  Warm up UC11 — Azure cost anomaly detection (enterprise-operations agent).

.DESCRIPTION
  Dataset scenario: the cost-anomaly skill and fixture install once during
  one-time setup. This script prints the exact prompt. Use -EnsureSkill to
  (re)install the skill and fixture.

  Underlying one-time command:
    Install-AgentSkill.ps1 -SkillName cost-anomaly
      -SkillPath .\sre-config\skills\cost-anomaly\SKILL.md
      -FixturePath .\docs\cost-anomaly-fixture.json

.EXAMPLE
  ./demo/Warmup-UC11-CostAnomaly.ps1
#>
[CmdletBinding()]
param(
    [switch]$EnsureSkill,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

$prompt = 'Use the cost-anomaly skill. Detect cost anomalies for this subscription over the last 7 days vs the prior baseline. Prefer live Cost Management; if unavailable, use the provided dataset and label it an estimate with its freshness lag. Rank drivers by absolute impact, correlate the top driver with deployment changes, separate new-resource cost from a true anomaly, project monthly impact, and give read-only savings recommendations.'

Write-DemoBanner -Number 11 -Title 'Azure cost anomaly detection' -Agent 'enterprise-operations agent'

$labPath = Join-Path (Get-DemoRepoRoot) 'labs/enterprise-operations'

if ($EnsureSkill) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Write-DemoStep 'Installing the cost-anomaly skill + fixture...'
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Install-AgentSkill.ps1' -Arguments @(
        '-SkillName', 'cost-anomaly',
        '-SkillPath', '.\sre-config\skills\cost-anomaly\SKILL.md',
        '-FixturePath', '.\docs\cost-anomaly-fixture.json'
    )
}
else {
    Write-DemoInfo 'No live seed — the skill/fixture load during one-time setup. Add -EnsureSkill to reinstall.'
}

Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'SQL Managed Instance = dominant driver; figures labeled estimate, not billed; correlates the real deployment.'
Write-DemoReset -Text 'None — dataset-only scenario.'
