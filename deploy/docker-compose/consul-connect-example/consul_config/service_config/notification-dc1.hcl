services {
  id = "notification-dc1"
  name = "notification"
  tags = [
    "cinemas-project",
    "v1"
  ]
  address = "10.10.0.8"
  port = 8000
  check = {
    id = "notification-dc1",
    name = "notification-dc1 TCP on port 8000 internal",
    tcp = "10.10.0.8:8000",
    interval = "10s",
    timeout = "1s"
  }
  connect = {
    sidecar_service = {
      port = 20000,
      check = {
        name = "Connect Envoy Sidecar",
        tcp = "10.10.0.8:20000",
        interval = "10s"
      },
      proxy = {}
    }
  }
}