# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = local.resource_names.app_gateway
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  # Gateway IP Configuration
  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.appgw.id
  }

  # Frontend Port Configuration
  frontend_port {
    name = "port_80"
    port = 80
  }

  frontend_port {
    name = "port_443"
    port = 443
  }

  # Frontend IP Configuration
  frontend_ip_configuration {
    name                 = "appGwPublicFrontendIp"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # Backend Address Pool
  backend_address_pool {
    name = "zabbix-backend-pool"
  }

  # Backend HTTP Settings
  backend_http_settings {
    name                  = "zabbix-backend-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  # HTTP Listener
  http_listener {
    name                           = "zabbix-http-listener"
    frontend_ip_configuration_name = "appGwPublicFrontendIp"
    frontend_port_name             = "port_80"
    protocol                       = "Http"
  }

  # Basic Request Routing Rule
  request_routing_rule {
    name                       = "zabbix-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "zabbix-http-listener"
    backend_address_pool_name  = "zabbix-backend-pool"
    backend_http_settings_name = "zabbix-backend-http-settings"
    priority                   = 1
  }

  # Managed Identity for Application Gateway
  identity {
    type = "SystemAssigned"
  }

  # Autoscale Configuration
  autoscale_configuration {
    min_capacity = 1
    max_capacity = 3
  }

  # WAF Configuration (optional, can be enabled later)
  # waf_configuration {
  #   enabled          = true
  #   firewall_mode    = "Prevention"
  #   rule_set_type    = "OWASP"
  #   rule_set_version = "3.2"
  # }
}
