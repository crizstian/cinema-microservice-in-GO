#!bin/bash

if [ "$CONSUL_HTTP_SSL" == "true" ]; then
  curl_ssl="--cacert ${CA_CERT_FILE}"
  ctmpl_ssl="-ca-file=${CA_CERT_FILE}"
fi

status=`curl $curl_ssl -s -X GET $CONSUL_SCHEME://${CONSUL_IP}:$CONSUL_PORT/v1/kv/cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/initMongo | jq  -r '.[].Value'| base64 -d -`

echo "MONGO [KEY/VALUE]  = ${status}"

if [ -z "$status" ];  then
  echo "Init Mongo Replica"


  for server in "mongodb1" "mongodb2" "mongodb3"
  do
    echo "Checking status of mongo cluster members"
    until curl -s $curl_ssl $CONSUL_SCHEME://${CONSUL_IP}:$CONSUL_PORT/v1/kv/cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/${server} | jq -r '.[].Value' | base64 -d - | grep -q started; do
        printf '.'
        sleep 5
    done
    echo "$server has started"
  done

  echo "Proceding with replica set configuration"

  export ip4_add=`hostname -i`

  /usr/bin/consul-template -template "/data/admin/admin.js.ctmpl:/data/admin/admin.js" -once
  /usr/bin/consul-template -template "/data/admin/grantRole.js.ctmpl:/data/admin/grantRole.js" -once
  /usr/bin/consul-template -template "/data/admin/replica.js.ctmpl:/data/admin/replica.js" -once

  /var/tmp/initMongo.sh &

  curl $curl_ssl -s \
      --request PUT \
      --data "started" \
    $CONSUL_SCHEME://${CONSUL_IP}:$CONSUL_PORT/v1/kv/cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/initMongo 

  wait
else 
  echo "Mongo replica config already started by other host"
fi