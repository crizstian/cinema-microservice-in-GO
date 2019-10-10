job "cinemas" {

  datacenters = ["dc1-ncv"]
  region      = "dc1-region"
  type        = "service"

  group "booking-service" {
    count = 1

    task "booking-service" {
      driver = "docker"
      config {
        image   = "crizstian/booking-service-go:v0.1"
      }

      env {
        DB_USER="cristian"
        DB_PASS="cristianPassword2017"
        DB_SERVERS="mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
        DB_NAME="booking"
        DB_REPLICA="rs1"
        SERVICE_PORT="3002"
        PAYMENT_URL="http://${NOMAD_UPSTREAM_ADDR_payment_api}"
        NOTIFICATION_URL="http://${NOMAD_UPSTREAM_ADDR_notification_api}"
      }

      resources {
        cpu    = 100
        memory = 100
      }
    }

    network {
      mode = "bridge"
      port "http" {
        static = 3002
        to     = 3002
      }
    }

    service {
      name = "booking-api"
      port = "3002"

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
  }

  group "mesh-gateway" {
    count = 1

    task "mesh-gateway" {
      driver = "exec"

      config {
        command = "consul"
        args    = [
          "connect", "envoy",
          "-mesh-gateway",
          "-register",
          "-http-addr", "172.20.20.11:8500",
          "-grpc-addr", "172.20.20.11:8502",
          "-wan-address", "172.20.20.11:${NOMAD_PORT_proxy}",
          "-address", "172.20.20.11:${NOMAD_PORT_proxy}",
          "-bind-address", "default=172.20.20.11:${NOMAD_PORT_proxy}",
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