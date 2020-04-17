variable "consul_address" {}
variable "consul_datacenter" {}
variable "consul_scheme" {}

variable "service_to_service_intentions" {
  default = [{
    source      = "booking-service"
    destination = ["payment-api", "notification-api", "mongodb1", "mongodb2", "mongodb3"]
  },{
    source      = "payment-api"
    destination = ["booking-service", "mongodb1", "mongodb2", "mongodb3"]
  },{
    source      = "notification-api"
    destination = ["booking-service", "mongodb1", "mongodb2", "mongodb3"]
  },{
    source      = "count-dashboard"
    destination = ["count-api"]
  },{
    source      = "count-api"
    destination = ["count-dashboard"]
  }]
}

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

variable "apps" {
  default = [
    "booking-service",
    "payment-service",
    "notification-service",
    "movie-service"
  ]
}

variable "dbs" {
  default = ["mongo-db"]
}

variable "infrastructure" {
  default = ["vault-agent"]
}