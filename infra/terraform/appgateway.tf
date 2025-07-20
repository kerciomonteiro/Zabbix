# Application Gateway for Multi-Application AKS Platform
# This provides a default configuration that works with the AKS ingress controller
# Applications can define their own ingress resources that will be managed by this gateway
resource "azurerm_application_gateway" "main" {
  name                = local.resource_names.app_gateway
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
  zones               = ["1", "2", "3"]

  sku {
    name = var.appgw_sku_name
    tier = var.appgw_sku_name
    # Note: For v2 SKUs, use either capacity OR autoscale_configuration, not both
    # We're using autoscale_configuration below, so capacity is omitted
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

  # Default Backend Address Pool (for AKS ingress controller)
  backend_address_pool {
    name = "aks-backend-pool"
  }

  # Default Backend HTTP Settings
  backend_http_settings {
    name                  = "aks-backend-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  # Default HTTP Listener
  http_listener {
    name                           = "default-http-listener"
    frontend_ip_configuration_name = "appGwPublicFrontendIp"
    frontend_port_name             = "port_80"
    protocol                       = "Http"
  }

  # Default Request Routing Rule
  request_routing_rule {
    name                       = "default-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "default-http-listener"
    backend_address_pool_name  = "aks-backend-pool"
    backend_http_settings_name = "aks-backend-http-settings"
    priority                   = 1
  }

  # Managed Identity for Application Gateway
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # Autoscale Configuration
  autoscale_configuration {
    min_capacity = var.appgw_min_capacity
    max_capacity = var.appgw_max_capacity
  }

  # WAF Configuration (conditional)
  dynamic "waf_configuration" {
    for_each = var.enable_waf && var.appgw_sku_name == "WAF_v2" ? [1] : []
    content {
      enabled          = true
      firewall_mode    = "Prevention"
      rule_set_type    = "OWASP"
      rule_set_version = "3.2"
    }
  }
}
