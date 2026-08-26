<#
.SYNOPSIS
  One-time demo setup — run ONCE before recording (not between demos).

.DESCRIPTION
  Configures the enterprise-operations agent with base skills, connectors, tasks
  and the write-approval hook, then installs the four dataset skills used by
  UC8/9/11/13. Optionally wires the Grubify GitHub deployment used by UC14.

  Mirrors the "One-time setup" block in SRE-AGENT-DEMO-RUNBOOK.md.

.PARAMETER IncludeGrubifyGitHub
  Also run labs/starter-lab/scripts/Setup-GrubifyDeployment.ps1 (requires 'gh auth login'
  and an active azd environment for the starter lab).

.PARAMETER GitHubRepository
  owner/repo for the Grubify deployment connection (default: shaleen-wonder-ent/grubify).

.EXAMPLE
  ./demo/Invoke-OneTimeSetup.ps1
.EXAMPLE
  ./demo/Invoke-OneTimeSetup.ps1 -IncludeGrubifyGitHub -GitHubRepository myorg/grubify
#>
[CmdletBinding()]
param(
    [string]$SubscriptionId,
    [switch]$IncludeGrubifyGitHub,
    [string]$GitHubRepository = 'shaleen-wonder-ent/grubify',
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

$eoPath = Join-Path (Get-DemoRepoRoot) 'labs/enterprise-operations'
$starterPath = Join-Path (Get-DemoRepoRoot) 'labs/starter-lab'

Write-Host ''
Write-Host '=== SRE Agent demo — one-time setup ===' -ForegroundColor Cyan

if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az', 'azd') }
Set-DemoSubscription -SubscriptionId $SubscriptionId

Write-DemoStep 'Base agent configuration (Configure-SreAgent.ps1)...'
Invoke-DemoPwsh -WorkingDirectory $eoPath -ScriptRelativePath 'scripts/Configure-SreAgent.ps1'

Write-DemoStep 'UC8 — entra-authentication skill + dataset (Add-EntraAuthSkill.ps1)...'
Invoke-DemoPwsh -WorkingDirectory $eoPath -ScriptRelativePath 'scripts/Add-EntraAuthSkill.ps1'

$skills = @(
    @{ Name = 'capacity-forecast';      Path = '.\sre-config\skills\capacity-forecast\SKILL.md';      Fixture = '.\docs\capacity-forecast-fixture.json'; Uc = 'UC9' },
    @{ Name = 'cost-anomaly';           Path = '.\sre-config\skills\cost-anomaly\SKILL.md';           Fixture = '.\docs\cost-anomaly-fixture.json';      Uc = 'UC11' },
    @{ Name = 'security-investigation'; Path = '.\sre-config\skills\security-investigation\SKILL.md'; Fixture = $null;                                    Uc = 'UC12' },
    @{ Name = 'fleet-health';           Path = '.\sre-config\skills\fleet-health\SKILL.md';           Fixture = $null;                                    Uc = 'UC13' }
)

foreach ($skill in $skills) {
    Write-DemoStep "$($skill.Uc) — installing the $($skill.Name) skill..."
    $installParams = @('-SkillName', $skill.Name, '-SkillPath', $skill.Path)
    if ($skill.Fixture) { $installParams += @('-FixturePath', $skill.Fixture) }
    Invoke-DemoPwsh -WorkingDirectory $eoPath -ScriptRelativePath 'scripts/Install-AgentSkill.ps1' -Arguments $installParams
}

if ($IncludeGrubifyGitHub) {
    Write-DemoStep "UC14 — Grubify GitHub deployment connection ($GitHubRepository)..."
    Assert-DemoTool 'gh'
    Invoke-DemoPwsh -WorkingDirectory $starterPath -ScriptRelativePath 'scripts/Setup-GrubifyDeployment.ps1' -Arguments @('-Repository', $GitHubRepository)
}
else {
    Write-DemoInfo 'Skipped UC14 Grubify GitHub wiring. Add -IncludeGrubifyGitHub (needs gh auth) to include it.'
}

Write-Host ''
Write-Host 'One-time setup complete. UC8/9/11/13 need no per-demo seed.' -ForegroundColor Green
Write-Host 'Per-demo warm-up: run demo/Warmup-UC*.ps1 (~2 min before the prompt for UC4/6/7/10/12).' -ForegroundColor Green
