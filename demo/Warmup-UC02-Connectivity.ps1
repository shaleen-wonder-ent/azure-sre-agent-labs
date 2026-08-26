<#
.SYNOPSIS
  Warm up UC2 — Connectivity diagnostics: hub to spoke to internet (Zava Learning agent).

.DESCRIPTION
  Injects a legacy cross-subnet NSG deny rule into the Zava Learning nsg-lane by
  calling the lab's chaos script, then prints the exact prompt to paste into the
  SRE Agent.

  Underlying script: labs/zava-learning/chaos/break-nsg.ps1

.EXAMPLE
  ./demo/Warmup-UC02-Connectivity.ps1
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

$prompt = 'Diagnose connectivity from the App Gateway to the internal apps subnet for the last 30 minutes. Trace DNS, effective NSG and routes, App Gateway backend health, and the destination listener. Return a hop table, identify the first failing hop, and propose the smallest correction without changing routes, NSGs, or DNS. Read-only.'

Write-DemoBanner -Number 2 -Title 'Connectivity diagnostics: hub to spoke to internet' -Agent 'Zava Learning agent'

if (-not $ResourceGroup) { $ResourceGroup = "rg-zava-learning-$EnvironmentPrefix-zava" }
$labPath = Join-Path (Get-DemoRepoRoot) 'labs/zava-learning'

if (-not $PromptOnly) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az', 'git') }
    Set-DemoSubscription -SubscriptionId $SubscriptionId
    [void](Test-DemoResourceGroup -ResourceGroup $ResourceGroup -SubscriptionId $SubscriptionId)
    Write-DemoStep "Injecting the legacy-cross-subnet-deny NSG rule via chaos/break-nsg.ps1 (RG: $ResourceGroup)..."
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'chaos/break-nsg.ps1' -Arguments @('-ResourceGroup', $ResourceGroup)
    Write-DemoInfo 'App Gateway backend health degrades; wait a couple of minutes before the prompt.'
}

Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'Finds the NSG deny rule as the first failing hop; rejects a healthy hop.'
Write-DemoReset -Text "pwsh ./chaos/fix-nsg.ps1 -ResourceGroup $ResourceGroup   (from labs/zava-learning)"
