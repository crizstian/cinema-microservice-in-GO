# Consul Connect Failover
This example shows how DC failover works with Consul service mesh. 

The setup contains two Consul datacenters federated together and connected using Consul Gateways. Both DC1 and DC2 contain instances of the Payment and Notification API's, under normal operating conditions the Booking Service will always use it's local instance of Paymanet and Notification API services. If something happen to the instance where Payment and Notification services are running and suddendly become unhealthy in DC1, traffic will automatically be routed to the second datacenter or DR.


Components:
* Private Network DC1
* Private Network DC2
* WAN Network (Consul Server, Consul Gateway)
* Consul Datacenter DC1 - Primary
* Consul Datacenter DC2 - Secondary, joined to DC1 with WAN federation
* Consul Gateway DC1
* Consul Gateway DC2
* Booking Service (DC1) communicates with Payment and Notification API's in DC1 by default, fails over to DC2
* Payment API service (DC1, DC2)
* Notification API service (DC1, DC2)

![](../images/failover.png)

## Configuration
To enable failover the following central configuraion is required:
* Service-Defaults for Booking service
* Service-Defaults for Payment service
* Service-Resolver for Payment service
* Service-Defaults for Notification service
* Service-Resolver for Notification service

see configuration files under the folder `provision/consul/dc1/central-config`

## Running the setup
We will use Vagrant to run Consul and Nomad as the container scheduler

You can run the setup using the following command:
```
$ vagrant up
...bash
==> dc1-consul-server: Running provisioner: shell...
    dc1-consul-server: Running: /var/folders/qx/4twdn0f10tsg2syrzv0r5c100000gn/T/vagrant-shell20191006-2688-15o07jv.sh
...
==> dc2-consul-server: Running provisioner: shell...
    dc2-consul-server: Running: /var/folders/qx/4twdn0f10tsg2syrzv0r5c100000gn/T/vagrant-shell20191006-2688-15o07jv.sh
```

To verify that both Vagrant boxes are up running, use the following command:
```bash
$ vagrant status
Current machine states:

dc1-consul-server         running (virtualbox)
dc2-consul-server         running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
```

Then SSH into the the boxes in order to deploy the cinema-microservice project
```bash
$ vagrant ssh dc1-consul-server
Welcome to Ubuntu 16.04.6 LTS (GNU/Linux 4.4.0-165-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

0 packages can be updated.
0 updates are security updates.

New release '18.04.2 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


vagrant@dc1-consul-server:~$
```


## Deploy Services
The microservices needs a MongoDB Cluster up and running, so we need to execute the following command to deploy the mongo containers with nomad.


First do nomad plan to see a dry-run deployment
```bash
vagrant@dc1-consul-server:~$ nomad plan /vagrant/deployment-files/db-cluster.dc1.hcl
Welcome to Ubuntu 16.04.6 LTS (GNU/Linux 4.4.0-165-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

0 packages can be updated.
0 updates are security updates.

New release '18.04.2 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


vagrant@dc1-consul-server:~$ sudo su