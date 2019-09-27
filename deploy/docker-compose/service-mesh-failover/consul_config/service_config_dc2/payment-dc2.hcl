services {
  id = "payment"
  name = "payment-dc2"
  tags = [
    "cinemas project",
    "v1"
  ]
  address = "10.8.0.7"
  port = 8000
  checks = [
    {
      id = "payment-dc2",
      name = "payment-dc2 TCP on port 8000 internal",
      http = "http://10.8.0.7:8000/ping",
      method = "GET",
      interval = "10s",
      timeout = "1s"
    }
  ]

  connect = {
    sidecar_service = {
      port = 20000,
        check = {
          name = "Connect Envoy Sidecar",
          tcp = "10.8.0.7:20000",
          interval = "10s"
        },
        proxy = {}
    }
  }
}