#!bin/bash

. /etc/environment

if [ "$CONSUL_HTTP_SSL" == "true" ]; then
  curl_ssl="--cacert ${CONSUL_CACERT}"
fi

if [ -n $CONSUL_HTTP_TOKEN ]; then
	echo "Setting consul token"
	header="--header \"X-Consul-Token: ${CONSUL_HTTP_TOKEN}\""
fi

curl -s \
    --cacert $VAULT_CACERT \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data '{"primary_cluster_addr ": "$VAULT_ADDR"}' \
    ${VAULT_ADDR}/v1/sys/replication/performance/primary/enable

sleep 2

SECONDARY_TOKEN=`curl -s --cacert $VAULT_CACERT --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data '{ "id": "nyc" }' ${VAULT_ADDR}/v1/sys/replication/performance/primary/secondary-token | jq ".wrap_info.token"`

echo "SECONDARY_TOKEN = $SECONDARY_TOKEN"

echo "curl -s $header $curl_ssl --request PUT --data "$SECONDARY_TOKEN" ${CONSUL_HTTP_ADDR}/v1/kv/cluster/global/vault/secondary-token"

curl -s $header $curl_ssl \
    --request PUT \
    --data "${SECONDARY_TOKEN}" \
    ${CONSUL_HTTP_ADDR}/v1/kv/cluster/global/vault/secondary-token