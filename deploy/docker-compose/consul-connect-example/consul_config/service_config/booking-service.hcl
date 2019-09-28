services {
  id   = "booking-dc1"
  name = "booking"
  tags = [
    "cinemas-project",
    "v1"
  ]
  address = "10.10.0.9"
  port    = 8000
  checks  = [
    {
      id       = "booking-dc1",
      name     = "booking TCP on port 8000 internal",
      tcp      = "10.10.0.9:8000",
      interval = "10s",
      timeout  = "1s"
    }
  ]
  connect = {
    sidecar_service = {
      port  = 20000,
      check = {
        name     = "Connect Envoy Sidecar",
        tcp      = "10.10.0.8:20000",
        interval = "10s"
      },
      proxy = {
        # destination_service_name = "booking"
        # destination_service_id = "booking-dc1"
        upstreams = [
          {
            destination_name   = "payment",
            local_bind_address = "127.0.0.1",
            local_bind_port    = 9091
          },
          {
            destination_name   = "notification",
            local_bind_address = "127.0.0.1",
            local_bind_port    = 9092
          }
        ]
      }
    }
  }
}