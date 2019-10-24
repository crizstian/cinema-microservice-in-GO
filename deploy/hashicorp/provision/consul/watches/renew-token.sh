#!/bin/bash

export VAULT_ADDR=http://172.20.20.11:8200

export VAULT_TOKEN=s.OAEONgS7PhBJN7xPwI5Wj3iU

echo "RENEW TOKEN WATCH HANDLER"

status=`consul kv get cluster/nodes/node-1/token-status`

if [ "$status" == "403" ]; then
  bash /vagrant/provision/vault/secrets/consul-get-token.sh $VAULT_TOKEN $1
else
  echo "agent token healthy"
fi
