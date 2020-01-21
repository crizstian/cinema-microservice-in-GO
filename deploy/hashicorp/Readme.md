# Cinemas Microservice in Go (Project)



This project consist on the following components:

```
.
├── base_docker_image (contains the base configurations for all microservices that interacts with vault and consul)
├── booking-service
├── cinemas-db
├── deploy
│   ├── docker-compose (local testing for non vault / consul interactions)
│   ├── hashicorp
│   │   ├── Vagrantfile (creates 2 vms with all hashicorp stack to run monitor secure the microservices)
│   │   ├── deployment-files (Nomad Job files to deploy the microservices)
│   │   ├── provision (configuration files in order to run all the hashicorp stack)
│   │   │   ├── consul
│   │   │   ├── docker-config
│   │   │   ├── nomad
│   │   │   ├── scripts (installation scripts, configuration scripts for the vms)
│   │   │   └── vault
│   └── readme.md (Documentation)
├── movie-service
├── notification-service
└── payment-service
```

General Information:

- 4 microservices written in Go, but 3 most used as shown the image below.
  - booking service comunicates to the payment wall in order to generate the cinema tickets.
  - payment wall will made the corresponding purchase charge.
  - booking service will comunicate to the notification service to send satisfactory purchase email to the user and send the cinemas tickets as well.

![](../images/Group5.png)

- 1 mongodb replica set cluster

  - (mongo architecture here)

- 2 deployment strategies
  - docker-compose strategy for local testing

  - hashicorp stack strategy for local cloud simulation testing
  
    - (microservices architecture here)

---
## Steps to initialize the environment and Test the Hashicorp Stack and the Microservices Architecture

This Repo contains a Vagranfile *(another Hashicorp product)* in order to create virtual machines with virtualbox as a provider. Vagrant helps us to define vms as code for local testing.

**Vagrant will install the following binaries:**

- docker@latest for ubuntu
- envoy@latest for ubuntu
- consul@1.6.1
- consul-template@0.24.0
- envconsul@0.9.0
- consul-replicate@0.4.0
- nomad@0.10.1
- terraform@0.12.19
- cni-plugins@v0.8.1
- vault@1.2.3
- dnsmasq@latest for ubuntu

The Vagrant configuration lives under the following directory: `deploy/hashicorp/provision/Vagrantfile`, and its provisioners lives under `deploy/hashicorp/provision/scripts`; the following scripts configures the vm:

- env.dc.sh (this has a set of environment variables defined)
- init.hashi.sh (this will copy all the config files from local to the vm)
- install.dnsmasq.sh (this installs and configures dnsmasq in the vm)
- install.sh (this installs all the binaries with the versions mentioned above)


## initialize the environment

By positioning in the terminal where the `Vagrantfile` is located, start the vm(s) by the following command: 
```
$ vagrant up

...
...
==> dc2-consul-server: Running provisioner: hosts...
==> dc2-consul-server: Running provisioner: shell...
    dc2-consul-server: Running: inline script
    dc2-consul-server: Vagrant Box provisioned!

```

Once the vm(s) are created you can execute the following command to see the list of vm(s) generated:

```
$ vagrant status

Current machine states:

dc1-consul-server         running (virtualbox)
dc2-consul-server         running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
```

Then ssh into the vm(s) with the following command:

Note: *open two terminal windows in order to ssh into both vms since we are going to issue commands in both vms almost at the same time*

```
$ vagrant ssh dc1-consul-server

Welcome to Ubuntu 16.04.6 LTS (GNU/Linux 4.4.0-171-generic x86_64)

0 packages can be updated.
0 updates are security updates.

New release '18.04.3 LTS' available.
Run 'do-release-upgrade' to upgrade to it.

Last login: Mon Jan 20 22:13:10 2020 from 10.0.2.2
_____________________________________________________________________

vagrant@dc1-consul-server:~$

```

Once you have sshed into both vms then you are ready to configure the hashicorp stack and to play with the environment. Lets verify that all hashicorp stack is working properly by executing the following commands:

Lets verify that Consul is up and running:
```
vagrant@dc1-consul-server:~$ sudo su

root@dc1-consul-server:/home/vagrant# consul members
Node               Address            Status  Type    Build      Protocol  DC   Segment
dc1-consul-server  172.20.20.11:8301  alive   server  1.6.1+ent  2         dc1  <all>
```

