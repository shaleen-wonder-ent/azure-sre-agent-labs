[CmdletBinding()]
param(
    [string]$ResourceGroupName = "rg-eops-uc6-lifecycle",
    [string]$Location = "eastus2",
    [string]$ChangeTagName = "change-ticket",
    [string]$ChangeTagValue = "CHG-DEMO-006",
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

$nsgApproved = "nsg-uc6-approved"
$routeUnapproved = "rt-uc6-unapproved"
$routeTemp = "rt-uc6-temp"
$now = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")

Write-Host "Seeding resource lifecycle events in '$ResourceGroupName' ($Location)..."

# Added (compliant): resource group carrying the approved change ticket.
az group create --name $ResourceGroupName --location $Location --subscription $SubscriptionId `
    --tags demo=sre-uc6 environment=lab "$ChangeTagName=$ChangeTagValue" --output none

# Added (compliant): NSG tagged with the approved change ticket.
az network nsg create --resource-group $ResourceGroupName --name $nsgApproved --location $Location `
    --subscription $SubscriptionId --tags demo=sre-uc6 "$ChangeTagName=$ChangeTagValue" --output none

# Added (governance exception): route table missing the required change ticket.
az network route-table create --resource-group $ResourceGroupName --name $routeUnapproved --location $Location `
    --subscription $SubscriptionId --tags demo=sre-uc6 --output none

# Added then Removed: disposable route table to prove delete detection from Activity Log.
az network route-table create --resource-group $ResourceGroupName --name $routeTemp --location $Location `
    --subscription $SubscriptionId --tags demo=sre-uc6 "$ChangeTagName=$ChangeTagValue" --output none

# Modified: material change to the approved NSG.
az network nsg rule create --resource-group $ResourceGroupName --nsg-name $nsgApproved --name allow-https `
    --subscription $SubscriptionId --priority 200 --access Allow --protocol Tcp --direction Inbound `
    --destination-port-ranges 443 --output none

# Removed: delete the disposable route table.
az network route-table delete --resource-group $ResourceGroupName --name $routeTemp --subscription $SubscriptionId --output none

$seeded = @(
    [pscustomobject]@{ Action = "Added";    Resource = $ResourceGroupName; Type = "resourceGroups";       Compliant = "yes" }
    [pscustomobject]@{ Action = "Added";    Resource = $nsgApproved;       Type = "networkSecurityGroups"; Compliant = "yes" }
    [pscustomobject]@{ Action = "Added";    Resource = $routeUnapproved;   Type = "routeTables";           Compliant = "no (missing $ChangeTagName)" }
    [pscustomobject]@{ Action = "Modified"; Resource = $nsgApproved;       Type = "securityRules";         Compliant = "yes" }
    [pscustomobject]@{ Action = "Removed";  Resource = $routeTemp;         Type = "routeTables";           Compliant = "yes" }
)

Write-Host ""
Write-Host "Seeded lifecycle events at $now (UTC):"
$seeded | Format-Table -AutoSize

Write-Host "Scope for prompt 6:"
Write-Host "  $resourceGroupId"
Write-Host ""
Write-Host "Expected agent findings:"
Write-Host "  - Added: $ResourceGroupName, $nsgApproved, $routeUnapproved"
Write-Host "  - Modified: $nsgApproved (allow-https rule)"
Write-Host "  - Removed: $routeTemp (visible only in Activity Log, not Resource Graph)"
Write-Host "  - Governance flag: $routeUnapproved is missing the '$ChangeTagName' tag"
Write-Host "  - No moves seeded; the agent should report Moved as empty"
Write-Host ""
Write-Host "Allow a few minutes for Activity Log ingestion, then run prompt 6 with the scope above."
Write-Host "Tear down later with: .\scripts\Seed-ResourceLifecycle.ps1 -Cleanup"
