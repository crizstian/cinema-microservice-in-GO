#!bin/bash

. /etc/environment


if [ "$CONSUL_HTTP_SSL" == "true" ]; then
  curl_ssl="--cacert ${CONSUL_CACERT}"
fi

export SECONDARY_TOKEN=`curl -s ${CONSUL_HTTP_ADDR}/v1/kv/cluster/global/vault/secondary-token | jq  -r '.[].Value'| base64 -d - | sed s/\"//g`

curl -s \
    --cacert $VAULT_CACERT \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data '{ "token": "'"$SECONDARY_TOKEN"'", "ca_file": "'"$VAULT_CACERT"'" }' \
    ${VAULT_ADDR}}/v1/sys/replication/performance/secondary/enable