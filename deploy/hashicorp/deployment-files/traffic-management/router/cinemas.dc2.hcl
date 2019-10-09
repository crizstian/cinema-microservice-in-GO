job "cinemas" {

  datacenters = ["dc2-ncv"]
  region      = "dc2-region"
  type        = "service"

  group "payment-api" {
    count = 1

    task "paymentapi" {
      driver = "docker"
      config {
        image   = "crizstian/payment-service-go:v0.1"
      }

      env {
        DB_USER="cristian"
        DB_PASS="cristianPassword2017"
        DB_SERVERS="mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
        DB_NAME="payment"
        DB_REPLICA="rs1"
        SERVICE_PORT="3000"
        STRIPE_SECRET="sk_test_lPPoJjmmbSjymtgo4r0O3z89"
        STRIPE_PUBLIC="pk_test_l10342hIODZmOJsBpY6GVPHj"
      }

      resources {
        cpu    = 100
        memory = 200
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

  group "notification-api-v1" {
    count = 1

    task "notification-api-v1" {
      driver = "docker"
      config {
        image   = "crizstian/notification-service-go:v0.1"
      }

      env {
        SERVICE_PORT="3001"
        EMAIL="crr.developer.9@gmail.com"
        EMAIL_PASS="Cris123#"
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
        image   = "crizstian/notification-service-go:v0.2"
      }

      env {
        SERVICE_PORT="3001"
        EMAIL="crr.developer.9@gmail.com"
        EMAIL_PASS="Cris123#"
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