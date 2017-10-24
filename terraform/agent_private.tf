#
# This is a terraform script to provision the DC/OS private agent nodes.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

data "template_file" "coreos_private_ignition" {
    template = "${file( "${path.module}/files/agent_setup.ign.tpl" ) }"
    count    = "${var.agent_private_count}"
    vars = {
        cluster_name = "${azurerm_resource_group.dcos.name}"
        my_ip        = "${element( azurerm_network_interface.dcosPrivateAgentIF0.*.private_ip_address, count.index ) }"
        vm_hostname  = "dcosprivateagent${count.index}"
    }
}

data "template_file" "portworx_config_json" {
    template = "${file( "${path.module}/files/px_config.json.tpl" )}"
    count    = "${var.agent_private_count}"
    vars     = {
        portworx_cluster_id  = "${var.portworx_cluster_id}"
        portworx_license_key = "${var.portworx_license_key}"
    }
}

# The first - eth0 - network interface for the Private agents
resource "azurerm_network_interface" "dcosPrivateAgentIF0" {
    name                    = "dcosPrivateAgentIF${count.index}-0"
    location                = "${azurerm_resource_group.dcos.location}"
    resource_group_name     = "${azurerm_resource_group.dcos.name}"
    count                   = "${var.agent_private_count}"

    ip_configuration {
        name                          = "privateAgentIPConfig"
        subnet_id                     = "${azurerm_subnet.dcosprivate.id}"
        private_ip_address_allocation = "static"
        private_ip_address            = "10.32.${count.index / 254}.${ (count.index + 10) % 254 }"
        #NO PUBLIC IP FOR THIS INTERFACE - VM ONLY ACCESSIBLE INTERNALLY
        #public_ip_address_id          = "${azurerm_public_ip.vmPubIP.id}"
    }
}

# This is the second - eth1 - interface for the private agents.
resource "azurerm_network_interface" "dcosPrivateAgentMgmt" {
    name                = "dcosPrivateAgentMgmtIF${count.index}-0"
    location            = "${azurerm_resource_group.dcos.location}"
    resource_group_name = "${azurerm_resource_group.dcos.name}"
    count               = "${var.agent_private_count}"
    ip_configuration {
        name                                    = "privateAgentMgmtIPConfig"
        subnet_id                               = "${azurerm_subnet.dcosMgmt.id}"
        private_ip_address_allocation           = "static"
        private_ip_address                      = "10.64.${count.index / 254}.${ (count.index + 10) % 254 }"
    }
}

# This is the third - eth2 - interface for the private agents.
resource "azurerm_network_interface" "dcosPrivateAgentStorage" {
    name                = "dcosPrivateAgentStorageIF${count.index}-0"
    location            = "${azurerm_resource_group.dcos.location}"
    resource_group_name = "${azurerm_resource_group.dcos.name}"
    count               = "${var.agent_private_count}"
    ip_configuration {
        name                                    = "privateAgentStorageIPConfig"
        subnet_id                               = "${azurerm_subnet.dcosStorageData.id}"
        private_ip_address_allocation           = "static"
        private_ip_address                      = "10.96.${count.index / 254}.${ (count.index + 10) % 254 }"
    }
}

/*
 * These are created separately instead of inline with the VM
 * b/c Terraform and Azure behave better on recreate that way.
 */
resource "azurerm_managed_disk" "storageDataDisk0" {
    name                 = "dcosPrivateAgentStorageDataDisk0-${count.index}"
    location             = "${azurerm_resource_group.dcos.location}"
    resource_group_name  = "${azurerm_resource_group.dcos.name}"
    storage_account_type = "${lookup( var.vm_type_to_os_disk_type, var.agent_private_size, "Premium_LRS" )}"
    create_option        = "Empty"
    disk_size_gb         = "${var.data_disk_size}"
    count                = "${var.agent_private_count}"

    lifecycle {
        prevent_destroy = true
    }

    tags {
        environment = "${var.instance_name}"
    }
}

