#!/bin/bash

set -e

echo "is CONSUL_HTTP_SSL = $CONSUL_HTTP_SSL"

if [ "$CONSUL_HTTP_SSL" == "true" ]; then
	echo "SSL IS ENABLED"
  curl_ssl="--cacert ${CA_CERT_FILE}"
fi

if [ "$DISABLE_CURL_SSL" == "true" ]; then
	echo "SSL IS BYPASS ON CURL ENABLED"
  curl_ssl="-k"
fi

if [ -n $CONSUL_HTTP_TOKEN ]; then
	echo "Setting consul token"
	header="--header \"X-Consul-Token: $CONSUL_HTTP_TOKEN\""
fi

if [ -n "$ACTIVE_ACTIVE" ] &&  [ `echo  $ACTIVE_ACTIVE |  tr [:upper:] [:lower:]` = "true" ]; then
    echo "ACTIVE_ACTIVE flag is set, NOT waiting for cluster active status"
else
  export CONSUL_HTTP_ADDR="${CONSUL_SCHEME}://${CONSUL_IP}:${CONSUL_PORT}"
  echo $CONSUL_HTTP_ADDR

  t="curl $header $curl_ssl -X GET $CONSUL_HTTP_ADDR/v1/kv/cluster/info/status"
  echo $t
  eval $t | jq .

  echo "Checking cluster state - active or standby"
  until eval $t | jq -r '.[].Value' | base64 -d - | grep -q active; do
      printf '.'
      sleep 5
  done
  echo "Cluster is in active state"
fi
echo "Proceeding with startup..."

exec $@