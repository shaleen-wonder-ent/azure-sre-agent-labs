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

$rgExists = az group exists --name $ResourceGroupName --subscription $SubscriptionId
if ($rgExists -ne "true") {
    az group create --name $ResourceGroupName --location $Location --subscription $SubscriptionId `
        --tags demo=sre-uc7 environment=lab --output none
}

$results = New-Object System.Collections.Generic.List[object]
$now = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")

# RBAC change: grant then remove Reader for the signed-in user, scoped to the demo group.
$principalId = az ad signed-in-user show --query id -o tsv 2>$null
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($principalId)) {
    az role assignment create --assignee-object-id $principalId --assignee-principal-type User `
        --role "Reader" --scope $resourceGroupId --subscription $SubscriptionId --output none 2>$null
    $rbacAdd = ($LASTEXITCODE -eq 0)
    az role assignment delete --assignee $principalId --role "Reader" --scope $resourceGroupId `
        --subscription $SubscriptionId --output none 2>$null
    $rbacRemove = ($LASTEXITCODE -eq 0)
    $results.Add([pscustomobject]@{ Category = "RBAC"; Change = "Reader role assignment added then removed"; Result = if ($rbacAdd -and $rbacRemove) { "Succeeded" } else { "Partial (check permissions)" } })
}
else {
    $results.Add([pscustomobject]@{ Category = "RBAC"; Change = "Skipped (could not resolve signed-in user)"; Result = "Skipped" })
}

# Modified: tag change on the resource group.
az tag update --resource-id $resourceGroupId --operation Merge --tags "last-reviewed=$now" --subscription $SubscriptionId --output none 2>$null
$results.Add([pscustomobject]@{ Category = "Resource update"; Change = "Resource group tag 'last-reviewed' set"; Result = "Succeeded" })

# Failed deployment: invalid storage SKU is accepted client-side but rejected by the resource provider.
$deploymentName = "uc7-failed-deploy-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))"
$templatePath = Join-Path $env:TEMP "uc7-failed-template.json"
$storageName = "uc7fail$([DateTime]::UtcNow.ToString('HHmmss'))"
@"
{
  "`$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": [
    {
      "type": "Microsoft.Storage/storageAccounts",
      "apiVersion": "2023-01-01",
      "name": "$storageName",
      "location": "$Location",
      "sku": { "name": "Standard_INVALID" },
      "kind": "StorageV2"
    }
  ]
}
"@ | Set-Content -Path $templatePath -Encoding utf8

az deployment group create --resource-group $ResourceGroupName --name $deploymentName `
    --template-file $templatePath --subscription $SubscriptionId --output none 2>$null
$results.Add([pscustomobject]@{ Category = "Deployment"; Change = "ARM deployment '$deploymentName' with invalid SKU"; Result = "Failed (expected)" })
Remove-Item $templatePath -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Seeded 24-hour change categories at $now (UTC):"
$results | Format-Table -AutoSize

Write-Host "Scope for prompt 7:"
Write-Host "  $resourceGroupId"
Write-Host ""
Write-Host "This scope also contains the use case 6 lifecycle events (adds, NSG rule, delete),"
Write-Host "so the 24-hour timeline spans resource, network, RBAC, and deployment categories."
Write-Host ""
Write-Host "Expected agent behaviour:"
Write-Host "  - One deduplicated UTC timeline, not a raw Activity Log dump"
Write-Host "  - Highlights the FAILED deployment '$deploymentName'"
Write-Host "  - Surfaces the RBAC add/remove and the inbound 443 NSG rule as notable changes"
Write-Host "  - Ranks changes by operational impact and states source coverage/gaps"
Write-Host ""
Write-Host "Allow a few minutes for Activity Log ingestion, then run prompt 7 with the scope above."
Write-Host "Tear down later with: .\scripts\Seed-ChangeDigest.ps1 -Cleanup"
