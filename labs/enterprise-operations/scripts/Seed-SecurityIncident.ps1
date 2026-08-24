[CmdletBinding()]
param(
    [string]$ResourceGroupName = "rg-eops-uc6-lifecycle",
    [string]$NsgName = "nsg-uc6-approved",
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

$ruleName = "allow-rdp-any"

if ($Cleanup) {
    az network nsg rule delete --resource-group $ResourceGroupName --nsg-name $NsgName --name $ruleName `
        --subscription $SubscriptionId 2>$null | Out-Null
    Write-Host "Secure baseline restored: removed '$ruleName' from '$NsgName'."
    return
}

$existingNsgs = az network nsg list --resource-group $ResourceGroupName --subscription $SubscriptionId --output json --only-show-errors | ConvertFrom-Json
$existingNames = @($existingNsgs | ForEach-Object { $_.name })
if ($existingNames -notcontains $NsgName) {
    throw "NSG '$NsgName' not found in '$ResourceGroupName'. Run Seed-ResourceLifecycle.ps1 first."
}

# Dangerous exposure: allow inbound RDP from any source.
az network nsg rule create --resource-group $ResourceGroupName --nsg-name $NsgName --name $ruleName `
    --subscription $SubscriptionId --priority 100 --direction Inbound --access Allow --protocol Tcp `
    --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" `
    --destination-port-ranges 3389 --description "Lab security exposure: inbound RDP from Internet" --output none

$assoc = az network nsg show --resource-group $ResourceGroupName --name $NsgName --subscription $SubscriptionId `
    --query "{subnets: subnets, nics: networkInterfaces}" -o json 2>$null | ConvertFrom-Json
$hasSubnets = $assoc -and $assoc.subnets
$hasNics = $assoc -and $assoc.nics

Write-Host ""
Write-Host "Seeded security exposure at $([DateTime]::UtcNow.ToString('u')):"
Write-Host "  NSG:   $NsgName"
Write-Host "  Rule:  $ruleName (Inbound Allow TCP 3389 from source *)"
Write-Host ""
Write-Host "Scope for prompt 12:"
Write-Host "  /subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
Write-Host ""
Write-Host "Expected agent behaviour:"
Write-Host "  - Attribute the NSG rule change to a caller and UTC time from the Activity Log"
Write-Host "  - Identify the dangerous rule (RDP/3389 open to the Internet)"
Write-Host "  - Scope blast radius honestly: NSG association subnets=$([bool]$hasSubnets) nics=$([bool]$hasNics)"
Write-Host "  - Say 'exposed', not 'compromised' (no evidence of actual access)"
Write-Host "  - Recommend removing the rule with incident-commander approval; preserve evidence"
Write-Host ""
Write-Host "Allow a few minutes for Activity Log ingestion, then run prompt 12 with the scope above."
Write-Host "Restore the secure baseline with: .\scripts\Seed-SecurityIncident.ps1 -Cleanup"
