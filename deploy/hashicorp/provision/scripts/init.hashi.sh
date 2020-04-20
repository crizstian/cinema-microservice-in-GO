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
sudo cp /vagrant/provision/certs/* /var/vault/config
sudo chmod -R +x /vagrant/provision/vault/system/

# Setup Other Files
sudo cp /vagrant/provision/docker/daemon.json.tmpl /etc/docker/daemon.json.tmpl
sudo cp /vagrant/provision/scripts/env.$1.sh /etc/environment

# Setup Restart daemons
sudo systemctl daemon-reload
echo "Restarting Consul"
sudo service consul restart
sudo service consul status
sudo cat /var/log/consul.log

echo "Waiting for Consul leader to bootstrap ACL System"
sudo bash /vagrant/provision/consul/system/wait-consul-leader.sh

echo "Bootstraping ACL System"
sudo bash /vagrant/provision/consul/system/bootstrap.sh

echo "Restarting Nomad and Vault"
sudo service vault restart
sudo service nomad restart
sudo service vault status
sudo cat /var/log/vault.log

echo "Waiting for Consul leader to unseal Vault"
sudo bash /vagrant/provision/consul/system/wait-consul-leader.sh
echo "Waiting for Vault leader to unseal the cluster"
sudo bash /vagrant/provision/vault/system/wait-vault-leader.sh

echo "Unsealing Vault ..."
sudo bash /vagrant/provision/vault/system/unseal.sh

sudo source /etc/environment
sudo consul-template -template "/etc/docker/daemon.json.tmpl:/etc/docker/daemon.json" -once

sudo service docker restart
sudo service csreplicate stop
sudo service vaultagent stop

# sudo echo 1 > /proc/sys/net/bridge/bridge-nf-call-arptables
# sudo echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
# sudo echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables