<#
.SYNOPSIS
  Warm up UC3 — VM and infrastructure incident investigation (vm-cosmosdb agent).

.DESCRIPTION
  Runs CPU stress (default) on vm-sap-app-01 via the lab's break-vm.sh, then
  prints the exact prompt to paste into the SRE Agent. The stress self-clears
  after 10 minutes.

  Underlying script: labs/vm-cosmosdb/scripts/break-vm.sh

.EXAMPLE
  ./demo/Warmup-UC03-VmIncident.ps1
.EXAMPLE
  ./demo/Warmup-UC03-VmIncident.ps1 -Mode memory
#>
[CmdletBinding()]
param(
    [ValidateSet('cpu', 'memory', 'drift', 'all')]
    [string]$Mode = 'cpu',
    [string]$SubscriptionId,
    [switch]$PromptOnly,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

$prompt = 'Investigate the incident on VM vm-sap-app-01 over the last 30 minutes. Check Resource Health, power state, CPU/memory, disk, network, and Activity Log. Correlate control-plane and guest evidence into a UTC timeline, name the probable cause and confidence, and recommend least-disruptive actions. Do not restart or resize without approval.'

Write-DemoBanner -Number 3 -Title 'VM and infrastructure incident investigation' -Agent 'vm-cosmosdb agent'

$labPath = Join-Path (Get-DemoRepoRoot) 'labs/vm-cosmosdb'

if (-not $PromptOnly) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az', 'azd') -RequireBash }
    Set-DemoSubscription -SubscriptionId $SubscriptionId
    Write-DemoStep "Triggering '$Mode' stress on vm-sap-app-01 via scripts/break-vm.sh..."
    Invoke-DemoBash -WorkingDirectory $labPath -ScriptRelativePath 'scripts/break-vm.sh' -Arguments @($Mode)
    Write-DemoInfo 'A Resource Health / metric alert fires within ~3-5 minutes.'
}

Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'Attributes sustained CPU from guest + control-plane evidence; restart is a gated mitigation, not the diagnosis.'
Write-DemoReset -Text 'None needed — the CPU stress self-clears after 10 minutes.'
