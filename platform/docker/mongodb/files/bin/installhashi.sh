#!/bin/sh

# Download consul-template
export CONSUL_VERSION=1.7.2
wget -q -O consul.zip "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip"
unzip consul.zip
chmod +x consul
mv consul /usr/bin/consul
rm consul.zip

# Download consul-template
export CONSUL_TEMPLATE_VERSION=0.22.0
curl -s https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip -o consul-template.zip

# Install consul-template
unzip consul-template.zip
chmod +x consul-template
mv consul-template /usr/bin/consul-template
rm consul-template.zip 

export ENVCONSUL_VERSION=0.9.0
curl -s https://releases.hashicorp.com/envconsul/${ENVCONSUL_VERSION}/envconsul_${ENVCONSUL_VERSION}_linux_amd64.zip -o envconsul.zip
unzip envconsul.zip
mv envconsul /usr/bin/envconsul
rm envconsul.zip