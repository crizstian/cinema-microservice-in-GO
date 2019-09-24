services {
  id = "payemnt-api"
  name = "payemnt-api"
  tags = [
    "cinemas project",
    "v1"
  ]
  address = "10.7.0.7"
  port = 8000
  checks = [
    {
      id = "payemnt-api",
      name = "payemnt-api TCP on port 8000 internal",
      http = "http://10.7.0.7:8000/ping",
      method = "GET",
      interval = "10s",
      timeout = "1s"
    }
  ]
}