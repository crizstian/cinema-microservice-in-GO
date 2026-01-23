#!/bin/sh
set -e

. /var/tmp/versions.sh

wget -q "https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VERSION}/containerpilot-${CONTAINERPILOT_VERSION}.tar.gz"
tar -zxvf containerpilot-${CONTAINERPILOT_VERSION}.tar.gz
mv containerpilot /usr/local/bin/containerpilot
rm containerpilot-${CONTAINERPILOT_VERSION}.tar.gz
