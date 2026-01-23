#!/bin/bash

source /etc/environment
env |grep VAULT

while true; do
  echo "curl -s --connect-timeout 5 --max-time 10 --retry 5 --retry-delay 0 --retry-max-time 40 --cacert ${VAULT_CACERT} ${VAULT_ADDR}/v1/sys/leader | jq .leader_address | sed 's/\"//g'"
  LEADER_IP=$(curl -s --connect-timeout 5 --max-time 10 --retry 5 --retry-delay 0 --retry-max-time 40 --cacert ${VAULT_CACERT} ${VAULT_ADDR}/v1/sys/leader | jq .leader_address | sed 's/"//g')
  if [ "$LEADER_IP" != "" ]; then
    echo "Vault leader already selected [$LEADER_IP]."
    break
  fi
  echo "Waiting for vault cluster leader..."
  sleep 10
done
