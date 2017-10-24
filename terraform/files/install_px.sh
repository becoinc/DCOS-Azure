#!/usr/bin/env bash

HDRS="/lib/modules"
docker run --restart=always --name px -d --net=host \
    --privileged=true                               \
    -v /run/docker/plugins:/run/docker/plugins      \
    -v /var/lib/osd:/var/lib/osd:shared             \
    -v /dev:/dev                                    \
    -v /etc/pwx:/etc/pwx                            \
    -v /opt/pwx/bin:/export_bin                     \
    -v /var/run/docker.sock:/var/run/docker.sock    \
    -v /var/cores:/var/cores                        \
    -v ${HDRS}:${HDRS}                              \
    jvinod/px:journal_dev

