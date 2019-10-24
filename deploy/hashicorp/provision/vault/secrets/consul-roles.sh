#!/bin/bash

export VAULT_TOKEN=$1
export VAULT_ADDR=http://172.20.20.11:8200

echo "Writing Consul Roles into Vault"

# Consul roles
vault write consul/roles/operator policies=sensitve-policy,server-policy,agent-policy

vault write consul/roles/operator-prefix policies=sensitve-policy,server-policy,agent-prefix-policy

vault write consul/roles/server policies=server-policy,agent-policy lease=300s

vault write consul/roles/agent policies=agent-policy,blocking-policy

vault write consul/roles/anonymous policies=blocking-policy,anonymous-policy
