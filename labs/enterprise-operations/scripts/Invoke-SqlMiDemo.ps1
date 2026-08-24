[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Diagnose", "Fault", "Reset")]
    [string]$Action,

    [ValidateRange(30, 600)]
    [int]$DurationSeconds = 600,

    [switch]$ApproveWrite,

    [switch]$AsObject,

    [string]$TerraformDirectory = (Join-Path $PSScriptRoot "..\infra"),
    [string]$ResourceGroupName,
    [string]$VirtualMachineName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TerraformOutputValue {
    param([Parameter(Mandatory)][string]$Name)

    $value = terraform -chdir="$TerraformDirectory" output -raw $Name 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value)) {
        throw "Terraform output '$Name' is unavailable. Supply the corresponding script parameter."
    }

    return $value.Trim()
}

if ($Action -ne "Diagnose" -and -not $ApproveWrite) {
    throw "$Action changes demo database state. Re-run with -ApproveWrite after reviewing scope and rollback."
}

if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
    $ResourceGroupName = Get-TerraformOutputValue -Name "resource_group_name"
}
if ([string]::IsNullOrWhiteSpace($VirtualMachineName)) {
    $VirtualMachineName = Get-TerraformOutputValue -Name "diagnostics_vm_name"
}

$command = switch ($Action) {
    "Diagnose" { "/usr/local/bin/sre-sqlmi diagnose" }
    "Fault" { "/usr/local/bin/sre-sqlmi fault $DurationSeconds" }
    "Reset" { "/usr/local/bin/sre-sqlmi reset" }
}

$accessToken = az account get-access-token --resource "https://database.windows.net/" --query accessToken -o tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accessToken)) {
    throw "Could not obtain an Azure SQL access token for the signed-in Entra administrator."
}

$runCommandName = $null
try {
    $subscriptionId = az account show --query id -o tsv
    $managementToken = az account get-access-token --resource "https://management.azure.com/" --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($managementToken)) {
        throw "Could not obtain an Azure Resource Manager access token."
    }

    $runCommandName = "InvokeSqlMiDemo-$Action-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff'))"
    $runCommandUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/$VirtualMachineName/runCommands/$runCommandName`?api-version=2024-11-01"
    $requestBody = @{
        location   = "centralindia"
        properties = @{
            source              = @{ script = "set -euo pipefail`n$command" }
            protectedParameters = @(
                @{ name = "SQLMI_ACCESS_TOKEN"; value = $accessToken }
            )
            asyncExecution      = $false
            timeoutInSeconds    = [Math]::Max(300, $DurationSeconds + 120)
        }
    } | ConvertTo-Json -Depth 8 -Compress

    Invoke-RestMethod -Method Put -Uri $runCommandUri -Headers @{ Authorization = "Bearer $managementToken" } -ContentType "application/json" -Body $requestBody | Out-Null
    az vm run-command wait --resource-group $ResourceGroupName --vm-name $VirtualMachineName --name $runCommandName --updated
    if ($LASTEXITCODE -ne 0) {
        throw "Azure Run Command did not complete for SQL MI demo action '$Action'."
    }

    $result = az vm run-command show --resource-group $ResourceGroupName --vm-name $VirtualMachineName --name $runCommandName --instance-view --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $result.instanceView.executionState -ne "Succeeded" -or $result.instanceView.exitCode -ne 0) {
        throw "SQL MI demo action '$Action' failed: $($result.instanceView.error)"
    }

    $actionResult = [pscustomobject]@{
        Action         = $Action
        ExecutionState = $result.instanceView.executionState
        Output         = $result.instanceView.output
    }

    if ($AsObject) {
        $actionResult
    }
    else {
        Write-Host "Action:          $($actionResult.Action)"
        Write-Host "Execution state: $($actionResult.ExecutionState)"
        Write-Host ""
        Write-Host "Output:"
        Write-Host $actionResult.Output
    }
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($runCommandName)) {
        az vm run-command delete --resource-group $ResourceGroupName --vm-name $VirtualMachineName --name $runCommandName --yes 2>$null
    }
    $accessToken = $null
    $managementToken = $null
    $requestBody = $null
    [GC]::Collect()
}
