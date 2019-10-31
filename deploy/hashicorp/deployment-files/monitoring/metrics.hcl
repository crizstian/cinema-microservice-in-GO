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
          "/vagrant/deployment-files/monitoring/grafana/config.ini:/etc/grafana/config.ini",
          "/vagrant/deployment-files/monitoring/grafana/provisioning:/etc/grafana/provisioning",
          "/vagrant/deployment-files/monitoring/grafana/dashboards:/var/lib/grafana/dashboards"
        ]
      }

      env {
        GF_SECURITY_ADMIN_PASSWORD="secret"
        GF_INSTALL_PLUGINS="grafana-clock-panel,briangann-gauge-panel,natel-plotly-panel,grafana-simple-json-datasource"
      }

      resources {
        cpu    = 50
        memory = 50

        network {
            mbits = 10
            port "service_port" {
            static = 3999
            to     = 3999
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

  group "telegraf" {
      
    task "telegraf" {
      driver = "docker"
      config {
        image = "telegraf"
         volumes = [
          "/vagrant/deployment-files/monitoring/telegraf/telegraf.conf:/etc/telegraf/telegraf.conf",
        ]
        port_map {
          service_port = 8125
        }
      }

      resources {
        cpu    = 50
        memory = 50
        network {
            mbits = 10
            port "service_port" {
              static = 8125
            }
        }
      }
      
      service {
        name = "telegraf"
        port = "service_port"
      }
    }
  }

  group "jaeger" {
    task "jaeger" {
      driver = "docker"
      config {
        image = "jaegertracing/all-in-one:1.13"
        command = "--log-level=debug"
         port_map {
          service_port_1 = 6831
          service_port_2 = 6832
          service_port_3 = 16686
        }
      }

      resources {
        cpu    = 50
        memory = 50

        network {
          mbits = 10
          port "service_port_1" {
            static = 6831
            to     = 6831
          }
          port "service_port_2" {
            static = 6832
            to     = 6832
          }
          port "service_port_3" {
            static = 16686
            to     = 16686
          }
        }
      }

      service {
        name = "jaeger"
        port = "service_port_3"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}