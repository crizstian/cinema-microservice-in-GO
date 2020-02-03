#!/bin/bash

. /etc/environment

echo "RENEW TOKEN WATCH HANDLER"

status=`consul kv get cluster/nodes/node-1/token-status`
ct=`consul kv get cluster/consul/rootToken`

if [ "$status" != "200" ]; then

export VAULT_AGENT_ADDR="https://172.20.20.11:8007"

TOKEN=`VAULT_TOKEN=$(cat /var/vault/config/agent/approleToken) vault token create -ttl=2m -explicit-max-ttl=2m -format=json | jq ".auth.client_token" | sed s/\"//g`

cd /vagrant/provision/vault/policies

terraform init

VAULT_TOKEN=$TOKEN TF_VAR_consul_token=$ct terraform apply -auto-approve

echo "terraform code ran; new consul token implemented"

else
  echo "token agent healthy"
fi
