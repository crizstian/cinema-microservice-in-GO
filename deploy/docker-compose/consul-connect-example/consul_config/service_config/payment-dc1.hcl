services {
  id = "payment-dc1"
  name = "payment"
  tags = [
    "cinemas-project",
    "v1"
  ]
  address = "10.10.0.7"
  port = 8000
  checks = [
    {
      id = "payment-dc1",
      name = "payment-dc1 TCP on port 8000 internal",
      tcp = "10.10.0.7:8000",
      interval = "10s",
      timeout = "1s"
    }
  ]
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