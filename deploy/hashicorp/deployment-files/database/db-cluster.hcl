job "cinemas-db" {

  datacenters = ["sfo-ncv"]
  region      = "sfo-region"
  type        = "service"

  group "mongo-cluster" {
    count = 1

    task "mongodb1" {
      driver = "docker"
      config {
        image   = "crizstian/cinemas-db:v0.4"
        port_map {
          service_port = 27017
        }
      }

      env {
        DB_PORT         = "27017"
        DB1             = "${NOMAD_ADDR_mongodb1_service_port}"
        DB2             = "${NOMAD_ADDR_mongodb2_service_port}"
        DB3             = "${NOMAD_ADDR_mongodb3_service_port}"        
        CONSUL_IP       = "consul.service.consul"
      }

      resources {
        network {
            mbits = 10
            port "service_port" {
              static = 27017
            }
        }
      }
      service {
        name = "mongodb1"
        tags = [ "cinemas-microservice-db", "db1" ]
        port = "service_port"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    task "mongodb2" {
      driver = "docker"
      config {
        image   = "crizstian/cinemas-db:v0.4"
        port_map {
          service_port = 27017
        }
      }

      env {
        DB_PORT         = "27017"
        DB1             = "${NOMAD_ADDR_mongodb1_service_port}"
        DB2             = "${NOMAD_ADDR_mongodb2_service_port}"
        DB3             = "${NOMAD_ADDR_mongodb3_service_port}"        
        CONSUL_IP       = "consul.service.consul"
      }

      resources {
        network {
            mbits = 10
            port "service_port" {
              static = 27018
            }
        }
      }
      service {
        name = "mongodb2"
        tags = [ "cinemas-microservice-db", "db2" ]
        port = "service_port"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    task "mongodb3" {
      driver = "docker"
      config {
        image   = "crizstian/cinemas-db:v0.4"
        port_map {
          service_port = 27017
        }
      }

      env {
        DB_PORT         = "27017"
        DB1             = "${NOMAD_ADDR_mongodb1_service_port}"
        DB2             = "${NOMAD_ADDR_mongodb2_service_port}"
        DB3             = "${NOMAD_ADDR_mongodb3_service_port}"        
        CONSUL_IP       = "consul.service.consul"
      }

      resources {
        network {
            mbits = 10
            port "service_port" {
              static = 27019
            }
        }
      }
      service {
        name = "mongodb3"
        tags = [ "cinemas-microservice-db", "db3" ]
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