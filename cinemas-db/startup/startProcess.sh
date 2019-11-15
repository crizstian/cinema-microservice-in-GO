#!/bin/bash
set -e

echo "Proceeding with startup..."
/var/tmp/start/startWithConfig.sh & 

curl -s --cacert /tmp/ca.crt.pem \
    --request PUT \
    --data "started" \
  https://${CONSUL_IP}:8501/v1/kv/cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/${NOMAD_TASK_NAME}

echo "Proceeding with replica set config..."
CONSUL_HTTP_SSL=true /usr/local/bin/consul lock -ca-file=/tmp/ca.crt.pem -http-addr=${CONSUL_IP}:8501 cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/initMongo /var/tmp/start/mongoStart.sh &

wait