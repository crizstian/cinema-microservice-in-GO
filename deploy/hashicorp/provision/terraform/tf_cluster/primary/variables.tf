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

variable "service_defaults_apps" {
  default = [
    {
      name           = "booking-service"
      mesh_resolver  = "local"
    },
    {
      name             = "notification-api"
      mesh_resolver    = "local"
      service_resolver = {
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
    },
    {
      name             = "payment-api"
      mesh_resolver    = "local"
      service_resolver = {
        Failover = {
          "*" = {
            Datacenters = ["nyc"]
          }
        }
      }
    },
    {
      name             = "count-dashboard"
      mesh_resolver    = "local"
    },
    {
      name             = "count-api"
      mesh_resolver    = "local"
    }
  ]
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