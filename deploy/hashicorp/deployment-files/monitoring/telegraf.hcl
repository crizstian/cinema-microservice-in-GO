job "telegraf" {

  datacenters = ["dc1-ncv"]
  region      = "dc1-region"
  type        = "service"

  group "telegraf" {
      
    task "telegraf" {
      driver = "docker"
      config {
        image = "telegraf"
         volumes = [
          "/vagrant/deployment-files/monitoring/telegraf.conf:/etc/telegraf/telegraf.conf",
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
}