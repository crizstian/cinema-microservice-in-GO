#!/bin/bash
set -e

echo "Proceeding with startup..."
/var/tmp/start/startWithConfig.sh & 

curl \
    --request PUT \
    --data "started" \
  http://${CONSUL_IP}:8500/v1/kv/cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/${NOMAD_TASK_NAME}

echo "Proceeding with replica set config..."
/usr/local/bin/consul lock -http-addr=${CONSUL_IP}:8500 cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/initMongo /var/tmp/start/mongoStart.sh &

wait


