#!/bin/bash
. /etc/environment

consul-template -template "/etc/docker/daemon.json.tmpl:/etc/docker/daemon.json" -once

consul-template -template "/var/nomad/config/nomad.hcl.tmpl:/var/nomad/config/nomad.hcl" -once

exec nomad agent -config /var/nomad/config >>/var/log/nomad.log 2>&1
