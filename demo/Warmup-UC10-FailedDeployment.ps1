<#
.SYNOPSIS
  Warm up UC10 — Failed deployment investigation (enterprise-operations agent).

.DESCRIPTION
  Seeds three ARM deployments (one good, two failed) into rg-eops-uc6-lifecycle,
  then prints the exact prompt. Deployment history ingests almost immediately.

  Underlying script: labs/enterprise-operations/scripts/Seed-DeploymentFaults.ps1

.EXAMPLE
  ./demo/Warmup-UC10-FailedDeployment.ps1
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-eops-uc6-lifecycle',
    [string]$SubscriptionId,
    [int]$WaitSeconds = 60,
    [switch]$NoWait,
    [switch]$Cleanup,
    [switch]$PromptOnly,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

$prompt = 'Failed deployment investigation for resource group rg-eops-uc6-lifecycle over the last 3 hours. Identify the first failing operation and error code for each, distinguish control-plane failures from runtime regressions, preserve the last known good deployment, and recommend fixes with approval gates. Read-only.'

Write-DemoBanner -Number 10 -Title 'Failed deployment investigation' -Agent 'enterprise-operations agent'

$labPath = Join-Path (Get-DemoRepoRoot) 'labs/enterprise-operations'
$seedArgs = @('-ResourceGroupName', $ResourceGroupName)
if ($SubscriptionId) { $seedArgs += @('-SubscriptionId', $SubscriptionId) }

if ($Cleanup) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Write-DemoStep "Deleting seed resource group '$ResourceGroupName'..."
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Seed-DeploymentFaults.ps1' -Arguments ($seedArgs + '-Cleanup')
    return
}

if (-not $PromptOnly) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Set-DemoSubscription -SubscriptionId $SubscriptionId
    Write-DemoStep "Seeding failed + last-known-good deployments into '$ResourceGroupName'..."
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Seed-DeploymentFaults.ps1' -Arguments $seedArgs
    if (-not $NoWait) { Wait-DemoIngestion -Seconds $WaitSeconds }
}

Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'First failing op + error code per deployment; last-known-good preserved; states no runtime regression.'
Write-DemoReset -Text './demo/Warmup-UC06-ResourceLifecycle.ps1 -Cleanup   (shared seed resource group)'
