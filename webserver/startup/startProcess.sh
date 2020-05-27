#!/bin/bash
set -e

echo "is CONSUL_HTTP_SSL = $CONSUL_HTTP_SSL"

if [ "$CONSUL_HTTP_SSL" == "true" ]; then
  curl_ssl="-consul-ssl -consul-ssl-ca-cert=${CA_CERT_FILE}"
fi

if [ -n $CONSUL_HTTP_TOKEN ] && [ $CONSUL_HTTP_TOKEN != "" ]; then
	echo "Setting consul token"
	header="--header \"X-Consul-Token: $CONSUL_HTTP_TOKEN\""
fi

if [ -n "$ACTIVE_ACTIVE" ] &&  [ `echo  $ACTIVE_ACTIVE |  tr [:upper:] [:lower:]` = "true" ]; then
    echo "ACTIVE_ACTIVE flag is set, NOT waiting for cluster active status"
else
    echo "Checking cluster state - active or standby"
    until curl $header $curl_ssl -s -X GET ${CONSUL_SCHEME}://${CONSUL_IP}:${CONSUL_PORT}/v1/kv/cluster/info/status | jq -r '.[].Value' | base64 -d - | grep -q active; do
        printf '.'
        sleep 5
    done
    echo "Cluster is in active state"
fi
echo "Proceeding with startup..."
 

exec consul-template -log-level err $curl_ssl -consul-addr ${CONSUL_IP}:${CONSUL_PORT} -exec-reload-signal=SIGHUP -template "/tmp/upstream.ctmpl:/etc/nginx/upstream.all.conf" -template "/tmp/domain.ctmpl:/etc/nginx/conf.d/domain.conf" -config "/tmp/ct-config.hcl"