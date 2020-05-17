#!/bin/bash
set -e

echo "is CONSUL_HTTP_SSL = $CONSUL_HTTP_SSL"

if [ "$CONSUL_HTTP_SSL" == "true" ]; then
  curl_ssl="--cacert ${CA_CERT_FILE}"
fi

if [ -n "$ACTIVE_ACTIVE" ] &&  [ `echo  $ACTIVE_ACTIVE |  tr [:upper:] [:lower:]` = "true" ]; then
    echo "ACTIVE_ACTIVE flag is set, NOT waiting for cluster active status"
else
    echo "Checking cluster state - active or standby"
    until curl $curl_ssl -s -X GET ${CONSUL_SCHEME}://$CONSUL_IP:$CONSUL_PORT/v1/kv/cluster/info/status | jq -r '.[].Value' | base64 -d - | grep -q active; do
        printf '.'
        sleep 5
    done
    echo "Cluster is in active state"
fi
echo "Proceeding with startup..."

exec $@