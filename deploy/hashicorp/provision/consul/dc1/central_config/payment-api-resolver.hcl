kind     = "service-resolver"
name     = "payment-api"

failover = {
  "*" = {
    datacenters = ["dc2"]
  }
}
