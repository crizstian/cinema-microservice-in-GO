job "metrics" {

  datacenters = ["dc1-ncv"]
  region      = "dc1-region"
  type        = "service"

  group "grafana" {

    task "grafana" {
      driver = "docker"
      config {
        image = "grafana/grafana"
         port_map {
          service_port = 3000
        }

        volumes = [
          "/vagrant/deployment-files/observability/grafana/config.ini:/etc/grafana/config.ini",
          "/vagrant/deployment-files/observability/grafana/provisioning:/etc/grafana/provisioning",
          "/vagrant/deployment-files/observability/grafana/dashboards:/var/lib/grafana/dashboards"
        ]
      }

      env {
        GF_SECURITY_ADMIN_PASSWORD="secret"
      }

      resources {
        cpu    = 50
        memory = 50

        network {
            mbits = 10
            port "service_port" {
              static = 3999
            }
        }
      }

      service {
        name = "grafana"
        port = "service_port"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }

  group "prometheus" {
    task "prometheus" {
      driver = "docker"
      config {
        image = "prom/prometheus"
         port_map {
          service_port = 9090
        }

        volumes = [
          "/vagrant/deployment-files/observability/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml"
        ]
      }

      resources {
        cpu    = 50
        memory = 50

        network {
            mbits = 10
            port "service_port" {
              static = 9990
            }
        }
      }

      service {
        name = "prometheus"
        port = "service_port"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }

  group "jaeger" {
    task "jaeger" {
      driver = "docker"
      config {
        image = "jaegertracing/all-in-one:1.13"
         port_map {
          service_port_1 = 5775
          service_port_2 = 6831
          service_port_3 = 6832
          service_port_4 = 5778
          service_port_5 = 16686
          service_port_6 = 14268
          service_port_7 = 9411
        }
      }

      env {
        COLLECTOR_ZIPKIN_HTTP_PORT=9411
      }


      resources {
        cpu    = 50
        memory = 50

        network {
          mbits = 10
          port "service_port_1" {
            static = 5775
          }
          port "service_port_2" {
            static = 6831
          }
          port "service_port_3" {
            static = 6832
          }
          port "service_port_4" {
            static = 5778
          }
          port "service_port_5" {
            static = 16686
            to     = 16686
          }
          port "service_port_6" {
            static = 14268
          }
          port "service_port_7" {
            static = 9411
            to     = 9411
          }
        }
      }

      service {
        name = "jaeger"
        port = "service_port_7"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}