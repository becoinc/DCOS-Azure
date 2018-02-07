#
# This is a terraform script to provision the DC/OS private agent nodes.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

resource "azurerm_availability_set" "largePrivateAgentVMAvailSet" {
    name                = "dcosLargePrivateAgentVmAvailSet"
    location            = "${azurerm_resource_group.dcos.location}"
    resource_group_name = "${azurerm_resource_group.dcos.name}"
    managed             = true
}

locals {
    large_my_ip  = "${azurerm_network_interface.dcosLargePrivateAgentIF0.*.private_ip_address}"
}

data "ignition_file" "private_agent_lg_hosts" {
    count      = "${var.agent_private_large_count}"
    filesystem = "root"
    path       = "/etc/hosts"
    mode       = 420
    content {
        content = <<EOF
127.0.0.1   localhost
::1         localhost
${local.large_my_ip[ count.index ]}    dcoslargeprivateagent${count.index}
EOF
    }
}

data "ignition_config" "private_agent_large" {
    count   = "${var.agent_private_large_count}"
    filesystems = [
        "${data.ignition_filesystem.lun2.id}",
        "${data.ignition_filesystem.lun3.id}",
        "${data.ignition_filesystem.lun4.id}",
    ]
    files = [
        "${data.ignition_file.env_profile.id}",
        "${data.ignition_file.tcp_keepalive.id}",
        "${data.ignition_file.private_agent_lg_hosts.*.id[ count.index ]}",
        "${data.ignition_file.azure_disk_udev_rules.id}"
    ]
    systemd = [
        "${data.ignition_systemd_unit.mask_locksmithd.id}",
        "${data.ignition_systemd_unit.mask_update_engine.id}",
        "${data.ignition_systemd_unit.private_agent_mount_var_log.id}",
        "${data.ignition_systemd_unit.private_agent_mount_var_lib_docker.id}",
        "${data.ignition_systemd_unit.private_agent_mount_var_lib_mesos_slave.id}",
    ]
}

# The first - eth0 - network interface for the Private agents
resource "azurerm_network_interface" "dcosLargePrivateAgentIF0" {
    name                          = "dcosLargePrivateAgentIF${count.index}-0"
    location                      = "${azurerm_resource_group.dcos.location}"
    resource_group_name           = "${azurerm_resource_group.dcos.name}"
    enable_accelerated_networking = "${lookup( var.vm_type_to_an, var.agent_private_large_size, "false" )}"
    count                         = "${var.agent_private_large_count}"

    ip_configuration {
        name                          = "lgPrivateAgentIPConfig"
        subnet_id                     = "${azurerm_subnet.dcosprivate.id}"
        private_ip_address_allocation = "static"
        private_ip_address            = "10.33.${count.index / 254}.${ (count.index + 10) % 254 }"
        #NO PUBLIC IP FOR THIS INTERFACE - VM ONLY ACCESSIBLE INTERNALLY
        #public_ip_address_id          = "${azurerm_public_ip.vmPubIP.id}"
    }
}

# This is the second - eth1 - interface for the private agents.
resource "azurerm_network_interface" "dcosLargePrivateAgentMgmt" {
    name                          = "dcosLargePrivateAgentMgmtIF${count.index}-0"
    location                      = "${azurerm_resource_group.dcos.location}"
    resource_group_name           = "${azurerm_resource_group.dcos.name}"
    count                         = "${var.agent_private_large_count}"
    enable_accelerated_networking = "${lookup( var.vm_type_to_an, var.agent_private_large_size, "false" )}"
    ip_configuration {
        name                                    = "lgPrivateAgentMgmtIPConfig"
        subnet_id                               = "${azurerm_subnet.dcosMgmt.id}"
        private_ip_address_allocation           = "static"
        private_ip_address                      = "10.66.${count.index / 254}.${ (count.index + 10) % 254 }"
    }
}

# This is the third - eth2 - interface for the private agents.
resource "azurerm_network_interface" "dcosLargePrivateAgentStorage" {
    name                          = "dcosLargePrivateAgentStorageIF${count.index}-0"
    location                      = "${azurerm_resource_group.dcos.location}"
    resource_group_name           = "${azurerm_resource_group.dcos.name}"
    count                         = "${var.agent_private_large_count}"
    enable_accelerated_networking = "${lookup( var.vm_type_to_an, var.agent_private_large_size, "false" )}"

    ip_configuration {
        name                                    = "lgPrivateAgentStorageIPConfig"
        subnet_id                               = "${azurerm_subnet.dcosStorageData.id}"
        private_ip_address_allocation           = "static"
        private_ip_address                      = "10.97.${count.index / 254}.${ (count.index + 10) % 254 }"
    }
}

/*
 * These are created separately instead of inline with the VM
 * b/c Terraform and Azure behave better on recreate that way.
 */
