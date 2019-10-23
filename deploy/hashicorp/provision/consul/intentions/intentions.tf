provider "consul" {
  address    = "172.20.20.11:8500"
  datacenter = "dc1"
}

resource "consul_intention" "allow-booking-to-payment" {
  source_name      = "booking-service"
  destination_name = "payment-api"
  action           = "allow"
}

resource "consul_intention" "allow-booking-to-notification" {
  source_name      = "booking-service"
  destination_name = "notification-api"
  action           = "allow"
}

resource "consul_intention" "allow-payment-to-booking" {
  source_name      = "payment-api"
  destination_name = "booking-service"
  action           = "allow"
}

resource "consul_intention" "allow-notification-to-booking" {
  source_name       = "notification-api"
  destination_name  = "booking-service"
  action            = "allow"
}

resource "consul_intention" "deny-all" {
  source_name      = "*"
  destination_name = "*"
  action           = "deny"
}
