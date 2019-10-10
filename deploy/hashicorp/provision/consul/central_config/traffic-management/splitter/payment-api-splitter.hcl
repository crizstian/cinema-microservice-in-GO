kind = "service-splitter"
name = "payment-api"

splits = [
  {
    weight = 60,
    service_subset = "v1"
  },
  {
    weight = 40,
    service_subset = "v2"
  }
]
