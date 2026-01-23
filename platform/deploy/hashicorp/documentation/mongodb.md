# MongoDB Replica Set Deployment

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