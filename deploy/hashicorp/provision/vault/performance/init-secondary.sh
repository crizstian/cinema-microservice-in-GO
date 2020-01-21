export SECONDARY_TOKEN=`curl -s http://172.20.20.31:8500/v1/kv/cluster/global/vault/secondary-token | jq  -r '.[].Value'| base64 -d - | sed s/\"//g`

curl -s \
    --cacert $VAULT_CACERT \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data '{ "token": "'"$SECONDARY_TOKEN"'", "ca_file": "'"$VAULT_CACERT"'" }' \
    https://172.20.20.31:8200/v1/sys/replication/performance/secondary/enable