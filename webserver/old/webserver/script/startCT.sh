#!/bin/sh
# This script is added just to reduce the complexity of the docker file

exec consul-template -log-level err -consul-addr $NOMAD_IP_aero:8500 -exec-reload-signal=SIGHUP -template "/var/tmp/upstream.ctmpl:/etc/nginx/upstream.all.conf" -template "/var/tmp/domain.ctmpl:/etc/nginx/conf.d/domain.conf" -config "/var/tmp/ct-config.hcl"
