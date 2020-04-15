#!/bin/bash
set -e

curl_ssl=
ctmpl_ssl=

echo "Proceeding with startup..."
/var/tmp/start/startWithConfig.sh & 

echo "is CONSUL_HTTP_SSL = $CONSUL_HTTP_SSL"

if [ "$CONSUL_HTTP_SSL" == "true" ]; then
  curl_ssl="--cacert ${CA_CERT_FILE}"
  ctmpl_ssl="-ca-file=${CA_CERT_FILE}"
fi

echo "Setting Server as started"
echo "curl -s $curl_ssl --request PUT --data started ${CONSUL_SCHEME}://${CONSUL_IP}:${CONSUL_PORT}/v1/kv/cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/${NOMAD_TASK_NAME}"

curl -s $curl_ssl \
    --request PUT \
    --data "started" \
  ${CONSUL_SCHEME}://${CONSUL_IP}:${CONSUL_PORT}/v1/kv/cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/${NOMAD_TASK_NAME}

echo "Proceeding with replica set config..."
echo "CONSUL_HTTP_SSL=${CONSUL_HTTP_SSL} /usr/local/bin/consul lock $ctmpl_ssl -http-addr=${CONSUL_IP}:${CONSUL_PORT} cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/initMongo /var/tmp/start/mongoStart.sh &"

CONSUL_HTTP_SSL=${CONSUL_HTTP_SSL} /usr/local/bin/consul lock $ctmpl_ssl -http-addr=${CONSUL_IP}:${CONSUL_PORT} cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/initMongo /var/tmp/start/mongoStart.sh &

wait