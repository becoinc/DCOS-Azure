#
# This is a terraform script to provision the DC/OS master nodes.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

data "template_file" "coreos_master_ignition" {
    template = "${file( "${path.module}/files/master_setup.ign.tpl") }"
    # Only 5 is supported right now. This is HA and production ready
    # to almost any scale.
    count    = "${var.master_count}"
    vars = {
        cluster_name = "${azurerm_resource_group.dcos.name}"
        master_num   = "${count.index}"
        my_ip        = "${element( azurerm_network_interface.master.*.private_ip_address, count.index ) }"
        vm_hostname  = "dcosmaster${count.index}"
    }
}

resource "azurerm_network_interface" "master" {
    name                      = "dcosmasternic${count.index}"
    location                  = "${azurerm_resource_group.dcos.location}"
    resource_group_name       = "${azurerm_resource_group.dcos.name}"
    count                     = "${var.master_count}"
    network_security_group_id = "${azurerm_network_security_group.dcosmaster.id}"

    ip_configuration {
        name                                    = "ipConfigNode"
        private_ip_address_allocation           = "static"
        private_ip_address                      = "172.16.0.${var.master_private_ip_address_index + count.index}"
        subnet_id                               = "${azurerm_subnet.dcosmaster.id}"
        // JZ - Removed because we have a bastion host.
        //load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.master.id}"]
        //load_balancer_inbound_nat_rules_ids     = ["${element(azurerm_lb_nat_rule.masterlbrulessh.*.id, count.index)}"]
    }
}

resource "azurerm_network_interface" "masterMgmt" {
    name                      = "dcosMasterMgmt${count.index}"
    location                  = "${azurerm_resource_group.dcos.location}"
    resource_group_name       = "${azurerm_resource_group.dcos.name}"
    count                     = "${var.master_count}"
    network_security_group_id = "${azurerm_network_security_group.dcosmgmt.id}"

    ip_configuration {
        name                                    = "ipConfigMgmt"
        private_ip_address_allocation           = "static"
        private_ip_address                      = "10.66.0.${var.master_private_ip_address_index + count.index}"
        subnet_id                               = "${azurerm_subnet.dcosMgmt.id}"
    }
}

resource "azurerm_virtual_machine" "master" {
    name                          = "dcosmaster${count.index}"
    location                      = "${azurerm_resource_group.dcos.location}"
    count                         = "${var.master_count}"
    resource_group_name           = "${azurerm_resource_group.dcos.name}"
    primary_network_interface_id  = "${element(azurerm_network_interface.master.*.id, count.index)}"
    network_interface_ids         = [
        "${element(azurerm_network_interface.master.*.id, count.index)}",
        "${element(azurerm_network_interface.masterMgmt.*.id, count.index)}"
    ]
    vm_size                       = "${var.master_size}"
    availability_set_id           = "${azurerm_availability_set.masterVMAvailSet.id}"
    delete_os_disk_on_termination = true
    # Bootstrap Node must be alive and well first.
    depends_on                    = [ "azurerm_virtual_machine.dcosBootstrapNodeVM" ]

    lifecycle {
        ignore_changes = ["admin_password"]
    }

    connection {
        type         = "ssh"
        host         = "${element( azurerm_network_interface.master.*.private_ip_address, count.index )}"
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

    provisioner "remote-exec" {
        inline = [
            "chmod 755 /opt/dcos/install.sh",
            "cd /opt/dcos && bash install.sh '172.16.0.8' 'master'"
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
        name              = "dcosMasterOSDisk${count.index}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "${lookup( var.vm_type_to_os_disk_type, var.master_size, "Premium_LRS" )}"
        disk_size_gb      = "${var.os_disk_size}"
    }

    os_profile {
        computer_name  = "dcosmaster${count.index}"
        admin_username = "${var.vm_user}"
        admin_password = "${uuid()}"
        custom_data    = "${element( data.template_file.coreos_master_ignition.*.rendered, count.index ) }"
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys {
            path     = "/home/${var.vm_user}/.ssh/authorized_keys"
            key_data = "${file(var.public_key_path)}"
        }
    }

}
