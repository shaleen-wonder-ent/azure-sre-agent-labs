[CmdletBinding()]
param(
    [string]$Repository = "shaleen-wonder-ent/grubify",
    [string]$ApplicationName = "github-grubify-deploy",
    [string]$OidcSubject = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-AzdValue([string]$Name) {
    $value = azd env get-value $Name 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value)) {
        throw "Could not resolve '$Name' from the active azd environment."
    }
    return $value.Trim()
}

gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Run 'gh auth login' before this script." }

$subscriptionId = (az account show --query id -o tsv).Trim()
$tenantId = (az account show --query tenantId -o tsv).Trim()
$resourceGroup = Get-AzdValue "AZURE_RESOURCE_GROUP"
$registryName = Get-AzdValue "AZURE_CONTAINER_REGISTRY_NAME"
$containerAppName = Get-AzdValue "CONTAINER_APP_NAME"

$applicationId = az ad app list --display-name $ApplicationName --query "[0].appId" -o tsv
if ([string]::IsNullOrWhiteSpace($applicationId)) {
    $applicationId = az ad app create --display-name $ApplicationName --query appId -o tsv
}
$servicePrincipalId = az ad sp show --id $applicationId --query id -o tsv 2>$null
if ([string]::IsNullOrWhiteSpace($servicePrincipalId)) {
    $servicePrincipalId = az ad sp create --id $applicationId --query id -o tsv
}

$subject = if ([string]::IsNullOrWhiteSpace($OidcSubject)) {
    if ($Repository -eq "shaleen-wonder-ent/grubify") {
        $ownerId = gh api "repos/$Repository" --jq .owner.id
        $repositoryId = gh api "repos/$Repository" --jq .id
        "repo:shaleen-wonder-ent@${ownerId}/grubify@${repositoryId}:ref:refs/heads/main"
    } else {
        "repo:${Repository}:ref:refs/heads/main"
    }
} else {
    $OidcSubject
}
$credentialName = "grubify-main"
$existingSubject = az ad app federated-credential list --id $applicationId --query "[?name=='$credentialName'].subject | [0]" -o tsv
if (-not [string]::IsNullOrWhiteSpace($existingSubject) -and $existingSubject.Trim() -ne $subject) {
    az ad app federated-credential delete --id $applicationId --federated-credential-id $credentialName
    $existingSubject = ""
}
if ([string]::IsNullOrWhiteSpace($existingSubject)) {
    $credentialFile = New-TemporaryFile
    try {
        @{
            name = $credentialName
            issuer = "https://token.actions.githubusercontent.com"
            subject = $subject
            description = "Deploy Grubify API from the protected main branch"
            audiences = @("api://AzureADTokenExchange")
        } | ConvertTo-Json | Set-Content -Path $credentialFile -Encoding utf8
        az ad app federated-credential create --id $applicationId --parameters $credentialFile | Out-Null
    }
    finally { Remove-Item $credentialFile -Force -ErrorAction SilentlyContinue }
}

$registryId = az acr show --name $registryName --query id -o tsv
$containerAppId = az containerapp show --resource-group $resourceGroup --name $containerAppName --query id -o tsv
az role assignment create --assignee-object-id $servicePrincipalId --assignee-principal-type ServicePrincipal --role AcrPush --scope $registryId | Out-Null
az role assignment create --assignee-object-id $servicePrincipalId --assignee-principal-type ServicePrincipal --role "Container Apps Contributor" --scope $containerAppId | Out-Null

$applicationId.Trim() | gh secret set AZURE_CLIENT_ID --repo $Repository
$tenantId | gh secret set AZURE_TENANT_ID --repo $Repository
$subscriptionId | gh secret set AZURE_SUBSCRIPTION_ID --repo $Repository
gh variable set AZURE_RESOURCE_GROUP --body $resourceGroup --repo $Repository
gh variable set AZURE_CONTAINER_REGISTRY_NAME --body $registryName --repo $Repository
gh variable set GRUBIFY_API_CONTAINER_APP --body $containerAppName --repo $Repository

Write-Host "OIDC deployment identity and repository configuration are ready for $Repository."