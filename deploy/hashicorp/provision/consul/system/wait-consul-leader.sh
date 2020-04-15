#!/bin/bash

source /etc/environment
env |grep CONS

if [ "$CONSUL_HTTP_SSL" == "true" ]; then
  curl_ssl="--cacert ${CONSUL_CACERT}"
fi

while true; do
  echo "curl -s $curl_ssl ${CONSUL_HTTP_ADDR}/v1/status/leader | sed 's/\"//g'"
  LEADER_IP=$(curl -s $curl_ssl ${CONSUL_HTTP_ADDR}/v1/status/leader | sed 's/"//g')
  if [ "$LEADER_IP" != "" ]; then
    echo "Consul leader already selected [$LEADER_IP]."
    break
  fi
  echo "Waiting for cluster leader..."
  sleep 10
done
