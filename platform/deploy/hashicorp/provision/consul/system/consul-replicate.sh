#!/bin/bash
. /etc/environment

# Make sure to use all our CPUs, because Consul can block a scheduler thread
export GOMAXPROCS=$(nproc)

if [ "$DATACENTER" == "nyc" ]; then
  exec consul-replicate -consul-addr=$HOST_IP:$CONSUL_PORT -prefix "cluster/apps@sfo" -prefix "cluster/nodes@sfo" -prefix "cluster/global@sfo" -prefix "terraform@sfo" -log-level debug >>/var/log/consul-replicate.log 2>&1
fi
