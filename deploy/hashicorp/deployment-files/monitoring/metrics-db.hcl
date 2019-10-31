job "metrics-db" {

  datacenters = ["dc1-ncv"]
  region      = "dc1-region"
  type        = "service"

  group "influxdb" {

    task "influxdb" {
      driver = "docker"
      config {
        image = "influxdb"
         port_map {
          service_port_1 = 8083
          service_port_2 = 8086
        }

        volumes = [
          "/vagrant/deployment-files/monitoring/influxdb/influxdb.conf:/etc/influxdb/influxdb.conf"
        ]
      }

      env {
        INFLUXDB_DATA_ENGINE="tsm1"
        INFLUXDB_REPORTING_DISABLED="false"
      }

      resources {
        cpu    = 50
        memory = 50

        network {
            mbits = 10
            port "service_port_1" {
              static = 8083
            }
            port "service_port_2" {
              static = 8086
            }
        }
      }

      service {
        name = "influxdb"
        port = "service_port_2"
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
          "/vagrant/deployment-files/monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml"
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
}