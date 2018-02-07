#
# This is a terraform script to setup Ignition on the DC/OS private agent nodes.
#
# Copyright (c) 2018 by Beco, Inc. All rights reserved.
#
# Created Feb-2018 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

data "ignition_file" "private_agent_lg_hosts" {
    count      = "${var.agent_private_large_count}"
    filesystem = "root"
    path       = "/etc/hosts"
    mode       = 420
    content {
        content = <<EOF
127.0.0.1   localhost
::1         localhost
${azurerm_network_interface.dcosLargePrivateAgentIF0.*.private_ip_address[ count.index ]}    dcoslargeprivateagent${count.index}
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
