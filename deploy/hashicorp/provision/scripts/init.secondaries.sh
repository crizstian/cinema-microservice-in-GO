#!/bin/bash
source /etc/environment

CONSUL_HTTP_TOKEN=`curl -s -k https://172.20.20.11:8500/v1/kv/cluster/consul/rootToken | jq  -r '.[].Value'| base64 -d -`
sed -i '/CONSUL_HTTP_TOKEN/d' /etc/environment
echo -e "\nexport CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN\n" >> /etc/environment

bash /vagrant/provision/scripts/common-services.sh