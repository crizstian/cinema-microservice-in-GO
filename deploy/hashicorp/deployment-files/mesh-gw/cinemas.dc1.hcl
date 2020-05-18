job "cinemas" {

  datacenters = ["sfo-ncv"]
  region      = "sfo-region"
  type        = "service"

  group "booking-service" {
    count = 1

    task "booking-service" {
      driver = "docker"
      config {
        image   = "crizstian/booking-service-go:v0.4"
      }

      env {
        SERVICE_PORT     = "3002"
        DB_SERVERS       = "mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
        CONSUL_IP        = "172.20.20.11"
        CONSUL_HTTP_TOKEN = "734bccc0-14ee-3da8-22ae-9e6398be54e7"
        PAYMENT_URL      = "http://${NOMAD_UPSTREAM_ADDR_payment_api}"
        NOTIFICATION_URL = "http://${NOMAD_UPSTREAM_ADDR_notification_api}"
      }

      resources {
        cpu    = 50
        memory = 50
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
      driver = "raw_exec"

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
          "-token", "734bccc0-14ee-3da8-22ae-9e6398be54e7",
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