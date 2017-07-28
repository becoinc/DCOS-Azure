resource "azurerm_public_ip" "master_lb" {
  name                         = "masterPublicIP"
  location                     = "${azurerm_resource_group.dcos.location}"
  resource_group_name          = "${azurerm_resource_group.dcos.name}"
  /*
  https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-public-ip-address
  Dynamic: Dynamic addresses are assigned only after the public IP address is associated
  to a NIC attached to a VM and the VM is started for the first time.
  Dynamic addresses can change if the VM the NIC is attached to is
  stopped (deallocated). The address remains the same if the VM is rebooted or
  stopped (but not deallocated).
  Static: Static addresses are assigned when the public IP address is created.
  Static addresses do not change even if the VM is put in the stopped (deallocated) state.
  The address is only released when the NIC is deleted.
  You can change the assignment method after the NIC is created.
   */
  public_ip_address_allocation = "Dynamic"
  domain_name_label            = "${var.masterFQDN}-${var.resource_suffix}"
}

resource "azurerm_lb" "master" {
  name                = "dcos-master-lb"
  location            = "${azurerm_resource_group.dcos.location}"
  resource_group_name = "${azurerm_resource_group.dcos.name}"

  frontend_ip_configuration {
    name                 = "dcos-master-lbFrontEnd"
    public_ip_address_id = "${azurerm_public_ip.master_lb.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "master" {
  resource_group_name = "${azurerm_resource_group.dcos.name}"
  loadbalancer_id     = "${azurerm_lb.master.id}"
  name                = "dcos-master-pool"
}

resource "azurerm_lb_nat_rule" "masterlbrulessh" {
  resource_group_name            = "${azurerm_resource_group.dcos.name}"
  count                          = "${var.master_count}"
  loadbalancer_id                = "${azurerm_lb.master.id}"
  name                           = "dcos-master-lb-SSH-${format("%01d", count.index+1)}"
  protocol                       = "Tcp"
  frontend_port                  = "${lookup(var.master_port, count.index+1)}"
  backend_port                   = 22
  frontend_ip_configuration_name = "dcos-master-lbFrontEnd"
}

/*
resource "azurerm_lb_nat_rule" "masterlbrulehttp" {
  resource_group_name            = "${azurerm_resource_group.dcos.name}"
  count                          = "${var.master_count}"
  loadbalancer_id                = "${azurerm_lb.master.id}"
  name                           = "dcos-master-lb-HTTP-${format("%01d", count.index+1)}"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "dcos-master-lbFrontEnd"
}

resource "azurerm_lb_nat_rule" "masterlbrulehttps" {
  resource_group_name            = "${azurerm_resource_group.dcos.name}"
  count                          = "${var.master_count}"
  loadbalancer_id                = "${azurerm_lb.master.id}"
  name                           = "dcos-master-lb-HTTPS-${format("%01d", count.index+1)}"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "dcos-master-lbFrontEnd"
}
*/
