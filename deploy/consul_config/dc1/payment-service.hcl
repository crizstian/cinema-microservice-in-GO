services {
  id = "payemnt-api"
  name = "payemnt-api"
  tags = [
    "cinemas project",
    "v1"
  ]
  address = "10.7.0.7"
  port = 8100
  checks = [
    {
      id = "payemnt-api",
      name = "payemnt-api TCP on port 8100",
      http = "http://0.0.0.0:8100/ping",
      method = "GET",
      interval = "10s",
      timeout = "1s"
    }
  ]
}