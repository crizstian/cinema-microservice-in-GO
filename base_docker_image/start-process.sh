#!/bin/sh
set -e

if [ -n "$ACTIVE_ACTIVE" ] &&  [ `echo  $ACTIVE_ACTIVE |  tr [:upper:] [:lower:]` = "true" ]; then
    echo "ACTIVE_ACTIVE flag is set, NOT waiting for cluster active status"
else
    echo "Checking cluster state - active or standby"
    until curl -s http://$CONSUL_IP:8500/v1/kv/cluster/info/status | jq -r '.[].Value' | base64 -d - | grep -q active; do
        printf '.'
        sleep 5
    done
    echo "Cluster is in active state"
fi
echo "Proceeding with startup..."

exec $@