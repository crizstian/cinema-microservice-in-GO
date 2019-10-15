#!bin/bash

status=`curl -k -s -X GET http://${CONSUL_IP}:8500/v1/kv/cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/initMongo | jq  -r '.[].Value'| base64 -d -`

echo "MONGO [KEY/VALUE]  = ${status}"

if [ -z "$status" ];  then
  echo "Init Mongo Replica"


  for server in "mongodb1" "mongodb2"
  do
    echo "Checking status of mongo cluster members"
    until curl -s http://${CONSUL_IP}:8500/v1/kv/cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/${server} | jq -r '.[].Value' | base64 -d - | grep -q started; do
        printf '.'
        sleep 5
    done
    echo "$server has started"
  done

  echo "Proceding with replica set configuration"

  export ip4_add=`hostname -i`

  consul-template -template "/data/admin/admin.js.ctmpl:/data/admin/admin.js" -once
  consul-template -template "/data/admin/grantRole.js.ctmpl:/data/admin/grantRole.js" -once
  consul-template -template "/data/admin/replica.js.ctmpl:/data/admin/replica.js" -once

  /var/tmp/start/initMongo.sh &

  curl \
      --request PUT \
      --data "started" \
    http://${CONSUL_IP}:8500/v1/kv/cluster/${NOMAD_JOB_NAME}/${NOMAD_GROUP_NAME}/initMongo 

  wait
else 
  echo "Mongo replica config already started by other host"
fi