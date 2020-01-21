# List of all steps

In the local machine:

```
$ vagrant up

$ vagrant status

$ vagrant ssh dc1-consul-server
```

In The Server `root@dc1-consul-server:/home/vagrant#`:
```
$ bash /vagrant/provision/vault/system/unseal.sh

$ source /etc/environment

$ bash /vagrant/provision/vault/performance/init-primary.sh
```
Once finished above steps go to `dc2-consul-server`

In The Server `root@dc2-consul-server:/home/vagrant#`:
```
$ source /etc/environment

$ bash /vagrant/provision/vault/performance/init-secondary.sh
```
Once finished above steps go back to `dc1-consul-server`

In The Server `root@dc1-consul-server:/home/vagrant#`:
```
$ cd /vagrant/provision/vault/policies/

$ terraform init

$ terraform plan

$ terraform apply -auto-approve
```
Once finished above steps, start vault agent:

In The Server `root@dc1-consul-server:/home/vagrant#`:
```
$ service vaultagent restart

$ service vaultagent status
```