job "cinemas-microservice" {

  datacenters = ["aero-aws-us-west-1"]
  region      = "aero-aws-us-west-1-region"
  type        = "service"

  constraint {
    attribute = "${node.class}"
    value     = "app"
  }

  group "movies-api" {
    count = 1

    task "movies-api" {
      driver = "docker"
      config {
        image   = "crizstian/movies-service-go:v0.1"
        port_map {
          service_port = 3000
        }
      }

      env {
       DB="movies"
       DB_USER="cristian"
       DB_PASS="cristianPassword2017"
       PORT="3000"
       DB_SERVERS="mongodb1.query.consul:27017,mongodb2.query.consul:27017,mongodb3.query.consul:27017"
      }

      resources {
        network {
            mbits = 10
            port "service_port" {}
            port "aero" {}
        }
      }
      service {
        name = "movies-api"
        tags = [ "cinemas-microservice" ]
        port = "service_port"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}