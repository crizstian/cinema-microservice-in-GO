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

  connect = {
    sidecar_service = {
      port = 20000,
      check = {
        name = "Connect Envoy Sidecar",
        tcp = "10.7.0.9:20000",
        interval = "10s"
      },
      proxy = {
        upstreams = [
          {
            destination_name = "payment",
            local_bind_address = "127.0.0.1",
            local_bind_port = 9091
          },
          {
            destination_name = "notification",
            local_bind_address = "127.0.0.1",
            local_bind_port = 9092
          }
        ]
      }
    }
  }
}