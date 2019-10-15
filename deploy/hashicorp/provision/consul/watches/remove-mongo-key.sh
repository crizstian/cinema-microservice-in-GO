#!/usr/bin/env bash
# status=`curl -k -s -X GET http://172.20.20.11:8500/v1/kv/cluster/cinemas-db/mongo-cluster/initMongo | jq  -r '.[].Value'| base64 -d -`

# echo "MONGO [KEY/VALUE]  = ${status}"

# if [[ "$status" == "started" ]];  then
#   echo "REMOVING KEY $1"
#   consul kv delete $1$2
# fi

echo "SERVICES WATCH"