#!bin/bash

id=`consul kv get cluster/nodes/node-1/id`
type=`consul kv get cluster/nodes/node-1/token-type`

response=`curl -o /dev/null -s -w "%{http_code}\n" http://172.20.20.11:8500/v1/acl/token/$id`

consul kv put cluster/nodes/node-1/token-status $response

if [ "$response" == "200" ]; then
  echo "Agent token $type is healthy"
elif [ "$response" == "403" ]; then
  echo "Agent Token $type has expired or not set"
  exit 1
else
  response=`curl -s http://172.20.20.11:8500/v1/acl/token/$id`
  echo "Something wrong happened"
  echo $response
  exit 1
fi