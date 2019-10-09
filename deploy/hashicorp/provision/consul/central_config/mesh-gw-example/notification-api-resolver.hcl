kind     = "service-resolver"
name     = "notification-api"

failover = {
  "*" = {
    datacenters = ["dc2"]
  }
}
