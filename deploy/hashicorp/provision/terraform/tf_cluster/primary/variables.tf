variable "consul_address" {}
variable "consul_datacenter" {}
variable "consul_datacenters" {
  type = (list)
}
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
            datacenters = ["nyc"]
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
            datacenters = ["nyc"]
          }
        }
      }
    }
  ]
}

variable "proxy_defaults" {
  default = {
    Config = {
envoy_prometheus_bind_addr = "0.0.0.0:9102"

envoy_extra_static_clusters_json = <<EOL
{
"connect_timeout": "3.000s",
"dns_lookup_family": "V4_ONLY",
"lb_policy": "ROUND_ROBIN",
"load_assignment": {
"cluster_name": "jaeger",
"endpoints": [
    {
        "lb_endpoints": [
            {
                "endpoint": {
                    "address": {
                        "socket_address": {
                            "address": "10.0.2.15",
                            "port_value": 6831,
                            "protocol": "TCP"
                        }
                    }
                }
            }
        ]
    }
]
},
"name": "jaeger",
"type": "STRICT_DNS"
}
EOL

envoy_tracing_json = <<EOL
{
"http": {
  "config": {
      "collector_cluster": "jaeger",
      "collector_endpoint": "/api/v1/spans",
      "shared_span_context": false
  },
  "name": "envoy.zipkin"
}
}
EOL
}
  }
}
variable "enable_proxy_defaults" {
  default = false
}