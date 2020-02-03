#!/bin/bash
. /etc/environment

# Make sure to use all our CPUs, because Consul can block a scheduler thread
export GOMAXPROCS=$(nproc)

if [ "$DATACENTER" == "dc2" ]; then
  exec consul-replicate -consul-addr=$HOST_IP:$CONSUL_PORT -prefix "cluster/apps@dc1" -prefix "cluster/nodes@dc1" -prefix "cluster/global@dc1" -prefix "terraform@dc1" -log-level debug >>/var/log/consul-replicate.log 2>&1
fi
