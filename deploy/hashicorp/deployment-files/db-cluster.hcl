job "db-cluster" {

  datacenters = ["dc1-ncv"]
  region      = "dc1-region"
  type        = "service"

  group "db-cluster" {
    count = 1

    task "mongodb1" {
      driver = "docker"
      config {
        image   = "crizstian/cinemas-db:v0.1"
        port_map {
          service_port = 27017
        }
      }

      env {
        DB_ADMIN_USER = "cristian"
        DB_ADMIN_PASS = "cristianPassword2017"
        DB_REPLICA_ADMIN = "replicaAdmin"
        DB_REPLICA_ADMIN_PASS = "replicaAdminPassword2017"
        DB_REPLSET_NAME = "rs1"
        DB_PORT = "27017"
        IS_PRIMARY = "false"
      }

      resources {
        network {
            mbits = 10
            port "service_port" {
              static = 27017
            }
            port "aero" {}
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
        image   = "crizstian/cinemas-db:v0.1"
        port_map {
          service_port = 27017
        }
      }

      env {
        DB_ADMIN_USER = "cristian"
        DB_ADMIN_PASS = "cristianPassword2017"
        DB_REPLICA_ADMIN = "replicaAdmin"
        DB_REPLICA_ADMIN_PASS = "replicaAdminPassword2017"
        DB_REPLSET_NAME = "rs1"
        DB_PORT = "27017"
        IS_PRIMARY = "false"
      }

      resources {
        network {
            mbits = 10
            port "service_port" {
              static = 27018
            }
            port "aero" {}
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
        image   = "crizstian/cinemas-db:v0.1"
        port_map {
          service_port = 27017
        }
      }

      env {
        DB_ADMIN_USER = "cristian"
        DB_ADMIN_PASS = "cristianPassword2017"
        DB_REPLICA_ADMIN = "replicaAdmin"
        DB_REPLICA_ADMIN_PASS = "replicaAdminPassword2017"
        DB_REPLSET_NAME = "rs1"
        DB_PORT = "27017"
        DB3 = "${NOMAD_ADDR_mongodb1_service_port}"
        DB2 = "${NOMAD_ADDR_mongodb2_service_port}"
        DB1 = "${NOMAD_ADDR_mongodb3_service_port}"
        IS_PRIMARY = "true"
      }

      resources {
        network {
            mbits = 10
            port "service_port" {
              static = 27019
            }
            port "aero" {}
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


  # group "movies-api" {
  #   count = 1

    #     restart {
    #   interval = "30s"
    #   attempts = 10
    #   delay    = "15s"
    #   mode     = "delay"
    # }

  #   task "movies-api" {
  #     driver = "docker"
  #     config {
  #       image   = "crizstian/movies-service-go:v0.1"
  #       port_map {
  #         service_port = 3000
  #       }
  #     }

  #     env {
  #      DB="movies"
  #      DB_USER="cristian"
  #      DB_PASS="cristianPassword2017"
  #      PORT="3000"
  #      DB_SERVERS="mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
  #     }

  #     resources {
  #       network {
  #           mbits = 10
  #           port "service_port" {}
  #           port "aero" {}
  #       }
  #     }
  #     service {
  #       name = "movies-api"
  #       tags = [ "cinemas-microservice" ]
  #       port = "service_port"
  #       check {
  #         type     = "tcp"
  #         interval = "10s"
  #         timeout  = "2s"
  #       }
  #     }
  #   }
  # }
}