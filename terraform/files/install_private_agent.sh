#!/usr/bin/env bash

BOOTSTRAP_URL=$1
ROLE=$2

mkdir /tmp/dcos
cd /tmp/dcos
curl -O http://${BOOTSTRAP_URL}/dcos_install.sh
sudo bash dcos_install.sh ${ROLE}
sudo sh -c 'echo MESOS_ATTRIBUTES=agentpool:default,pxfabric:pxclust1 >> /var/lib/dcos/mesos-slave-common'
sudo rm -f /var/lib/mesos/slave/meta/slaves/latest
sudo systemctl restart dcos-mesos-slave.service
