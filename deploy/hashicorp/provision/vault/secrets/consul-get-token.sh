export VAULT_ADDR=http://172.20.20.11:8200

echo "Get Consul Role Token from Vault"

response=`vault read -format=json consul/creds/$1`

id=`echo $response | jq .data.accessor | sed s/\"//g`
echo "ID: $id"

token=`echo $response | jq .data.token | sed s/\"//g`
echo "Token: $token"

echo "Token-Type": $1

consul kv put cluster/nodes/node-1/id $id
consul kv put cluster/nodes/node-1/token $token
consul kv put cluster/nodes/node-1/token-type $1
consul kv put cluster/nodes/node-1/token-status 200