Lets verify if Nomad is up and running
```
root@dc1-consul-server:/home/vagrant# nomad server members
Name                          Address       Port  Status  Leader  Protocol  Build   Datacenter  Region
dc1-consul-server.dc1-region  172.20.20.11  4648  alive   true    2         0.10.1  dc1-ncv     dc1-region
```

Lets verify if Vault is up and running
```
root@dc1-consul-server:/home/vagrant# vault status
Key                Value
---                -----
Seal Type          shamir
Initialized        false
Sealed             true
Total Shares       0
Threshold          0
Unseal Progress    0/0
Unseal Nonce       n/a
Version            n/a
HA Enabled         true
```

All main 3 hashicorp binaries are up and running, if you want to check deeper, you can see the logs of them at the following path: `/var/log/`.

- Consul: `/var/log/consul.log`
- Nomad: `/var/log/nomad.log`
- Vault: `/var/log/vault.log`

---
## Hashicorp Vault Configuration

We are going to configure first Vault and we are going to perform the following actions:

- unseal vault(s)
- enable performance replication [this step is only valid with enterprise binaries]
- create vault policies (using terraform)
- enable kv secret engine and write secrets
- enable vault agent for consul operations

### Vault configuration

Before we start to configure vault lets check first what is the current configuration of vault, and how does vault run insdide the vm.

The vault config lives under `deploy/hashicorp/provision/vault/config/vault.hcl.tmpl`

you may be notice that the file extension is `.tmpl` and not `.hcl` this is because we are using consul-template in order to generate the vault config file dynamically: why like this, because we want to set the values of the configuration file depending on the instance/vm where vault is running, so consul-template here helps us to read the environment variable of the vm and then generate the corresponding file with the proper values.

```
# General Settings 
cluster_name = "{{ env "DATACENTER" }}"
ui = true

# Advertise the non-loopback interface
api_addr     = "https://{{ env "HOST_IP" }}:8200"
cluster_addr = "https://{{ env "HOST_IP" }}:8201"

...please see the file for the full configuration
```
So how do we start and translate the consul-template file in order to vault can start. We do that by running the script that lives under `deploy/hashicorp/provision/system/vault-init.sh` this file will be executed by the vault.service that is installed in the systemd folder, which will execute once the vm boots up.

So the magic happens with this line:
```
consul-template -template "/var/vault/config/vault.hcl.tmpl:/var/vault/config/vault.hcl" -once
```
once generated we can execute the following line:
```
exec vault server -config=/var/vault/config/vault.hcl >>/var/log/vault.log 2>&1
```

and this is how vault starts inside the vm.

### **Step 1** Unseal Vault(s)

In order to use vault we need to unseal them and there is a script which contains all the steps to unseal the vault, we are going to use the vault api to do this;
the file that unseal the vault lives under `deploy/hashicorp/provision/vault/system/unseal.sh`. This script will init vault, unseal vault, and store the vault keys and root token in consul; please see the unseal.sh file for better understanding.

First we need to ssh into the vm(s); once there we need to execute the following command:
```
root@dc1-consul-server:/home/vagrant# bash /vagrant/provision/vault/system/unseal.sh
```

and you will see the following output:

```
STARTING TO UNSEAL VAULT
...
...
...
Vault steal unsealed numer of key applied in
Vault steal unsealed numer of key applied 1
Vault steal unsealed numer of key applied 2
Vault steal unsealed numer of key applied 3
Vault server: 172.20.20.11 has been unsealed
Vault successfully unsealed
```

*in order to access files from the vagrant vm into our local machine, we can use the shared folder created by vagrant; we can access all files that are in the same path as the vagrant file is; in order to do that we just need to set the path `/vagrant/` and then the file or folder we want, in this case we execute the script `/vagrant/provision/vault/system/unseal.sh`*

**Note:** *Please ensure to unseal both vm(s) in order to enable performace replication; Repeat the same command in the second vm.*

### **Step 2** Enable Performance Replication for Vault [Enterprise step]

Once we have unsealed our vault(s) the script above write the root token into file `/etc/environment` so in order to proceed with vault interactions we need read that file to set the token in our environment variables so we need to execute the following command:
```
$ source /etc/environment
```

Once the environment variables loaded we can execute the following command:
```
root@dc1-consul-server:/home/vagrant# bash /vagrant/provision/vault/performance/init-primary.sh

{"request_id":"1e29a906-fb37-b402-0292-e1d94f449924","lease_id":"","renewable":false,"lease_duration":0,"data":null,"wrap_info":null,"warnings":["This cluster is being enabled as a primary for replication. Vault will be unavailable for a brief period and will resume service shortly."],"auth":null}
```

