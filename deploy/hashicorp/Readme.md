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
The Microservices needs a MongoDB Cluster up and running, so we need to execute the following command to deploy the mongo containers with nomad.


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
root@dc1-consul-server:/home/vagrant# nomad plan /vagrant/deployment-files/db-cluster.dc1.hcl
+ Job: "db-cluster"
+ Task Group: "db-cluster" (1 create)
  + Task: "mongodb1" (forces create)
  + Task: "mongodb2" (forces create)
  + Task: "mongodb3" (forces create)

Scheduler dry-run:
- All tasks successfully allocated.

Job Modify Index: 0
To submit the job with version verification run:

nomad job run -check-index 0 /vagrant/deployment-files/db-cluster.dc1.hcl

When running the job with the check-index flag, the job will only be run if the
server side version matches the job modify index returned. If the index has
changed, another user has modified the job and the plans results are
potentially invalid.
```

Then do a nomad run, to deploy the mongo cluster
```bash
vagrant@dc1-consul-server:~$ nomad run /vagrant/deployment-files/db-cluster.dc1.hcl
==> Monitoring evaluation "64522cad"
    Evaluation triggered by job "db-cluster"
    Allocation "0ee1d8a3" created: node "89f97afb", group "db-cluster"
    Evaluation within deployment: "e777c7c2"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "64522cad" finished with status "complete"
```

Then wait unitl db cluster is fully deployed to proceed with the microservices, expect to see a similar message in your output.

you can monitor the deployment with the following command:

```bash
vagrant@dc1-consul-server:~$ nomad status db-cluster

...
Latest Deployment
ID          = e777c7c2
Status      = successful
Description = Deployment completed successfully
...
```


### Prepared Queries with Terraform


### Deploy cinema-microservices



## Testing failover
Curl the local endpoint, by default API resolves to local datacenter

```
$ curl localhost:9090

# Reponse from: web #
Hello World
## Called upstream uri: http://localhost:9091
  # Reponse from: api #
  API DC1
```

Kill the API service in DC1

```
$ docker kill failover_api_dc1_1
```

Curl the local endpoint again, upstream requests will failover to the DC2 API service, it may take a few seconds for the health checks to fail for the DC1 API instance. Transient failures while the system is failing over to the second DC could be mitigated with retries (Demo coming soon).

```
$ curl localhost:9090

# Reponse from: web #
Hello World
## Called upstream uri: http://localhost:9091
  # Reponse from: api #
  API DC2
```
