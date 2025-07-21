# Network Security Groups
resource "azurerm_network_security_group" "aks" {
  name                = local.resource_names.nsg_aks
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowAKSApiServer"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "appgw" {
  name                = local.resource_names.nsg_appgw
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowGatewayManager"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = local.resource_names.vnet
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.common_tags
}

# AKS Subnet
resource "azurerm_subnet" "aks" {
  name                 = local.resource_names.aks_subnet
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_address_prefix]
}

# Application Gateway Subnet
resource "azurerm_subnet" "appgw" {
  name                 = local.resource_names.appgw_subnet
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.appgw_subnet_address_prefix]
}

# Associate NSGs with Subnets
resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.appgw.id
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw" {
  name                = local.resource_names.public_ip
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  domain_name_label   = "dal2-devmon-mgt-devops"
  tags                = local.common_tags
}
