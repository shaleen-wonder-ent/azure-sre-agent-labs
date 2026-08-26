<#
.SYNOPSIS
  Warm up UC6 — Services or resources added/removed in the past 7 days (enterprise-operations agent).

.DESCRIPTION
  Seeds resource-lifecycle Activity Log events (added/removed/tagged) into
  rg-eops-uc6-lifecycle, waits for ingestion, then prints the exact prompt.

  Underlying script: labs/enterprise-operations/scripts/Seed-ResourceLifecycle.ps1

.EXAMPLE
  ./demo/Warmup-UC06-ResourceLifecycle.ps1
.EXAMPLE
  ./demo/Warmup-UC06-ResourceLifecycle.ps1 -Cleanup
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

$prompt = 'Inventory Azure resources created, deleted, moved, or materially modified in resource group rg-eops-uc6-lifecycle during the last seven days. Query Activity Log and Resource Graph. Return separate Added/Removed/Moved/Modified tables, deduplicate child operations, attribute callers, and flag changes missing the change-ticket tag. Read-only.'

Write-DemoBanner -Number 6 -Title 'Resources added or removed (past 7 days)' -Agent 'enterprise-operations agent'

$labPath = Join-Path (Get-DemoRepoRoot) 'labs/enterprise-operations'
$seedArgs = @('-ResourceGroupName', $ResourceGroupName)
if ($SubscriptionId) { $seedArgs += @('-SubscriptionId', $SubscriptionId) }

if ($Cleanup) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Write-DemoStep "Deleting seed resource group '$ResourceGroupName'..."
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Seed-ResourceLifecycle.ps1' -Arguments ($seedArgs + '-Cleanup')
    return
}

if (-not $PromptOnly) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Set-DemoSubscription -SubscriptionId $SubscriptionId
    Write-DemoStep "Seeding resource-lifecycle events into '$ResourceGroupName'..."
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Seed-ResourceLifecycle.ps1' -Arguments $seedArgs
    if (-not $NoWait) { Wait-DemoIngestion -Seconds $WaitSeconds }
}

Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'Lists the deleted route table from Activity Log (absent in Resource Graph) and flags the missing-tag resource.'
Write-DemoReset -Text './demo/Warmup-UC06-ResourceLifecycle.ps1 -Cleanup   (also clears UC7/UC10 seed data)'
