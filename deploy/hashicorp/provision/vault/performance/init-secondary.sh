#!bin/bash

. /etc/environment


if [ "$CONSUL_HTTP_SSL" == "true" ]; then
  curl_ssl="--cacert ${VAULT_CACERT}"
fi

if [ -n $CONSUL_HTTP_TOKEN ]; then
	echo "Setting consul token"
	header="--header \"X-Consul-Token: ${CONSUL_HTTP_TOKEN}\""
fi

second="curl -s $header $curl_ssl ${CONSUL_HTTP_ADDR}/v1/kv/cluster/global/vault/secondary-token"

echo $second

export SECONDARY_TOKEN=$(eval $second | jq  -r '.[].Value'| base64 -d - | sed s/\"//g)

echo $SECONDARY_TOKEN

REQUEST="curl -s --cacert $VAULT_CACERT --header 'X-Vault-Token: $VAULT_TOKEN' --request POST --data '{ \"token\": \"$SECONDARY_TOKEN\", \"ca_file\": \"$VAULT_CACERT\" }' ${VAULT_ADDR}/v1/sys/replication/performance/secondary/enable"

echo $REQUEST

curl $curl_ssl --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data "{ \"token\": \"$SECONDARY_TOKEN\", \"ca_file\": \"$VAULT_CACERT\" }" ${VAULT_ADDR}/v1/sys/replication/performance/secondary/enable