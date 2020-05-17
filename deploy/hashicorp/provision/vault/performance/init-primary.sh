#!bin/bash

. /etc/environment

if [ "$CONSUL_HTTP_SSL" == "true" ]; then
  curl_ssl="--cacert ${CONSUL_CACERT}"
fi

curl -s \
    --cacert $VAULT_CACERT \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data '{}' \
    ${VAULT_ADDR}/v1/sys/replication/performance/primary/enable

sleep 2

SECONDARY_TOKEN=`curl --cacert $VAULT_CACERT --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data '{ "id": "sfo" }' ${VAULT_ADDR}/v1/sys/replication/performance/primary/secondary-token | jq ".wrap_info.token"`

curl -s $curl_ssl \
    --request PUT \
    --data "$SECONDARY_TOKEN" \
    ${CONSUL_HTTP_ADDR}/v1/kv/cluster/global/vault/secondary-token