[CmdletBinding()]
param(
    [string]$ResourceGroupName = "rg-eops-uc6-lifecycle",
    [string]$Location = "eastus2",
    [string]$SubscriptionId,
    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
    $SubscriptionId = az account show --query id -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($SubscriptionId)) {
        throw "Could not resolve the current Azure subscription. Run 'az login' first."
    }
}

$resourceGroupId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"

if ($Cleanup) {
    az group delete --name $ResourceGroupName --subscription $SubscriptionId --yes --no-wait 2>$null | Out-Null
    Write-Host "Cleanup requested. Deleting resource group '$ResourceGroupName' (async)."
    return
}

if ((az group exists --name $ResourceGroupName --subscription $SubscriptionId) -ne "true") {
    az group create --name $ResourceGroupName --location $Location --subscription $SubscriptionId `
        --tags demo=sre-uc10 environment=lab --output none
}

$stamp = [DateTime]::UtcNow.ToString("yyyyMMddHHmmss")
$results = New-Object System.Collections.Generic.List[object]

function Invoke-SeedDeployment {
    param([string]$Name, [string]$TemplateJson, [string]$ExpectClass)
    $path = Join-Path $env:TEMP "$Name.json"
    $TemplateJson | Set-Content -Path $path -Encoding utf8
    az deployment group create --resource-group $ResourceGroupName --name $Name `
        --template-file $path --subscription $SubscriptionId --output none 2>$null
    $state = az deployment group show --resource-group $ResourceGroupName --name $Name `
        --query "properties.provisioningState" -o tsv 2>$null
    Remove-Item $path -ErrorAction SilentlyContinue
    $results.Add([pscustomobject]@{ Deployment = $Name; Class = $ExpectClass; Result = $state })
}

# Last known good: a valid free resource that deploys successfully.
Invoke-SeedDeployment -Name "uc10-good-deploy-$stamp" -ExpectClass "Successful (last known good)" -TemplateJson @"
{
  "`$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": [
    { "type": "Microsoft.Network/routeTables", "apiVersion": "2023-09-01", "name": "rt-uc10-good", "location": "$Location", "properties": { "disableBgpRoutePropagation": false } }
  ]
}
"@

# Failure class 1: invalid resource configuration (rejected by the resource provider).
Invoke-SeedDeployment -Name "uc10-bad-sku-$stamp" -ExpectClass "Failed - invalid configuration (SKU)" -TemplateJson @"
{
  "`$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": [
    { "type": "Microsoft.Storage/storageAccounts", "apiVersion": "2023-01-01", "name": "uc10sku$stamp", "location": "$Location", "sku": { "name": "Standard_INVALID" }, "kind": "StorageV2" }
  ]
}
"@

# Failure class 2: missing dependency (child resource whose parent does not exist).
Invoke-SeedDeployment -Name "uc10-bad-dependency-$stamp" -ExpectClass "Failed - missing dependency (parent not found)" -TemplateJson @"
{
  "`$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": [
    { "type": "Microsoft.Network/networkSecurityGroups/securityRules", "apiVersion": "2023-09-01", "name": "nsg-uc10-absent/deny-all", "properties": { "priority": 100, "access": "Deny", "direction": "Inbound", "protocol": "*", "sourceAddressPrefix": "*", "destinationAddressPrefix": "*", "sourcePortRange": "*", "destinationPortRange": "*" } }
  ]
}
"@

Write-Host ""
Write-Host "Seeded deployment history at $([DateTime]::UtcNow.ToString('u')):"
$results | Format-Table -AutoSize

Write-Host "Scope for prompt 10:"
Write-Host "  $resourceGroupId"
Write-Host ""
Write-Host "Expected agent findings:"
Write-Host "  - Last known good: uc10-good-deploy-$stamp (route table succeeded)"
Write-Host "  - First failing operation, deploy 1: storage account rejected (invalid SKU / InvalidAccountType)"
Write-Host "  - First failing operation, deploy 2: security rule parent NSG not found (missing dependency)"
Write-Host "  - These are control-plane (ARM) failures, not successful rollouts with a runtime regression"
Write-Host "  - Recommend correction/roll-forward; preserve the last known good; no redeploy without approval"
Write-Host ""
Write-Host "Allow a few minutes for Activity Log ingestion, then run prompt 10 with the scope above."
Write-Host "Tear down later with: .\scripts\Seed-DeploymentFaults.ps1 -Cleanup"
