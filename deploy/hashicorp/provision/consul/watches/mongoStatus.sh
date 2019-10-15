#!/usr/bin/env bash
len=`curl -s http://172.20.20.11:8500/v1/kv/$1?keys | jq  '. | length'`

echo "SERVICES AVAILABLE FOR $1: $len"

if [[ "$len" == "" ]]; then
  echo "nothing to delete"
elif [[ "$len" == "1" ]]; then
  consul kv delete $1$2
fi