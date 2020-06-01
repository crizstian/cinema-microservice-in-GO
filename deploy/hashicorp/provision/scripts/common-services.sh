#!/bin/bash

source /etc/environment

echo "Setting Consul Token to the system"
sudo service consul restart
sudo service consul status

echo "Restarting Nomad and Vault"
sudo service vault restart
sudo service vault status

sudo service nomad restart
sudo service nomad status

echo "Waiting for Consul leader to unseal Vault"
sudo bash /vagrant/provision/consul/system/wait-consul-leader.sh

echo "Unsealing Vault ..."
sudo bash /vagrant/provision/vault/system/unseal.sh

source /etc/environment
env | grep CONS

consul-template -template "/etc/docker/daemon.json.tmpl:/etc/docker/daemon.json" -once
sudo service docker restart
sudo service csreplicate restart