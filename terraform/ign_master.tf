#
# This is a terraform script to setup Ignition for DC/OS master nodes.
#
# Copyright (c) 2018 by Beco, Inc. All rights reserved.
#
# Created Feb-2018 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

locals {
    master_my_ip = "${azurerm_network_interface.master.*.private_ip_address}"
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
${local.master_my_ip[ count.index ]}    dcosmaster${count.index}
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
    --listen-peer-urls="https://127.0.0.1:2380,https://${local.master_my_ip[ count.index ]}:2380" \
    --listen-client-urls="https://127.0.0.1:2379,https://${local.master_my_ip[ count.index ]}:2379,http://${local.master_my_ip[ count.index ]}:12379" \
    --initial-advertise-peer-urls="https://${local.master_my_ip[ count.index ]}:2380" \
    --initial-cluster="${local.cluster_name}-etcd-0=https://172.16.0.10:2380,${local.cluster_name}-etcd-1=https://172.16.0.11:2380,${local.cluster_name}-etcd-2=https://172.16.0.12:2380,${local.cluster_name}-etcd-3=https://172.16.0.13:2380,${local.cluster_name}-etcd-4=https://172.16.0.14:2380" \
    --initial-cluster-state="new" \
    --initial-cluster-token="${local.cluster_name}-etcd-token" \
    --advertise-client-urls="https://${local.master_my_ip[ count.index ]}:2379" \
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
What=/dev/disk/azure/scsi1/lun2
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
What=/dev/disk/azure/scsi1/lun3
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
        "${data.ignition_filesystem.lun1.id}",
        "${data.ignition_filesystem.lun2.id}",
        "${data.ignition_filesystem.lun3.id}",
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
