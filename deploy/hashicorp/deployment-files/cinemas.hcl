job "cinemas" {

  datacenters = ["dc1-ncv"]
  region      = "dc1-region"
  type        = "service"

  group "payment-api" {
    count = 1

    task "paymentapi" {
      driver = "docker"
      config {
        image   = "crizstian/payment-service-go:v0.1"
      }

      env {
        DB_USER="cristian"
        DB_PASS="cristianPassword2017"
        DB_SERVERS="mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
        DB_NAME="payment"
        DB_REPLICA="rs1"
        SERVICE_PORT="3000"
        STRIPE_SECRET="sk_test_lPPoJjmmbSjymtgo4r0O3z89"
        STRIPE_PUBLIC="pk_test_l10342hIODZmOJsBpY6GVPHj"
      }

      resources {
        cpu    = 100
        memory = 200
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "payment-api"
      port = "3000"

      connect {
        sidecar_service {}
      }
    }
  }

  group "notification-api" {
    count = 1

    task "notificationapi" {
      driver = "docker"
      config {
        image   = "crizstian/notification-service-go:v0.1"
      }

      env {
        SERVICE_PORT="3001"
        EMAIL="cristiano.rosetti@gmail.com"
        EMAIL_PASS="Cris123@#"
      }

      resources {
        cpu    = 100
        memory = 200
      }
    }

    network {
      mode = "bridge"
    }

    service {
      name = "notification-api"
      port = "3001"

      connect {
        sidecar_service {}
      }
    }
  }


  group "booking-service" {
    count = 1

    task "booking-service" {
      driver = "docker"
      config {
        image   = "crizstian/booking-service-go:v0.1"
      }

      env {
        DB_USER="cristian"
        DB_PASS="cristianPassword2017"
        DB_SERVERS="mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
        DB_NAME="booking"
        DB_REPLICA="rs1"
        SERVICE_PORT="3002"
        PAYMENT_URL="http://${NOMAD_UPSTREAM_ADDR_payment_api}"
        NOTIFICATION_URL="http://${NOMAD_UPSTREAM_ADDR_notification_api}"
      }

      resources {
        cpu    = 100
        memory = 200
      }
    }

    network {
      mode = "bridge"
      port "http" {
        static = 3002
        to     = 3002
      }
    }

    service {
      name = "booking-api"
      port = "3002"

      connect {
        sidecar_service {
          proxy {
            upstreams {
               destination_name = "payment-api"
               local_bind_port = 8080
            }
            upstreams {
               destination_name = "notification-api"
               local_bind_port = 8081
            }
          }
        }
      }
    }
  }
}