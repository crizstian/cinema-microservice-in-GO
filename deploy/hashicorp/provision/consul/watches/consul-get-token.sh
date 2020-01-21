#!/bin/bash
. /etc/environment

echo "Get Consul Role Token from Vault"

response=`vault read -format=json consul/creds/$1`
id=`echo $response | jq .data.accessor | sed s/\"//g`
token=`echo $response | jq .data.token | sed s/\"//g`

consul kv put cluster/nodes/node-1/id $id
consul kv put cluster/nodes/node-1/token $token
consul kv put cluster/nodes/node-1/token-type $1
consul kv put cluster/nodes/node-1/token-status 200

CONSUL_HTTP_TOKEN=$token consul acl set-agent-token default $token

id=`consul kv get cluster/nodes/node-1/id`
token=`consul kv get cluster/nodes/node-1/token`
type=`consul kv get cluster/nodes/node-1/token-type`
status=`consul kv get cluster/nodes/node-1/token-status`

echo "ID: $id"
echo "Token: $token"
echo "Token-Type: $type"
echo "Token-Status: $status"
