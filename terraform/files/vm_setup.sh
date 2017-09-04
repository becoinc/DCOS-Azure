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
  google/cadvisor:v0.27.0 --global_housekeeping_interval=1m0s --housekeeping_interval=5s
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
