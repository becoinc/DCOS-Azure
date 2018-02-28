#!/usr/bin/env bash

BOOTSTRAP_URL=$1
ROLE=$2
ATTR=$3

mkdir /tmp/dcos
cd /tmp/dcos
curl -O http://${BOOTSTRAP_URL}/dcos_install.sh
sudo bash dcos_install.sh ${ROLE}
# These large nodes do not get setup for PX right now.
sudo sh -c "echo MESOS_ATTRIBUTES=${ATTR} >> /var/lib/dcos/mesos-slave-common"
sudo rm -f /var/lib/mesos/slave/meta/slaves/latest
sudo systemctl restart dcos-mesos-slave.service
