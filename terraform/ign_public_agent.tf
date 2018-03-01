#
# This is a terraform script to provision the DC/OS public agent nodes ignition.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

data "ignition_file" "public_agent_hosts" {
    count      = "${var.agent_public_count}"
    filesystem = "root"
    path       = "/etc/hosts"
    mode       = 420
    content {
        content = <<EOF
127.0.0.1   localhost
::1         localhost
${azurerm_network_interface.dcosPublicAgentIF0.*.private_ip_address[ count.index ]}    dcospublicagent${count.index}
EOF
    }
}

/**
 * Mount the lun2 data disk on /var/lib/docker
 */
data "ignition_systemd_unit" "public_agent_mount_var_lib_docker" {
    name    = "var-lib-docker.mount"
    enabled = true
    content = <<EOF
[Unit]
Before=local-fs.target
[Mount]
What=/dev/disk/azure/scsi1/lun2
Where=/var/lib/docker
Type=xfs
[Install]
WantedBy=local-fs.target
EOF
}

/**
 * Mount the lun3 data disk on /var/lib/mesos/slave
 */
data "ignition_systemd_unit" "public_agent_mount_var_lib_mesos_slave" {
    name    = "var-lib-mesos-slave.mount"
    enabled = true
    content = <<EOF
[Unit]
Before=local-fs.target
[Mount]
What=/dev/disk/azure/scsi1/lun3
Where=/var/lib/mesos/slave
Type=xfs
[Install]
WantedBy=local-fs.target
EOF
}

data "ignition_config" "public_agent" {
    count   = "${var.agent_public_count}"
    filesystems = [
        "${data.ignition_filesystem.lun1.id}",
        "${data.ignition_filesystem.lun2.id}",
        "${data.ignition_filesystem.lun3.id}",
    ]
    files = [
        "${data.ignition_file.env_profile.id}",
        "${data.ignition_file.tcp_keepalive.id}",
        "${data.ignition_file.public_agent_hosts.*.id[ count.index ]}",
        "${data.ignition_file.azure_disk_udev_rules.id}"
    ]
    systemd = [
        "${data.ignition_systemd_unit.mask_locksmithd.id}",
        "${data.ignition_systemd_unit.mask_update_engine.id}",
        "${data.ignition_systemd_unit.mount_var_log.id}",
        "${data.ignition_systemd_unit.public_agent_mount_var_lib_docker.id}",
        "${data.ignition_systemd_unit.public_agent_mount_var_lib_mesos_slave.id}",
    ]
}

# Dump the contents of the ignition file out for debugging
resource "local_file" "public_agent_ignition" {
    count    = "${var.agent_public_count}"
    content  = "${data.ignition_config.public_agent.*.rendered[ count.index ]}"
    filename = "${path.cwd}/outputs/public_agent_ignition-${count.index}.ign"
}

