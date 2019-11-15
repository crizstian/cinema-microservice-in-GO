#!/bin/bash

. /etc/environment

echo "RENEW TOKEN WATCH HANDLER"

status=`consul kv get cluster/nodes/node-1/token-status`
vault_token=`consul kv get cluster/vault/rootToken | sed s/\"//g`

if [ "$status" != "200" ]; then
 VAULT_TOKEN=$vault_token bash /vagrant/provision/vault/secrets/consul-get-token.sh $1
else
  echo "agent token healthy"
fi
