[CmdletBinding()]
param(
    [string]$TerraformDirectory = (Join-Path $PSScriptRoot "..\infra"),
    [string]$ResourceGroupName,
    [string]$VirtualMachineName,
    [string]$SqlMiFqdn,
    [string]$DatabaseName = "sre_demo"
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

function ConvertTo-GzipBase64 {
    param([Parameter(Mandatory)][string]$Value)

    $output = [IO.MemoryStream]::new()
    $gzip = [IO.Compression.GzipStream]::new($output, [IO.Compression.CompressionLevel]::SmallestSize, $true)
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
        $gzip.Write($bytes, 0, $bytes.Length)
    }
    finally {
        $gzip.Dispose()
    }

    return [Convert]::ToBase64String($output.ToArray())
}

if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
    $ResourceGroupName = Get-TerraformOutputValue -Name "resource_group_name"
}
if ([string]::IsNullOrWhiteSpace($VirtualMachineName)) {
    $VirtualMachineName = Get-TerraformOutputValue -Name "diagnostics_vm_name"
}
if ([string]::IsNullOrWhiteSpace($SqlMiFqdn)) {
    $SqlMiFqdn = Get-TerraformOutputValue -Name "sqlmi_fqdn"
}
$accessToken = az account get-access-token --resource "https://database.windows.net/" --query accessToken -o tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accessToken)) {
    throw "Could not obtain an Azure SQL access token for the signed-in Entra administrator."
}

$bootstrapScript = (Get-Content (Join-Path $PSScriptRoot "sqlmi\bootstrap.sh") -Raw).Replace("`r`n", "`n")
$bootstrapSql = (Get-Content (Join-Path $PSScriptRoot "sqlmi\bootstrap.sql") -Raw).Replace("`r`n", "`n")
$commandScript = (Get-Content (Join-Path $PSScriptRoot "sqlmi\sre-sqlmi") -Raw).Replace("`r`n", "`n")

$payload = @"
set -euo pipefail
base64 -d <<'BOOTSTRAP_SCRIPT' | gzip -d >/tmp/bootstrap.sh
$(ConvertTo-GzipBase64 -Value $bootstrapScript)
BOOTSTRAP_SCRIPT
base64 -d <<'BOOTSTRAP_SQL' | gzip -d >/tmp/bootstrap.sql
$(ConvertTo-GzipBase64 -Value $bootstrapSql)
BOOTSTRAP_SQL
base64 -d <<'SRE_COMMAND' | gzip -d >/tmp/sre-sqlmi
$(ConvertTo-GzipBase64 -Value $commandScript)
SRE_COMMAND
chmod 0700 /tmp/bootstrap.sh
/tmp/bootstrap.sh
"@
$payload = $payload.Replace("`r`n", "`n")

try {
    $subscriptionId = az account show --query id -o tsv
    $managementToken = az account get-access-token --resource "https://management.azure.com/" --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($managementToken)) {
        throw "Could not obtain an Azure Resource Manager access token."
    }

    $runCommandUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/$VirtualMachineName/runCommands/InitializeSqlMiDemo?api-version=2024-11-01"
    $requestBody = @{
        location   = "centralindia"
        properties = @{
            source              = @{ script = $payload }
            parameters          = @(
                @{ name = "SQLMI_FQDN"; value = $SqlMiFqdn }
                @{ name = "SQLMI_DATABASE"; value = $DatabaseName }
            )
            protectedParameters = @(
                @{ name = "SQLMI_ACCESS_TOKEN"; value = $accessToken }
            )
            asyncExecution      = $false
            timeoutInSeconds    = 3600
        }
    } | ConvertTo-Json -Depth 8 -Compress

    Invoke-RestMethod -Method Put -Uri $runCommandUri -Headers @{ Authorization = "Bearer $managementToken" } -ContentType "application/json" -Body $requestBody | Out-Null
    az vm run-command wait --resource-group $ResourceGroupName --vm-name $VirtualMachineName --name InitializeSqlMiDemo --updated
    if ($LASTEXITCODE -ne 0) {
        throw "Azure Managed Run Command did not complete successfully."
    }

    $runCommand = az vm run-command show --resource-group $ResourceGroupName --vm-name $VirtualMachineName --name InitializeSqlMiDemo --instance-view --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Could not retrieve Azure Managed Run Command results."
    }

    if ($runCommand.instanceView.executionState -ne "Succeeded" -or $runCommand.instanceView.exitCode -ne 0) {
        throw "SQL MI bootstrap failed on the diagnostics VM: $($runCommand.instanceView.error)"
    }

    $runCommand | Select-Object provisioningState, instanceView | ConvertTo-Json -Depth 8
}
finally {
    $accessToken = $null
    $managementToken = $null
    $requestBody = $null
    [GC]::Collect()
}
