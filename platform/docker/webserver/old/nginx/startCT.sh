#!/bin/sh
# This script is added just to reduce the complexity of the docker file

#exec consul-template -consul-addr consul.service:8500 -exec-reload-signal=SIGHUP -template "/var/tmp/default.ctmpl:/usr/local/nginx/conf/nginx.conf" -exec /var/tmp/startNginx.sh

exec consul-template -consul-addr ${NOMAD_IP_aero}:8500 -config "/var/tmp/ct-config.hcl" -config "/var/tmp/ct-templates.hcl" -config "/var/tmp/ct-custom.hcl"
