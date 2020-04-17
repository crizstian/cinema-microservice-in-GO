provider "consul" {
  address    = var.consul_address
  datacenter = var.consul_datacenter
  scheme     = var.consul_scheme
}

terraform {
  backend "consul" {}
}

module "tf_consul" {
  source = "./consul"

  datacenters = ["dc2", "dc1"]
  
  enabled_prepared_queries = true
  prepared_queries         = var.prepared_queries
  external_services        = var.external_services

  kv = [{
    path  = "cluster/info/status"
    value = "standby"
  }]
}