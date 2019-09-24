services {
  id = "notification-api"
  name = "notification-api"
  tags = [
    "cinemas project",
    "v1"
  ]
  address = "10.7.0.8"
  port = 8000
  checks = [
    {
      id = "notification-api",
      name = "notification-api TCP on port 8000 internal",
      http = "http://10.7.0.8:8000/ping",
      method = "GET",
      interval = "10s",
      timeout = "1s"
    }
  ]
}