/*
 * These are created separately instead of inline with the VM
 * b/c Terraform and Azure behave better on recreate that way.
 */
resource "azurerm_managed_disk" "portworxjournaldisk" {
    name                 = "dcosPrivateAgentPxJournalDisk-${count.index}"
    location             = "${azurerm_resource_group.dcos.location}"
    resource_group_name  = "${azurerm_resource_group.dcos.name}"
    storage_account_type = "${lookup( var.vm_type_to_os_disk_type, var.agent_private_size, "Premium_LRS" )}"
    create_option        = "Empty"
    disk_size_gb         = "${var.px_journal_disk_size}"
    count                = "${var.agent_private_count}"

    lifecycle {
        prevent_destroy = true
    }

    tags {
        environment = "${var.instance_name}"
    }
}


resource "azurerm_virtual_machine" "dcosPrivateAgent" {
    name                          = "dcosprivateagent${count.index}"
    location                      = "${azurerm_resource_group.dcos.location}"
    resource_group_name           = "${azurerm_resource_group.dcos.name}"
    primary_network_interface_id  = "${element( azurerm_network_interface.dcosPrivateAgentIF0.*.id, count.index )}"
    network_interface_ids         = [
        "${element( azurerm_network_interface.dcosPrivateAgentIF0.*.id, count.index )}",
        "${element( azurerm_network_interface.dcosPrivateAgentMgmt.*.id, count.index )}",
        "${element( azurerm_network_interface.dcosPrivateAgentStorage.*.id, count.index )}"
    ]
    vm_size                       = "${var.agent_private_size}"
    availability_set_id           = "${azurerm_availability_set.privateAgentVMAvailSet.id}"
    delete_os_disk_on_termination = true
    count                         = "${var.agent_private_count}"
    depends_on                    = ["azurerm_virtual_machine.master"]

    lifecycle {
        ignore_changes  = [ "storage_os_disk", "os_profile" ]
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
        source      = "${path.module}/files/install_private_agent.sh"
        destination = "/opt/dcos/install_private_agent.sh"
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
            "chmod 755 /opt/dcos/install_private_agent.sh",
            "cd /opt/dcos && bash install_private_agent.sh '172.16.0.8' 'slave'"
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
        managed_disk_type = "${lookup( var.vm_type_to_os_disk_type, var.agent_private_size, "Premium_LRS" )}"
        disk_size_gb      = "${var.os_disk_size}"
    }

    storage_data_disk {
        name              = "dcosPrivateAgentStorageDataDisk0-${count.index}"
        caching           = "ReadOnly"
        create_option     = "Attach"
        managed_disk_id   = "${ element( azurerm_managed_disk.storageDataDisk0.*.id, count.index ) }"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_private_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.data_disk_size}"
        lun               = 0
    }

    storage_data_disk {
        name              = "dcosPrivateAgentPxJournalDisk-${count.index}"
        caching           = "ReadOnly"
        create_option     = "Attach"
        managed_disk_id   = "${ element( azurerm_managed_disk.portworxjournaldisk.*.id, count.index ) }"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_private_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.px_journal_disk_size}"
        lun               = 1
    }

    os_profile {
        computer_name  = "dcosprivateagent${count.index}"
        admin_username = "${var.vm_user}"
        admin_password = "${uuid()}"
        # According to the Azure Terraform Documentation
        # and https://docs.microsoft.com/en-us/azure/virtual-machines/linux/using-cloud-init
        # Cloud init is supported on ubuntu and coreos for custom_data.
        # However, according to CoreOS, their Ignition format is preferred.
        # cloud-init on Azure appears to be the deprecated coreos-cloudinit
        # Therefore we are going to try ignition.
        custom_data    = "${element( data.template_file.coreos_private_ignition.*.rendered, count.index ) }"
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
