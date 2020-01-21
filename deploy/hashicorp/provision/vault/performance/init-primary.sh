#!bin/bash

. /etc/environment

curl -s \
    --cacert $VAULT_CACERT \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data '{}' \
    https://172.20.20.11:8200/v1/sys/replication/performance/primary/enable

sleep 2

SECONDARY_TOKEN=`curl --cacert $VAULT_CACERT --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data '{ "id": "dc2" }' https://172.20.20.11:8200/v1/sys/replication/performance/primary/secondary-token | jq ".wrap_info.token"`

curl -s \
    --request PUT \
    --data "$SECONDARY_TOKEN" \
    http://172.20.20.11:8500/v1/kv/cluster/global/vault/secondary-token