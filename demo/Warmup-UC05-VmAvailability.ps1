<#
.SYNOPSIS
  Warm up UC5 — VM availability report, past 30 days (vm-cosmosdb agent).

.DESCRIPTION
  Loads the vm-availability-reporting skill and its 30-day fixture into the lab
  agent via the lab's configure-availability-demo.sh, then prints the exact
  prompt to paste into the SRE Agent. This is a dataset scenario — no live fault.

  Underlying script: labs/vm-cosmosdb/scripts/configure-availability-demo.sh

.EXAMPLE
  ./demo/Warmup-UC05-VmAvailability.ps1
#>
[CmdletBinding()]
param(
    [string]$SubscriptionId,
    [switch]$PromptOnly,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

$prompt = 'Create a VM availability report for all VMs in this lab for the 30 complete days ending today. Define the availability formula and sampling interval, report available/unavailable/unknown/excluded minutes per VM, compare to a 99.9% target, and flag retention gaps. This is read-only.'

Write-DemoBanner -Number 5 -Title 'VM availability report (past 30 days)' -Agent 'vm-cosmosdb agent'

$labPath = Join-Path (Get-DemoRepoRoot) 'labs/vm-cosmosdb'

if (-not $PromptOnly) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az', 'azd') -RequireBash }
    Set-DemoSubscription -SubscriptionId $SubscriptionId
    Write-DemoStep 'Loading the availability skill + 30-day dataset via scripts/configure-availability-demo.sh...'
    Invoke-DemoBash -WorkingDirectory $labPath -ScriptRelativePath 'scripts/configure-availability-demo.sh'
    Write-DemoInfo 'No live seed is required — run the prompt anytime after this loads.'
}

Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'Reports unknown time separately; refuses a 30-day claim if retention is shorter.'
Write-DemoReset -Text 'None — dataset-only scenario.'
