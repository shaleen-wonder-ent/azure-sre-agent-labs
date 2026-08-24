// ============================================================
// Cosmos DB Module — NoSQL API with managed identity (no keys)
// ============================================================

param location string
param environmentName string
param tags object
param vmIdentityPrincipalId string = ''
param privateEndpointSubnetId string
param vnetId string

var accountName = 'cosmos-${environmentName}'
var dbName = 'ecommerce'

// Cosmos DB Data Contributor role
var cosmosDataContributorRoleId = '00000000-0000-0000-0000-000000000002'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: accountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: true
    enableAutomaticFailover: true
    publicNetworkAccess: 'Disabled'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  tags: tags
}

resource privateDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${environmentName}-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnetId }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${accountName}'
  location: location
  tags: tags
  properties: {
    subnet: { id: privateEndpointSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'cosmos-sql'
        properties: {
          privateLinkServiceId: cosmosAccount.id
          groupIds: [ 'Sql' ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cosmos-sql'
        properties: { privateDnsZoneId: privateDnsZone.id }
      }
    ]
  }
}

// Assign Cosmos DB Data Contributor to VM's managed identity
resource cosmosRbac 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = if (!empty(vmIdentityPrincipalId)) {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, vmIdentityPrincipalId, cosmosDataContributorRoleId)
  properties: {
    roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/${cosmosDataContributorRoleId}'
    principalId: vmIdentityPrincipalId
    scope: cosmosAccount.id
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: dbName
  properties: {
    resource: {
      id: dbName
    }
  }
}

resource productsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: 'products'
  properties: {
    resource: {
      id: 'products'
      partitionKey: {
        paths: ['/category']
        kind: 'Hash'
      }
    }
  }
}

resource ordersContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: database
  name: 'orders'
  properties: {
    resource: {
      id: 'orders'
      partitionKey: {
        paths: ['/status']
        kind: 'Hash'
      }
    }
  }
}

output accountName string = cosmosAccount.name
output endpoint string = cosmosAccount.properties.documentEndpoint
output accountId string = cosmosAccount.id
output databaseName string = dbName
