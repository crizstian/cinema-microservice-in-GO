#!/bin/bash
. /etc/environment

# Make sure to use all our CPUs, because Consul can block a scheduler thread
export GOMAXPROCS=$(nproc)

# consul-template -template "/var/consul/config/consul-config.hcl.template:/var/consul/config/consul-config.hcl" -once

if [ "$DATACENTER" == "dc2" ]; then
  exec consul-replicate -consul-addr=$HOST_IP:$CONSUL_PORT -prefix "cluster/apps@dc1" -prefix "cluster/global@dc1" -prefix "terraform@dc1" -log-level debug >>/var/log/consul-replicate.log 2>&1
fi

# if [ "$DATACENTER" == "dc1" ]; then
  # exec consul-replicate -consul-addr=$CONSUL_DC1 -prefix "cluster/apps@dc2" -prefix "cluster/global@dc2" -prefix "terraform@dc2" -log-level debug >>/var/log/consul-replicate.log 2>&1
# fi
