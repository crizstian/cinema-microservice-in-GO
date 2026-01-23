#!bin/bash

. /etc/environment

if [ "$CONSUL_HTTP_SSL" == "true" ]; then
  curl_ssl="--cacert ${CONSUL_CACERT}"
fi

curl -s \
    --cacert $VAULT_CACERT \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data '{"primary_cluster_addr ": "$VAULT_ADDR"}' \
    ${VAULT_ADDR}/v1/sys/replication/performance/primary/enable

sleep 2

SECONDARY_TOKEN=`curl -s --cacert $VAULT_CACERT --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data '{ "id": "nyc-2" }' ${VAULT_ADDR}/v1/sys/replication/performance/primary/secondary-token | jq ".wrap_info.token"`

echo "SECONDARY_TOKEN = $SECONDARY_TOKEN"

CONSUL_HTTP_TOKEN=${CONSUL_HTTP_TOKEN} consul kv put cluster/global/vault/secondary-token "${SECONDARY_TOKEN}"