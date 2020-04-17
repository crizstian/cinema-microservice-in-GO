#!/bin/bash
. /etc/environment

consul-template -template "/var/consul/config/consul.hcl.tmpl:/var/consul/config/consul.hcl" -once

exec consul agent -config-dir=/var/consul/config/ >>/var/log/consul.log 2>&1