job "cinemas" {

  datacenters = ["sfo-ncv"]
  region      = "sfo-region"
  type        = "service"

  group "booking-api" {
    count = 1

    network {
      mode = "bridge"

      port "http" {
        static = 3002
        to     = 3002
      }

      port "healthcheck" {
        to = -1
      }
    }

    service {
      name = "booking-api"
      port = "http"
      tags = ["cinemas-project"]

      check {
        name     = "booking-api-health"
        port     = "healthcheck"
        type     = "http"
        protocol = "http"
        path     = "/ping"
        interval = "10s"
        timeout  = "3s"
        expose   = true
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
               destination_name = "payment-api"
               local_bind_port = 8080
            }
            upstreams {
               destination_name = "notification-api"
               local_bind_port = 8081
            }
          }
        }
      }
    }

    task "booking-api" {
      driver = "docker"

      config {
        image   = "crizstian/booking-service-go:v0.4"
      }

      env {
        SERVICE_PORT     = "3002"
        DB_SERVERS       = "mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"

        CONSUL_IP        = "consul.service.consul"
        CONSUL_SCHEME   = "https"
        CONSUL_HTTP_SSL = "true"
        
        PAYMENT_URL      = "http://${NOMAD_UPSTREAM_ADDR_payment_api}"
        NOTIFICATION_URL = "http://${NOMAD_UPSTREAM_ADDR_notification_api}"
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }
  }

  group "mesh-gateway" {
    count = 1

    task "mesh-gateway" {
      driver = "raw_exec"

      config {
        command = "consul"
        args    = [
          "connect", "envoy",
          "-mesh-gateway",
          "-register",
          "-service", "gateway-primary",
          "-address", ":${NOMAD_PORT_proxy}",
          "-wan-address", "172.20.20.11:${NOMAD_PORT_proxy}",
          "-admin-bind", "127.0.0.1:19005",
          "-token", "9267d886-3c2f-926e-4115-dbaad3595ff5",
          "-deregister-after-critical", "5s",
          "--",
          "-l", "debug"
        ]
      }

      resources {
        cpu    = 100
        memory = 100

        network {
          port "proxy" {
            static = 8433
          }
        }
      }
    }
  }
}