This script enables the performance replication on the primary vault, and then generates the secondary vault token; once generated this token will be stored in the consul kv store under the path `global/vault/secondary-token` and this value will be replicated into the second consul cluster automatically by the `consul-replicate` service that is running in the vm (we will be talking about this in the consul section).

once finshed the step above we can execute the following command in the second vm:

```
root@dc2-consul-server:/home/vagrant# source /etc/environment

root@dc2-consul-server:/home/vagrant# bash /vagrant/provision/vault/performance/init-secondary.sh

{"request_id":"2009ef4c-0903-bbbd-3be1-54cf787c05ea","lease_id":"","renewable":false,"lease_duration":0,"data":null,"wrap_info":null,"warnings":["Vault has successfully found secondary information; it may take a while to perform setup tasks. Vault will be unavailable until these tasks and initial sync complete."],"auth":null}
```

and with this we have enabled performance replication in vault; and now we can have active/active clusters (more on this on Consul / Nomad configurations).

With this we can now write policies, secrets, enable auth methods, and all of this operations will be replicated into the second vault and with this Vault replication addresses providing consistency, scalability, and highly-available disaster recovery.

**Note:** *Using replication requires a storage backend that supports transactional updates, such as Consul.*

### **Step 3** Create Vault Policies (using Terraform)

Now that we have a complete Vault setup, we can now start using vault features like creating policies, enabling secret engines, enabling auth methods, etc.

By using terraform and the vault provier we have the ability to define policies as code, and so we can have also centralized vault configurations as code as well this helps us to be more declarative and to follow the pattern immutable infrastructure.

The terraform code for this repo lives under `deploy/hashicorp/provision/vault/polices` and the configurations are sectioned by:

- `app-policies.tf` which contains applications policies configurations.
- `app-roles.tf` which generates the role-id and secret-id for the applications.
- `backend.tf` which has the configurations for vault auth methods as code.
- `main.tf` which has the providers configurations as the terraform backend
- `personas-policies.tf` which has the policies for an admin user and a provisioner user (like jenkins or terraform).
- `secrets.tf` which handles operations like creating vault userpass users, or consul roles.

in order to execute this terraform code we need to position where this files are located, so once again we are going to use the vagrant shared folder like the following:

```
root@dc1-consul-server:/home/vagrant# cd /vagrant/provision/vault/policies/

root@dc1-consul-server:/vagrant/provision/vault/policies# terraform init

Initializing the backend...
Backend configuration changed!
...
Successfully configured the backend "consul"! Terraform will automatically
use this backend unless the backend configuration changes.
...
* provider.consul: version = "~> 2.6"
* provider.vault: version = "~> 2.7"

Terraform has been successfully initialized!
```
Once we do the `terraform init` our terraform backend has been setup which will store the terraform state file in consul kv store under `terraform/dc1/vault/policies/state`

then we can do `terraform plan` to see the changes that we are going to implement and then we need to do `terraform apply -auto-approve`:

**Note** *Remember to load the environment variables; since terraform relies on them for best practices*

```
root@dc1-consul-server:/vagrant/provision/vault/policies# source /etc/environment

root@dc1-consul-server:/vagrant/provision/vault/policies# terraform plan
...
Plan: 35 to add, 0 to change, 0 to destroy.
```

```
root@dc1-consul-server:/vagrant/provision/vault/policies# terraform apply -auto-approve
vault_auth_backend.approle: Creating...
vault_policy.infrastructure-policy[0]: Creating...
vault_policy.admin-policy: Creating...
vault_policy.apps-policy[0]: Creating...
...
vault_approle_auth_backend_role.apps-role[4]: Creating...
vault_approle_auth_backend_role.apps-role[2]: Creating...
...
consul_keys.apps-secret-id[3]: Creating...
consul_keys.apps-secret-id[3]: Creation complete after 0s [id=consul]

Apply complete! Resources: 35 added, 0 changed, 0 destroyed.
```

And with we have created policies, enabled auth methods, store secrets and we have created the admin user so we can now log in in the second vault with this user. since performance replication is enabled.

Now you can go visit the Vault UI at `https://172.20.20.11:8200/ui` and if you log in with the userpass method with the user `admin` and password `admin` and you will be able to see all the configurations made with terraform; and if you visit the second vault UI at `https://172.20.20.31:8200/ui` with the same method and user you will be able to see that all the data written in Vault 1 will be present in Vault 2.

