#!/bin/bash

while true; do
  LEADER_IP=$(curl -s "http://$1:8500/v1/status/leader" | sed 's/"//g')
  if [ "$LEADER_IP" != "" ]; then
    echo "Consul leader already selected [$LEADER_IP]."
    break
  fi
  echo "Waiting for cluster leader..."
  sleep 10
done
