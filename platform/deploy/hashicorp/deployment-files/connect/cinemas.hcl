job "cinemas" {

  datacenters = ["sfo-ncv"]
  region      = "sfo-region"
  type        = "service"

  group "payment-api" {
    count = 1

    network {
      mode = "bridge"
      
      port "healthcheck" {
        to = -1
      }
    }

    service {
      name = "payment-api"
      port = "3000"

      check {
        name     = "payment-api-health"
        port     = "healthcheck"
        type     = "http"
        protocol = "http"
        path     = "/ping"
        interval = "5s"
        timeout  = "2s"
        expose   = true
      }

      connect {
        sidecar_service {}
      }
    }

    task "payment-api" {
      driver = "docker"

      config {
        image = "crizstian/payment-service-go:v0.4"
      }

      env {
        DB_SERVERS        = "mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
        SERVICE_PORT      = "3000"
        CONSUL_IP         = "consul.service.consul"
        CONSUL_SCHEME     = "https"
        CONSUL_HTTP_SSL   = "true"
        DISABLE_CURL_SSL  = "true"
        CONSUL_HTTP_TOKEN = "f12225f4-7703-33d8-40ca-7adb014d47c9"
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }
  }

  group "notification-api" {
    count = 1
    
    network {
      mode = "bridge"

      port "healthcheck" {
        to = -1
      }
    }

      service {
      name = "notification-api"
      port = "3001"

      check {
        name     = "notification-api-health"
        port     = "healthcheck"
        type     = "http"
        protocol = "http"
        path     = "/ping"
        interval = "5s"
        timeout  = "2s"
        expose   = true
      }

      connect {
        sidecar_service {}
      }
    }

    task "notification-api" {
      driver = "docker"

      config {
        image   = "crizstian/notification-service-go:v0.4.1"
      }

      env {
        SERVICE_PORT    = "3001"
        CONSUL_IP       = "consul.service.consul"
        CONSUL_SCHEME   = "https"
        CONSUL_HTTP_SSL = "true"
        DISABLE_CURL_SSL  = "true"
        CONSUL_HTTP_TOKEN = "9acbfe4e-d842-a3ab-3631-2c50699bd07f"
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }
  }

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
      tags = ["cinemas-project", "ENTRY"]

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

        CONSUL_IP       = "consul.service.consul"
        CONSUL_SCHEME   = "https"
        CONSUL_HTTP_SSL = "true"
        DISABLE_CURL_SSL  = "true"
        CONSUL_HTTP_TOKEN = "74bb155f-09c8-8fb5-050a-e2e01f6f3646"
        
        PAYMENT_URL      = "http://${NOMAD_UPSTREAM_ADDR_payment_api}"
        NOTIFICATION_URL = "http://${NOMAD_UPSTREAM_ADDR_notification_api}"
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }
  }
}