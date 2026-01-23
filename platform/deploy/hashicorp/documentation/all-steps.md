# List of all steps

### Vagrant Steps
In the local machine:

```
$ vagrant up

$ vagrant status

$ vagrant ssh dc1-consul-server
```
### Vault Steps

In The Server `root@dc1-consul-server:/home/vagrant#`:
```
$ bash /vagrant/provision/vault/system/unseal.sh

$ source /etc/environment

$ bash /vagrant/provision/vault/performance/init-primary.sh
```
Once finished above steps go to `dc2-consul-server`

In The Server `root@dc2-consul-server:/home/vagrant#`:
```
$ bash /vagrant/provision/vault/system/unseal.sh

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

### Consul Steps 
```
$ bash /vagrant/provision/consul/acl/bootstrap.sh
```

In the server `root@dc1-consul-server:/vagrant/provision/consul/acl#`

``` 
$ terraform init

$ terraform plan

$ terraform apply -auto-approve

```

Once the consul acl policies are created proceed to uncomment the `consul.tf` file

and implement the consul token integration with vault.

```
$ cd /vagrant/provision/vault/policies/

$ terraform init

$ terraform plan

$ terraform apply -auto-approve
```