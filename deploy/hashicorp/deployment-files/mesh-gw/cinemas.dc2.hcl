job "cinemas" {

  datacenters = ["nyc-ncv"]
  region      = "nyc-region"
  type        = "service"

  group "payment-api" {
    count = 1

    task "payment-api" {
      driver = "docker"
      config {
        image = "crizstian/payment-service-go:v0.4"
      }

      env {
        DB_SERVERS      = "mongodb1.service.consul:27017,mongodb2.service.consul:27018,mongodb3.service.consul:27019"
        SERVICE_PORT    = "3000"
        CONSUL_IP       = "172.20.20.31"
        CONSUL_SCHEME   = "https"
        CONSUL_HTTP_SSL = "true"
        CONSUL_HTTP_TOKEN = "734bccc0-14ee-3da8-22ae-9e6398be54e7"
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "payment-api"
      port = "3000"

      connect {
        sidecar_service {}
      }
    }
  }

  group "notification-api" {
    count = 1

    task "notification-api" {
      driver = "docker"
      config {
        image   = "crizstian/notification-service-go:v0.4"
      }

      env {
        SERVICE_PORT    = "3001"
        CONSUL_IP       = "172.20.20.31"
        CONSUL_SCHEME   = "https"
        CONSUL_HTTP_SSL = "true"
        CONSUL_HTTP_TOKEN = "734bccc0-14ee-3da8-22ae-9e6398be54e7"
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "notification-api"
      port = "3001"

      connect {
        sidecar_service {}
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
          "-http-addr", "172.20.20.31:8500",
          "-grpc-addr", "172.20.20.31:8502",
          "-wan-address", "172.20.20.31:${NOMAD_PORT_proxy}",
          "-address", "172.20.20.31:${NOMAD_PORT_proxy}",
          "-bind-address", "default=172.20.20.31:${NOMAD_PORT_proxy}",
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