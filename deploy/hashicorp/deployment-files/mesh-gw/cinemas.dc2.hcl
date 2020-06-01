job "cinemas" {

  datacenters = ["nyc-ncv"]
  region      = "nyc-region"
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
        DB_SERVERS      = "mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
        SERVICE_PORT    = "3000"
        CONSUL_IP       = "consul.service.consul"
        CONSUL_SCHEME   = "https"
        CONSUL_HTTP_SSL = "true"
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
        image   = "crizstian/notification-service-go:v0.4"
      }

      env {
        SERVICE_PORT    = "3001"
        CONSUL_IP       = "consul.service.consul"
        CONSUL_SCHEME   = "https"
        CONSUL_HTTP_SSL = "true"
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
          "-service", "gateway-secondary",
          "-address", ":${NOMAD_PORT_proxy}",
          "-wan-address", "172.20.20.21:${NOMAD_PORT_proxy}",
          "-admin-bind", "127.0.0.1:19005",
          "-token", "c6b64436-5f05-deba-c579-ef7d08de8763",
          "-deregister-after-critical", "5s",
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