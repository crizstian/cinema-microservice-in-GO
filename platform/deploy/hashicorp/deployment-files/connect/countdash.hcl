job "countdash" {
  datacenters = ["sfo-ncv"]
  region      = "sfo-region"
  type        = "service"

  group "api" {
    count = 1

    network {
      mode = "bridge"

      port "healthcheck" {
        to = -1
      }
    }

    service {
      name = "count-api"
      port = "9001"

      check {
        name     = "api-health"
        port     = "healthcheck"
        type     = "http"
        protocol = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "3s"
        expose   = true
      }

      connect {
        sidecar_service {}
      }
    }

    task "web" {
      driver = "docker"

      config {
        image = "hashicorpnomad/counter-api:v1"
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }
  }

  group "dashboard" {
    count = 1
    
    network {
      mode = "bridge"

      port "http" {
        static = 9002
        to     = 9002
      }

      port "healthcheck" {
        to = -1
      }
    }

    service {
      name = "count-dashboard"
      port = "http"

      check {
        name     = "dashboard-health"
        port     = "healthcheck"
        type     = "http"
        protocol = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "3s"
        expose   = true
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "count-api"
              local_bind_port  = 8080
            }
          }
        }
      }
    }

    task "dashboard" {
      driver = "docker"

      env {
        COUNTING_SERVICE_URL = "http://${NOMAD_UPSTREAM_ADDR_count_api}"
      }

      config {
        image = "hashicorpnomad/counter-dashboard:v1"
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }
  }
}