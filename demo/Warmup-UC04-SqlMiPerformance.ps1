<#
.SYNOPSIS
  Warm up UC4 — Azure SQL Managed Instance performance analysis (enterprise-operations agent).

.DESCRIPTION
  Seeds a live blocking transaction on the demo SQL MI, then runs Diagnose to
  reveal the blocked/blocker session IDs. Substitute those IDs into the printed
  prompt (they replace <BLOCKED> and <BLOCKER>). Also confirm the SQL MI name in
  the prompt matches your deployment (default in the recording: sqlmi-lab-b684kg).

  Underlying script: labs/enterprise-operations/scripts/Invoke-SqlMiDemo.ps1

.EXAMPLE
  ./demo/Warmup-UC04-SqlMiPerformance.ps1
.EXAMPLE
  ./demo/Warmup-UC04-SqlMiPerformance.ps1 -Reset
#>
[CmdletBinding()]
param(
    [int]$DurationSeconds = 600,
    [string]$SubscriptionId,
    [switch]$Reset,
    [switch]$PromptOnly,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

$prompt = 'Analyze performance for SQL Managed Instance sqlmi-lab-b684kg / database sre_demo for the last 15 minutes. Blocked session <BLOCKED> waits on LCK_M_X (UPDATE); blocker <BLOCKER> is suspended in WAITFOR; Query Store query_id 18 ~18.9 ms, 883 reads. Rank bottlenecks, separate observed from inferred, disclose the short baseline, redact statement text, recommend the least disruptive fix, and perform no writes.'

Write-DemoBanner -Number 4 -Title 'Azure SQL Managed Instance performance analysis' -Agent 'enterprise-operations agent'

$labPath = Join-Path (Get-DemoRepoRoot) 'labs/enterprise-operations'

if ($Reset) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Set-DemoSubscription -SubscriptionId $SubscriptionId
    Write-DemoStep 'Clearing the blocking fault (Invoke-SqlMiDemo.ps1 -Action Reset)...'
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Invoke-SqlMiDemo.ps1' -Arguments @('-Action', 'Reset', '-ApproveWrite')
    Write-DemoInfo 'Fault cleared.'
    return
}

if (-not $PromptOnly) {
    if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az') }
    Set-DemoSubscription -SubscriptionId $SubscriptionId

    Write-DemoStep "Seeding the blocking transaction for ${DurationSeconds}s (Invoke-SqlMiDemo.ps1 -Action Fault)..."
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Invoke-SqlMiDemo.ps1' -Arguments @('-Action', 'Fault', '-DurationSeconds', $DurationSeconds, '-ApproveWrite')

    Write-DemoStep 'Reading the blocked/blocker session IDs (Invoke-SqlMiDemo.ps1 -Action Diagnose)...'
    Write-DemoWarn 'Copy the session_id (blocked) and blocking_session_id (blocker) below into the prompt.'
    Invoke-DemoPwsh -WorkingDirectory $labPath -ScriptRelativePath 'scripts/Invoke-SqlMiDemo.ps1' -Arguments @('-Action', 'Diagnose')
}

Write-DemoWarn 'Replace <BLOCKED> and <BLOCKER> with the session IDs above before pasting.'
Write-DemoPrompt -Text $prompt
Write-DemoHighlight -Text 'Lock contention ranked #1; CPU/IO/storage/platform explicitly ruled out; no scaling recommended.'
Write-DemoReset -Text './demo/Warmup-UC04-SqlMiPerformance.ps1 -Reset   (clears the blocking fault)'
