#!/bin/bash
set -e

# exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# . /etc/environment

vault_url="http://172.20.20.11:8200/v1/sys"

rootToken=""

function vaultConfig {
  isInitialized=`curl -s $vault_url/init | jq .initialized`

  if [ "$isInitialized" == "false" ];  then

    initVaultResponse=`curl -s -X PUT -H "Content-Type: application/json" -d '{"secret_shares":5,"secret_threshold":5}' $vault_url/init`
    error=`echo $initVaultResponse | jq .errors`

    if [ -z "$error" ];  then
      exit -1
    fi

    keys=`echo $initVaultResponse | jq .keys`
    rootToken=`echo $initVaultResponse | jq .root_token`

    echo $keys > file.json

    vaultConsulKV "file" "cluster/vault/unsealKeys"
    vaultConsulKV $rootToken "cluster/vault/rootToken"

    rm file.json

    unsealVault "${keys[@]}"

  else
    echo "Already initialized"
    keysFromConsul=`curl -s -X GET http://172.20.20.11:8500/v1/kv/cluster/vault/unsealKeys | jq -r '.[].Value' | base64 -d -`
    unsealVault "${keysFromConsul[@]}"
  fi
}

function isSealed {
    vault_url="http://$1:8200/v1/sys"
    response=`curl -s $vault_url/seal-status | jq .sealed`
    if [ "$response" == "true" ]; then
      return 1
    else
      return 0
    fi
}

function unsealVault {
  keys=$1
  keysCount=`echo $keys | jq '. | length'`

  if [ $keysCount > 0 ]; then
    servers=`curl -s http://$(hostname):8500/v1/catalog/service/vault`
    serversCount=`echo $servers | jq '. | length'`
    
    for i in $(seq 1 $serversCount); do

      server=`echo $servers | jq .[$((i-1))].Address | sed  's/"//g'`

      while true; do
        vault_url="http://$server:8200/v1/sys"
        r=`curl -s $vault_url/seal-status | jq .sealed`
        if [ "$r" == "true" ];  then
          for j in in $(seq 1 $keysCount); do
            key=`echo $keys | jq .[$((j-1))]`
            
            command="curl -s -X PUT -H 'Content-Type: application/json' -d '{\"key\":$key}' http://${server}:8200/v1/sys/unseal"
            request=`eval $command`
            ur=`echo $request | jq .sealed`
            if [ "$ur" == "true" ];  then
              echo "Vault steal unsealed numer of key applied $j"
            elif [ "$ur" == "false" ]; then
              echo "Vault server: $server has been unsealed"
              break
            else 
              echo "Vault unseal failed for server $server with response $(echo $result | jq .response)"
              break
            fi
          done
        else 
          echo "Vault successfully unsealed"
          break
        fi
      done
    done
  fi
}

function unsealServer {
  server=$1
  key=$2
  command="curl -s -X PUT -H 'Content-Type: application/json' -d '{\"key\":$key}' http://${server}:8200/v1/sys/unseal"
  request=`eval $command`
  response=`echo $request | jq .sealed`
  if [ "$response" == "true" ]; then
    return 1
  elif [ "$response" == "false" ]; then
    return 0
  else 
    echo "Vault unseal failed with response $(echo $result | jq .response)"
    return -1
  fi
}

function vaultConsulKV {
  data=$1
  path=$2
  url="http://172.20.20.11:8500/v1/kv/$path"
  if [ "$data" == "file" ]; then
   curl -s --request PUT -H "Content-Type: application/json" --data @file.json $url
  else
   curl -s --request PUT -H "Content-Type: application/json" --data $data $url
  fi
}

function main {
  vaultStart=`curl -s -X GET http://172.20.20.11:8500/v1/kv/cluster/lock/vaultUnseal | jq  -r '.[].Value'| base64 -d -`

  if [ -z "$vaultStart" ];  then
    echo "STARTING TO UNSEAL VAULT"
    vaultConfig
    vaultConsulKV "true" "cluster/lock/vaultUnseal"
    VAULT_TOKEN=$rootToken vault secrets enable -path=secrets kv
  else
    echo "Vault Already initialized"
  fi
}

main

bash /vagrant/provision/vault/secrets.sh $rootToken