<#
.SYNOPSIS
  Warm up UC12 — Security incident investigation (enterprise-operations agent).

.DESCRIPTION
  Opens an inbound RDP allow-any rule on the approved NSG (an Activity Log
  security event) in rg-eops-uc6-lifecycle, waits for ingestion, then prints the
  exact prompt. Restore the secure baseline afterwards with -Cleanup.

  Underlying script: labs/enterprise-operations/scripts/Seed-SecurityIncident.ps1

.EXAMPLE
  ./demo/Warmup-UC12-SecurityIncident.ps1
.EXAMPLE
  ./demo/Warmup-UC12-SecurityIncident.ps1 -Cleanup
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-eops-uc6-lifecycle',
    [string]$NsgName = 'nsg-uc6-approved',
    [string]$SubscriptionId,
    [int]$WaitSeconds = 120,
    [switch]$NoWait,
    [switch]$Cleanup,
    [switch]$PromptOnly,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

$prompt = 'Security incident investigation for resource group rg-eops-uc6-lifecycle over the last 2 hours — a suspected NSG rule change. Attribute the change (who/when/where), identify the rule and port/protocol/source, scope blast radius from association and reachability, decide exposure vs compromise, and give approval-gated containment. Read-only.'

Write-DemoBanner -Number 12 -Title 'Security incident investigation' -Agent 'enterprise-operations agent'

$labPath = Join-Path (Get-DemoRepoRoot) 'labs/enterprise-operations'
$seedArgs = @('-ResourceGroupName', $ResourceGroupName, '-NsgName', $NsgName)
if ($SubscriptionId) { $seedArgs += @('-SubscriptionId', $SubscriptionId) }

if ($Cleanup) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Write-DemoStep 'Restoring the secure NSG baseline (removing allow-rdp-any)...'
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Seed-SecurityIncident.ps1' -Arguments ($seedArgs + '-Cleanup')
    return
}

if (-not $PromptOnly) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Set-DemoSubscription -SubscriptionId $SubscriptionId
    Write-DemoWarn "This opens inbound RDP (3389 from *) on '$NsgName'. Restore it with -Cleanup after recording."
    Write-DemoStep "Seeding the NSG rule change into '$ResourceGroupName'..."
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Seed-SecurityIncident.ps1' -Arguments $seedArgs
    if (-not $NoWait) { Wait-DemoIngestion -Seconds $WaitSeconds }
}

Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'Verdict EXPOSURE, not compromise; blast radius scoped (NSG unassociated -> zero live traffic); attribution with truncated IPs.'
Write-DemoReset -Text './demo/Warmup-UC12-SecurityIncident.ps1 -Cleanup   (restores the secure NSG baseline)'
