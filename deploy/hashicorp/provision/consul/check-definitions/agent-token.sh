#!/bin/bash

. /etc/environment

id=`consul kv get cluster/nodes/node-1/id`
type=`consul kv get cluster/nodes/node-1/token-type`

response=`curl --cacert /var/vault/config/ca.crt.pem -o /dev/null -s -w "%{http_code}\n" $CONSUL_HTTP_ADDR/v1/acl/token/$id`

echo "Response Token Status: $response"

if [ "$response" == "200" ]; then
  echo "Agent token $type is healthy"
elif [ "$response" == "403" ]; then
  echo "Agent Token $type has expired or not set"
  consul kv put cluster/nodes/node-1/token-status $response
  exit 1
else
  response=`curl -s $CONSUL_HTTP_ADDR/v1/acl/token/$id`
  echo "Something wrong happened"
  echo $response
  exit 1
fi