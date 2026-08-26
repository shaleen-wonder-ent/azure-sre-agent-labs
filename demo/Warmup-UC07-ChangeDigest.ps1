<#
.SYNOPSIS
  Warm up UC7 — Everything changed in the last 24 hours (enterprise-operations agent).

.DESCRIPTION
  Seeds a 24-hour change digest (RBAC add/remove, NSG rule, a failed deployment,
  tag updates) into rg-eops-uc6-lifecycle, waits for ingestion, then prints the
  exact prompt.

  Underlying script: labs/enterprise-operations/scripts/Seed-ChangeDigest.ps1

.EXAMPLE
  ./demo/Warmup-UC07-ChangeDigest.ps1
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-eops-uc6-lifecycle',
    [string]$SubscriptionId,
    [int]$WaitSeconds = 120,
    [switch]$NoWait,
    [switch]$Cleanup,
    [switch]$PromptOnly,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

$prompt = 'Build a unified UTC change timeline for resource group rg-eops-uc6-lifecycle over the last 24 hours: resource writes/deletes, deployments, NSG/route changes, and RBAC/policy changes. Group child operations by correlation/deployment ID, rank by operational impact, and flag failed or suspicious changes. Do not claim causality from timing alone. Read-only.'

Write-DemoBanner -Number 7 -Title 'Everything changed in the last 24 hours' -Agent 'enterprise-operations agent'

$labPath = Join-Path (Get-DemoRepoRoot) 'labs/enterprise-operations'
$seedArgs = @('-ResourceGroupName', $ResourceGroupName)
if ($SubscriptionId) { $seedArgs += @('-SubscriptionId', $SubscriptionId) }

if ($Cleanup) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Write-DemoStep "Deleting seed resource group '$ResourceGroupName'..."
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Seed-ChangeDigest.ps1' -Arguments ($seedArgs + '-Cleanup')
    return
}

if (-not $PromptOnly) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Set-DemoSubscription -SubscriptionId $SubscriptionId
    Write-DemoStep "Seeding the 24-hour change digest into '$ResourceGroupName'..."
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Seed-ChangeDigest.ps1' -Arguments $seedArgs
    if (-not $NoWait) { Wait-DemoIngestion -Seconds $WaitSeconds }
}

Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'One deduplicated timeline; flags the FAILED deployment and the RBAC + NSG changes as higher risk.'
Write-DemoReset -Text './demo/Warmup-UC06-ResourceLifecycle.ps1 -Cleanup   (shared seed resource group)'
