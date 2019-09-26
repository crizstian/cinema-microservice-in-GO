services {
  id = "booking-api"
  name = "booking-api"
  tags = [
    "cinemas project",
    "v1"
  ]
  address = "10.7.0.9"
  port = 8000
  checks = [
    {
      id = "booking-api",
      name = "booking-api TCP on port 8000 internal",
      http = "http://10.7.0.9:8000/ping",
      method = "GET",
      interval = "10s",
      timeout = "1s"
    }
  ]
}