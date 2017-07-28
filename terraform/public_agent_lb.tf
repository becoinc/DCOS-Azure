/*
  This is the public ip/hostname of the load balancer in front of the
  public agents.
  NOT the agents themselves.
 */
resource "azurerm_public_ip" "agent_public_lb" {
  name                         = "publicAgentsLBPublicIP"
  location                     = "${azurerm_resource_group.dcos.location}"
  resource_group_name          = "${azurerm_resource_group.dcos.name}"
  public_ip_address_allocation = "Static"
  domain_name_label            = "${var.publicAgentFQDN}-${var.resource_suffix}"
}

resource "azurerm_lb" "agent_public" {
  name                = "dcos-agent-public-lb"
  location            = "${azurerm_resource_group.dcos.location}"
  resource_group_name = "${azurerm_resource_group.dcos.name}"

  frontend_ip_configuration {
    name                 = "dcos-agent-public-lbFrontEnd"
    public_ip_address_id = "${azurerm_public_ip.agent_public_lb.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "agent_public" {
  resource_group_name = "${azurerm_resource_group.dcos.name}"
  loadbalancer_id     = "${azurerm_lb.agent_public.id}"
  name                = "dcos-agent-public-pool"
}

resource "azurerm_lb_probe" "agent_public_http" {
  resource_group_name = "${azurerm_resource_group.dcos.name}"
  loadbalancer_id     = "${azurerm_lb.agent_public.id}"
  name                = "tcpHTTPProbe"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "agent_public_http" {
  resource_group_name            = "${azurerm_resource_group.dcos.name}"
  loadbalancer_id                = "${azurerm_lb.agent_public.id}"
  name                           = "LBRuleHTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  frontend_ip_configuration_name = "dcos-agent-public-lbFrontEnd"
  backend_port                   = 80
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.agent_public.id}"
  probe_id                       = "${azurerm_lb_probe.agent_public_http.id}"
  idle_timeout_in_minutes        = 5
  load_distribution              = "Default"
  enable_floating_ip             = false
}

resource "azurerm_lb_probe" "agent_public_https" {
  resource_group_name = "${azurerm_resource_group.dcos.name}"
  loadbalancer_id     = "${azurerm_lb.agent_public.id}"
  name                = "tcpHTTPSProbe"
  port                = 443
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "agent_public_https" {
  resource_group_name            = "${azurerm_resource_group.dcos.name}"
  loadbalancer_id                = "${azurerm_lb.agent_public.id}"
  name                           = "LBRuleHTTPS"
  protocol                       = "Tcp"
  frontend_port                  = 443
  frontend_ip_configuration_name = "dcos-agent-public-lbFrontEnd"
  backend_port                   = 443
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.agent_public.id}"
  probe_id                       = "${azurerm_lb_probe.agent_public_https.id}"
  idle_timeout_in_minutes        = 5
  load_distribution              = "Default"
  enable_floating_ip             = false
}

resource "azurerm_lb_probe" "agent_public_8080" {
  resource_group_name = "${azurerm_resource_group.dcos.name}"
  loadbalancer_id     = "${azurerm_lb.agent_public.id}"
  name                = "tcpPort8080Probe"
  port                = 8080
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "agent_public_8080" {
  resource_group_name            = "${azurerm_resource_group.dcos.name}"
  loadbalancer_id                = "${azurerm_lb.agent_public.id}"
  name                           = "LBRulePort8080"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  frontend_ip_configuration_name = "dcos-agent-public-lbFrontEnd"
  backend_port                   = 8080
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.agent_public.id}"
  probe_id                       = "${azurerm_lb_probe.agent_public_8080.id}"
  idle_timeout_in_minutes        = 5
  load_distribution              = "Default"
  enable_floating_ip             = false
}

resource "azurerm_lb_probe" "agent_public_9090" {
  resource_group_name = "${azurerm_resource_group.dcos.name}"
  loadbalancer_id     = "${azurerm_lb.agent_public.id}"
  name                = "tcpPort9090Probe"
  port                = 9090
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "agent_public_9090" {
  resource_group_name            = "${azurerm_resource_group.dcos.name}"
  loadbalancer_id                = "${azurerm_lb.agent_public.id}"
  name                           = "LBRulePort9090"
  protocol                       = "Tcp"
  frontend_port                  = 9090
  frontend_ip_configuration_name = "dcos-agent-public-lbFrontEnd"
  backend_port                   = 9090
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.agent_public.id}"
  probe_id                       = "${azurerm_lb_probe.agent_public_9090.id}"
  idle_timeout_in_minutes        = 5
  load_distribution              = "Default"
  enable_floating_ip             = false
}
