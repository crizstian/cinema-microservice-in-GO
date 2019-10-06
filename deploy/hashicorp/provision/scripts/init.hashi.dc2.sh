sudo mkdir -p /var/consul/config
sudo mkdir -p /var/nomad/config

sudo cp /vagrant/provision/consul/dc2/* /var/consul/config/
sudo cp /vagrant/provision/consul/system/consul.service /etc/systemd/system/consul.service

sudo cp /vagrant/provision/nomad/dc2/* /var/nomad/config/
sudo cp /vagrant/provision/nomad/system/nomad.service /etc/systemd/system/nomad.service

sudo cp /vagrant/provision/docker-config/dc2/daemon.json /etc/docker/daemon.json

sudo systemctl daemon-reload
sudo service consul restart
sudo service nomad restart
sudo service docker restart
