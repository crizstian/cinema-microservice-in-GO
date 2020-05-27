kind     = "service-resolver"
name     = "payment-api"

failover = {
  "*" = {
    datacenters = ["nyc"]
  }
}
