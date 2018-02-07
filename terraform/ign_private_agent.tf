#
# This is a terraform script to setup Ignition for the DC/OS private agent nodes.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

data "ignition_file" "private_agent_hosts" {
    count      = "${var.agent_private_count}"
    filesystem = "root"
    path       = "/etc/hosts"
    mode       = 420
    content {
        content = <<EOF
127.0.0.1   localhost
::1         localhost
${azurerm_network_interface.dcosPrivateAgentIF0.*.private_ip_address[ count.index ]}    dcosprivateagent${count.index}
EOF
    }
}

/**
 * Mount the lun2 data disk on /var/log
 */
data "ignition_systemd_unit" "private_agent_mount_var_log" {
    name    = "var-log.mount"
    enabled = true
    content = <<EOF
[Unit]
Before=local-fs.target
[Mount]
What=/dev/disk/azure/scsi1/lun2
Where=/var/log
Type=xfs
[Install]
WantedBy=local-fs.target
EOF
}

/**
 * Mount the lun3 data disk on /var/lib/docker
 */
data "ignition_systemd_unit" "private_agent_mount_var_lib_docker" {
    name    = "var-lib-docker.mount"
    enabled = true
    content = <<EOF
[Unit]
Before=local-fs.target
[Mount]
What=/dev/disk/azure/scsi1/lun3
Where=/var/lib/docker
Type=xfs
[Install]
WantedBy=local-fs.target
EOF
}

/**
 * Mount the lun4 data disk on /var/lib/mesos/slave
 */
data "ignition_systemd_unit" "private_agent_mount_var_lib_mesos_slave" {
    name    = "var-lib-mesos-slave.mount"
    enabled = true
    content = <<EOF
[Unit]
Before=local-fs.target
[Mount]
What=/dev/disk/azure/scsi1/lun4
Where=/var/lib/mesos/slave
Type=xfs
[Install]
WantedBy=local-fs.target
EOF
}

data "ignition_config" "private_agent" {
    count   = "${var.agent_private_count}"
    filesystems = [
        "${data.ignition_filesystem.lun2.id}",
        "${data.ignition_filesystem.lun3.id}",
        "${data.ignition_filesystem.lun4.id}",
    ]
    files = [
        "${data.ignition_file.env_profile.id}",
        "${data.ignition_file.tcp_keepalive.id}",
        "${data.ignition_file.private_agent_hosts.*.id[ count.index ]}",
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
