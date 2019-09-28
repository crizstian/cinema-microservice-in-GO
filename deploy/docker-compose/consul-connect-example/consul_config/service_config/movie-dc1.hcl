services {
  id = "movie-dc1"
  name = "movie"
  tags = [
    "cinemas-project",
    "v1"
  ]
  address = "10.10.0.6"
  port = 8000
  checks = [
    {
      id = "movie-dc1",
      name = "movie-dc1 TCP on port 8000 internal",
      tcp = "10.10.0.6:8000",
      interval = "10s",
      timeout = "1s"
    }
  ]
  connect = {
    sidecar_service = {
      port = 20000,
      check = {
        name = "Connect Envoy Sidecar",
        tcp = "10.10.0.6:20000",
        interval = "10s"
      },
      proxy = {}
    }
  }
}