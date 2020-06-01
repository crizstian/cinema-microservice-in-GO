job "ingress-nginx" {

  datacenters = ["sfo-ncv"]
  region      = "sfo-region"
  type        = "service"


  group "nginx-web-service" {
    count = 1

    network {
      mode = "bridge"

      port "https" {
        static = 443
        to     = 443
      }

      port "healthcheck" {
        static = 80
        to     = 80
      }
    }

    service {
      name = "nginx-web-service"
      port = "https"
      tags = ["ingress-lb", "ENTRY"]

      check {
        name     = "nginx-web-service-health"
        port     = "healthcheck"
        type     = "http"
        protocol = "http"
        path     = "/"
        interval = "10s"
        timeout  = "3s"
        expose   = true
      }
    }

    task "nginx-web-service" {
      driver = "docker"
      config {
        image = "crizstian/cinemas-web-server:v0.1"
        force_pull = true
      }

      env {
        SERVICE_PORT    = "80"
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
}