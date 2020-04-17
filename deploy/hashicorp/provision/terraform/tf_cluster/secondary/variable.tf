variable "prepared_queries" {
  default = [{
    service      = "mongodb1"
    failover_dcs = ["dc1"]
  },{
    service      = "mongodb2"
    failover_dcs = ["dc1"]
  },{
    service      = "mongodb3"
    failover_dcs = ["dc1"]
  }]
}

variable "external_services" {
  default = [{
    name    = mongodb1
    address = "192.168.15.10"
    port    = 27017
    tags    = ["external-service", "external-db"]
  },{
    name    = mongodb2
    address = "192.168.15.10"
    port    = 27018
    tags    = ["external-service", "external-db"]
  },{
    name    = mongodb3
    address = "192.168.15.10"
    port    = 27019
    tags    = ["external-service", "external-db"]
  }]
}