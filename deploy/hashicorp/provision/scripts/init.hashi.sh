sudo mkdir -p /var/consul/config
sudo mkdir -p /var/nomad/config
sudo mkdir -p /var/vault/config

# Setup Consul Files
sudo cp /vagrant/provision/consul/$1/* /var/consul/config/
# sudo cp /vagrant/provision/consul/watches/* /var/consul/config/
# sudo cp /vagrant/provision/consul/check-definitions/* /var/consul/config/
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
sudo cp /vagrant/provision/vault/system/vault.service /etc/systemd/system/vault.service
sudo cp /vagrant/provision/certs/* /var/vault/config
sudo chmod -R +x /vagrant/provision/vault/system/

# Setup Other Files
sudo cp /vagrant/provision/docker-config/$1/daemon.json /etc/docker/daemon.json
sudo cp /vagrant/provision/scripts/env.$1.sh /etc/environment

# Setup Restart daemons
sudo systemctl daemon-reload
sudo service consul restart
sudo service vault restart
sudo service nomad restart
sudo service docker restart
sudo service csreplicate restart