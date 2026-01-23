job "nginx-web-service" {

  datacenters = ["aero-aws-us-west-1"]
  region      = "aero-aws-us-west-1-region"
  type        = "service"

   constraint {
      operator  = "distinct_hosts"
      value     = "true"
    }

  group "nginx-web-service" {
    count = 3

    task "nginx-web-service" {
      driver = "docker"
      config {
        image = "crizstian/webserver:v0.2"
        force_pull = true
        port_map {
          https = 443
        }
      }

    resources {
      network {
          mbits = 10
          port "https" {
            static = 443
          }
          port "aero" {}
        }
      }
    }
  }
}