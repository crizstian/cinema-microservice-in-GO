variable "consul_address" {}
variable "consul_datacenter" {}
variable "consul_datacenters" {
  type = (list)
}
variable "consul_scheme" {}

variable "service_to_service_intentions" {
  default = [{
    source      = "booking-api"
    destination = ["payment-api", "notification-api"]
    action      = "allow"
  }, {
    source      = "payment-api"
    destination = ["booking-api"]
    action      = "allow"
  }, {
    source      = "notification-api"
    destination = ["booking-api"]
    action      = "allow"
  }, {
    source      = "count-dashboard"
    destination = ["count-api"]
    action      = "allow"
  }, {
    source      = "count-api"
    destination = ["count-dashboard"]
    action      = "allow"
  }]
}

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

variable "central_config_apps" {

  default = {
    service_defaults = [
     "booking-api",
     "notification-api",
     "payment-api",
     "count-dashboard",
     "count-api"
    ]

    service_resolver = [{
      name   = "notification-api"
      config = {
        DefaultSubset = "v1"
        Subsets = {
          "v1" = {
            Filter = "Service.Meta.version == v1"
          }
          "v2" = {
            Filter = "Service.Meta.version == v2"
          }
        }
        Failover = {
          "*" = {
            Datacenters = ["nyc"]
          }
        }
      }
    }, {
      name   = "payment-api"
      config = {
        Failover = {
          "*" = {
            Datacenters = ["nyc"]
          }
        }
      }
    }]
  }
}

variable "proxy_defaults" {
  default = {
      MeshGateway = {
        Mode = "local"
    }
  }
}
variable "enable_proxy_defaults" {
  default = false
}