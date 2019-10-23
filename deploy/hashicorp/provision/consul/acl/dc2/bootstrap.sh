#!/bin/bash

echo "curl -s --request PUT http://172.20.20.31:8500/v1/acl/bootstrap"
response=`curl -s --request PUT http://172.20.20.31:8500/v1/acl/bootstrap`
echo $response

rootToken=`echo $response | jq .SecretID | sed s/\"//g`

echo "CONSUL_HTTP_TOKEN=$rootToken consul acl set-agent-token default $rootToken"
CONSUL_HTTP_TOKEN=$rootToken consul acl set-agent-token default $rootToken

echo "consul kv put cluster/consul/rootToken $rootToken"
consul kv put cluster/consul/rootToken $rootToken


