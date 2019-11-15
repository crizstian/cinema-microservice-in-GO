#!/bin/bash
. /etc/environment

# Make sure to use all our CPUs, because Consul can block a scheduler thread
export GOMAXPROCS=$(nproc)

# consul-template -template "/var/consul/config/consul-config.hcl.template:/var/consul/config/consul-config.hcl" -once

exec consul agent -config-dir=/var/consul/config/ >>/var/log/consul.log 2>&1
