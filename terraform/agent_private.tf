
# The first network interface for the Private agents
resource "azurerm_network_interface" "dcosPrivateAgentIF0" {
    name                = "dcosPrivateAgentIF${count.index}-0"
    location            = "${azurerm_resource_group.dcos.location}"
    resource_group_name = "${azurerm_resource_group.dcos.name}"
    count               = "${var.agent_private_count}"
    ip_configuration {
        name                          = "privateAgentIPConfig"
        subnet_id                     = "${azurerm_subnet.dcosprivate.id}"
        private_ip_address_allocation = "Static"
        private_ip_address            = "10.32.${count.index / 254}.${ (count.index + 10) % 254 }"
        #NO PUBLIC IP FOR THIS INTERFACE - VM ONLY ACCESSIBLE INTERNALLY
        #public_ip_address_id          = "${azurerm_public_ip.vmPubIP.id}"
    }
}

resource "azurerm_virtual_machine" "dcosPrivateAgent" {
  name                          = "dcosPrivateAgent${count.index}"
  location                      = "${azurerm_resource_group.dcos.location}"
  resource_group_name           = "${azurerm_resource_group.dcos.name}"
  primary_network_interface_id  = "${element( azurerm_network_interface.dcosPrivateAgentIF0.*.id, count.index )}"
  network_interface_ids         = [ "${element( azurerm_network_interface.dcosPrivateAgentIF0.*.id, count.index )}" ]
  vm_size                       = "${var.agent_private_size}"
  availability_set_id           = "${azurerm_availability_set.privateAgentVMAvailSet.id}"
  delete_os_disk_on_termination = true
  count                         = "${var.agent_private_count}"
  depends_on                    = ["azurerm_virtual_machine_extension.master"]

  connection {
    type         = "ssh"
    host         = "${element( azurerm_network_interface.dcosPrivateAgentIF0.*.private_ip_address, count.index )}"
    user         = "${var.vm_user}"
    timeout      = "30s"
    private_key  = "${file(var.private_key_path)}"
    # Configuration for the Jumpbox
    bastion_host        = "${azurerm_private_ip.bootstrap.ip_address}"
    bastion_user        = "${var.vm_user}"
    bastion_private_key = "${file(var.bootstrap_private_key_path)}"
  }

  lifecycle {
    ignore_changes  = ["admin_password"]
  }

  storage_image_reference {
    publisher = "${var.image["publisher"]}"
    offer     = "${var.image["offer"]}"
    sku       = "${var.image["sku"]}"
    version   = "${var.image["version"]}"
  }

  storage_os_disk {
      name              = "dcosPrivateAgentOsDisk${count.index}"
      caching           = "ReadWrite"
      create_option     = "FromImage"
      managed_disk_type = "Premium_LRS"
  }

  os_profile {
      computer_name  = "dcosPrivateAgent${count.index}"
      admin_username = "${var.vm_user}"
      admin_password = "${uuid()}"
      # According to the Azure Terraform Documentation
      # and https://docs.microsoft.com/en-us/azure/virtual-machines/linux/using-cloud-init
      # Cloud init is supported on ubuntu and coreos for custom_data.
      # However, according to CoreOS, their Ignition format is preferred.
      # cloud-init on Azure appears to be the deprecated coreos-cloudinit
      # Therefore we are going to try ignition.
      custom_data    = "${base64encode(file( "${path.module}/files/disableautoreboot.ign" ))}"
  }

  os_profile_linux_config {
      disable_password_authentication = true
      ssh_keys {
        path     = "/home/${var.vm_user}/.ssh/authorized_keys"
        key_data = "${file(var.public_key_path)}"
      }
  }

  tags {
      environment = "${var.instance_name}"
  }

}

resource "azurerm_virtual_machine_extension" "dcosPrivateAgentExtension" {
  name                        = "installDCOSPrivateAgent${format("%01d", count.index+1)}"
  location                    = "${azurerm_resource_group.dcos.location}"
  count                       = "${var.agent_private_count}"
  depends_on                  = ["azurerm_virtual_machine.dcosPrivateAgent"]
  resource_group_name         = "${azurerm_resource_group.dcos.name}"
  virtual_machine_name        = "dcosPrivateAgent${count.index}"
  publisher                   = "Microsoft.Azure.Extensions"
  type                        = "CustomScript"
  type_handler_version        = "2.0"
  auto_upgrade_minor_version  = true

  # The install script is now baked in using custom_data and cloud-init
  settings = <<SETTINGS
    {
        "commandToExecute": "cd /opt/dcos && bash install.sh '172.16.0.8' 'slave'"
    }
SETTINGS

}
