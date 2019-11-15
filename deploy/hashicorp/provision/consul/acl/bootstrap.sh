#!/bin/bash

. /etc/environment

echo "Bootstrap Consul ACL System"
echo "curl -s --cacert /var/vault/config/ca.crt.pem --request PUT $CONSUL_HTTP_ADDR/v1/acl/bootstrap"
response=`curl -s --cacert /var/vault/config/ca.crt.pem --request PUT $CONSUL_HTTP_ADDR/v1/acl/bootstrap`
echo $response

rootToken=`echo $response | jq .SecretID | sed s/\"//g`

echo "Setting Consul Root Token"
echo "CONSUL_HTTP_TOKEN=$rootToken consul acl set-agent-token default $rootToken"
CONSUL_HTTP_TOKEN=$rootToken consul acl set-agent-token default $rootToken


echo "Storing Consul Root Token"
echo "consul kv put cluster/consul/rootToken $rootToken"
consul kv put cluster/consul/rootToken $rootToken


