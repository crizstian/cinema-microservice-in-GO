variable "dbs" {
  default = [{
    ip = "192.168.15.10"
    port = 27017
  },{
    ip = "192.168.15.10"
    port = 27018
  },{
    ip = "192.168.15.10"
    port = 27019
  }]
}

provider "consul" {
  address    = "172.20.20.31:8500"
  datacenter = "dc2"
  scheme     = "http"
}

terraform {
  backend "consul" {
    address = "172.20.20.11:8500"
    path    = "terraform/dc2/consul/prepared-queries/state"
  }
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
  node = consul_node.mongodb_node[count.index].name
  port = var.dbs[count.index].port
  tags = ["external-services", "external-database"]
  datacenter = "dc2"
}

resource "consul_prepared_query" "mongodb_prepared_query" {
  count = length(var.dbs)

  name         = "mongodb${count.index+1}"
  near         = "_agent"
  service      = "mongodb${count.index+1}"

  failover {
    nearest_n   = 3
    datacenters = ["dc1"]
  }
}
