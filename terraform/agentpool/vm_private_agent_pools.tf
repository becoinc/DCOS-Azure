#
# This is a terraform script to provision the DC/OS private agent nodes.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

locals {
    // This turns var.extra_pool_names and var.include_in_default_pool and var.extra_attributes
    // into:
    // agentpool:x,agentpool:y,agentpool:default,attr:val,...
    mesos_attributes = "${join( ",",
        compact(
            concat(
                formatlist( "agentpool:%s",
                    compact(
                        concat( var.extra_pool_names, list( var.include_in_default_pool == true ? "default" : "" ) ) ) ), var.extra_attributes ) ) )}"
}

resource "local_file" "mesos_attrs" {
    content  = "${local.mesos_attributes}"
    filename = "${path.cwd}/outputs/${var.modname}_mesos_attr.ign"
}

/*
 * Each pools of agents gets its own avail set.
 */
resource "azurerm_availability_set" "dcosPrivateAgentPool" {
    count               = "${var.agent_count > 0 ? 1 : 0}"
    name                = "dcosAgent${ var.modname }VmAvailSet"
    location            = "${var.azure_region}"
    resource_group_name = "${var.azure_resource_group}"
    managed             = true
}

# The first - eth0 - network interface for the Private agents
resource "azurerm_network_interface" "dcosPrivateAgentPri" {
    name                          = "dcos${ var.modname }If${count.index}-0"
    location                      = "${var.azure_region}"
    resource_group_name           = "${var.azure_resource_group}"
    enable_accelerated_networking = "${lookup( var.vm_type_to_an, var.agent_size, "false" )}"
    count                         = "${var.agent_count}"

    ip_configuration {
        name                          = "${var.modname}IPConfig"
        subnet_id                     = "${var.primary_subnet}"
        private_ip_address_allocation = "static"
        private_ip_address            = "10.${33 + var.mod_instance_id}.${count.index / 254}.${ (count.index + 10) % 254 }"
    }
}

# This is the second - eth1 - interface for the private agents.
resource "azurerm_network_interface" "dcosPrivateAgentMgmt" {
    name                          = "dcos${ var.modname }MgmtIF${count.index}-0"
    location                      = "${var.azure_region}"
    resource_group_name           = "${var.azure_resource_group}"
    count                         = "${var.agent_count}"
    enable_accelerated_networking = "${lookup( var.vm_type_to_an, var.agent_size, "false" )}"

    ip_configuration {
        name                          = "${var.modname}MgmtIPConfig"
        subnet_id                     = "${var.secondary_subnet}"
        private_ip_address_allocation = "static"
        private_ip_address            = "10.${66 + var.mod_instance_id}.${count.index / 254}.${ (count.index + 10) % 254 }"
    }
}

resource "azurerm_virtual_machine" "dcosPrivateAgent" {
    name                          = "dcos${ var.modname }agent${count.index}"
    location                      = "${var.azure_region}"
    resource_group_name           = "${var.azure_resource_group}"
    primary_network_interface_id  = "${azurerm_network_interface.dcosPrivateAgentPri.*.id[ count.index ]}"
    network_interface_ids         = [
        "${ azurerm_network_interface.dcosPrivateAgentPri.*.id[ count.index ] }",
        "${ azurerm_network_interface.dcosPrivateAgentMgmt.*.id[ count.index ] }",
    ]
    vm_size                          = "${var.agent_size}"
    availability_set_id              = "${azurerm_availability_set.dcosPrivateAgentPool.id}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true
    count                            = "${var.agent_count}"

    lifecycle {
        ignore_changes  = [ "admin_password" ]
    }

    connection {
        type         = "ssh"
        host         = "${azurerm_network_interface.dcosPrivateAgentPri.*.private_ip_address[ count.index ]}"
        user         = "${var.vm_user}"
        timeout      = "120s"
        private_key  = "${file(var.private_key_path)}"
        # Configuration for the Jumpbox
        bastion_host        = "${var.bastion_host_ip}"
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
        source      = "${path.module}/../files/vm_setup.sh"
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
        source      = "${path.module}/files/install_lg_private_agent.sh"
        destination = "/opt/dcos/install_lg_private_agent.sh"
    }

    provisioner "file" {
        source      = "${path.module}/../files/50-docker.network"
        destination = "/tmp/50-docker.network"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo mv /tmp/50-docker.network /etc/systemd/network/",
            "sudo chmod 644 /etc/systemd/network/50-docker.network",
            "sudo systemctl restart systemd-networkd",
            "chmod 755 /opt/dcos/install_lg_private_agent.sh",
            "cd /opt/dcos && bash install_lg_private_agent.sh '172.16.0.8' 'slave'",
        ]
    }

    provisioner "file" {
        destination = "/tmp/mesos-slave-common"
        content     = "MESOS_ATTRIBUTES=${local.mesos_attributes}"
    }

    /*
     * Provision the attributes.
     */
    provisioner "remote-exec" {
        inline = [
            "sudo mv /tmp/mesos-slave-common /var/lib/dcos/mesos-slave-common",
            "sudo chown root:root /var/lib/dcos/mesos-slave-common",
            "sudo rm -f /var/lib/mesos/slave/meta/slaves/latest",
            "sudo systemctl restart dcos-mesos-slave.service",
        ]
    }

    boot_diagnostics {
        enabled     = true
        storage_uri = "${var.boot_diag_blob_endpoint}"
    }

    storage_image_reference {
        publisher = "${var.image["publisher"]}"
        offer     = "${var.image["offer"]}"
        sku       = "${var.image["sku"]}"
        version   = "${var.image["version"]}"
    }

    storage_os_disk {
        name              = "dcos${var.modname}OsDisk${count.index}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "${lookup( var.vm_type_to_os_disk_type, var.agent_size, "Premium_LRS" )}"
        disk_size_gb      = "${var.os_disk_size}"
    }

    # Storage for /var/log
    storage_data_disk {
        name              = "dcos${var.modname}Log-${count.index}"
        caching           = "None"
        create_option     = "Empty"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.io_offload_disk_size}"
        lun               = 1
    }

    # Storage for /var/lib/docker
    storage_data_disk {
        name              = "dcos${var.modname}Docker-${count.index}"
        caching           = "ReadOnly"
        create_option     = "Empty"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.io_offload_disk_size}"
        lun               = 2
    }

    # Storage for /var/lib/mesos/slave
    storage_data_disk {
        name              = "dcos${var.modname}Mesos-${count.index}"
        caching           = "ReadOnly"
        create_option     = "Empty"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.mesos_slave_disk_size}"
        lun               = 3
    }

    storage_data_disk {
        name              = "dcos${var.modname}Volume0-${count.index}"
        caching           = "ReadOnly"
        create_option     = "Empty"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.data_disk_size}"
        lun               = 4
    }

    os_profile {
        computer_name  = "dcos${var.modname}agent${count.index}"
        admin_username = "${var.vm_user}"
        admin_password = "${uuid()}"
        # According to the Azure Terraform Documentation
        # and https://docs.microsoft.com/en-us/azure/virtual-machines/linux/using-cloud-init
        # Cloud init is supported on ubuntu and coreos for custom_data.
        # However, according to CoreOS, their Ignition format is preferred.
        # cloud-init on Azure appears to be the deprecated coreos-cloudinit
        # Therefore we are going to try ignition.
        custom_data    = "${ data.ignition_config.private_agent_pool.*.rendered[ count.index ] }"
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
