provider "consul" {
  address    = "172.20.20.11:8500"
  datacenter = "dc1"
  scheme     = "http"
}

terraform {
  backend "consul" {
    address = "172.20.20.11:8500"
    path    = "terraform/consul/prepared-queries/state"
  }
}

resource "consul_keys" "cluster_status" {
  datacenter = "dc1"

  key {
    path  = "cluster/info/status"
    value = "active"
  }
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