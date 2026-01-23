#!/bin/bash

. /etc/environment

if [ "$CONSUL_HTTP_SSL" == "true" ]; then
  curl_ssl="--cacert ${CONSUL_CACERT}"
  echo "SSL Enabled"
fi

echo "Bootstrap Consul ACL System"
echo "curl -s $curl_ssl --request PUT $CONSUL_HTTP_ADDR/v1/acl/bootstrap"
response=`curl -s $curl_ssl --request PUT $CONSUL_HTTP_ADDR/v1/acl/bootstrap`
echo $response

rootToken=`echo $response | jq .SecretID | sed s/\"//g`

# echo "Setting Consul Root Token"
# echo "CONSUL_HTTP_TOKEN=$rootToken consul acl set-agent-token default $rootToken"
# CONSUL_HTTP_TOKEN=$rootToken consul acl set-agent-token default $rootToken


echo "Storing Consul Root Token"
echo "consul kv put cluster/consul/rootToken $rootToken"
CONSUL_HTTP_TOKEN=$rootToken consul kv put cluster/consul/rootToken $rootToken

sed -i '/CONSUL_HTTP_TOKEN/d' /etc/environment
echo -e "\nexport CONSUL_HTTP_TOKEN=$rootToken\n" >> /etc/environment

