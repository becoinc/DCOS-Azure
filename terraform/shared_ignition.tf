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