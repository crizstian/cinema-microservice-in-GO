kind     = "service-router"
name     = "payment-api"

routes = [
  {
    match {
      http {
        path_regex = "/payment/makePurchase"
      }
    }

    destination {
      service = "payment-api"
      service_subset = "v1"
    }
  },
  {
    match {
      http {
        path_prefix = "/v2"
      }
    }

    destination {
      service = "payment-api"
      service_subset = "v2"
    }
  },
]
