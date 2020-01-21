#!/bin/bash

. /etc/environment

echo "RENEW TOKEN WATCH HANDLER"

status=`consul kv get cluster/nodes/node-1/token-status`
vault_token=`consul kv get cluster/vault/rootToken | sed s/\"//g`

if [ "$status" != "200" ]; then

export VAULT_AGENT_ADDR="https://172.20.20.11:8007"

export TOKEN=`VAULT_TOKEN=$(cat /var/vault/config/approleToken) vault token create -ttl=2m -explicit-max-ttl=2m -format=json | jq ".auth.client_token" | sed s/\"//g`

 VAULT_TOKEN=$TOKEN bash /vagrant/provision/vault/secrets/consul-get-token.sh $1
else
  echo "agent token healthy"
fi
