services {
  id = "movie-api"
  name = "movie-api"
  tags = [
    "cinemas project",
    "v1"
  ]
  address = "10.7.0.6"
  port = 8000
  checks = [
    {
      id = "movie-api",
      name = "movie-api TCP on port 8000 internal",
      tcp = "10.7.0.6:8000",
      interval = "10s",
      timeout = "1s"
    }
  ]
}