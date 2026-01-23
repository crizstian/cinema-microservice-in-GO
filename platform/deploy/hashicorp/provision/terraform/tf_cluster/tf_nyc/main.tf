provider "consul" {
  address    = var.consul_address
  datacenter = var.consul_datacenter
  scheme     = var.consul_scheme
}

terraform {
  backend "consul" {}
}

module "tf_consul" {
  source = "../../consul"

  datacenters = ["nyc", "sfo"]
  datacenter  = var.consul_datacenter
  store_kv    = [{
    path  = "cluster/info/status"
    value = "disabled"
  }]
  enabled_prepared_queries = true
  prepared_queries         = var.prepared_queries
  external_services        = var.external_services
}