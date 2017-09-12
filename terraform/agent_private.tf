#
# This is a terraform script to provision the DC/OS private agent nodes.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

# The first network interface for the Private agents
resource "azurerm_network_interface" "dcosPrivateAgentIF0" {
    name                = "dcosPrivateAgentIF${count.index}-0"
    location            = "${azurerm_resource_group.dcos.location}"
    resource_group_name = "${azurerm_resource_group.dcos.name}"
    count               = "${var.agent_private_count}"
    ip_configuration {
        name                          = "privateAgentIPConfig"
        subnet_id                     = "${azurerm_subnet.dcosprivate.id}"
        private_ip_address_allocation = "static"
        private_ip_address            = "10.32.${count.index / 254}.${ (count.index + 10) % 254 }"
        #NO PUBLIC IP FOR THIS INTERFACE - VM ONLY ACCESSIBLE INTERNALLY
        #public_ip_address_id          = "${azurerm_public_ip.vmPubIP.id}"
    }
}

resource "azurerm_network_interface" "dcosPrivateAgentMgmt" {
    name                = "dcosPrivateAgentMgmtIF${count.index}-0"
    location            = "${azurerm_resource_group.dcos.location}"
    resource_group_name = "${azurerm_resource_group.dcos.name}"
    count               = "${var.agent_private_count}"
    ip_configuration {
        name                                    = "privateAgentMgmtIPConfig"
        subnet_id                               = "${azurerm_subnet.dcosMgmt.id}"
        private_ip_address_allocation           = "static"
        private_ip_address                      = "10.226.${count.index / 254}.${ (count.index + 10) % 254 }"
    }
}

resource "azurerm_virtual_machine" "dcosPrivateAgent" {
  name                          = "dcosPrivateAgent${count.index}"
  location                      = "${azurerm_resource_group.dcos.location}"
  resource_group_name           = "${azurerm_resource_group.dcos.name}"
  primary_network_interface_id  = "${element( azurerm_network_interface.dcosPrivateAgentIF0.*.id, count.index )}"
  network_interface_ids         = [ "${element( azurerm_network_interface.dcosPrivateAgentIF0.*.id, count.index )}",
                                    "${element( azurerm_network_interface.dcosPrivateAgentMgmt.*.id, count.index )}" ]
  vm_size                       = "${var.agent_private_size}"
  availability_set_id           = "${azurerm_availability_set.privateAgentVMAvailSet.id}"
  delete_os_disk_on_termination = true
  count                         = "${var.agent_private_count}"
  depends_on                    = ["azurerm_virtual_machine.master"]

  lifecycle {
    ignore_changes  = ["admin_password"]
  }

  connection {
    type         = "ssh"
    host         = "${element( azurerm_network_interface.dcosPrivateAgentIF0.*.private_ip_address, count.index )}"
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

  # Provision the VM itself.
  provisioner "file" {
    source      = "${path.module}/files/vm_setup.sh"
    destination = "/opt/dcos/vm_setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod 755 /opt/dcos/vm_setup.sh",
      "sudo /opt/dcos/vm_setup.sh"
    ]
  }

  # Now the provisioning for DC/OS
  provisioner "file" {
    source      = "${path.module}/files/install.sh"
    destination = "/opt/dcos/install.sh"
  }

  provisioner "file" {
    source      = "${path.module}/files/50-docker.network"
    destination = "/tmp/50-docker.network"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/50-docker.network /etc/systemd/network/",
      "sudo chmod 644 /etc/systemd/network/50-docker.network",
      "sudo systemctl restart systemd-networkd",
      "chmod 755 /opt/dcos/install.sh",
      "cd /opt/dcos && bash install.sh '172.16.0.8' 'slave'"
    ]
  }

  boot_diagnostics {
    enabled     = true
    storage_uri = "${azurerm_storage_account.dcos.primary_blob_endpoint}"
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
