using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'compliance-demo')
param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus2')
param containerImage = readEnvironmentVariable('CONTAINER_IMAGE', '')
param principalId = readEnvironmentVariable('AZURE_PRINCIPAL_ID', '')
param cicdServicePrincipalClientId = readEnvironmentVariable('CICD_SERVICE_PRINCIPAL_CLIENT_ID', '')
