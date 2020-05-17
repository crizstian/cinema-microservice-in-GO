#!/bin/bash
set -e

curl_ssl=
ctmpl_ssl=

env

echo $MONG_KEYFILE | sed  "s/\"//g" | base64 -d >> /data/keyfile/mongo-keyfile

chmod 600 /data/keyfile/mongo-keyfile

echo "Proceeding with startup..."
/tmp/startWithConfig.sh & 

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
echo "CONSUL_HTTP_SSL=${CONSUL_HTTP_SSL} /usr/bin/consul lock $ctmpl_ssl -http-addr=${CONSUL_IP}:${CONSUL_PORT} cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/initMongo /tmp/mongoStart.sh &"

CONSUL_HTTP_SSL=${CONSUL_HTTP_SSL} /usr/bin/consul lock $ctmpl_ssl -http-addr=${CONSUL_IP}:${CONSUL_PORT} cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/initMongo /tmp/mongoStart.sh &

wait