// Main deployment template for AKS cluster with Zabbix infrastructure
targetScope = 'resourceGroup'

@description('Deployment location')
param location string = resourceGroup().location

@description('Deployment environment name')
@minLength(1)
@maxLength(64)
param environmentName string

@description('Principal ID of the deployment user for role assignments')
param principalId string = ''

@description('Unique suffix to ensure resource names are globally unique')
var resourceToken = take(uniqueString(subscription().id, resourceGroup().id, environmentName), 8)

// Create resource names with resource token
var resourceNames = {
  vnet: 'vnet-${resourceToken}'
  aksCluster: 'aks-${resourceToken}'
  aksNodeRg: 'rg-${environmentName}-aks-nodes-${resourceToken}'
  subnet: {
    aks: 'subnet-aks-${resourceToken}'
    appgw: 'subnet-appgw-${resourceToken}'
  }
  identity: 'id-${resourceToken}'
  logAnalytics: 'law-${resourceToken}'
  containerRegistry: 'crzabbix${replace(resourceToken, '-', '')}'
  appGateway: 'appgw-${resourceToken}'
  publicIp: 'pip-appgw-${resourceToken}'
  nsg: {
    aks: 'nsg-aks-${resourceToken}'
    appgw: 'nsg-appgw-${resourceToken}'
  }
}

// Virtual Network and Subnets
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: resourceNames.vnet
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.224.0.0/12'
      ]
    }
    subnets: [
      {
        name: resourceNames.subnet.aks
        properties: {
          addressPrefix: '10.224.0.0/16'
          networkSecurityGroup: {
            id: aksNetworkSecurityGroup.id
          }
        }
      }
      {
        name: resourceNames.subnet.appgw
        properties: {
          addressPrefix: '10.225.0.0/24'
          networkSecurityGroup: {
            id: appGatewayNetworkSecurityGroup.id
          }
        }
      }
    ]
  }
}

// Network Security Groups
resource aksNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: resourceNames.nsg.aks
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    securityRules: [
      {
        name: 'AllowAKSApiServer'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource appGatewayNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: resourceNames.nsg.appgw
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAppGwManagement'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
    ]
  }
}

// User Assigned Managed Identity
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: resourceNames.identity
  location: location
  tags: {
    'azd-env-name': environmentName
  }
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: resourceNames.logAnalytics
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: resourceNames.containerRegistry
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Allow'
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}

// Public IP for Application Gateway
resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: resourceNames.publicIp
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: 'dal2-devmon-mgt-${resourceToken}'
    }
  }
}

// Application Gateway (for NGINX Ingress external IP)
resource applicationGateway 'Microsoft.Network/applicationGateways@2024-05-01' = {
  name: resourceNames.appGateway
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: '${virtualNetwork.id}/subnets/${resourceNames.subnet.appgw}'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'zabbixBackendPool'
        properties: {}
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'defaultHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: 'defaultHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', resourceNames.appGateway, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', resourceNames.appGateway, 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'defaultRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 1
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', resourceNames.appGateway, 'defaultHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', resourceNames.appGateway, 'zabbixBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', resourceNames.appGateway, 'defaultHttpSettings')
          }
        }
      }
    ]
    enableHttp2: false
    autoscaleConfiguration: {
      minCapacity: 2
      maxCapacity: 10
    }
  }
}

