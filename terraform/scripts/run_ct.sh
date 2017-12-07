#!/usr/bin/env bash
#
# This script selects and runs 'ct', the Core OS
# configuration transpiler for our environment.
#
# Output is written to STDOUT for easy use with terraform external provisioners.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created 17-Nov-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md

VER='v0.5.0'
PLATFORM=azure
OS=`uname`
BASEDIR=`dirname $0`

if [ "Darwin" == "${OS}" ]; then
    echo "Discovered OS X"
    BIN="${BASEDIR}/../tools/ct-${VER}-x86_64-apple-darwin"
else
    echo "Discovered Linux"
    BIN="${BASEDIR}/../tools/ct-${VER}-x86_64-unknown-linux-gnu"
fi

if [ ! -x "${BIN}" ]; then
    echo "${BIN}: ct binary not executable"
    exit 1
fi

if [ $# != 1 ]; then
    echo "Usage: $0 container_linux_config.yaml"
    exit 1
fi

YAML=$1

if [ ! -r $YAML ]; then
    echo "YAML file not found: ${YAML}."
    exit 1
fi

${BIN} -in-file ${YAML} \
    -platform ${PLATFORM} \
    -pretty \
    -strict
