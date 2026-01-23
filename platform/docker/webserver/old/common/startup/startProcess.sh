#!/bin/sh
set -e

. /var/tmp/startup/utils.sh

# The purpose of this script is to do the config file preparation
# for the end user by utilizing the environment variables that are set by envconsul
# using consul-template. At the same time we also pass the consul address to the
# consul-template so that the end user can still use any direct variable replacement from consul
#
# Also note that we are not recommending consul-template to directly map the consul values and instead
# use the environment variables from envconsul. The reason being, envconsul allows to have two different
# paths with the same parameters and this helps to use a global path as well as pod specific path.

if [ -n "$ACTIVE_ACTIVE" ] &&  [ `echo  $ACTIVE_ACTIVE |  tr [:upper:] [:lower:]` = "true" ]; then
    echo "ACTIVE_ACTIVE flag is set, NOT waiting for cluster active status"
else
    echo Checking cluster state - active or standby
    until curl -s http://${NOMAD_IP_aero}:8500/v1/kv/cluster/info/status | jq -r '.[].Value' | base64 -d - | grep -q active; do
        printf '.'
        sleep 5
    done
    echo "Cluster is in active state"
fi
echo "Proceeding with startup..."

exec $@
