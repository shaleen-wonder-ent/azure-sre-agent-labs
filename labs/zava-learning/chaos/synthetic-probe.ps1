<#
.SYNOPSIS
  External synthetic monitor for the Zava learner journey (verification only).

  Hits the public App Gateway frontend (portal -> courses -> quiz launch) on a loop and
  reports whether a real student can complete the journey — the outside-in view.

  It does NOT raise incidents. A connectivity blackhole (e.g. the legacy NSG DENY shipped
  by break-nsg.ps1) makes App Gateway mark its backend unhealthy, which fires the native
  Azure Monitor metric alert 'Zava-portal-unreachable' (UnhealthyHostCount) — the SRE
  Agent picks that up autonomously. Use this probe to confirm the outage from the outside.

.EXAMPLE
  pwsh chaos/synthetic-probe.ps1
  pwsh chaos/synthetic-probe.ps1 -Failures 3 -IntervalSec 10
#>
param(
  [string]$ResourceGroup = "rg-zava-learning-demo",
  [string]$Url,
  [int]$Failures = 3,
  [int]$IntervalSec = 10,
  [int]$TimeoutSec = 8,
  [int]$MaxAttempts = 12
)
. "$PSScriptRoot\_common.ps1"

$result = Invoke-SyntheticGate -ResourceGroup $ResourceGroup -Url $Url `
  -Failures $Failures -IntervalSec $IntervalSec -TimeoutSec $TimeoutSec `
  -MaxAttempts $MaxAttempts

if ($result -and $result.outage) {
  Write-Host "[synthetic] Outage confirmed from the outside. Azure Monitor alert 'Zava-portal-unreachable' fires; the SRE Agent investigates." -ForegroundColor Cyan
  exit 0
} else {
  Write-Host "[synthetic] Journey healthy (or did not fail consistently)." -ForegroundColor Green
  exit 2
}
