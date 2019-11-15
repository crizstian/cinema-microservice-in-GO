#!/bin/bash

while true; do
  LEADER_IP=$(curl -s "http://$CONSUL_HTTP_ADDR/v1/status/leader" | sed 's/"//g')
  if [ "$LEADER_IP" != "" ]; then
    echo "Consul leader already selected [$LEADER_IP]."
    break
  fi
  echo "Waiting for cluster leader..."
  sleep 10
done
