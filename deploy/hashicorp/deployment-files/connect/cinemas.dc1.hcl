job "cinemas" {

  datacenters = ["dc1-ncv"]
  region      = "dc1-region"
  type        = "service"

  group "payment-api" {
    count = 1

    task "payment-api" {
      driver = "docker"
      config {
        image = "crizstian/payment-service-go:v0.3"
      }

      env {
        DB_SERVERS   = "mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
        SERVICE_PORT = "3000"
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
        image   = "crizstian/notification-service-go:v0.3"
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

      connect {
        sidecar_service {}
      }
    }
  }


  group "booking-service" {
    count = 1

    task "booking-service" {
      driver = "docker"
      config {
        image   = "crizstian/booking-service-go:v0.3"
      }

      env {
        SERVICE_PORT     = "3002"
        CONSUL_IP        = "172.20.20.11"
        DB_SERVERS       = "mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
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
}