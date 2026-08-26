<#
.SYNOPSIS
  Warm up UC14 — App-centric OOM incident to deployed fix (Starter Lab agent / Grubify API).

.DESCRIPTION
  Event-driven scenario with NO chat prompt. This floods the Grubify cart API to
  exhaust memory on the vulnerable build; Azure Monitor routes the HTTP 5xx alert
  to the incident-handler in autonomous mode, which investigates and opens a fix
  PR. A human merges, then GitHub Actions deploys the fixed image.

  Precondition: the connected Grubify repo main branch and deployed image must
  contain the intentional 10 MB-per-request leak in CartController.cs. GitHub is
  wired once via labs/starter-lab/scripts/Setup-GrubifyDeployment.ps1 (run during
  one-time setup, or via Invoke-OneTimeSetup.ps1 -IncludeGrubifyGitHub).

  Underlying script: labs/starter-lab/scripts/break-app.sh

.EXAMPLE
  ./demo/Warmup-UC14-OomToPr.ps1
.EXAMPLE
  ./demo/Warmup-UC14-OomToPr.ps1 -AppUrl https://grubify... -RequestCount 300 -SleepInterval 0.4
#>
[CmdletBinding()]
param(
    [string]$AppUrl,
    [int]$RequestCount,
    [double]$SleepInterval,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DemoCommon.psm1') -Force

Write-DemoBanner -Number 14 -Title 'App-centric OOM -> fix PR -> deploy' -Agent 'Starter Lab agent / Grubify API'

$labPath = Join-Path (Get-DemoRepoRoot) 'labs/starter-lab'

if (-not $SkipPrereqCheck) { Test-DemoPrereq -Tools @('az', 'azd') -RequireBash }

# break-app.sh takes positional [app-url] [request-count] [sleep-seconds]; a custom
# count/interval requires an explicit URL, otherwise the script auto-resolves the URL.
$breakArgs = @()
if ($AppUrl) {
    $breakArgs += $AppUrl
    if ($PSBoundParameters.ContainsKey('RequestCount')) { $breakArgs += "$RequestCount" }
    if ($PSBoundParameters.ContainsKey('SleepInterval')) { $breakArgs += "$SleepInterval" }
}
elseif ($PSBoundParameters.ContainsKey('RequestCount') -or $PSBoundParameters.ContainsKey('SleepInterval')) {
    Write-DemoWarn 'Custom -RequestCount/-SleepInterval require -AppUrl; running with defaults (200 requests @ 0.5s).'
}

Write-DemoStep 'Flooding the Grubify cart API to induce the memory leak (scripts/break-app.sh)...'
Invoke-DemoBash -WorkingDirectory $labPath -ScriptRelativePath 'scripts/break-app.sh' -Arguments $breakArgs

Write-Host ''
Write-Host 'This use case is event-driven — no chat prompt. Record the autonomous response:' -ForegroundColor Green
Write-Host '  1. Open https://sre.azure.com -> Activities -> Incidents' -ForegroundColor White
Write-Host '  2. Select [Sev3] alert-http-5xx-srelab-starter (include closed/recent incidents)' -ForegroundColor White
Write-Host '  3. Show the RCA: CartController.AddItemToCart retains a 10 MB byte[] per request' -ForegroundColor White
Write-Host '  4. Open the agent-created PR (fix only + evidence/validation/rollback)' -ForegroundColor White
Write-Host '  5. Merge manually -> Actions: Deploy Grubify API builds grubify-api:<sha>, verifies /health' -ForegroundColor White
Write-Host '  6. Re-run this script to confirm: 200 successes, 0 errors, No memory-leak failure detected' -ForegroundColor White

Write-DemoHighlight -Text 'Correlates cart HTTP 5xx + OutOfMemoryException with the unbounded 10 MB allocation; creates a minimal fix PR; a human merges; Actions deploys an immutable SHA image and verifies /health.'
Write-DemoReset -Text 'The merged fix on main is the reset. Re-run break-app.sh to confirm no memory-leak failure.'
