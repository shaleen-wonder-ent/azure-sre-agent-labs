[CmdletBinding()]
param(
    [string] $TerraformDirectory = (Join-Path $PSScriptRoot '..\terraform'),

    [ValidateRange(1, 168)]
    [int] $LookbackHours = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($command in @('terraform', 'az')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "$command is required."
    }
}

$terraformOutputJson = & terraform "-chdir=$TerraformDirectory" output -json
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read Terraform outputs.'
}
$outputs = $terraformOutputJson | ConvertFrom-Json -Depth 100
$workspaceId = $outputs.log_analytics_workspace_customer_id.value
$query = @"
F5Telemetry_CL
| where TimeGenerated > ago(${LookbackHours}h)
| extend Category = tostring(column_ifexists("telemetryEventCategory_s", "unknown"))
| summarize Events=count(), LastSeen=max(TimeGenerated) by Category
| order by Events desc
"@

Write-Host "Querying workspace $workspaceId..."
& az monitor log-analytics query `
    --workspace $workspaceId `
    --analytics-query $query `
    --output table
if ($LASTEXITCODE -ne 0) {
    throw 'Log Analytics query failed. Confirm Azure CLI login and workspace access.'
}