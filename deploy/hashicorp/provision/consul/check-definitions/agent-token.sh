#!/bin/bash

# . /etc/environment

# id=`consul kv get cluster/nodes/node-1/token-id`
# type=`consul kv get cluster/nodes/node-1/token-type`
# lease=`consul kv get cluster/nodes/node-1/token-lease-duration`

# response=`curl -o /dev/null -s -w "%{http_code}\n" $CONSUL_HTTP_ADDR/v1/acl/token/$id`

# t=$(curl -s $CONSUL_HTTP_ADDR/v1/acl/token/$id | jq ".CreateTime" | sed s/\"//g)

# d1=$(date --date=$t "+%s")

# d2=$(date --date="$t + $lease seconds" "+%s")

# curr=$(date -d "+ 500 seconds" "+%s")

# echo "curr=$curr"

# echo "d1=$d1"
# echo "d2=$d2"
# echo "lease=$lease"
# echo "response=$response"

# if [ $d2 > $curr ]; then
#   echo "Agent token $type is healthy"
# else
#   consul kv put cluster/nodes/node-1/token-status 400
#   echo "Agent token $type is close to expired renewal token process in progress"
#   exit 1
# fi

# if [ $response != 200 ]; then
#   consul kv put cluster/nodes/node-1/token-status 400
#   exit 1
# fi


# # if [ $p -gt 50 ]; then
# # elif [ $p -lt 50 ] && [ $diff -gt 20 ]; then 
# #   echo "Agent token $type is healthy but will expire soon"
# # elif [ $p -lt 10 ]; then
# #   echo "Agent token $type is close to expired renewal token process in progress"
# #   consul kv put cluster/nodes/node-1/token-status 400
# #   exit 1
# # fi

echo "Test of a health check in a script"