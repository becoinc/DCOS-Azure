
# The first network interface for the public agents
resource "azurerm_network_interface" "dcosPublicAgentIF0" {
    name                = "dcosPublicAgentIF${count.index}-0"
    location            = "${azurerm_resource_group.dcos.location}"
    resource_group_name = "${azurerm_resource_group.dcos.name}"
    count               = "${var.agent_public_count}"
    ip_configuration {
        name                          = "publicAgentIPConfig"
        subnet_id                     = "${azurerm_subnet.dcospublic.id}"
        private_ip_address_allocation = "Static"
        private_ip_address            = "10.0.${count.index / 254}.${ (count.index + 10) % 254 }"
        #NO PUBLIC IP FOR THIS INTERFACE - VM ONLY ACCESSIBLE INTERNALLY
        #public_ip_address_id          = "${azurerm_public_ip.vmPubIP.id}"
    }
}

resource "azurerm_virtual_machine" "dcosPublicAgent" {
  name                          = "dcosPublicAgent${count.index}"
  location                      = "${azurerm_resource_group.dcos.location}"
  resource_group_name           = "${azurerm_resource_group.dcos.name}"
  primary_network_interface_id  = "${element( azurerm_network_interface.dcosPublicAgentIF0.*.id, count.index )}"
  network_interface_ids         = [ "${element( azurerm_network_interface.dcosPublicAgentIF0.*.id, count.index )}" ]
  vm_size                       = "${var.agent_public_size}"
  availability_set_id           = "${azurerm_availability_set.publicAgentVMAvailSet.id}"
  delete_os_disk_on_termination = true
  count                         = "${var.agent_public_count}"
  depends_on                    = ["azurerm_virtual_machine.master"]

  lifecycle {
    ignore_changes  = ["admin_password"]
  }

  connection {
    type         = "ssh"
    host         = "${element( azurerm_network_interface.dcosPublicAgentIF0.*.private_ip_address, count.index )}"
    user         = "${var.vm_user}"
    timeout      = "120s"
    private_key  = "${file(var.private_key_path)}"
    # Configuration for the Jumpbox
    bastion_host        = "${azurerm_public_ip.dcosBootstrapNodePublicIp.ip_address}"
    bastion_user        = "${var.vm_user}"
    bastion_private_key = "${file(var.bootstrap_private_key_path)}"
  }

  # provisioners execute in order.
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/dcos",
      "sudo chown ${var.vm_user} /opt/dcos",
      "sudo chmod 755 -R /opt/dcos"
    ]
  }

  # Now the provisioning for DC/OS
  provisioner "file" {
    source      = "${path.module}/files/install.sh"
    destination = "/opt/dcos/install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 755 /opt/dcos/install.sh",
      "cd /opt/dcos && bash install.sh '172.16.0.8' 'slave_public'"
    ]
  }

  storage_image_reference {
    publisher = "${var.image["publisher"]}"
    offer     = "${var.image["offer"]}"
    sku       = "${var.image["sku"]}"
    version   = "${var.image["version"]}"
  }

  storage_os_disk {
      name              = "dcosPublicAgentOsDisk${count.index}"
      caching           = "ReadWrite"
      create_option     = "FromImage"
      managed_disk_type = "Premium_LRS"
  }

  os_profile {
      computer_name  = "dcosPublicAgent${count.index}"
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
