#
# This is a terraform script with some shared ignition configuration items.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

/**
 *
 * Configure Azure Disks to have consistent names by LUN
 *
 * See https://docs.microsoft.com/en-us/azure/virtual-machines/linux/troubleshoot-device-names-problems
 *
 */
data "ignition_file" "azure_disk_udev_rules" {
    filesystem = "root"
    path       = "/etc/udev/rules.d/66-azure-storage.rules"
    mode       = 0644
    content {
        content = "${file( "${path.module}/files/66-azure-storage.rules" )}"
    }
}

/**
 * This sets the DC/OS env. variable to ensure time is in sync.
 */
data "ignition_file" "env_profile" {
    filesystem = "root"
    path       = "/etc/profile.env"
    mode       = 420
    content {
        content = "export ENABLE_CHECK_TIME=true"
    }
}

/**
 * Sets the Linux Kernel TCP Keepalive settings.
 *
 * This is useful for working with the l4lb in DC/OS that has
 * various connection timeouts.
 */
data "ignition_file" "tcp_keepalive" {
    filesystem = "root"
    path       = "/etc/sysctl.d/tcp_keepalive.conf"
    mode       = 420
    content {
        content = "net.ipv4.tcp_keepalive_time=3600"
    }
}

/**
 * Used to disable automatic updates.
 */
data "ignition_systemd_unit" "mask_update_engine" {
    name = "update-engine.service"
    mask = true
}

/**
 * Used to disable the distributed locking service used to do
 * rolling reboots by taking a lock from etcd.
 */
data "ignition_systemd_unit" "mask_locksmithd" {
    name = "locksmithd.service"
    mask = true
}

# WARNING: Do not use LUN0. Linux treats it oddly
# w.r.t. how it sort-of overlaps with the ROOT device.

/**
 * Format /dev/disk/azure/scsi1/lun0 with XFS filesystem.
 *
 * We don't know here which of the LUNs is /dev/sdX
 *
 * Note that for ignition ONLY the number of disks matters.
 *
 * This is because the Azure Udev rules won't have yet named things
 * properly. -- The implication is that the order of sdc, sdd, sde
 * might change. This is an Azure issue.
 *
 * The systemd mount units mount things by the proper names.
 */
data "ignition_filesystem" "lun1" {
    mount {
        device = "/dev/disk/by-path/acpi-VMBUS:01-scsi-0:0:0:1"
        format = "xfs"
    }
}

/**
 * Format /dev/disk/azure/scsi1/lun1 with XFS filesystem.
 *
 * We don't know here which of the LUNs is /dev/sdX
 *
 * Note that for ignition ONLY the number of disks matters.
 *
 * This is because the Azure Udev rules won't have yet named things
 * properly. -- The implication is that the order of sdc, sdd, sde
 * might change. This is an Azure issue.
 *
 * The systemd mount units mount things by the proper names.
 */
data "ignition_filesystem" "lun2" {
    mount {
        device = "/dev/disk/by-path/acpi-VMBUS:01-scsi-0:0:0:2"
        format = "xfs"
    }
}

/**
 * Format /dev/disk/azure/scsi1/lun3 with XFS filesystem.
 *
 * We don't know here which of the LUNs is /dev/sdX
 *
 * Note that for ignition ONLY the number of disks matters.
 *
 * This is because the Azure Udev rules won't have yet named things
 * properly. -- The implication is that the order of sdc, sdd, sde
 * might change. This is an Azure issue.
 *
 * The systemd mount units mount things by the proper names.
 */
data "ignition_filesystem" "lun3" {
    mount {
        device = "/dev/disk/by-path/acpi-VMBUS:01-scsi-0:0:0:3"
        format = "xfs"
    }
}

/**
 * Format /dev/disk/azure/scsi1/lun4 with XFS filesystem.
 *
 * We don't know here which of the LUNs is /dev/sdX
 *
 * Note that for ignition ONLY the number of disks matters.
 *
 * This is because the Azure Udev rules won't have yet named things
 * properly. -- The implication is that the order of sdc, sdd, sde
 * might change. This is an Azure issue.
 *
 * The systemd mount units mount things by the proper names.
 */
data "ignition_filesystem" "lun4" {
    mount {
        device = "/dev/disk/by-path/acpi-VMBUS:01-scsi-0:0:0:4"
        format = "xfs"
    }
}

/**
 * Mount the lun1 data disk on /var/log
 */
data "ignition_systemd_unit" "mount_var_log" {
    name    = "var-log.mount"
    enabled = true
    content = <<EOF
[Unit]
Before=local-fs.target
[Mount]
What=/dev/disk/azure/scsi1/lun1
Where=/var/log
Type=xfs
[Install]
WantedBy=local-fs.target
EOF
}
