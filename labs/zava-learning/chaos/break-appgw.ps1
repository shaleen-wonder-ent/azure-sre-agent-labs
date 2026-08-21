<#
.SYNOPSIS
  App Gateway lane probe fault, shipped FROM IaC.
#>
param(
  [string]$ResourceGroup = "rg-zava-learning-demo"
)
. "$PSScriptRoot\_common.ps1"

Write-Host "[break-appgw] Shipping the bad quiz-appgw probe path from IaC..." -ForegroundColor Yellow

Write-Host "  1/2 Committing bad release (appgwLaneProbePath=/status-ping) to GitHub..." -ForegroundColor Gray
$changed = Set-ParamLine -Pattern '"appgwLaneProbePath"\s*:\s*\{\s*"value"\s*:\s*"/health"\s*\}' `
                         -Replacement '"appgwLaneProbePath": { "value": "/status-ping" }'
if ($changed) { Invoke-GitPush -Message "Update quiz appgw lane health probe path" }
else { Write-Host "  (appgwLaneProbePath already /status-ping in source)" -ForegroundColor DarkGray }

Write-Host "  2/2 Updating the live quiz-appgw health probe to /status-ping..." -ForegroundColor Gray
$gatewayName = Get-AppGwName -ResourceGroup $ResourceGroup
$live = Set-AppGwProbePath -ResourceGroup $ResourceGroup -GatewayName $gatewayName `
                           -ProbeName "quiz-appgw-health" -Path "/status-ping"
if (-not $live) {
  Write-Host "[break-appgw] FAILED: the live probe did not change to /status-ping (gateway busy or error)." -ForegroundColor Red
  Write-Host "             The fault is NOT live. Re-run break-appgw." -ForegroundColor Red
  exit 1
}

Write-Host "[break-appgw] Fault live + in source. The gateway marks the quiz-appgw backend unhealthy." -ForegroundColor Red
# No manual paging: App Gateway reports the backend unhealthy, firing the Azure Monitor metric alert
# (Zava-portal-unreachable) and the Zava-portal-5xx-elevated log alert; the SRE Agent investigates.