// AKS Cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-09-01' = {
  name: resourceNames.aksCluster
  location: location
  tags: {
    'azd-env-name': environmentName
    'azd-service-name': 'zabbix'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    dnsPrefix: 'aks-${resourceToken}'
    nodeResourceGroup: resourceNames.aksNodeRg
    kubernetesVersion: '1.29.9'
    enableRBAC: true
    disableLocalAccounts: false
    
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: 2
        vmSize: 'Standard_D2s_v3'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        enableAutoScaling: true
        minCount: 1
        maxCount: 5
        vnetSubnetID: '${virtualNetwork.id}/subnets/${resourceNames.subnet.aks}'
        enableNodePublicIP: false
        maxPods: 110
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '1'
        }
      }
      {
        name: 'workerpool'
        count: 3
        vmSize: 'Standard_D4s_v3'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        enableAutoScaling: true
        minCount: 2
        maxCount: 10
        vnetSubnetID: '${virtualNetwork.id}/subnets/${resourceNames.subnet.aks}'
        enableNodePublicIP: false
        maxPods: 110
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '1'
        }
        nodeLabels: {
          'workload-type': 'application'
        }
      }
    ]
    
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      outboundType: 'loadBalancer'
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
      loadBalancerSku: 'standard'
    }
    
    apiServerAccessProfile: {
      enablePrivateCluster: false
      authorizedIPRanges: []
    }
    
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
        }
      }
      azurepolicy: {
        enabled: true
      }
      ingressApplicationGateway: {
        enabled: true
        config: {
          applicationGatewayId: applicationGateway.id
        }
      }
    }
    
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
      nodeOSUpgradeChannel: 'NodeImage'
    }
    
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    
    oidcIssuerProfile: {
      enabled: true
    }
  }
}

// Role Assignments
resource contributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
}

resource acrPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
}

resource networkContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4d97b98b-1d4f-4787-a291-c67834d212e7' // Network Contributor
}

// AKS Cluster identity role assignments
resource aksIdentityContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, userAssignedIdentity.id, contributorRole.id)
  properties: {
    roleDefinitionId: contributorRole.id
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aksIdentityNetworkContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: virtualNetwork
  name: guid(virtualNetwork.id, userAssignedIdentity.id, networkContributorRole.id)
  properties: {
    roleDefinitionId: networkContributorRole.id
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aksIdentityAcrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, userAssignedIdentity.id, acrPullRole.id)
  properties: {
    roleDefinitionId: acrPullRole.id
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// User role assignment for management
resource userContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  scope: resourceGroup()
  name: guid(resourceGroup().id, principalId, contributorRole.id)
  properties: {
    roleDefinitionId: contributorRole.id
    principalId: principalId
    principalType: 'User'
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_RESOURCE_GROUP string = resourceGroup().name

output AKS_CLUSTER_NAME string = aksCluster.name
output AKS_CLUSTER_ID string = aksCluster.id
output AKS_CLUSTER_FQDN string = aksCluster.properties.fqdn
output AKS_CLUSTER_PORTAL_FQDN string = aksCluster.properties.azurePortalFQDN
output AKS_CLUSTER_NODE_RESOURCE_GROUP string = aksCluster.properties.nodeResourceGroup

output CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output CONTAINER_REGISTRY_NAME string = containerRegistry.name

output VNET_ID string = virtualNetwork.id
output VNET_NAME string = virtualNetwork.name
output AKS_SUBNET_ID string = '${virtualNetwork.id}/subnets/${resourceNames.subnet.aks}'
output APPGW_SUBNET_ID string = '${virtualNetwork.id}/subnets/${resourceNames.subnet.appgw}'

output APPLICATION_GATEWAY_NAME string = applicationGateway.name
output APPLICATION_GATEWAY_ID string = applicationGateway.id
output PUBLIC_IP_ADDRESS string = publicIp.properties.ipAddress
output PUBLIC_IP_FQDN string = publicIp.properties.dnsSettings.fqdn

output LOG_ANALYTICS_WORKSPACE_ID string = logAnalyticsWorkspace.id
output LOG_ANALYTICS_WORKSPACE_NAME string = logAnalyticsWorkspace.name

output USER_ASSIGNED_IDENTITY_ID string = userAssignedIdentity.id
output USER_ASSIGNED_IDENTITY_CLIENT_ID string = userAssignedIdentity.properties.clientId
output USER_ASSIGNED_IDENTITY_PRINCIPAL_ID string = userAssignedIdentity.properties.principalId

output RESOURCE_GROUP_ID string = resourceGroup().id
