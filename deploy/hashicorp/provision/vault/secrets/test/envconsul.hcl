vault {
  address = "http://vault.service.consul:8200"
  token   = "s.yppvHaopaVWkhe9eUPb4h7tg"
  renew_token   = false
}

secret {
  no_prefix = true
  path   = "secret/booking-service"
}