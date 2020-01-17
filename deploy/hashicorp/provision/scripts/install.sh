#!/usr/bin/env bash
CONSUL_ENTERPRISE=$1
VAULT_ENTERPRISE=$2

echo "CONSUL_ENTERPRISE=$1"
echo "VAULT_ENTERPRISE=$2"

# Install Keys
curl -sL -s https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

curl -sL -sL 'https://getenvoy.io/gpg' | sudo apt-key add -
sudo add-apt-repository \
"deb [arch=amd64] https://dl.bintray.com/tetrate/getenvoy-deb \
$(lsb_release -cs) \
stable"

sudo apt-get update
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    getenvoy-envoy \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    unzip \
    jq

cat >> ~/.bashrc <<"END"
# Coloring of hostname in prompt to keep track of what's what in demos, blue provides a little emphasis but not too much like red
NORMAL="\[\e[0m\]"
BOLD="\[\e[1m\]"
DARKGRAY="\[\e[90m\]"
BLUE="\[\e[34m\]"
PS1="$DARKGRAY\u@$BOLD$BLUE\h$DARKGRAY:\w\$ $NORMAL"
END

if [ "$CONSUL_ENTERPRISE" != "true"]; then
# Download consul
export CONSUL_VERSION=1.6.1
curl -sL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip -o consul.zip

# Install consul
unzip consul.zip
sudo chmod +x consul
sudo mv consul /usr/bin/consul
else 
    cp /vagrant/bin/consul .
    sudo chmod +x consul
    sudo mv consul /usr/bin/consul
fi

# Download consul-template
export CONSUL_TEMPLATE_VERSION=0.22.0
curl -sL https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip -o consul-template.zip

# Install consul-template
unzip consul-template.zip
sudo chmod +x consul-template
sudo mv consul-template /usr/bin/consul-template

export ENVCONSUL_VERSION=0.9.0
curl -sL https://releases.hashicorp.com/envconsul/${ENVCONSUL_VERSION}/envconsul_${ENVCONSUL_VERSION}_linux_amd64.zip -o envconsul.zip
unzip envconsul.zip
sudo chmod +x consul-template
sudo mv envconsul /usr/bin/envconsul

# Download nomad
export NOMAD_VERSION=0.10.1
curl -sL https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip -o nomad.zip

# Install nomad
unzip nomad.zip
sudo chmod +x nomad
sudo mv nomad /usr/bin/nomad

# Install CNI Plugin for Nomad
curl -sL -L -o cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v0.8.1/cni-plugins-linux-amd64-v0.8.1.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

# Download vault
if [ "$VAULT_ENTERPRISE" != "true" ]; then
    export VAULT_VERSION=1.2.3
    curl -sL https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip -o vault.zip

    # Install vault
    unzip vault.zip
    sudo chmod +x vault
    sudo mv vault /usr/bin/vault
else 
    cp /vagrant/bin/vault .
    sudo chmod +x vault
    sudo mv vault /usr/bin/vault
fi