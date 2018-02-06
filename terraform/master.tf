#
# This is a terraform script to provision the DC/OS master nodes.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

locals {
    my_ip        = "${azurerm_network_interface.master.*.private_ip_address}"
    cluster_name = "${azurerm_resource_group.dcos.name}"
}

data "ignition_file" "master_hosts" {
    count      = "${var.master_count}"
    filesystem = "root"
    path       = "/etc/hosts"
    mode       = 420
    content {
        content = <<EOF
127.0.0.1   localhost
::1         localhost
${local.my_ip[ count.index ]}    dcosmaster${count.index}
EOF
    }
}

data "ignition_systemd_unit" "master_etcd" {
    count   = "${var.master_count}"
    name    = "etcd-member.service"
    enabled = true
    dropin {
        name = "20-clct-etcd-member.conf"
        content = <<EOF
[Service]
ExecStart=
ExecStart=/usr/lib/coreos/etcd-wrapper $ETCD_OPTS \
    --name="${local.cluster_name}-etcd-${count.index}" \
    --listen-peer-urls="https://127.0.0.1:2380,https://${local.my_ip[ count.index ]}:2380" \
    --listen-client-urls="https://127.0.0.1:2379,https://${local.my_ip[ count.index ]}:2379,http://${local.my_ip[ count.index ]}:12379" \
    --initial-advertise-peer-urls="https://${local.my_ip[ count.index ]}:2380" \
    --initial-cluster="${local.cluster_name}-etcd-0=https://172.16.0.10:2380,${local.cluster_name}-etcd-1=https://172.16.0.11:2380,${local.cluster_name}-etcd-2=https://172.16.0.12:2380,${local.cluster_name}-etcd-3=https://172.16.0.13:2380,${local.cluster_name}-etcd-4=https://172.16.0.14:2380" \
    --initial-cluster-state="new" \
    --initial-cluster-token="${local.cluster_name}-etcd-token" \
    --advertise-client-urls="https://${local.my_ip[ count.index ]}:2379" \
    --auto-tls \
    --peer-auto-tls \
    --auto-compaction-retention=3 \
    --quota-backend-bytes=8589934592 \
    --snapshot-count=5000
Environment="ETCD_IMAGE_TAG=v3.2.10"
EOF
    }
}

/**
 * Mount the lun1 data disk on /var/lib/dcos/exhibitor/
 */
data "ignition_systemd_unit" "master_mount_var_lib_dcos_exhibitor" {
    name    = "var-lib-dcos-exhibitor.mount"
    enabled = true
    content = <<EOF
[Unit]
Before=local-fs.target
[Mount]
What=/dev/disk/azure/scsi1/lun1
Where=/var/lib/dcos/exhibitor
Type=xfs
[Install]
WantedBy=local-fs.target
EOF
}

/**
 * Mount the lun2 data disk on /var/lib/etcd
 */
data "ignition_systemd_unit" "master_mount_var_lib_etcd" {
    name    = "var-lib-etcd.mount"
    enabled = true
    content = <<EOF
[Unit]
Before=local-fs.target
[Mount]
What=/dev/disk/azure/scsi1/lun2
Where=/var/lib/etcd
Type=xfs
[Install]
WantedBy=local-fs.target
EOF
}

data "ignition_config" "master" {
    # Only 5 is supported right now. This is HA and production ready
    # to almost any scale.
    count   = "${var.master_count}"
    filesystems = [
        "${data.ignition_filesystem.dev_sdb.id}",
        "${data.ignition_filesystem.dev_sdc.id}",
        "${data.ignition_filesystem.dev_sdd.id}",
        "${data.ignition_filesystem.dev_sde.id}",
    ]
    files = [
        "${data.ignition_file.env_profile.id}",
        "${data.ignition_file.tcp_keepalive.id}",
        "${data.ignition_file.master_hosts.*.id[ count.index ]}",
        "${data.ignition_file.azure_disk_udev_rules.id}"
    ]
    systemd = [
        "${data.ignition_systemd_unit.mask_locksmithd.id}",
        "${data.ignition_systemd_unit.mask_update_engine.id}",
        "${data.ignition_systemd_unit.mount_var_log.id}",
        "${data.ignition_systemd_unit.master_mount_var_lib_dcos_exhibitor.id}",
        "${data.ignition_systemd_unit.master_mount_var_lib_etcd.id}",
        "${data.ignition_systemd_unit.master_etcd.*.id[ count.index ]}"
    ]
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
        //load_balancer_inbound_nat_rules_ids     = ["${(azurerm_lb_nat_rule.masterlbrulessh.*.id, count.index)}"]
    }
}

resource "azurerm_virtual_machine" "master" {
    name                             = "dcosmaster${count.index}"
    location                         = "${azurerm_resource_group.dcos.location}"
    count                            = "${var.master_count}"
    resource_group_name              = "${azurerm_resource_group.dcos.name}"
    primary_network_interface_id     = "${azurerm_network_interface.master.*.id[ count.index ] }"
    network_interface_ids            = [ "${azurerm_network_interface.master.*.id[ count.index ] }" ]
    vm_size                          = "${var.master_size}"
    availability_set_id              = "${azurerm_availability_set.masterVMAvailSet.id}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true
    # Bootstrap Node must be alive and well first.
    depends_on                    = [ "azurerm_virtual_machine.dcosBootstrapNodeVM" ]

    lifecycle {
        ignore_changes = ["admin_password"]
    }

    connection {
        type         = "ssh"
        host         = "${ azurerm_network_interface.master.*.private_ip_address[ count.index ] }"
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

    /**
     * These extra disks ensure that the synchronous write load from ZK and etcd
     * do not cause other problems with the cluster.
     *
     * A more aggressive configuration would be to split the ZK and etcd WAL
     * drives out as well.
     */

    # Storage for /var/log
    storage_data_disk {
        name              = "dcosMasterLogDisk-${count.index}"
        caching           = "None"
        create_option     = "Empty"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_private_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.io_offload_disk_size}"
        lun               = 0
    }

    # Storage for /var/lib/dcos/exhibitor/
    storage_data_disk {
        name              = "dcosMasterZkDisk-${count.index}"
        caching           = "None"
        create_option     = "Empty"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_private_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.io_offload_disk_size}"
        lun               = 1
    }

    # Storage for /var/lib/etcd
    storage_data_disk {
        name              = "dcosMasterEtcdDisk-${count.index}"
        caching           = "None"
        create_option     = "Empty"
        managed_disk_type = "${ lookup( var.vm_type_to_os_disk_type, var.agent_private_size, "Premium_LRS" ) }"
        disk_size_gb      = "${var.io_offload_disk_size}"
        lun               = 2
    }

    os_profile {
        computer_name  = "dcosmaster${count.index}"
        admin_username = "${var.vm_user}"
        admin_password = "${uuid()}"
        custom_data    = "${ data.ignition_config.master.*.rendered[ count.index ] }"
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys {
            path     = "/home/${var.vm_user}/.ssh/authorized_keys"
            key_data = "${file(var.public_key_path)}"
        }
    }

}
