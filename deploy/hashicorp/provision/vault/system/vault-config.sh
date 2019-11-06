#!/bin/bash
set -e

# exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# . /etc/environment

vault_url="$VAULT_ADDR/v1/sys"
rootToken=""

function vaultConfig {
  echo "curl -s $vault_url/init"
  isInitialized=`curl -s $vault_url/init | jq .initialized`
  echo $isInitialized

  if [ "$isInitialized" == "false" ];  then

    echo "curl -s -X PUT -H Content-Type: application/json -d {secret_shares:5,secret_threshold:5} $vault_url/init"
    initVaultResponse=`curl -s -X PUT -H "Content-Type: application/json" -d '{"secret_shares":5,"secret_threshold":5}' $vault_url/init`
    echo $initVaultResponse
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
    keysFromConsul=`curl -s -X GET $CONSUL_URL/v1/kv/cluster/vault/unsealKeys | jq -r '.[].Value' | base64 -d -`
    unsealVault "${keysFromConsul[@]}"
  fi
}

function isSealed {
    echo "http://$1:8200/v1/sys"
    vault_url="http://$1:8200/v1/sys"
    response=`curl -s $vault_url/seal-status | jq .sealed`
    echo $response
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
    echo "curl -s $CONSUL_URL/v1/catalog/service/vault"
    servers=`curl -s $CONSUL_URL/v1/catalog/service/vault`
    serversCount=`echo $servers | jq '. | length'`
    echo $servers
    
    for i in $(seq 1 $serversCount); do

      server=`echo $servers | jq .[$((i-1))].Address | sed  's/"//g'`

      while true; do
        echo "http://$server:8200/v1/sys"
        vault_url="http://$server:8200/v1/sys"
        r=`curl -s $vault_url/seal-status | jq .sealed`
        echo $r
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
  url="$CONSUL_URL/v1/kv/$path"
  if [ "$data" == "file" ]; then
   curl -s --request PUT -H "Content-Type: application/json" --data @file.json $url
  else
   curl -s --request PUT -H "Content-Type: application/json" --data $data $url
  fi
}

function main {
  
  bash /vagrant/provision/consul/system/wait-consul-leader.sh "172.20.20.11"

  echo "curl -s -X GET $CONSUL_URL/v1/kv/cluster/vault/vaultUnseal"
  vaultStart=`curl -s -X GET $CONSUL_URL/v1/kv/cluster/vault/vaultUnseal | jq  -r '.[].Value'| base64 -d -`
  echo $vaultStart

  if [ -z "$vaultStart" ];  then
    echo "STARTING TO UNSEAL VAULT"
    vaultConfig
    vaultConsulKV "true" "cluster/vault/vaultUnseal"
  else
    echo "Vault Already unsealed"
  fi
}

main