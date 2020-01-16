variable "dbs" {
  default = [{
    ip = "192.168.15.3"
    port = 27017
  },{
    ip = "192.168.15.3"
    port = 27018
  },{
    ip = "192.168.15.3"
    port = 27019
  }]
}

provider "consul" {
  address    = "172.20.20.31:8500"
  datacenter = "dc2"
  scheme     = "http"

  # ca_file    = "../../../certs/ca.crt.pem"
  # cert_file  = "../../../certs/server.crt.pem"
  # key_file   = "../../../certs/server.key.pem"
}

resource "consul_keys" "cluster_status" {
  datacenter = "dc2"

  key {
    path  = "cluster/info/status"
    value = "standby"
  }
}

resource "consul_node" "mongodb_node" {
  count = length(var.dbs)

  name    = "mongodb${count.index+1}"
  address = var.dbs[count.index].ip
}

resource "consul_service" "mongodb_service" {
  count = length(var.dbs)

  name = "mongodb${count.index+1}"
  node = "${consul_node.mongodb_node[count.index].name}"
  port = var.dbs[count.index].port
  tags = ["external-services", "external-database"]
  datacenter = "dc2"
}

resource "consul_prepared_query" "mongodb1" {
  name         = "mongodb1"
  near         = "_agent"
  service      = "mongodb1"

  failover {
    nearest_n   = 3
    datacenters = ["dc1"]
  }
}
resource "consul_prepared_query" "mongodb2" {
  name         = "mongodb2"
  near         = "_agent"
  service      = "mongodb2"

  failover {
    nearest_n   = 3
    datacenters = ["dc1"]
  }
}
resource "consul_prepared_query" "mongodb3" {
  name         = "mongodb3"
  near         = "_agent"
  service      = "mongodb3"

  failover {
    nearest_n   = 3
    datacenters = ["dc1"]
  }
}

resource "consul_prepared_query" "vault" {
  name         = "vault"
  near         = "_agent"
  service      = "vault"

  failover {
    nearest_n   = 3
    datacenters = ["dc1"]
  }
}