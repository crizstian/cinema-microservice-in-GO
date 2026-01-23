#!/bin/sh
set -e

. /var/tmp/versions.sh

# wget -q -O consul.zip "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip"
# unzip consul.zip
# mv consul /usr/local/bin/consul
# rm consul.zip

wget -q -O consul-template.zip "https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip"
unzip consul-template.zip
mv consul-template /usr/local/bin/consul-template
rm consul-template.zip

wget -q -O envconsul.zip "https://releases.hashicorp.com/envconsul/${ENVCONSUL_VERSION}/envconsul_${ENVCONSUL_VERSION}_linux_amd64.zip"
unzip envconsul.zip
mv envconsul /usr/local/bin/envconsul
rm envconsul.zip

chmod +x /usr/local/bin/*
