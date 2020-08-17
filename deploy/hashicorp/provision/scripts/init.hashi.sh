#!/bin/bash

sudo mkdir -p /var/consul/config
sudo mkdir -p /var/nomad/config
sudo mkdir -p /var/vault/config
sudo mkdir -p /var/vault/config/agent

# Setup Consul Files
sudo cp /vagrant/provision/consul/config/* /var/consul/config/
sudo cp /vagrant/provision/consul/watches/* /var/consul/config/
sudo cp /vagrant/provision/consul/check-definitions/* /var/consul/config/
sudo cp /vagrant/provision/consul/system/consul.service /etc/systemd/system/consul.service
sudo cp /vagrant/provision/consul/system/csreplicate.service /etc/systemd/system/csreplicate.service
sudo chmod -R +x /var/consul/config/
sudo chmod -R +x /vagrant/provision/consul/system/

# Setup Nomad Files
sudo cp /vagrant/provision/nomad/config/* /var/nomad/config/
sudo cp /vagrant/provision/nomad/system/nomad.service /etc/systemd/system/nomad.service
sudo chmod -R +x /vagrant/provision/nomad/system/

# Setup Vault Files
sudo cp /vagrant/provision/vault/config/* /var/vault/config/
sudo cp /vagrant/provision/vault/agent/* /var/vault/config/agent/
sudo cp /vagrant/provision/vault/agent/vaultagent.service /etc/systemd/system/vaultagent.service
sudo cp /vagrant/provision/vault/system/vault.service /etc/systemd/system/vault.service
sudo cp /vagrant/provision/certs/*.pem /var/vault/config
sudo chmod -R +x /vagrant/provision/vault/system/

# Setup Other Files
sudo cp /vagrant/provision/docker/daemon.json.tmpl /etc/docker/daemon.json.tmpl
sudo cp /vagrant/provision/scripts/env.sh /etc/environment

sudo sed -i "s/@local_ip/$2/" /etc/environment
sudo sed -i "s/@primary_ip/$2/" /etc/environment
sudo sed -i "s/@dc/$1/" /etc/environment
sudo sed -i "s/@primary/sfo/" /etc/environment
sudo sed -i "s/@secondary/nyc/" /etc/environment
sudo sed -i "s/@list_ips/'[\"172.20.20.11\",\"172.20.20.21\"]'/" /etc/environment

sudo cat /etc/environment
source /etc/environment

# Setup Restart daemons
sudo systemctl daemon-reload
sudo service consul stop
sudo service vault stop
sudo service nomad stop
sudo service docker stop
sudo service csreplicate stop
sudo service vaultagent stop

if [ "$1" == "sfo" ]; then 
  echo "Restarting Consul"
  sudo service consul restart
  sudo service consul status
  
  echo "Waiting for Consul leader to bootstrap ACL System"
  sudo bash /vagrant/provision/consul/system/wait-consul-leader.sh

  echo "Bootstraping ACL System"
  sudo bash /vagrant/provision/consul/system/bootstrap.sh

  sudo bash /vagrant/provision/scripts/common-services.sh

  sudo bash /vagrant/provision/vault/performance/init-primary.sh

  source /etc/environment
  echo '
  key "cluster/consul/rootToken" {
    policy = "read"
  }
  node_prefix "" {
    policy = "read"
  }
  service_prefix "" {
    policy = "read"
  }
  session_prefix "" {
    policy = "read"
  }
  agent_prefix "" {
    policy = "read"
  }
  query_prefix "" {
    policy = "read"
  }
  operator = "read"' |  consul acl policy create -name anonymous -rules -

  consul acl token update -id anonymous -policy-name anonymous 1>/dev/null
fi

if [ "$1" != "sfo" ]; then
  sudo bash /vagrant/provision/scripts/init.secondaries.sh
  sudo bash /vagrant/provision/vault/performance/init-secondary.sh
fi