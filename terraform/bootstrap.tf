resource "azurerm_public_ip" "dcosBootstrapNodePublicIp" {
  name                         = "bootstrapPublicIP"
  location                     = "${azurerm_resource_group.dcos.location}"
  resource_group_name          = "${azurerm_resource_group.dcos.name}"
  public_ip_address_allocation = "Dynamic"
}

resource "azurerm_network_interface" "dcosBootstrapNodeIF0" {
  name                      = "bootstrapnic"
  location                  = "${azurerm_resource_group.dcos.location}"
  resource_group_name       = "${azurerm_resource_group.dcos.name}"
  network_security_group_id = "${azurerm_network_security_group.dcosbootstrapnode.id}"

  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "static"
    private_ip_address            = "172.16.0.8"
    subnet_id                     = "${azurerm_subnet.dcosmaster.id}"
    public_ip_address_id          = "${azurerm_public_ip.dcosBootstrapNodePublicIp.id}"
  }
}

/*
  This box is _also_ used as a bastion host for ssh into the cluster.
  You can separate the ssh keys for the bastion host and the rest of the
  vms so that you can do per-user keys to login to the cluster, but stealing
  the internal private key still won't get you actually in the door.
 */
resource "azurerm_virtual_machine" "dcosBootstrapNodeVM" {
  name                          = "dcosBootstrapVM"
  location                      = "${azurerm_resource_group.dcos.location}"
  resource_group_name           = "${azurerm_resource_group.dcos.name}"
  network_interface_ids         = ["${azurerm_network_interface.dcosBootstrapNodeIF0.id}"]
  vm_size                       = "${var.bootstrap_size}"
  delete_os_disk_on_termination = true

  lifecycle {
    ignore_changes = ["admin_password"]
  }

  connection {
    type         = "ssh"
    host         = "${azurerm_public_ip.dcosBootstrapNodePublicIp.ip_address}"
    user         = "${var.vm_user}"
    timeout      = "30s"
    private_key  = "${file(var.bootstrap_private_key_path)}"
  }

  # Provisioners are executed in order.

  # Putting the private key here makes hopping around better.
  provisioner "file" {
    source = "${var.private_key_path}"
    destination = "/home/${var.vm_user}/.ssh/id_rsa"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/${var.vm_user}/.ssh/id_rsa",
      "sudo mkdir -p /opt/dcos",
      "sudo chown ${var.vm_user} /opt/dcos",
      "sudo chmod 755 -R /opt/dcos"
    ]
  }

  # Now the provisioning for DC/OS
  provisioner "file" {
    source      = "${path.module}/files/bootstrap.sh"
    destination = "/opt/dcos/bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 755 /opt/dcos/bootstrap.sh",
      "cd /opt/dcos && bash bootstrap.sh '172.16.0.8' '${var.dcos_download_url}'"
    ]
  }

  storage_os_disk {
    name              = "dcosBootstrapVMDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "${var.image["publisher"]}"
    offer     = "${var.image["offer"]}"
    sku       = "${var.image["sku"]}"
    version   = "${var.image["version"]}"
  }

  os_profile {
    computer_name  = "bootstrap"
    admin_username = "${var.vm_user}"
    admin_password = "${uuid()}"
    custom_data    = "${file( "${path.module}/files/disableautoreboot.ign" )}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.vm_user}/.ssh/authorized_keys"
      key_data = "${file(var.bootstrap_public_key_path)}"
    }
  }
}

/*
JZ - Keep this around for reference. It seems better to use the
terraform remote-exec provisioner when possible.
resource "azurerm_virtual_machine_extension" "bootstrap" {
  name                        = "dcosConfiguration"
  location                    = "${azurerm_resource_group.dcos.location}"
  resource_group_name         = "${azurerm_resource_group.dcos.name}"
  virtual_machine_name        = "${azurerm_virtual_machine.bootstrap.name}"
  publisher                   = "Microsoft.Azure.Extensions"
  type                        = "CustomScript"
  type_handler_version        = "2.0"
  auto_upgrade_minor_version  = true

  # We use cloud-init to bake the script into the custom_data of the VM.
  settings = <<SETTINGS
    {
        "commandToExecute": "cd /opt/dcos && bash bootstrap.sh '172.16.0.8' '${var.dcos_download_url}'"
    }
SETTINGS

}
*/