**Note** *if you are not using vault enterprise all the steps above should also work, the only difference is that you will not be able to replicate data between clusters; ignore the step 2 and the verification process for replication.*

### **Step 4** Vault Agent

Vault Agent is a client daemon that provides the following features:

- Auto-Auth - Automatically authenticate to Vault and manage the token renewal process for locally-retrieved dynamic secrets.

- Caching - Allows client-side caching of responses containing newly created tokens and responses containing leased secrets generated off of these newly created tokens.

- Templating - Allows rendering of user supplied templates by Vault Agent, using the token generated by the Auto-Auth step.

With having the agent running on the vm our processes or applications will have the ability to call vault with localhost and with the benefit of the auto-auth, in Step 3 we have generated a policy, a role-id and secret-id for this vault agent in order to do our vault operations.

We are going to use Vault Agent to integrate it with Consul and Nomad in order to have the ability to be creating and renewing Consul Tokens and Nomad Tokens for its ACL system.

The vault agent configurations lives under `deploy/hashicorp/provision/vault/agent`, here we will have as same as vault server config file a consul-template file in order to generate this file dynamically by the environment variables set in the vm; 

```
auto_auth {
   method "approle" {
       mount_path = "auth/approle"
       config = {
           role_id_file_path   = "/var/vault/config/agent/roleID"
           secret_id_file_path = "/var/vault/config/agent/secretID"
           remove_secret_id_file_after_reading = false
       }
   }

   sink "file" {
       config = {
           path = "/var/vault/config/agent/approleToken"
       }
   }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address 			= "{{ env "HOST_IP" }}:8007"
  tls_cert_file = "{{ env "VAULT_CLIENT_CERT" }}"
	tls_key_file  = "{{ env "VAULT_CLIENT_KEY" }}"
}
```

for the auto-auth we are going to use the appRole auth method; the vault agent is configured as a service in the vm called `vaultagent` and we are going to enable this service by executing the following command:

```
root@dc1-consul-server:/vagrant/provision/vault/policies# service vaultagent restart

root@dc1-consul-server:/vagrant/provision/vault/policies# service vaultagent status
● vaultagent.service - Vault Agent
   Loaded: loaded (/etc/systemd/system/vaultagent.service; disabled; vendor preset: enabled)
   Active: active (running) since Tue 2020-01-21 21:33:25 UTC; 3s ago
 Main PID: 30241 (vault)
    Tasks: 10
   Memory: 7.9M
      CPU: 63ms
   CGroup: /system.slice/vaultagent.service
           └─30241 vault agent -config=/var/vault/config/agent/agent.hcl

Jan 21 21:33:25 dc1-consul-server systemd[1]: Started Vault Agent.
```

We restart the service since at vm boot we dont have any configuration in place for the vault agent until we setup the information in the vault server, and at boot we set the vaultagent service to be stopped, so now that we have the required information we can restart the vault agent, and then we can check the status. To check more details about the vault agent process you can check the logs under following path:
```
root@dc1-consul-server:/vagrant/provision/vault/policies# cat /var/log/vault-agent.log
==> Vault server started! Log data will stream in below:

==> Vault agent configuration:

           Api Address 1: https://172.20.20.11:8007
                     Cgo: disabled
               Log Level: info
                 Version: Vault v1.2.3+prem

2020-01-21T21:33:25.482Z [INFO]  sink.file: creating file sink
2020-01-21T21:33:25.482Z [INFO]  sink.file: file sink configured: path=/var/vault/config/agent/approleToken
2020-01-21T21:33:25.483Z [INFO]  auth.handler: starting auth handler
2020-01-21T21:33:25.483Z [INFO]  auth.handler: authenticating
2020-01-21T21:33:25.483Z [INFO]  sink.server: starting sink server
2020-01-21T21:33:25.508Z [INFO]  auth.handler: authentication successful, sending token to sinks
2020-01-21T21:33:25.508Z [INFO]  auth.handler: starting renewal process
2020-01-21T21:33:25.509Z [INFO]  sink.file: token written: path=/var/vault/config/agent/approleToken
2020-01-21T21:33:25.516Z [INFO]  auth.handler: renewed auth token
```

and since we are running the `vault agent` in the same vm where the `vault server` is running, we have set the vault agent address to `8007` so it doesnt collide with `8200`.

With all vault configurations already in place we can now start reviewing the Consul Configurations.


## Hashicorp Consul Configuration


## Hashicorp Nomad Configuration


## Hashicorp Terraform Configuration

