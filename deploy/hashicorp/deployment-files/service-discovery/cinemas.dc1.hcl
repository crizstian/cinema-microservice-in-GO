job "cinemas" {

  datacenters = ["sfo-ncv"]
  region      = "sfo-region"
  type        = "service"

  group "payment-api" {
    count = 1

    task "payment-api" {
      driver = "docker"
      config {
        image   = "crizstian/payment-service-go:v0.4"
      }

      env {
        SERVICE_PORT    = "3000"
        DB_SERVERS      = "mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
        CONSUL_IP       = "consul.service.consul"
        CONSUL_SCHEME   = "https"
        CONSUL_HTTP_SSL = "true"
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }

    network {
      mode = "bridge"
      port "http" {
        static = 3000
        to     = 3000
      }
    }

    service {
      name = "payment-api"
      port = "http"
      tags = ["${NOMAD_JOB_NAME}"]

      check {
        type     = "http"
        port     = "http"
        path     = "/ping"
        interval = "5s"
        timeout  = "2s"
      }
    }
  }


  group "notification-api" {
    count = 1

    task "notification-api" {
      driver = "docker"
      config {
        image   = "crizstian/notification-service-go:v0.4"
      }

      env {
        SERVICE_PORT    = "3001"
        CONSUL_IP       = "consul.service.consul"
        CONSUL_SCHEME   = "https"
        CONSUL_HTTP_SSL = "true"
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }

    network {
      mode = "bridge"
      port "http" {
        static = 3001
        to     = 3001
      }
    }

    service {
      name = "notification-api"
      port = "http"
      tags = ["${NOMAD_JOB_NAME}"]

      check {
        type     = "http"
        port     = "http"
        path     = "/ping"
        interval = "5s"
        timeout  = "2s"
      }
    }
  }


  group "booking-api" {
    count = 1

    task "booking-api" {
      driver = "docker"
      config {
        image   = "crizstian/booking-service-go:v0.4"
      }

      env {
        SERVICE_PORT     = "3002"
        CONSUL_IP        = "consul.service.consul"
        DB_SERVERS       = "mongodb1.query.consul:27017,mongodb2.query.consul:27018,mongodb3.query.consul:27019"
        PAYMENT_URL      = "http://payment-api.service.consul:3000"
        NOTIFICATION_URL = "http://notification-api.service.consul:3001"
        CONSUL_SCHEME    = "https"
        CONSUL_HTTP_SSL  = "true"
      }

      resources {
        cpu    = 50
        memory = 50
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
      port = "http"
      tags = ["${NOMAD_JOB_NAME}"]

      check {
        type     = "http"
        port     = "http"
        path     = "/ping"
        interval = "5s"
        timeout  = "2s"
      }
    }
  }
}