sudo mkdir -p /var/consul/config
sudo mkdir -p /var/nomad/config
sudo mkdir -p /var/vault/config

sudo cp /vagrant/provision/consul/$1/* /var/consul/config/
sudo cp /vagrant/provision/consul/watches/* /var/consul/config/
sudo cp /vagrant/provision/consul/check-definitions/* /var/consul/config/
sudo cp /vagrant/provision/consul/system/consul.service /etc/systemd/system/consul.service
sudo chmod +x /var/consul/config/*.sh
sudo chmod +x /vagrant/provision/consul/system/*.sh

sudo cp /vagrant/provision/nomad/config/* /var/nomad/config/
sudo cp /vagrant/provision/nomad/system/nomad.service /etc/systemd/system/nomad.service
sudo chmod +x /vagrant/provision/nomad/system/*.sh

sudo cp /vagrant/provision/vault/config/* /var/vault/config/
sudo cp /vagrant/provision/vault/system/vault.service /etc/systemd/system/vault.service
sudo cp /vagrant/provision/certs/* /var/vault/config
sudo chmod +x /vagrant/provision/vault/system/*.sh

sudo cp /vagrant/provision/docker-config/$1/daemon.json /etc/docker/daemon.json
sudo cp /vagrant/provision/scripts/env.$1.sh /etc/environment

sudo systemctl daemon-reload
sudo service consul restart
sudo service vault restart
sudo service nomad restart
sudo service docker restart
