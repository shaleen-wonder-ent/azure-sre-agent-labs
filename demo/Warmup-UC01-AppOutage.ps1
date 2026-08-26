<#
.SYNOPSIS
  Warm up UC1 — Application outage root cause analysis (Zava Learning agent).

.DESCRIPTION
  Injects the "no healthy instances" fault into the Zava Learning quiz lane
  (drops the quiz-app to zero replicas) by calling the lab's chaos script, then
  prints the exact prompt to paste into the SRE Agent.

  Underlying script: labs/zava-learning/chaos/break-app.ps1

.EXAMPLE
  ./demo/Warmup-UC01-AppOutage.ps1
.EXAMPLE
  ./demo/Warmup-UC01-AppOutage.ps1 -ResourceGroup rg-zava-learning-srelab-zava
#>
[CmdletBinding()]
param(
    [string]$EnvironmentPrefix = 'srelab',
    [string]$ResourceGroup,
    [string]$SubscriptionId,
    [switch]$PromptOnly,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

$prompt = 'Investigate the outage affecting the Zava Learning quiz launch over the last 30 minutes. Correlate Application Insights, Log Analytics, Azure Monitor alerts, and deployment history. Build a UTC timeline, rank hypotheses, name the leading root cause and confidence, and recommend the least disruptive mitigation. Read-only.'

Write-DemoBanner -Number 1 -Title 'Application outage root cause analysis' -Agent 'Zava Learning agent'

if (-not $ResourceGroup) { $ResourceGroup = "rg-zava-learning-$EnvironmentPrefix-zava" }
$labPath = Join-Path (Get-DemoRepoRoot) 'labs/zava-learning'

if (-not $PromptOnly) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az', 'git') }
    Set-DemoSubscription -SubscriptionId $SubscriptionId
    [void](Test-DemoResourceGroup -ResourceGroup $ResourceGroup -SubscriptionId $SubscriptionId)
    Write-DemoStep "Injecting the scale-to-zero fault via chaos/break-app.ps1 (RG: $ResourceGroup)..."
    Write-DemoInfo 'This commits the bad release to GitHub and deactivates the live quiz-app revision.'
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'chaos/break-app.ps1' -Arguments @('-ResourceGroup', $ResourceGroup)
    Write-DemoInfo 'The Azure Monitor 5xx alert flows to the agent as an incident within a few minutes.'
}

Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'Names the quiz/assessment tier and the scale-to-zero change; does not blame app code for every 5xx.'
Write-DemoReset -Text "pwsh ./chaos/fix-app.ps1 -ResourceGroup $ResourceGroup   (from labs/zava-learning)"
