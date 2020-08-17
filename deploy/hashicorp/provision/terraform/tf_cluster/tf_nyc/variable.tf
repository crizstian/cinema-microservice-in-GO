variable "consul_address" {}
variable "consul_datacenter" {}
variable "consul_datacenters" {
  type = (list)
}
variable "consul_scheme" {}

variable "prepared_queries" {
  default = [{
    service      = "mongodb1"
    failover_dcs = ["sfo"]
  },{
    service      = "mongodb2"
    failover_dcs = ["sfo"]
  },{
    service      = "mongodb3"
    failover_dcs = ["sfo"]
  }]
}

variable "external_services" {
  default = [{
    name    = "mongodb1"
    address = "192.168.15.6"
    port    = 27017
    tags    = ["external-service", "external-db"]
  },{
    name    = "mongodb2"
    address = "192.168.15.6"
    port    = 27018
    tags    = ["external-service", "external-db"]
  },{
    name    = "mongodb3"
    address = "192.168.15.6"
    port    = 27019
    tags    = ["external-service", "external-db"]
  }]
}