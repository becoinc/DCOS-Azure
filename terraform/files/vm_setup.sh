#!/bin/bash

#
# This is a script to perform some early configuration on the machines.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
# Created 2-Aug-2017 by Jeffrey Zampieron <jeff@beco.io>
# License: See included LICENSE.md
#
# This script should be run as root.

WAACONF=/usr/share/oem/waagent.conf

#############################################################################
# Enable Swap.
# See https://support.microsoft.com/en-us/help/4010058/how-to-add-a-swap-file-in-linux-azure-virtual-machines
RESOURCE_DISK_SIZE=`df -m |grep resource|tr -s ' ' |cut -f 4 -d ' '`
SWAP_SIZE=$(expr ${RESOURCE_DISK_SIZE} / 2)
echo "Updating ${WAACONF} file."
sed -i -e 's/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/' ${WAACONF}
sed -i -e "s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=${SWAP_SIZE}/" ${WAACONF}
systemctl restart waagent

#############################################################################
# Configure Azure Disks to have consistent names by LUN
#
# See https://docs.microsoft.com/en-us/azure/virtual-machines/linux/troubleshoot-device-names-problems
#############################################################################
# Put the 66-azure-storage.rules file is in place already...
cat <<EOF > /etc/udev/rules.d/66-azure-storage.rules
ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_VENDOR}=="Msft", ENV{ID_MODEL}=="Virtual_Disk", GOTO="azure_disk"
GOTO="azure_end"

LABEL="azure_disk"
# Root has a GUID of 0000 as the second value
# The resource/resource has GUID of 0001 as the second value
ATTRS{device_id}=="?00000000-0000-*", ENV{fabric_name}="root", GOTO="azure_names"
ATTRS{device_id}=="?00000000-0001-*", ENV{fabric_name}="resource", GOTO="azure_names"
# Wellknown SCSI controllers
ATTRS{device_id}=="{f8b3781a-1e82-4818-a1c3-63d806ec15bb}", ENV{fabric_scsi_controller}="scsi0", GOTO="azure_datadisk"
ATTRS{device_id}=="{f8b3781b-1e82-4818-a1c3-63d806ec15bb}", ENV{fabric_scsi_controller}="scsi1", GOTO="azure_datadisk"
ATTRS{device_id}=="{f8b3781c-1e82-4818-a1c3-63d806ec15bb}", ENV{fabric_scsi_controller}="scsi2", GOTO="azure_datadisk"
ATTRS{device_id}=="{f8b3781d-1e82-4818-a1c3-63d806ec15bb}", ENV{fabric_scsi_controller}="scsi3", GOTO="azure_datadisk"
GOTO="azure_end"

# Retrieve LUN number for datadisks
LABEL="azure_datadisk"
ENV{DEVTYPE}=="partition", PROGRAM="/bin/sh -c 'readlink /sys/class/block/%k/../device|cut -d: -f4'", ENV{fabric_name}="$env{fabric_scsi_controller}/lun$result", GOTO="azure_names"
PROGRAM="/bin/sh -c 'readlink /sys/class/block/%k/device|cut -d: -f4'", ENV{fabric_name}="$env{fabric_scsi_controller}/lun$result", GOTO="azure_names"
GOTO="azure_end"

# Create the symlinks
LABEL="azure_names"
ENV{DEVTYPE}=="disk", SYMLINK+="disk/azure/$env{fabric_name}"
ENV{DEVTYPE}=="partition", SYMLINK+="disk/azure/$env{fabric_name}-part%n"

LABEL="azure_end"
EOF
udevadm trigger --subsystem-match=block

#############################################################################
# Docker config
#
#############################################################################

# On CoreOS, the docker daemon is socket started by default.
# this means on reboot any --restart=always containers don't
# start. The below fixes this.
systemctl enable docker

#############################################################################
# Install and setup cAdvisor
# See https://docs.docker.com/engine/admin/resource_constraints/#configure-the-default-cfs-scheduler
# for details on setting the cpu and memory limits in Docker.

# Port 63000 is selected b/c it's not used by Mesos or Marathon in DC/OS v1.9.2
# See: https://docs.mesosphere.com/1.9/installing/ports/
docker run \
  --restart=always \
  --memory=128m \
  --cpu-quota=40000 \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:rw \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --volume=/usr/bin/journalctl:/usr/bin/journalctl:ro \
  --publish=63000:8080 \
  --detach=true \
  --name=cadvisor \
  google/cadvisor:v0.28.3 --global_housekeeping_interval=1m0s --housekeeping_interval=5s
if [ $? != 0 ]; then
  echo "Failed to start cAdvisor v0.27.0."
  exit 1
fi
echo "Started cAdvisor."

#############################################################################
# Install and setup node exporter
#
# Port 63001 is selected b/c it's not used by Mesos or Marathon in DC/OS v1.9.2
# See: https://docs.mesosphere.com/1.9/installing/ports/
docker run \
  --restart=always \
  --memory=128m \
  --cpu-quota=20000 \
  --volume=/:/rootfs:ro \
  --volume=/sys:/sys:ro \
  --publish=63001:9100 \
  --detach=true \
  --name=node-exporter \
  prom/node-exporter:v0.14.0

if [ $? != 0 ]; then
  echo "Failed to start node exporter v0.14.0."
  exit 1
fi
echo "Started Node Exporter."
