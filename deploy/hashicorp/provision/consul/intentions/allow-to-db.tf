resource "consul_intention" "allow-booking-to-db1" {
  source_name      = "booking-service"
  destination_name = "mongodb1"
  action           = "allow"
}
resource "consul_intention" "allow-booking-to-db2" {
  source_name      = "booking-service"
  destination_name = "mongodb2"
  action           = "allow"
}
resource "consul_intention" "allow-booking-to-db3" {
  source_name      = "booking-service"
  destination_name = "mongodb3"
  action           = "allow"
}

resource "consul_intention" "allow-payment-to-db1" {
  source_name      = "payment-api"
  destination_name = "mongodb1"
  action           = "allow"
}
resource "consul_intention" "allow-payment-to-db2" {
  source_name      = "payment-api"
  destination_name = "mongodb2"
  action           = "allow"
}
resource "consul_intention" "allow-payment-to-db3" {
  source_name      = "payment-api"
  destination_name = "mongodb3"
  action           = "allow"
}


resource "consul_intention" "allow-notification-to-db1" {
  source_name      = "notification-api"
  destination_name = "mongodb1"
  action           = "allow"
}
resource "consul_intention" "allow-notification-to-db2" {
  source_name      = "notification-api"
  destination_name = "mongodb2"
  action           = "allow"
}
resource "consul_intention" "allow-notification-to-db3" {
  source_name      = "notification-api"
  destination_name = "mongodb3"
  action           = "allow"
}

