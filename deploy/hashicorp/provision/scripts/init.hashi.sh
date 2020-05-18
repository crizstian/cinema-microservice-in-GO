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
sudo sed -i "s/@list_ips/'[\"172.20.20.11\",\"172.20.20.31\"]'/" /etc/environment

sudo cat /etc/environment
sudo source /etc/environment

# Setup Restart daemons
sudo systemctl daemon-reload
echo "Restarting Consul"
sudo service consul restart
sudo service consul status

if [ "$1" == "sfo" ]; then 
  echo "Waiting for Consul leader to bootstrap ACL System"
  sudo bash /vagrant/provision/consul/system/wait-consul-leader.sh

  echo "Bootstraping ACL System"
  sudo bash /vagrant/provision/consul/system/bootstrap.sh
fi

echo "Restarting Nomad and Vault"
sudo service vault restart
sudo service vault status
sudo service nomad restart
sudo service nomad status

if [ "$1" == "sfo" ]; then 
  echo "Waiting for Consul leader to unseal Vault"
  sudo bash /vagrant/provision/consul/system/wait-consul-leader.sh
  echo "Waiting for Vault leader to unseal the cluster"
  sudo bash /vagrant/provision/vault/system/wait-vault-leader.sh

  echo "Unsealing Vault ..."
  sudo bash /vagrant/provision/vault/system/unseal.sh
fi

sudo consul-template -template "/etc/docker/daemon.json.tmpl:/etc/docker/daemon.json" -once
sudo service docker restart

if [ "$1" == "nyc" ]; then 
  sudo service csreplicate restart
  sudo service vaultagent stop
fi