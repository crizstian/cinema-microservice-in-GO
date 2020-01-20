job "cinemas" {

  datacenters = ["dc2-ncv"]
  region      = "dc2-region"
  type        = "service"

  group "notification-api-v1" {
    count = 1

    task "notification-api-v1" {
      driver = "docker"
      config {
        image   = "crizstian/notification-service-go:v0.4"
      }

      env {
        SERVICE_PORT="3001"
        CONSUL_IP = "172.20.20.11"
      }

      resources {
        cpu    = 100
        memory = 100
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "notification-api"
      port = "3001"
      tags = ["notification-api-v1", "cinema-microservice-project"]

      meta {
        version = "1"
      }

      connect {
        sidecar_service {}
      }
    }
  }


  group "notification-api-v2" {
    count = 1

    task "notification-api-v2" {
      driver = "docker"
      config {
        image   = "crizstian/notification-service-go:v0.3-tls"
      }

      env {
        SERVICE_PORT = "3001"
        CONSUL_IP    = "172.20.20.11"
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
      tags = ["notification-api-v2", "cinema-microservice-project"]

      meta {
        version = "2"
      }
      connect {
        sidecar_service {}
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
          "-http-addr", "172.20.20.31:8500",
          "-grpc-addr", "172.20.20.31:8502",
          "-wan-address", "172.20.20.31:${NOMAD_PORT_proxy}",
          "-address", "172.20.20.31:${NOMAD_PORT_proxy}",
          "-bind-address", "default=172.20.20.31:${NOMAD_PORT_proxy}",
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