resource "azurerm_managed_disk" "lgStorageDataDisk0" {
    name                 = "dcosLgPrivateAgentStorageDataDisk0-${count.index}"
    location             = "${azurerm_resource_group.dcos.location}"
    resource_group_name  = "${azurerm_resource_group.dcos.name}"
    storage_account_type = "${lookup( var.vm_type_to_os_disk_type, var.agent_private_large_size, "Premium_LRS" )}"
    create_option        = "Empty"
    disk_size_gb         = "${var.data_disk_size}"
    count                = "${var.agent_private_large_count}"

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
resource "azurerm_managed_disk" "lgStorageDataDisk1" {
    name                 = "dcosLgPrivateAgentStorageDataDisk1-${count.index}"
    location             = "${azurerm_resource_group.dcos.location}"
    resource_group_name  = "${azurerm_resource_group.dcos.name}"
    storage_account_type = "${lookup( var.vm_type_to_os_disk_type, var.agent_private_large_size, "Premium_LRS" )}"
    create_option        = "Empty"
    disk_size_gb         = "${var.data_disk_size}"
    count                = "${var.agent_private_large_count}"

    lifecycle {
        prevent_destroy = true
    }

    tags {
        environment = "${var.instance_name}"
    }
}

resource "azurerm_virtual_machine" "dcosLargePrivateAgent" {
    name                          = "dcoslargeprivateagent${count.index}"
    location                      = "${azurerm_resource_group.dcos.location}"
    resource_group_name           = "${azurerm_resource_group.dcos.name}"
    primary_network_interface_id  = "${azurerm_network_interface.dcosLargePrivateAgentIF0.*.id[ count.index ]}"
    network_interface_ids         = [
        "${ azurerm_network_interface.dcosLargePrivateAgentIF0.*.id[ count.index ] }",
        "${ azurerm_network_interface.dcosLargePrivateAgentMgmt.*.id[ count.index ] }",
        "${ azurerm_network_interface.dcosLargePrivateAgentStorage.*.id[ count.index ] }"
    ]
    vm_size                       = "${var.agent_private_large_size}"
    availability_set_id           = "${azurerm_availability_set.largePrivateAgentVMAvailSet.id}"
    delete_os_disk_on_termination = true
    count                         = "${var.agent_private_large_count}"
    depends_on                    = ["azurerm_virtual_machine.master"]

    lifecycle {
        ignore_changes  = [ "admin_password" ]
    }

    connection {
        type         = "ssh"
        host         = "${azurerm_network_interface.dcosLargePrivateAgentIF0.*.private_ip_address[ count.index ]}"
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
        source      = "${path.module}/files/install_lg_private_agent.sh"
        destination = "/opt/dcos/install_lg_private_agent.sh"
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
            "chmod 755 /opt/dcos/install_lg_private_agent.sh",
            "cd /opt/dcos && bash install_lg_private_agent.sh '172.16.0.8' 'slave'"
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
        name              = "dcosLgPrivateAgentOsDisk${count.index}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "${lookup( var.vm_type_to_os_disk_type, var.agent_private_large_size, "Premium_LRS" )}"
        disk_size_gb      = "${var.os_disk_size}"
    }

    storage_data_disk {
        name              = "${ azurerm_managed_disk.lgStorageDataDisk0.*.name[ count.index ] }"
        caching           = "ReadOnly"
        create_option     = "Attach"
        managed_disk_id   = "${ azurerm_managed_disk.lgStorageDataDisk0.*.id[ count.index ] }"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_private_large_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.data_disk_size}"
        lun               = 0
    }

    storage_data_disk {
        name              = "${ azurerm_managed_disk.lgStorageDataDisk1.*.name[ count.index ] }"
        caching           = "ReadOnly"
        create_option     = "Attach"
        managed_disk_id   = "${ azurerm_managed_disk.lgStorageDataDisk1.*.id[ count.index ] }"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_private_large_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.data_disk_size}"
        lun               = 1
    }

    # Storage for /var/log
    storage_data_disk {
        name              = "dcosLgPrivateLogDisk-${count.index}"
        caching           = "None"
        create_option     = "Empty"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_private_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.io_offload_disk_size}"
        lun               = 2
    }

    # Storage for /var/lib/docker
    storage_data_disk {
        name              = "dcosLgPrivateDockerDisk-${count.index}"
        caching           = "ReadOnly"
        create_option     = "Empty"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_private_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.io_offload_disk_size}"
        lun               = 3
    }

    # Storage for /var/lib/mesos/slave
    storage_data_disk {
        name              = "dcosLgPrivateMesosDisk-${count.index}"
        caching           = "ReadOnly"
        create_option     = "Empty"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_private_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.mesos_slave_disk_size}"
        lun               = 4
    }

    os_profile {
        computer_name  = "dcoslargeprivateagent${count.index}"
        admin_username = "${var.vm_user}"
        admin_password = "${uuid()}"
        # According to the Azure Terraform Documentation
        # and https://docs.microsoft.com/en-us/azure/virtual-machines/linux/using-cloud-init
        # Cloud init is supported on ubuntu and coreos for custom_data.
        # However, according to CoreOS, their Ignition format is preferred.
        # cloud-init on Azure appears to be the deprecated coreos-cloudinit
        # Therefore we are going to try ignition.
        custom_data    = "${ data.ignition_config.private_agent_large.*.rendered[ count.index ] }"
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
