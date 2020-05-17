job "cinemas" {

  datacenters = ["sfo-ncv"]
  region      = "sfo-region"
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
        CONSUL_IP       = "172.20.20.11"
        CONSUL_SCHEME   = "https"
        CONSUL_HTTP_SSL = "true"
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }

    network {
      mode = "bridge"
      port "http" {
        to = 3000
      }
    }

    service {
      name = "payment-api"
      port = "http"
      tags = ["cinemas-project"]

      check {
        type     = "http"
        port     = "http"
        path     = "/ping"
        interval = "5s"
        timeout  = "2s"
      }

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
        CONSUL_IP       = "172.20.20.11"
        CONSUL_SCHEME   = "https"
        CONSUL_HTTP_SSL = "true"
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }

    network {
      mode = "bridge"
      port "http" {
        to = 3001
      }
    }

    service {
      name = "notification-api"
      port = "http"
      tags = ["cinemas-project"]

      check {
        type     = "http"
        port     = "http"
        path     = "/ping"
        interval = "5s"
        timeout  = "2s"
      }

      connect {
        sidecar_service {}
      }
    }
  }


  group "booking-api" {
    count = 1

    task "booking-api" {
      driver = "docker"
      config {
        image   = "crizstian/booking-service-go:v0.4"
      }

      env {
        SERVICE_PORT     = "3002"
        CONSUL_IP        = "172.20.20.11"
        DB_SERVERS       = "mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
        PAYMENT_URL      = "http://${NOMAD_UPSTREAM_ADDR_payment_api}"
        NOTIFICATION_URL = "http://${NOMAD_UPSTREAM_ADDR_notification_api}"
        CONSUL_SCHEME    = "https"
        CONSUL_HTTP_SSL  = "true"
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
      port = "http"
      tags = ["cinemas-project"]

      check {
        type     = "http"
        port     = "http"
        path     = "/ping"
        interval = "5s"
        timeout  = "2s"
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
  }
}